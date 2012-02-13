#!/usr/bin/env ruby

require 'utilrb/logger'
require 'orocos/log'
 
module Vizkit
    class ContextMenu
        def self.widget_for(type_name,parent,pos)
            menu = Qt::Menu.new(parent)

            # Determine applicable widgets for the output port
            widgets = Vizkit.default_loader.widget_names_for_value(type_name)
            widgets.uniq!
            widgets.each do |w|
                menu.add_action(Qt::Action.new(w, parent))
            end
            # Display context menu at cursor position.
            action = menu.exec(parent.viewport.map_to_global(pos))
            action.text if action
        end

        def self.task_state(task,parent,pos)
            menu = Qt::Menu.new(parent)

            #add some helpers
            menu.add_action(Qt::Action.new("Load Configuration", parent))
            #there will be no task model if the Task is not reachable 
            begin
                if Orocos.conf.find_task_configuration_object(task)
                    menu.add_action(Qt::Action.new("Reapply Configuration", parent)) 
                end
            rescue ArgumentError
            end
            menu.add_action(Qt::Action.new("Save Configuration", parent))
            menu.addSeparator

            if task.state == :PRE_OPERATIONAL
                menu.add_action(Qt::Action.new("Configure Task", parent))
            elsif task.error?
                menu.add_action(Qt::Action.new("Reset Exception", parent))
            elsif task.running?
                menu.add_action(Qt::Action.new("Stop Task", parent))
            elsif task.ready?
                menu.add_action(Qt::Action.new("Cleanup Task", parent))
                menu.add_action(Qt::Action.new("Start Task", parent))
            end

            #check if there are widgets for the task 
            if task.model && task.__task
                menu.addSeparator
                Vizkit.default_loader.control_names_for_value(task.__task.class).each do |w|
                    menu.add_action(Qt::Action.new(w, parent))
                end
                #show widgets for model and all super models
                model = task.model
                while model
                    widgets = Vizkit.default_loader.control_names_for_value(model.name)
                    widgets.each do |w|
                        menu.add_action(Qt::Action.new(w, parent))
                    end
                    model = model.superclass
                end
            end


            # Display context menu at cursor position.
            action = menu.exec(parent.viewport.map_to_global(pos))
            if action
                begin
                    if action.text == "Start Task"
                        task.start
                    elsif action.text == "Configure Task"
                        task.configure
                    elsif action.text == "Stop Task"
                        task.stop
                    elsif action.text == "Reset Exception"
                        task.reset_exception
                    elsif action.text == "Cleanup Task"
                        task.cleanup
                    elsif action.text == "Load Configuration"
                        file_name = Qt::FileDialog::getOpenFileName(nil,"Load Config",File.expand_path("."),"Config Files (*.yml)")
                        task.load_conf(file_name) if file_name
                    elsif action.text == "Apply Configuration"
                        task.apply_conf
                    elsif action.text == "Save Configuration"
                        file_name = Qt::FileDialog::getSaveFileName(nil,"Save Config",File.expand_path("."),"Config Files (*.yml)")
                        #delete the file if it already exists (the dialog is asking the use)
                        #TODO add code to merge the configuration with an existing file 
                        File.delete file_name if File.exist? file_name
                        task.save_conf(file_name) if file_name
                    elsif
                        Vizkit.control task.__task,:widget => action.text
                    end
                rescue RuntimeError => e 
                    puts e
                end
            end
        end

        def self.control_widget_for(type_name,parent,pos)
            menu = Qt::Menu.new(parent)

            # Determine applicable widgets for the output port
            widgets = Vizkit.default_loader.control_names_for_value(type_name)
            return nil if widgets.empty?
            widgets.each do |w|
                menu.add_action(Qt::Action.new(w, parent))
            end
            # Display context menu at cursor position.
            action = menu.exec(parent.viewport.map_to_global(pos))
            action.text if action
        end
    end

    # The TreeModeler class' purpose is to provide useful functionality for
    # working with Qt's StandardItemModel (handled as TreeModel). The main focus
    # is the generation of (sub) trees out of (compound) data structures such as sensor samples
    # with possibly multiple layers of data. 
    # Multilayer recognition only works with Typelib::CompoundType.
    class TreeModeler
        attr_accessor :model,:root,:force_update,:enable_tooling

        def initialize(tree_view)
            @max_array_fields = 30 
            @model = Qt::StandardItemModel.new
            @model.set_horizontal_header_labels(["Property","Value"])
            @root = @model.invisibleRootItem
            @tooltip = "Right-click for a list of available display widgets for this data type."
            @dirty_items = Array.new
            @force_update = false
            @readers = Hash.new

            #do not show state ports
            @enable_tooling = false

            #we cannot use object_id from ruby because 
            @object_storage = Array.new
            setup_tree_view(tree_view)
        end

        #call this to setup your Qt::TreeView object
        def setup_tree_view(tree_view)
            @tree_view = tree_view
            tree_view.setModel(@model)
            tree_view.setAlternatingRowColors(true)
            tree_view.setSortingEnabled(false)
            tree_view.connect(SIGNAL('customContextMenuRequested(const QPoint&)')) do |pos|
              context_menu(tree_view,pos)
            end
            tree_view.connect(SIGNAL('doubleClicked(const QModelIndex&)')) do |item|
                item = @model.item_from_index(item)
                if item.isEditable 
                  @dirty_items << item unless @dirty_items.include? item
                else
                  pos = tree_view.mapFromGlobal(Qt::Cursor::pos())
                  pos.y -= tree_view.header.size.height
                  context_menu(tree_view,pos,true)
                end
            end
        end

        # Updates a sub tree for an existing parent item. Non-existent 
        # children will be added to parent_item.
        def update(sample, item_name=nil, parent_item=@root, read_from_model=false,row=0)
            Vizkit.debug("Updating subtree for #{item_name}, sample.class = #{sample.class}")
            if item_name
              # Try to find item in model. Is there already a matching 
              # child item for sample in parent_item?
              item = direct_child(parent_item, item_name)
              unless item
                  Vizkit.debug("No item for item_name '#{item_name}'found. Generating one and appending it to parent_item.")
                  item,item2 = child_items(parent_item,-1)
              end
              item,item2 = child_items(parent_item,item.row)

              item.setText(item_name)
              if sample
                  match = sample.class.to_s.match('/(.*)>$')
                  text = if !match
                             sample.class.to_s
                         else
                             match[1]
                         end
                  item2.set_text(text)
              end
              update_object(sample, item, read_from_model,row)
            else
              update_object(sample, parent_item, read_from_model,row)
            end
            [item,item2]
        end

        #context menu to chose a widget for displaying the selected 
        #item
        #if auto == true the widget is selected automatically 
        #if there is only one 
        #TODO restructure this method 
        #
        def context_menu(tree_view,pos,auto=false,port=nil)
            item = @model.item_from_index(tree_view.index_at(pos))
            return if !item

            #try to find a parent which is a Typelib::CompoundType
            object = item_to_object(item)
            if !object 
                item,type = find_parent(item,Typelib::CompoundType.class)
                object = item_to_object(item)
                return if !object
            end

            item2 = item
            if item.parent
                if item.column == 0
                    item2 = item.parent.child(item.row,1)
                else
                    item = item.parent.child(item.row,0)
                end
            end

            #if no port is given try to find one by searching for a parent of type Port
            #this is needed to determine if someone clicked on a subfield
            if !port
                if(object == Orocos::Log::OutputPort || object == Orocos::OutputPort) 
                    port = port_from_item(item)
                elsif(object == Typelib::CompoundType.class)
                    port = port_from_item(item)
                end
            end

            #check if someone clicked on a property 
            subfield = subfield_from_item(item)
            property = property_from_item(item)

            #if object is a task 
            if object.is_a? Vizkit::TaskProxy
                ContextMenu.task_state(object,tree_view,pos)
            elsif object.is_a? Orocos::Log::Annotations
                    widget_name = Vizkit::ContextMenu.widget_for(Orocos::Log::Annotations,tree_view,pos)
                    if widget_name
                        widget = Vizkit.display object, :widget => widget_name
                        widget.setAttribute(Qt::WA_QuitOnClose, false) if widget
                    end
            #if object is a port or part of a port
            elsif(port) 
                #TODO
                #create a proxy class for subfields which behave like ports
                if auto && !subfield
                    #check if there is a default widget 
                    begin 
                        widget = Vizkit.display port,:subfield => subfield
                        widget.setAttribute(Qt::WA_QuitOnClose, false) if widget
                    rescue RuntimeError 
                        auto = false
                    end
                end
                #auto can be modified in the other if block
                if !auto 
                    type_name = if !subfield.empty?
                                    item2.text
                                else
                                    port.type_name
                                end
                    widget_name = Vizkit::ContextMenu.widget_for(type_name,tree_view,pos)
                    if widget_name
                        widget = Vizkit.display(port, :widget => widget_name,:subfield => subfield,:type_name => type_name)
                        widget.setAttribute(Qt::WA_QuitOnClose, false) if widget
                    end
                end
            #if object is a property or part of the property
            elsif(property)
                if(object == Typelib::CompoundType.class)
                    type_name = if subfield 
                                    item2.text
                                else
                                    property.type.class.name
                                end
                    widget_name = Vizkit::ContextMenu.control_widget_for(type_name,tree_view,pos)
                    if widget_name
                        widget = Vizkit.control nil, :widget => widget_name ,:type_name => type_name do |sample| 
                            update_object(sample,item)
                            @dirty_items << item unless @dirty_items.include? item
                            widget.close
                        end
                    end
                end
            end
        end

        def update_dirty_items
            properties = dirty_items(Orocos::Property)
            properties.each do |item|
                task_item,task = find_parent(item,Vizkit::TaskProxy)
                raise "Found no task for #{item.text}" unless task
                next if !task.ping
                item = item.parent.child(item.row,0) if item.column == 1
                prop = task.property(item.text)
                raise "Found no property called #{item.text} for task #{task.name}"unless prop
                sample = prop.new_sample.zero!
                update_object(sample,item,true)
                prop.write sample
            end
            unmark_dirty_items
        end

        def dirty_items(type=nil)
            return @dirty_items if !type
            items = dirty_items.map {|item| it,_=find_parent(item,type);it}
            items.compact.uniq
        end

        def unmark_dirty_items
            @dirty_items.clear
        end

        def find_parent(child,type)
            object = item_to_object(child)
            if object.class == type || object == type
                [child,object]
            else
                if child.parent 
                    find_parent(child.parent,type)
                else
                    nil
                end
            end
        end

        # Gets a pair of parent_item's direct children in the specified row. 
        # Constraint: There are only two children in each row (columns 0 and 1).
        def child_items(parent_item,row)
            item = parent_item.child(row)
            item2 = parent_item.child(row,1)
            unless item
                item = Qt::StandardItem.new
                parent_item.append_row(item)
                item2 = Qt::StandardItem.new
                parent_item.set_child(item.row,1,item2)

                item.setEditable(false)
                item2.setEditable(false)
            end
            [item,item2]
        end

        # Checks if there is a direct child of parent_item corresponding to item_name.
        # If yes, the child will be returned; nil otherwise. 
        # 'Direct' refers to a difference in (tree) depth of 1 between parent and child.
        def direct_child(parent_item, item_name)
            children = direct_children(parent_item) do |child,_|
                if child.text.eql?(item_name)
                    return child
                end
            end
            nil
        end

        # Returns pairs of all direct children (pair: row 0, row 1) as an array.
        def direct_children(parent_item,&block)
            children = []
            0.upto(parent_item.row_count-1) do |rc|
                item = parent_item.child(rc,0)
                item2 = parent_item.child(rc,1)
                children << [item,item2]

                block.call(item,item2) if block_given?
            end
            children
        end

        # Sets all child items' editable status to the value of <i>editable</i> 
        # except items acting as parent. 'Child item' refers to the value of 
        # the (property,value) pair.
        def set_all_children_editable(parent_item, editable)
            direct_children(parent_item) do |item,item2|
                item.setEditable(false)
                if item.has_children
                    item2.set_editable(false)
                    set_all_children_editable(item, editable)
                else
                    item2.set_editable(editable)
                end
            end
        end

        def subfield_from_item(item)
            object = item_to_object(item)
            fields = Array.new
            if object == Orocos::OutputPort || object == Orocos::Log::OutputPort
                fields 
            else
                if item.parent 
                    fields = subfield_from_item(item.parent)
                    fields << item.text
                else
                    fields
                end
            end
        end

        def port_from_item(item)
            port_item,port = find_parent(item,Orocos::OutputPort)
            port_item,port = find_parent(item,Orocos::Log::OutputPort) if !port
            return nil if !port

            _,task = find_parent(item,Vizkit::TaskProxy)
            _,task = find_parent(item,Orocos::Log::TaskContext) if !task 
            
            return nil if !port || !task
            if task.respond_to? :ping
                if task.ping
                    task.port(port_item.text) 
                else 
                    nil
                end
            else
                task.port(port_item.text)
            end
        end

        def property_from_item(item)
            property_item,property = find_parent(item,Orocos::Property)
            return nil if !property

            _,task = find_parent(item,Vizkit::TaskProxy)
            _,task = find_parent(item,Orocos::Log::TaskContext) if !task 
            
            return nil if !task
            if task.respond_to? :ping
                if task.ping
                    task.property(property_item.text) 
                else 
                    nil
                end
            else
                task.property(property_item.text) 
            end
        end

        def encode_data(item,object)
            #we cannot use object_id because on a 64 Bits system
            #the object_id cannot be stored inside a Qt::Variant 
            item.setData(Qt::Variant.new @object_storage.size)
            @object_storage << object 
        end

        private

        def item_to_object(item)
            @object_storage[item.data.to_i] if item && item.data.isValid 
        end

        def dirty?(item)
            @dirty_items.include?(item)
        end

        #return true if the item shall be updated returns false if 
        #the parent is not expanded 
        def update_item?(item)
            if force_update || !@tree_view || !item.parent || 
               @tree_view.is_expanded(@model.index_from_item(item.parent))
                true
            else
                false
            end
        end

        def reader_for(task_proxy,port_name)
          full_name = "#{task_proxy.name}_#{port_name}"
          return @readers[full_name] if @readers.has_key?(full_name)
          @readers[full_name] = task_proxy.port(port_name).reader
        end

        # Adds object to parent_item as a child. Object's children will be 
        # added as well. The original tree structure will be preserved.
        def update_object(object, parent_item, read_from_model=false, row=0)
            if object.kind_of?(Orocos::Log::Replay)
                row = 0
                if !object.annotations.empty?
                    item, item2 = child_items(parent_item,0)
                    item.setText("- Global Meta Data - ")
                    sub_row = 0
                    object.annotations.each do |annotation|
                        update_object(annotation,item,read_from_model,sub_row)
                        sub_row +=1
                    end
                    row =+ 1
                end
                object.tasks.each do |task|
                    next if !task.used?
                    update_object(task,parent_item,read_from_model,row)
                    row += 1
                end
            elsif object.kind_of?(Orocos::Log::Annotations)
                item, item2 = child_items(parent_item,row)
                item.setText(object.stream.name)
                item2.setText(object.stream.type_name)

                encode_data(item,object)
                encode_data(item2,object)
                
                item2, item3 = child_items(item,0)
                item2.setText("samples")
                item3.setText(object.samples.size.to_s)

            elsif object.kind_of?(Orocos::Log::LogMarker)
                item, item2 = child_items(parent_item,row)
                item.setText(object.type.to_s)
                item2.setText(object.comment)
                
                item2, item3 = child_items(item,0)
                item2.setText("time")
                item3.setText(object.time.to_s)

                item2, item3 = child_items(item,0)
                item2.setText("index")
                item3.setText(object.index.to_s)

            elsif object.kind_of?(Vizkit::TaskProxy)
                item, item2 = child_items(parent_item,row)
                item.setText(object.name)

                if object.doc?
                  item.set_tool_tip(object.doc)
                  item2.set_tool_tip(object.doc)
                end

                encode_data(item,object)
                encode_data(item2,object)
                item2.setText(object.state.to_s) 

                if !object.ping
                    item.removeRows(0,item.rowCount)
                else

                    item3, item4 = child_items(item,0)
                    item3.setText("Properties")
                    row = 0
                    object.each_property do |attribute|
                        update_object(attribute,item3,read_from_model,row)
                        row+=1
                    end

                    #setting ports
                    item3, item4 = child_items(item,1)
                    item3.setText("Input Ports")
                    item5, item6 = child_items(item,2)
                    item5.setText("Output Ports")

                    irow = 0
                    orow = 0
                    object.__task.each_port do |port|
                        if port.is_a?(Orocos::InputPort)
                            update_object(port,item3,read_from_model,irow)
                            irow += 1
                        else
                            next if !enable_tooling && port.name == "state"
                            update_object(port,item5,read_from_model,orow)
                            orow +=1
                        end
                    end
                end

            elsif object.kind_of?(Orocos::Log::TaskContext)
                item, item2 = child_items(parent_item,row)
                item.setText(object.name)
                item2.setText(object.file_path)
                encode_data(item,object)
                encode_data(item2,object)

                row = 0
                object.each_port do |port|
                    next unless port.used?
                    next if !enable_tooling && port.name == "state"
                    update_object(port,item,read_from_model,row)
                    row += 1
                end

                if !object.properties.empty?
                    item3, item4 = child_items(item,row)
                    row = 0
                    item3.setText("Properties")
                    object.each_property do |property|
                        update_object(property,item3,read_from_model,row)
                        row += 1
                    end
                end

            elsif object.kind_of?(Orocos::Property)
                item, item2 = child_items(parent_item,row)
                item.setText(object.name)

                if object.doc?
                  item.set_tool_tip(object.doc)
                  item2.set_tool_tip(object.doc)
                end

                if update_item?(item) || read_from_model
                    update_object(object.read,item,read_from_model)
                end

                if item.has_children 
                    set_all_children_editable(item,true)
                else
                    item2.set_editable(true)
                end
                if @dirty_items.empty?
                    encode_data(item,Orocos::Property)
                    encode_data(item2,Orocos::Property)
                end
            elsif object.kind_of?(Orocos::Log::Property)
                item, item2 = child_items(parent_item,row)
                item.setText(object.name)

                #do not show meta data for now because they are quite
                #uninteresting for properties 

                if update_item?(item)
                    update_object(object.read,item,read_from_model)
                end
            elsif object.kind_of?(Orocos::OutputPort)
                item, item2 = child_items(parent_item,row)
                item.setText(object.name)
                item2.setText(object.type_name.to_s)

                if object.doc?
                  item.set_tool_tip(object.doc)
                  item2.set_tool_tip(object.doc)
                else
                  # Set tooltip informing about context menu
                  item.set_tool_tip(@tooltip)
                  item2.set_tool_tip(@tooltip)
                end

                #do not encode the object because 
                #the port is only a temporary object!
                encode_data(item,object.class)
                encode_data(item2,object.class)

                if update_item?(item)
                    _,task = find_parent(parent_item,Vizkit::TaskProxy)
                    raise "cannot find task for port #{object.name}" if !task
                    reader = reader_for(task,object.name)
                    update_object(reader.read,item) if reader
                end
            elsif object.kind_of?(Orocos::InputPort)
                item, item2 = child_items(parent_item,row)
                if object.doc?
                  item.set_tool_tip(object.doc)
                  item2.set_tool_tip(object.doc)
                end
                item.setText(object.name)
                item2.setText(object.type_name.to_s)
            elsif object.kind_of?(Orocos::Log::OutputPort)
                item, item2 = child_items(parent_item,row)
                item.setText(object.name)
                item2.setText(object.type_name.to_s)

                # Set tooltip informing about context menu
                item.set_tool_tip(@tooltip)
                item2.set_tool_tip(@tooltip)

                #encode the object 
                encode_data(item,Orocos::Log::OutputPort)
                encode_data(item2,Orocos::Log::OutputPort)

                #add meta data
                item2, item3 = child_items(item,0)
                item2.setText("Meta Data")
                update_object(object.metadata,item2)

                item2, item3 = child_items(item,1)
                item2.setText("Samples")
                item3.setText(object.number_of_samples.to_s)

                item2, item3 = child_items(item,2)
                item2.setText("Filter")
                if object.filter
                    item3.setText("yes")
                else
                    item3.setText("no")
                end
                
        elsif object.kind_of?(Hash)
                object.each_pair do |key,value|
                    item, item2 = child_items(parent_item,row)
                    item.setText(key.to_s)
                    item2.setText(value.to_s)
                    row+=1
                end
        elsif object.kind_of?(Typelib::CompoundType)
                Vizkit.debug("update_object->CompoundType")

                row = 0;
                object.each_field do |name,value|
                    item, item2 = child_items(parent_item,row)
                    item.set_text name
                    #this is a workaround 
                    #if each field is created by its self we cannot write 
                    #the data back to the sample and we do not know its name 
                    if(value.kind_of?(Typelib::CompoundType))
                        encode_data(item,Typelib::CompoundType.class)
                        encode_data(item2,Typelib::CompoundType.class)
                        item2.set_text(value.class.name)
                    end
                    if read_from_model
                        object.set_field(name,update_object(value,item,read_from_model,row))
                    elsif !dirty?(item)
                        update_object(value,item,read_from_model,row)
                    end
                    row += 1
                end
                #delete all other rows
                parent_item.remove_rows(row,parent_item.row_count-row) if row < parent_item.row_count

            elsif object.is_a?(Array) || (object.kind_of?(Typelib::Type) && object.respond_to?(:each))
                Vizkit.debug("update_object->Array||Typelib+each")
                if object.size > @max_array_fields
                    item2 = parent_item.parent.child(parent_item.row,parent_item.column+1)
                    item2.set_text "#{object.size} fields ..."
                elsif object.size > 0
                    row = 0
                    object.each_with_index do |val,row|
                        item,item2 = child_items(parent_item,row)
                        item2.set_text val.class.name
                        item.set_text "[#{row}]"
                        if read_from_model
                            object[row] = update_object(val,item,read_from_model,row)
                        else
                            update_object(val,item,read_from_model,row)
                        end
                    end
                    #delete all other rows
                    row += 1
                    parent_item.remove_rows(row,parent_item.row_count-row) if row < parent_item.row_count
                elsif read_from_model
                    a = (update_object(object.to_ruby,parent_item,read_from_model,0))
                    if a.kind_of? String
                        # Append char by char because Typelib::ContainerType.<<(value) does not support argument strings longer than 1.
                        a.each_char do |c|
                            object << c
                        end
                    end
                end
            else
                Vizkit.debug("update_object->else")

                # Handle atomic types properly if they do not have grandparents
                if parent_item.parent
                    item = parent_item # == parent_item.parent.child(parent_item.row,parent_item.column)
                    item2 = parent_item.parent.child(parent_item.row,parent_item.column+1)
                else
                    item, item2 = child_items(parent_item,row)
                    item.set_text parent_item.text
                end

                if object != nil
                    if read_from_model
                        Vizkit.debug("Mode: Reading user input")
                        raise "name differs" if(object.respond_to?(:name) && item.text != object.name)
                        #convert type
                        type = object
                        if object.is_a? Typelib::Type
                            Vizkit.debug("We have a Typelib::Type.")
                            type = object.to_ruby 
                        end

                        Vizkit.debug("Changing property '#{item.text}' to value '#{item2.text}'")
                        Vizkit.debug("object of class type #{object.class}, object.to_ruby (if applicable) is of class type #{type.class}")

                        data = item2.text if type.is_a? String
                        begin
                            data = Math.class_eval(item2.text.gsub(',', '.')).to_f if type.is_a? Float # use international decimal point
                            data = Math.class_eval(item2.text).to_i if type.is_a? Fixnum
                        rescue
                            data = object
                        end
                        data = item2.text.to_i if type.is_a? File
                        data = item2.text.to_i == 1 || item2.text == "true" if type.is_a? FalseClass
                        data = item2.text.to_i == 1 || item2.text == "true" if type.is_a? TrueClass
                        data = item2.text.to_sym if type.is_a? Symbol
                        data = Time.local(item2.text) if type.is_a? Time
                        Vizkit.debug("Converted object data: '#{data}'")

                        if object.is_a? Typelib::Type
                            Typelib.copy(object,Typelib.from_ruby(data, object.class))
                        else
                            object = data
                        end
                    else
                        Vizkit.debug("Mode: Displaying data")
                        case object
                        when Float
                            item2.set_text(object.to_s.gsub(',', '.')) if !dirty?(item2)
                        when Time
                            format = "#{object.strftime('%d/%m/%Y %H:%M:%S')}.#{'%.03i' % [object.tv_usec / 1000]}.#{'%.03i' % [object.tv_usec % 1000]}"
                            item2.set_text(format) if !dirty?(item2)
                        else
                            item2.set_text(object.to_s) if !dirty?(item2)
                        end
                    end
                else
                    item2.setText "no samples received"
                end
            end
            object
        end
    end
end
