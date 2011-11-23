require 'vizkit/action_info'

class LogControl

  module Functions
    
    def control(replay,options=Hash.new)
      raise "Cannot control #{replay.class}" if !replay.instance_of?(Orocos::Log::Replay)
      
      @log_replay = replay
      @replay_on = false 
      @slider_pressed = false
      @user_speed = @log_replay.speed
      @show_marker = false 
      @signal_mapper = nil
      
      # Information about the recent displayed context menu actions.
      # key: widget name
      # value: ActionInfo
      @widget_action_hash = Hash.new 

      dir = File.dirname(__FILE__)
      @pause_icon =  Qt::Icon.new(File.join(dir,'pause.png'))
      @play_icon = Qt::Icon.new(File.join(dir,'play.png'))
     # setFixedSize(253,146)
      #
      setAttribute(Qt::WA_QuitOnClose, true);

      connect(slider, SIGNAL('valueChanged(int)'), lcd_index, SLOT('display(int)'))
      slider.connect(SIGNAL('sliderReleased()'),self,:slider_released)
      bnext.connect(SIGNAL('clicked()'),self,:bnext_clicked)
      #bnext.connect(SIGNAL('clicked()'),self,:bnextmarker_clicked)
      bback.connect(SIGNAL('clicked()'),self,:bback_clicked)
      #bback.connect(SIGNAL('clicked()'),self,:bprevmarker_clicked)
      bstop.connect(SIGNAL('clicked()'),self,:bstop_clicked)
      bplay.connect(SIGNAL('clicked()'),self,:bplay_clicked)
      treeView.connect(SIGNAL('doubleClicked(const QModelIndex&)'),self,:tree_double_clicked)
      treeView.connect(SIGNAL('customContextMenuRequested(const QPoint&)'),self,:contextMenuHandler)
      slider.connect(SIGNAL(:sliderPressed)) {@slider_pressed = true;}
      
      if(options.has_key?(:show_marker))
             if options[:show_marker] == true
                 @show_marker = true
             end
      end
     

      if(options.has_key?(:marker_type) and @show_marker == true)
          @log_replay.add_marker_stream_by_type(options[:marker_type])
          add_marker_from_replay if not @log_replay.markers.empty?
      end
      if(options.has_key?(:marker_stream) and @show_marker == true)
          @log_replay.add_marker_stream_by_name(options[:marker_stream])
          add_marker_from_replay if not @log_replay.markers.empy?
      end

      @log_replay.align unless @log_replay.aligned?
      return if !@log_replay.replay?
      @log_replay.process_qt_events = true
      slider.maximum = @log_replay.size-1

      #add replayed streams to tree view 
      @tree_model = Qt::StandardItemModel.new
      @tree_model.setHorizontalHeaderLabels(["Replayed Tasks","Information"])
      @root_item = @tree_model.invisibleRootItem
      treeView.setModel(@tree_model)
      treeView.setAlternatingRowColors(true)
      treeView.setSortingEnabled(true)
      
      @brush = Qt::Brush.new(Qt::Color.new(200,200,200))
      @widget_hash = Hash.new
      @mapping = Hash.new
     
		 	#if not @log_replay.tasks
			#	STDERR.puts "Cannot handle empty Task"
			#else
        @log_replay.tasks.each do |task|
        next if !task.used?
        item, item2 = get_item(task.name,task.name, @root_item)
        item2.setText(task.file_path)
        #setting ports
        task.each_port do |port|
          next unless port.used?
          key = task.name+"_"+ port.name
          item2, item3 = get_item(key,port.name, item)
          @mapping[item2] = port
          @mapping[item3] = port
          item3.setText(port.type_name.to_s)
          
          # Set tooltip informing about context menu
          tooltip = "Right-click for a list of available display widgets for this data type."
          item2.set_tool_tip(tooltip)
          item3.set_tool_tip(tooltip)

          item4, item5 = get_item(key,"Samples", item2)
          item5.setText(port.number_of_samples.to_s)

          item4, item5 = get_item(key,"Filter", item2)
          if port.filter
            item5.setText("yes")
          else
            item5.setText("no")
          end
        end
      end
			#end
      treeView.resizeColumnToContents(0)
      display_info
    end


    def initialize_marker_view()
        if @show_marker
            marker_view.show
            geo = size()
            geo.setHeight(460)
            resize(geo)
            @marker_mapping = Hash.new
            @marker_model = Qt::StandardItemModel.new
            @marker_model.setColumnCount(1)
            @marker_model.setHorizontalHeaderLabels(["Information"])
            @marker_root = @marker_model.invisibleRootItem
            marker_view.setModel(@marker_model)
            marker_view.setAlternatingRowColors(true)
            marker_view.setSortingEnabled(true)
            marker_view.connect(SIGNAL('doubleClicked(const QModelIndex&)'),self,:marker_tree_double_clicked)
        end
    end

    def add_marker_from_replay()
        initialize_marker_view
        raise "Internal error marker_roor is not set, this souldn't occur" if not @marker_root

        #don't use step, alining takes to much time we need only the header
        #if later on more informations are requierd please re-read only current sample
        @log_replay.markers.each do |sample|
            time = sample.time
            target_sample_pos = @log_replay.sample_index_for_time(time)
            slider.addMarker(target_sample_pos)

	    #Only getting first line, to prevent too log messages
            string = sample.comment.split("\n")[0] 
	    string = "<nil>" if not string

            item = marker_item(sample.id,string, @marker_root)
            marker_item("id_#{sample.id}","ID: #{sample.id}",item)
            marker_item("comment_#{sample.id}",sample.comment,item)
            marker_item("time_#{sample.id}",sample.time,item) 
        end
    end

    def marker_tree_double_clicked(model_index)
      item = @marker_model.itemFromIndex(model_index)
      return unless @marker_mapping.has_key? item.text
      @log_replay.seek(@marker_mapping[item.text]) if @marker_mapping[item.text].is_a? Time
      display_info
    end

    def tree_double_clicked(model_index)
      item = @tree_model.itemFromIndex(model_index)
      return unless @mapping.has_key? item
      port = @mapping[item]
      widget = @widget_hash[port]
      if widget
        Vizkit.connect(widget)
        widget.show
      else
        widget = Vizkit.display port
        widget.setAttribute(Qt::WA_QuitOnClose, false) if widget
        @widget_hash[port]=widget
      end
    end
    
    def playing?
      @replay_on
    end

    def marker_item(key,name,root_item)
      item = Qt::StandardItem.new(name.to_s)
      item.setEditable(false)
      root_item.appendRow(item)
      @marker_mapping[name.to_s] = name
      return item
    end

    def get_item(key,name,root_item)
      item = Qt::StandardItem.new(name)
      item.setEditable(false)
      root_item.appendRow(item)
      item2 = Qt::StandardItem.new
      item2.setEditable(false)
      root_item.setChild(item.row,1,item2)
      return [item,item2]
    end

    def display_info

      slider.setSliderPosition(@log_replay.sample_index) unless @slider_pressed
      if @log_replay.time
        timestamp.text = @log_replay.time.strftime("%a %D %H:%M:%S." + "%06d" % @log_replay.time.usec)
        lcd_speed.display(@log_replay.actual_speed)
        last_port.text = @log_replay.current_port.full_name if @log_replay.current_port
      else
        timestamp.text = "0"
      end
    end

    def speed=(double)
      @user_speed = double
      @log_replay.speed = double
      @log_replay.reset_time_sync
    end

    def speed
      @user_speed
    end

    def auto_replay
      @replay_on = true
      @log_replay.reset_time_sync
      last_warn = Time.now 
      last_info = Time.now
      while @replay_on
       bplay_clicked if !@log_replay.step(true) #stop replay if end of file is reached
       if Time.now - last_info > 0.1
        last_info = Time.now
        $qApp.processEvents
        display_info      #we do not display the info every step to save cpu time
       end
      end
      display_info        #display info --> otherwise info is maybe not up to date
    end

    def slider_released
      @slider_pressed = false
      return if !@log_replay.replay?
      @log_replay.reset_time_sync
      @log_replay.seek(slider.value)
      display_info
    end
    
    def bnextmarker_clicked
      return if !@log_replay.replay?
      @log_replay.next_marker()
      display_info
    end
    
    def bprevmarker_clicked
      return if !@log_replay.replay?
      @log_replay.prev_marker()
      display_info
    end


    def bnext_clicked
      return if !@log_replay.replay?
      if @replay_on
        #we cannot use speed= here because this would overwrite the 
        #user_speed which is the default speed for replay
        @log_replay.speed = @log_replay.speed*2
        @log_replay.reset_time_sync
      else
        @log_replay.step(false)
      end
      display_info
    end

    def bback_clicked 
      return if !@log_replay.replay?
      if @replay_on
        @log_replay.speed = @log_replay.speed*0.5
        @log_replay.reset_time_sync
      else
        @log_replay.step_back
      end
      display_info
    end
    
    def bstop_clicked 
       return if !@log_replay.replay?
       bplay_clicked if @replay_on
       @log_replay.rewind
       @log_replay.reset_time_sync
       display_info
    end

    def refresh
        @log_replay.refresh
    end
    
    def bplay_clicked 
      return if !@log_replay.replay?
      if @replay_on
        bplay.icon = @play_icon
        @replay_on = false
      else
        bplay.icon = @pause_icon
        bstop_clicked if @log_replay.eof?
        self.speed = @user_speed
        auto_replay
      end
    end
  
  def contextMenuHandler(pos)
    item = @tree_model.item_from_index(treeView.index_at(pos))
    if item && item.parent && !item.parent.parent
        # Clicked on an output port item in the view. Set up context menu.
        menu = Qt::Menu.new(treeView)
        #debugger
        
        task_name = item.parent.text
        
        # Assign port name and type correctly depending on the clicked column.
        port_name = "";
        port_type = "";
        if item.column == 0
            port_name = item.text
            port_type = item.parent.child(item.row,1).text
        elsif item.column == 1
            port_name = item.parent.child(item.row, 0).text
            port_type = item.text
        end
        
        loader = Vizkit.default_loader
        
        # Determine applicable widgets for the output port
        widgets = []
        widgets = loader.widget_names_for_value(port_type)
        
        # Always offer struct viewer as widget if not yet present.
        if not widgets.include? "StructViewer"
            widgets << "StructViewer"
        end

        # Give action handler information about the caller 
        # -- i.e. the specific widget entry in the menu -- 
        # in order to display the correct widget.
        @signal_mapper = Qt::SignalMapper.new(self)
        @signal_mapper.connect(SIGNAL('mapped(const QString&)'), self, :clicked_action)
        
        widgets.each do |w|
            a = Qt::Action.new(w, self)
            menu.add_action(a)
            connect(a, SIGNAL('triggered()'), @signal_mapper, SLOT('map()'));

            # Saving information for action handler
            action_info = ActionInfo.new
            action_info[ActionInfo::WIDGET_NAME] = w
            action_info[ActionInfo::TASK_NAME] = task_name
            action_info[ActionInfo::PORT_NAME] = port_name
            action_info[ActionInfo::PORT_TYPE] = port_type
            @widget_action_hash[w] = action_info;
            
            @signal_mapper.set_mapping(a, w);
        end
        
