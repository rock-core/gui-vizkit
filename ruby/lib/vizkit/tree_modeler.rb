#!/usr/bin/env ruby

require 'utilrb/logger'
require 'orocos/log'
 
module Vizkit
    extend Logger::Root('tree_modeler.rb', Logger::INFO)
    class ContextMenu
        def self.widget_for(type_name,parent,pos)
            menu = Qt::Menu.new(parent)

            # Determine applicable widgets for the output port
            widgets = Vizkit.default_loader.widget_names_for_value(type_name)

            #TODO this should be handled by the uiloader at some point
            # Always offer struct viewer as widget if not yet present.
            widgets << "StructViewer" unless widgets.include? "StructViewer"

            widget_action_hash = Hash.new
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
        attr_accessor :model,:root

        def initialize
            @max_array_fields = 30 
            @model = Qt::StandardItemModel.new
            @model.set_horizontal_header_labels(["Property","Value"])
            @root = @model.invisibleRootItem
            @tooltip = "Right-click for a list of available display widgets for this data type."
            @dirty_items = Array.new

            #we cannot use object_id from ruby because 
            @object_storage = Array.new
        end

        #call this to setup your Qt::TreeView object
        def setup_tree_view(tree_view)
            tree_view.setModel(@model)
            tree_view.setAlternatingRowColors(true)
            tree_view.setSortingEnabled(true)
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
        def context_menu(tree_view,pos,auto=false,port=nil)
            item = @model.item_from_index(tree_view.index_at(pos))
            item2 = item
            if item.parent
                if item.column == 0
                    item2 = item.parent.child(item.row,1)
                else
                    item = item.parent.child(item.row,0)
                end
            end

            object = item_to_object(item)
            return if !object 
            subfield = nil

            #if not port is given try to find one by searching for a parent of type Port
            if !port
                if(object == Orocos::Log::OutputPort || object == Orocos::OutputPort) 
                    port = port_from_item(item)
                elsif(object.is_a? Typelib::CompoundType)
                    port = port_from_item(item)
                    subfield = subfield_from_item(item)
                end
            end

            #TODO
            #create a proxy class for subfields which behave like ports
            return if !port #this happens if no samples are received or a wrong item was selected
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
                type_name = item2.text
                widget_name = Vizkit::ContextMenu.widget_for(type_name,tree_view,pos)
                if widget_name
                    #TODO let the uiloader handle this 
                    widget = if widget_name != "StructViewer"
                                 widget = Vizkit.default_loader.create_widget widget_name
                             else
                                 nil
                             end
                    widget = Vizkit.display port, :widget => widget,:subfield => subfield,:type_name=> type_name
                    widget.setAttribute(Qt::WA_QuitOnClose, false) if widget
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
                task.port(port_item.text) if task.ping
            else
                task.port(port_item.text)
            end
        end

        def encode_data(item,object)
            #we cannot use object_id because on a 64 Bits system
            #the object_id cannot be stored insight a Qt::Variant 
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

        # Adds object to parent_item as a child. Object's children will be 
        # added as well. The original tree structure will be preserved.
        def update_object(object, parent_item, read_from_model=false, row=0)
            if object.kind_of?(Orocos::Log::Replay)
                row = 0
                object.tasks.each do |task|
                    next if !task.used?
                    update_object(task,parent_item,read_from_model,row)
                    row += 1
                end
            elsif object.kind_of?(Vizkit::TaskProxy)
                item, item2 = child_items(parent_item,row)
                item.setText(object.name)

                encode_data(item,object)
                encode_data(item2,object)

                if !object.ping
                    item2.setText("not reachable")
                    item.removeRows(0,item.rowCount)
                else
                    item2.setText(object.state.to_s) 

                    item3, item4 = child_items(item,0)
                    item3.setText("Attributes")
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
                    object.each_port do |port|
                        if port.is_a?(Orocos::InputPort)
                            update_object(port,item3,read_from_model,irow)
                            irow += 1
                        else
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
                    update_object(port,item,read_from_model,row)
                    row += 1
                end
            elsif object.kind_of?(Orocos::Property)
                item, item2 = child_items(parent_item,row)
                item.setText(object.name)
                update_object(object.read,item,read_from_model)
                if item.has_children 
                    set_all_children_editable(item,true)
                else
                    item2.set_editable(true)
                end
                encode_data(item,Orocos::Property)
                encode_data(item2,Orocos::Property)
            elsif object.kind_of?(Orocos::OutputPort)
                item, item2 = child_items(parent_item,row)
                item.setText(object.name)
                item2.setText(object.type_name.to_s)

                # Set tooltip informing about context menu
                item.set_tool_tip(@tooltip)
                item2.set_tool_tip(@tooltip)

                #do not encode the object because 
                #the port is only a temporary object!
                encode_data(item,object.class)
                encode_data(item2,object.class)

                _,task = find_parent(parent_item,Vizkit::TaskProxy)
                raise "cannot find task for port #{object.name}" if !task
                reader = task.__reader_for_port(object.name)
                update_object(reader.read,item) if reader
            elsif object.kind_of?(Orocos::InputPort)
                item, item2 = child_items(parent_item,row)
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

                item2, item3 = child_items(item,0)
                item2.setText("Samples")
                item3.setText(object.number_of_samples.to_s)

                item2, item3 = child_items(item,1)
                item2.setText("Filter")
                if object.filter
                    item3.setText("yes")
                else
                    item3.setText("no")
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
                        encode_data(item,Typelib::CompoundType)
                        encode_data(item2,Typelib::CompoundType)
                        item2.set_text(value.class.name)
                    end
                    if read_from_model
                        object.set_field(name,update_object(value,item,read_from_model,row,name))
                    else
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

                if object
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
                        data = item2.text.gsub(',', '.').to_f if type.is_a? Float # use international decimal point
                        data = item2.text.to_i if type.is_a? Fixnum
                        data = item2.text.to_i if type.is_a? File
                        data = item2.text.to_i == 0 if type.is_a? FalseClass
                        data = item2.text.to_i == 1 if type.is_a? TrueClass
                        data = item2.text.to_sym if type.is_a? Symbol
                        data = Time.new(item2.text) if type.is_a? Time
                        Vizkit.debug("Converted object data: '#{data}'")

                        if object.is_a? Typelib::Type
                            Typelib.copy(object,Typelib.from_ruby(data, object.class))
                        else
                            object = data
                        end
                    else
                        Vizkit.debug("Mode: Displaying data")
                        if object.is_a? Float
                            item2.set_text(object.to_s.gsub(',', '.')) if !dirty?(item2)
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
