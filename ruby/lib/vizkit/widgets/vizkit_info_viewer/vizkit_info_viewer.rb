require 'utilrb/qt/variant/from_ruby.rb'
# Graphical user interface displaying information of a Utilrb::EventLoop
# such as queued tasks and worker threads executing the tasks. The key
# information is the task's time consumption. Completed tasks are no 
# longer displayed.
# 
# Periodical timers are listed, as well. You even have basic interactive
# possibilities such as cancelling the timer and setting the period.
#
# This GUI is intended to help developers debug their own GUIs or other
# applications with asynchronous components by identifying 'hanging' tasks 
# like network communication etc.
#
# @author Allan Conquest <allan.conquest@dfki.de>
class VizkitInfoViewer

    # The number of ms after which the trees are being updated.
    # Note: Do not set this value too low because that could
    #       make double-click interactions impossible.
    attr_reader :update_frequency #ms
    
    # Tasks with runtimes shorter than this threshold are being ignored.
    attr_reader :time_threshold #ms

    # Is a timer currently being edited by the user?
    @on_edit = false
    
    # The timer which is being edited right now.
    @edited_timer = nil
    
    # The position of the tab for log messages in the tab view
    LOG_TAB_INDEX = 1 if !defined? LOG_TAB_INDEX
    
    # Column in event timer tree view storing the data object
    TIMER_DATA_COLUMN = 1

    module Functions
        def init(parent = nil, update_frequency = 500, time_threshold = 1000)
            @event_loop = Orocos::Async.event_loop
            Kernel.raise "No event loop available!" unless @event_loop
            register_for_errors
            
            @update_frequency = update_frequency
            @time_threshold = time_threshold
            
            @thread_pool = @event_loop.thread_pool
            
            
            # References to the objects in the view
            @item_hash = Hash.new
            
            # Local keep-alive references of cancelled timers. 
            # Start them again to re-add them to the event loop.
            @cancelled_timers = []

            update_timer = Qt::Timer.new
            update_timer.connect(SIGNAL('timeout()')) do
                update
            end
            
            # Actions on tasks
            @action_stop_task = Qt::Action.new("Stop", self)
            
            # Actions on event timers
            @action_cancel_timer = Qt::Action.new("Cancel", self)
            @action_start_timer = Qt::Action.new("Start", self)
            @action_delete_timer = Qt::Action.new("Delete", self)
            
            # Context menus
            task_menu = Qt::Menu.new(self)
            treeWidget.set_context_menu_policy(Qt::CustomContextMenu)
            task_menu.add_action(@action_stop_task)
            
            event_timer_menu = Qt::Menu.new(self)
            event_tree.set_context_menu_policy(Qt::CustomContextMenu)
            event_timer_menu.add_action(@action_cancel_timer)
            event_timer_menu.add_action(@action_start_timer)
            event_timer_menu.add_action(@action_delete_timer)

            # Task tree
            task_column_headers = ["Task", "Time elapsed", "State"]
            treeWidget.set_column_count(task_column_headers.size)
            treeWidget.set_header_labels(task_column_headers)
            treeWidget.set_edit_triggers(Qt::AbstractItemView::NoEditTriggers)

            @active_task_item = Qt::TreeWidgetItem.new
            @active_task_item.set_text(0, "Active tasks")
            treeWidget.add_top_level_item(@active_task_item)

            @waiting_task_item = Qt::TreeWidgetItem.new
            @waiting_task_item.set_text(0, "Waiting tasks")
            treeWidget.add_top_level_item(@waiting_task_item)
            
            treeWidget.expand_to_depth 1
            
            # Event tree with timers
            event_column_headers = ["Timer","Period","State"]
            event_tree.set_column_count(event_column_headers.size)
            event_tree.set_header_labels(event_column_headers)
            event_tree.set_edit_triggers(Qt::AbstractItemView::NoEditTriggers)
            
            event_tree.connect(SIGNAL('itemDoubleClicked(QTreeWidgetItem*, int)')) do |item, col|
                if column_editable?(col)
                    if start_edit(item)
                        #event_tree.open_persistent_editor(item, col)
                        event_tree.edit_item(item, col)
                    end
                end
            end
            
            event_tree.connect(SIGNAL('itemChanged(QTreeWidgetItem*, int)')) do |item, col|
                # TODO The persistent editor does not get closed if the item's text does not change.
                if column_editable?(col)
                    #timer = @item_hash[item]
                    timer = item_data(item).to_ruby
                    timer.period = item.text(col).to_f
                    if end_edit(item)
                        #event_tree.close_persistent_editor(item, col)
                    end
                end
            end

            event_tree.expand_to_depth 1
            
            # Setup context menus on each view
            [treeWidget, event_tree].each do |view|
                view.connect(SIGNAL('customContextMenuRequested(const QPoint&)')) do |pos|
                    item = view.item_at(pos)
                    next unless item
                    object = item_data(item).to_ruby
                    if object
                        menu = case view
                            when treeWidget then task_menu
                            when event_tree then event_timer_menu
                            else Kernel.raise "Unsupported view"
                        end
                        context_menu(menu, view.viewport.mapToGlobal(pos), object)
                    end
                end
            end
            update
            
            # Other initializations
            update_timer.start(@update_frequency)
            
            # Display notification when new logs arrived
            # TODO use cleaner approach with 'validate/invalidate' operation
            # TODO reset notification on tab click
         #   tabWidget.log_text_browser.connect(SIGNAL('textChanged()')) do
         #       # Append '*' to the log tab's title
         #       tabWidget.set_tab_text(LOG_TAB_INDEX,"#{tabWidget.tab_text(LOG_TAB_INDEX)}*")
         #   end
            
            update_tree_view
        end
        
        # Opens given (context) menu at given position (in global coordinates).
        # Submit the object the chosen action shall work on, i.e. a task or timer.
        def context_menu(menu, pos, object)
            action = menu.exec(pos)
            case action
                # Task actions
                when @action_stop_task then
                    object.terminate!
                # Event timer actions
                when @action_cancel_timer then
                    if timer_cancelled?(object)
                        Vizkit.warn "You cannot cancel timers twice."
                    else
                        object.cancel
                        @cancelled_timers << object
                    end
                when @action_start_timer then
                    if timer_cancelled?(object)
                        @cancelled_timers.delete object
                        object.start
                    else
                        Vizkit.warn "You cannot start timers twice."
                    end
                when @action_delete_timer then
                    object.cancel
                    @cancelled_timers.delete object
                when nil
                    # Ignore if no action is returned at all, e.g. if you discard the context menu.
                else Kernel.raise "Unsupported action"
            end
            
            update
        end

        def update
            ## Update task tree
            
            # Remove all tasks from tree
            #@active_task_item.take_children
            #@waiting_task_item.take_children
            
            # Add updated tasks to tree
            @thread_pool.tasks.each do |task|
                item = nil
                
                # Ignore tasks which have not yet run long enough but are already started.
                next if task.started? and task.time_elapsed <= @time_threshold / 1000
                
                if task.started?
                    item = @active_task_item 
                else
                    item = @waiting_task_item
                end
                
                child = task_data_item(task)
                item.add_child(child)

                # Make task accessible for context menu
                @item_hash[child] = task
            end
            
            ## Update event loop timer tree
            
            # Skip event update if a timer edit is happening.
            #if not @on_edit
                
                # Update current event timer items and remove obsolete items.
                dirty_children = []
                
                # temp list
                displayed_timers = []
                
                root_item = event_tree.invisible_root_item
                ctr = 0
                
                while ctr < root_item.child_count do
                    child = root_item.child(ctr)
                    
                    list = (@event_loop.timers + @cancelled_timers)
                    timer = item_data(child).to_ruby
                    if list.include? timer
                        #debugger
                        # child represents a non-obsolete timer. update.
                        if @cancelled_timers.include? timer
                            # display as cancelled
                            update_timer_item(child, timer, true)
                        else
                            update_timer_item(child, timer, false)
                        end
                        # add item's timer object to temp list
                        displayed_timers << item_data(child).to_ruby
                        
                        # TODO handle items that are currently being edited
                    else
                        # Mark obsolete event timer items for removal
                        dirty_children << child
                    end
                    ctr = ctr + 1
                end
                
                # Remove obsolete event timer items
                dirty_children.each do |child|
                    ret = event_tree.take_top_level_item(event_tree.invisible_root_item.index_of_child(child))
                    Kernel.raise "Error during item deletion" unless ret
                end
                
                # Check for new event timers
                (@event_loop.timers - displayed_timers).each do |t|
                    next if t.single_shot?
                    
                    # Add item to tree
                    child = event_timer_data_item(t, false)
                    event_tree.add_top_level_item(child)
                end
                
                
                # Add current timer information      
                #@event_loop.timers.each do |t|
                #    # Ignore non-periodic timers. Not necessary for cancelled 
                #    # timers (see below) because single shot timers never get displayed.
                #    next if t.single_shot? 
                #    child = event_timer_data_item(t, false)
                #    @item_hash[child] = t
                #    event_tree.add_top_level_item(child)
                #end
                
                # Add local copies of cancelled timers
                #@cancelled_timers.each do |timer|
                #    child = event_timer_data_item(timer, true)
                #    @item_hash[child] = timer
                #    event_tree.add_top_level_item(child)
                #end
            #end
            
            ## Update statistics view
            label_threads_total.set_text(@thread_pool.spawned.to_s)
            label_threads_waiting.set_text(@thread_pool.waiting.to_s)
            label_threads_backlog.set_text(@thread_pool.backlog.to_s)
            
            # Average run and wait times. Use UTC to avoid time zone handling.
            label_execution_time.set_text(Time.at(@thread_pool.avg_run_time).utc.strftime("%Hh %Mm %Ss"))
            label_waiting_time.set_text(Time.at(@thread_pool.avg_wait_time).utc.strftime("%Hh %Mm %Ss"))
            
            # Do this last! Minimize column width
            update_tree_view
        end
        
        def update_tree_view
            treeWidget.column_count.times do |col|
                treeWidget.resize_column_to_contents col
            end
        end
        
        private
        
        # Register for error messages
        def register_for_errors
            error_classes = [Orocos::CORBA::ComError, Orocos::NotFound]
            @event_loop.on_errors(error_classes) do |e|
                log_text_browser.append "#{Time.now}: #{e}"
            end
        end
        
        # Packs needed task information into an item for the tree.
        def task_data_item(task)
            data = []
            data << task.description << Time.at(task.time_elapsed).utc.strftime("%Hh %Mm %Ss") << task.state
            item = Qt::TreeWidgetItem.new
            item.set_flags(item.flags.to_i | Qt::ItemIsEditable.to_i)
            data.size.times do |i|
                item.set_text(i, data[i].to_s)
            end
            item
        end
        
        # Packs needed event timer information into an item for the tree.
        def event_timer_data_item(timer, cancelled = false)
            Kernel.raise "Not a timer type: #{timer}" if not timer.is_a? Utilrb::EventLoop::Timer
            item = Qt::TreeWidgetItem.new
            item.set_flags(item.flags.to_i | Qt::ItemIsEditable.to_i)
            update_timer_item(item, timer, cancelled)
            # Store timer object representation at item for 'direct access' from context menu
            item.set_data(TIMER_DATA_COLUMN, Qt::UserRole, Qt::Variant.from_ruby(timer))
            item
        end

        def update_task_item(item, task = nil)
            # TODO
        end
        
        def update_timer_item(item, timer = nil, cancelled = false)
            timer = item_data(item).to_ruby unless timer
            data = []
            data << timer.doc << timer.period << (cancelled ? "cancelled" : "running")
            data.size.times do |i|
                item.set_text(i, data[i].to_s)
            end
        end
        
        def start_edit(obj)
            if @on_edit
                Vizkit.warn "You can only edit one object at a time."
                return false
            end            
            @on_edit = true
            @edited_object = obj
            true
        end
        
        def end_edit(obj)
            if not @on_edit
                Vizkit.warn "You cannot end editing an object before starting."
                return false
            end            
            Kernel.raise "You are trying to end editing of the wrong object!" if not @edited_object.equal? obj
            @edited_object = nil
            @on_edit = false
            true
        end

        def timer_cancelled? (timer)
            Kernel.raise "Not a timer object: #{timer}" if not timer.is_a?(Utilrb::EventLoop::Timer)
            not @cancelled_timers.find_index(timer).nil?
        end
        
        def column_editable?(col)
            return col == TIMER_DATA_COLUMN
        end
        
        def item_data(item)
            return item.data(TIMER_DATA_COLUMN, Qt::UserRole)
        end
    end

    def self.create_widget(parent=nil)
        @widget = Vizkit.load(File.join(File.dirname(__FILE__),'vizkit_info_viewer.ui'),parent)
        @widget.extend Functions
        @widget.init parent
        @widget
    end
end

Vizkit::UiLoader.register_ruby_widget("VizkitInfoViewer",VizkitInfoViewer.method(:create_widget))