#        item = @tree_model.item_from_index(treeView.index_at(pos))
        
        # Display context menu at cursor position.
        menu.exec(treeView.viewport.map_to_global(pos))
    end
  end
  
      # Action handler for context menu clicks. 
    def clicked_action(widget_name)
        info = @widget_action_hash[widget_name]
        #Vizkit.info "Triggered widget '#{info[ActionInfo::WIDGET_NAME]}'"

        # Set up and display widget
        widget = Vizkit.default_loader.create_widget(info[ActionInfo::WIDGET_NAME])

        task_context = nil;
        @log_replay.tasks.each do |task|
            if task.name.eql? info[ActionInfo::TASK_NAME]
                task_context = task
            end
        end
        if !task_context
            raise "Problem getting task context for logged port!"
        end
        port = task_context.port(info[ActionInfo::PORT_NAME])
        port.connect_to(widget)
        widget.show
        
        @widget_action_hash.clear
    end
  
  end # module Functions

  def self.create_widget(parent = nil)
    form = Vizkit.load(File.join(File.dirname(__FILE__),'LogControl.ui'),parent)

    form.extend Functions
    form.marker_view.hide
    geo = form.size()
    geo.setHeight(260)
    form.resize(geo)

    #workaround 
    #it seems that widgets which are created by the UiLoader do not 
    #forward message calls to ruby
    short = Qt::Shortcut.new(Qt::KeySequence.new("Ctrl+R"),form)
    short.connect(SIGNAL('activated()'))do
        form.refresh
    end



    #workaround
    #it is not possible to define virtual functions for qidgets which are loaded
    #via UiLoader (qtruby1.8)
    #stop replay if all windows are closed
    $qApp.connect(SIGNAL(:lastWindowClosed)) do 
      form.instance_variable_set(:@replay_on,false)
    end

    form
  end
  
end

Vizkit::UiLoader.register_ruby_widget('log_control',LogControl.method(:create_widget))
