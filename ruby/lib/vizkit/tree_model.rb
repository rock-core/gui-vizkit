require '../vizkit'
require 'utilrb/qt/variant/from_ruby.rb'

module Vizkit
    class ContextMenu
        def self.widget_for(type_name,parent,pos)
            menu = Qt::Menu.new(parent)

            # Determine applicable widgets for the output port
            widgets = Vizkit.default_loader.find_all_plugin_names(:argument=>type_name, :callback_type => :display,:flags => {:deprecated => false})
            widgets.uniq!
            widgets.each do |w|
                menu.add_action(Qt::Action.new(w, parent))
            end
            # Display context menu at cursor position.
            action = menu.exec(parent.viewport.map_to_global(pos))
            action.text if action
        end

        def self.task_state(task,parent,pos)
            return if !task.respond_to? :model
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
                Vizkit.default_loader.find_all_plugin_names(:argument => task,:callback_type => :control,:flags => {:deprecated => false}).each do |w|
                    menu.add_action(Qt::Action.new(w, parent))
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
                        task.apply_conf_file(file_name) if file_name
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
            Vizkit.default_loader.find_all_plugin_names(:argument => type_name,:callback_type => :control,:flags => {:deprecated => false}).each do |w|
                menu.add_action(Qt::Action.new(w, parent))
            end
            # Display context menu at cursor position.
            action = menu.exec(parent.viewport.map_to_global(pos))
            action.text if action
        end
    end

    # editor for enum values
    class EnumEditor < Qt::ComboBox
        def initialize(parent,data)
            super(parent)
            data.to_a.each do |val|
                addItem(val.to_s)
            end
        end
        # we cannot use user properties here
        # there is no way to define some on the ruby side
        def getData
            currentText
        end
    end

    # buttons for cancel or acknowledge a custom property change
    class AcknowledgeEditor < Qt::DialogButtonBox
        def initialize(parent,data,delegate)
            super(parent)
            addButton("Apply",Qt::DialogButtonBox::AcceptRole)
            addButton("Reject",Qt::DialogButtonBox::RejectRole)
            setCenterButtons(true)
            setAutoFillBackground(true)

            self.connect SIGNAL('rejected()') do
                data.parent.reset(data)
                delegate.closeEditor(self)
            end
            self.connect SIGNAL('accepted()') do
                data.parent.write(data)
                delegate.commitData(self)
                delegate.closeEditor(self)
            end
        end
    end

    # Delegate to select editor for editing tree view items
    class ItemDelegate < Qt::StyledItemDelegate
        def initialize(tree_view,parent = nil)
            super(parent)
            @tree_view = tree_view
        end

        def createEditor (parent, option,index)
            data = index.data(Qt::EditRole)
            if data.type == Qt::Variant::StringList
                Vizkit::EnumEditor.new(parent,data)
            elsif data.to_ruby?
                model = data.to_ruby
                Vizkit::AcknowledgeEditor.new(parent,model,self)
            else
                super
            end
        end

        def setModelData(editor,model,index)
            # we cannot use user properties here 
            # there is no way to define some on the ruby side
            if editor.respond_to? :getData
                model.setData(index,Qt::Variant.new(editor.getData),Qt::EditRole)
            else
                super
            end

            # show reject and apply buttons if the parent has the options
            # :accept => true
            parent = index
            while (parent = parent.parent).isValid
                item = model.itemFromIndex(parent)
                if item.respond_to?(:options) && !!item.options[:accept]
                    index = parent.parent.child(parent.row,1)
                    @tree_view.setCurrentIndex(index)
                    @tree_view.edit(index)
                    break
                end
            end
        end
    end

    # Typelib data model which is used by the item model to access the
    # underlying data
    class TypelibDataModel
        class MetaData < Struct.new(:parent,:row,:field)
            def val
                parent[field.first]
            end
            def field_type
                field.last
            end
            def field_accessor
                field.first
            end
            def field_name
                if field.first.is_a? Fixnum
                    "[#{field.first}]"
                else
                    field.first.to_s
                end
            end
        end

        attr_accessor :root
        attr_accessor :options
        # options :editable, :accept
        def initialize(root_item,parent = nil, options=Hash.new)
            @root = root_item
            @meta_data = Hash.new
            @modified_by_user = false
            @parent = parent
            @options = options
        end

        # returns true if the model was modified by the user
        # the modification flag will be deleted the next time
        # update is called
        def modified_by_user?
            !!@modified_by_user
        end

        def context_menu(item,pos,parent)
        end

        def on_change(&block)
            @on_change = block
        end

        def child(row,item = @root)
            child,field = if !item.is_a? Typelib::Type
                              [nil,nil]
                          elsif item.class.respond_to? :fields
                              field = item.class.fields[row]
                              if field
                                  [item.raw_get(field.first),field]
                              else
                                  [nil,nil]
                              end
                          elsif item.respond_to?(:raw_get) && item.size > row
                              [item.raw_get(row),[row,item.element_t]]
                          else
                              [nil,nil]
                          end
            if child
                #encode child as symbol if we got a non persistent ruby object
                #and safe meta data for the child
                child = if child.is_a? Typelib::Type
                            child
                        else
                            "#{item.object_id}_#{row}".to_sym
                        end
                @meta_data[child] ||= MetaData.new(item,row,field)
                child
            end
        end

        def rows(item=@root)
            if !item.is_a?(Typelib::Type) || item.class.name == "/base/Time"
                0
            elsif item.class.respond_to? :fields
                item.class.fields.size
            elsif item.respond_to? :raw_get
                item.size
            else
                0
            end
        end

        def parent=(parent)
            @parent = parent
        end

        def parent(item=@root)
            if item.object_id == @root.object_id
                return @parent
            end
            data = @meta_data[item]
            return nil unless data
            if data.parent.object_id == @root.object_id
                self
            else
                data.parent
            end
        end

        def update(data)
            @modified_by_user = false
            Typelib.copy(@root,data)
            item_changed
        end

        # indicates that an item has changed
        def item_changed
            number_of_elements = rows()-1
            0.upto(number_of_elements) do |i|
                @on_change.call child(i,@root)
            end
        end

        def field_type(item)
            data = @meta_data[item]
            data.field_type if data
        end

        def field_accessor(item)
            data = @meta_data[item]
            data.field_accessor if data
        end

        def field_name(item)
            data = @meta_data[item]
            name = if data
                       data.field_name
                   else
                       ""
                   end
            Qt::Variant.new(name)
        end

        def raw_data(item)
            data = @meta_data[item]
            data.val if data
        end

        def data(item,role=Qt::DisplayRole)
            data = @meta_data[item]
            return Qt::Variant.new unless data
            item_val = data.val
            val = if role == Qt::DisplayRole
                      if item_val.is_a? Typelib::Type
                          item_val.class.name
                      else
                          if item_val.is_a?(Float) || item_val.is_a?(Fixnum) ||
                              item_val.is_a?(TrueClass) || item_val.is_a?(FalseClass)
                              item_val
                          elsif item_val.is_a? Time
                              "#{item_val.strftime("%-d %b %Y %H:%M:%S")}.#{item_val.nsec.to_s}"
                          elsif item_val.is_a? Array 
                              data.field_type.name
                          else
                              item_val.to_s
                          end
                      end
                  elsif role == Qt::EditRole
                      if item_val.is_a? Typelib::Type
                          item_val.class.name
                      else
                          if item_val.is_a?(Float) || item_val.is_a?(Fixnum) ||
                              item_val.is_a?(TrueClass) || item_val.is_a?(FalseClass)
                              item_val
                          elsif item_val.is_a? Time
                              Qt::DateTime.new(item_val)
                          elsif item_val.is_a? Symbol
                              #add current value at the front
                              arr = data.field_type.keys.keys
                              arr.delete(item_val.to_s)
                              arr.insert(0,item_val.to_s)
                              arr
                          else
                              item_val.to_s
                          end
                      end
                  elsif role == Qt::ToolTipRole
                      if item_val.is_a? Typelib::Type
                          data.field_type.to_s
                      end
                  else
                      nil
                  end
            Qt::Variant.new(val)
        end

        def set(item,value)
            data = @meta_data[item]
            return false if !data || !data.parent

            item_val = data.val
            val = if item_val.is_a? Integer
                      value.to_i
                  elsif item_val.is_a? Float
                      value.to_f
                  elsif item_val.is_a? String
                      value.toString.to_s
                  elsif item_val.is_a? Time
                      Time.at(value.toDateTime.toTime_t)
                  elsif item_val.is_a? Symbol
                      value.toString.to_sym
                  end
            return false unless val
            data.parent[data.field.first] = val
            # set modified flag
            @modified_by_user = true
        end

        def flags(item)
            if @options[:editable]
                item_val = @meta_data[item].val
                if !item_val.is_a?(Typelib::Type) && rows(item) == 0
                    Qt::ItemIsEnabled | Qt::ItemIsEditable
                else
                    Qt::ItemIsEnabled
                end
            end
        end

        def stop_listening(item=nil)
        end
    end

    # used to embed n Data models
    class ProxyDataModel
        attr_accessor :root,:editable
        attr_accessor :options
        MetaData = Struct.new(:name,:value,:data,:listener)
        def initialize(parent = nil)
            @root = Hash.new
            @item_to_model = Hash.new         # maps items to their model
            @meta_data = Hash.new
            @parent = parent
            @editable = false
            @options = Hash.new
        end

        def on_change(&block)
            @on_change = block
        end

        def item_changed(item)
            @on_change.call item if @on_change && item.object_id != @root.object_id
            number_of_elements = rows(item)-1
            0.upto(number_of_elements) do |i|
                item_changed child(i,item)
            end
        end

        def stop_listening(item=@root)
            model = @item_to_model[item]
            if model
                model.stop_listening
            else
                if item == @root
                    @meta_data.each_pair do |model,meta|
                        if meta.listener
                            meta.listener.stop
                        end
                        model.stop_listening
                    end
                else
                    meta = @meta_data[item]
                    if meta && meta.listener
                        meta.listener.stop
                    end
                    item.stop_listening
                end
            end
        end

        def add(model,name,value,data=nil,listener=nil)
            raise "no model" until model
            raise "no name" until name

            model.on_change do |item|
                @on_change.call(item) if @on_change
            end
            model.parent = self
            @root[name] = model
            @meta_data[model] = MetaData.new(name,value,data,listener)
            @on_change.call(self) if @on_change
        end

        def data_value(model,value)
            @meta_data[model].value = value
        end

        def child(row,parent=@root)
            model = @item_to_model[parent]
            if model
                p = model.child(row,parent)
                @item_to_model[p] ||= model if p
                p
            else
                if parent==@root
                    @root[@root.keys[row]]
                else
                    if parent.respond_to? :child
                        p = parent.child(row)
                        @item_to_model[p] ||= parent if p
                        p
                    end
                end
            end
        end

        def rows(item=@root)
            model = @item_to_model[item]
            if model
                model.rows(item)
            elsif item == @root
                item.size
            else
                if item.respond_to? :rows
                    item.rows()
                else
                    0
                end
            end
        end

        def parent(item=@root)
            return @parent if item == @root
            model = @item_to_model[item]
            if model
                parent = model.parent(item)
                if parent.object_id == self.object_id || !parent
                    model
                else
                    parent
                end
            else
                nil
            end
        end

        def field_type(item)
            model = @item_to_model[item]
            if model
                model.field_type(item)
            end
        end

        def field_name(item)
            model = @item_to_model[item]
            if model
                model.field_name(item)
            else
                Qt::Variant.new(@meta_data[item].name)
            end
        end

        def field_accessor(item)
            model = @item_to_model[item]
            if model
                model.field_accessor(item)
            else
                @meta_data[item].name
            end
        end

        def raw_data(item)
            model = @item_to_model[item]
            if model
                meta = @meta_data[model]
                meta.listener.start if meta.listener && !meta.listener.listening?
                model.raw_data(item)
            else
                @meta_data[item].data
            end
        end

        def data(item,role=Qt::DisplayRole)
            model = @item_to_model[item]
            if model
                meta = @meta_data[model]
                meta.listener.start if meta.listener && !meta.listener.listening?
                model.data(item,role)
            else
                if role == Qt::EditRole
                    Qt::Variant.from_ruby item
                elsif role == Qt::DisplayRole && item.modified_by_user?
                    Qt::Variant.new(@meta_data[item].value.to_s + " (modified)")
                else
                    Qt::Variant.new(@meta_data[item].value.to_s)
                end
            end
        end

        def set(item,value)
            model = @item_to_model[item]
            if model
                model.set(item,value)
            else
                false
            end
        end

        def flags(item)
            model = @item_to_model[item]
            if model
                model.flags(item)
            else
                if options[:editable]
                    Qt::ItemIsEnabled | Qt::ItemIsEditable
                else
                    Qt::ItemIsEnabled
                end
            end
        end

        def context_menu(item,pos,parent_widget)
            model = @item_to_model[item]
            if model
                model.context_menu(item,pos,parent_widget)
            end
        end

        def parent=(parent)
            @parent = parent
        end

        def modified_by_user?
            false
        end
    end

    class InputPortsDataModel < ProxyDataModel
        def add(port)
            sample = port.new_sample
           # sample.zero!
            super(TypelibDataModel.new(sample,self),port.name,port.type_name,port)
        end
    end

    class OutputPortsDataModel < ProxyDataModel
        def add(port)
            sample = port.new_sample
            model = TypelibDataModel.new(sample,self)
            listener = port.on_data do |data|
                model.update(data)
            end
            listener.stop
            super(model,port.name,port.type_name,port,listener)
        end

        def port_from_index(index)
            a = []
            while index
                data = raw_data(index)
                return data,a.reverse if data.respond_to?(:type_name)
                a << field_accessor(index)
                index = parent(index)
            end
            [nil,[]]
        end

        def context_menu(item,pos,parent_widget)
            port,subfield = port_from_index(item)
            return unless port
            if port.output?
                port_temp = if !subfield.empty?
                                port.sub_port(subfield,field_type(item))
                            else
                                port
                            end
                widget_name = Vizkit::ContextMenu.widget_for(port_temp.type_name,parent_widget,pos)
                if widget_name
                    widget = Vizkit.display(port_temp, :widget => widget_name)
                    widget.setAttribute(Qt::WA_QuitOnClose, false) if widget.is_a? Qt::Widget
                end
            else
                widget_name = Vizkit::ContextMenu.control_widget_for(port.type_name,parent_widget,pos)
                if widget_name
                    widget = Vizkit.control port, :widget => widget_name
                end
            end
            true
        end
    end

    class PropertiesDataModel < ProxyDataModel

        def initialize(parent = nil)
            super
            options[:editable] = true
        end

        def add(property)
            raise ArgumentError, "no property given" unless property
            sample = property.read

            model = TypelibDataModel.new(sample,self,:editable => true,:accept => true)
            property.on_change do |data|
                if !model.modified_by_user?
                    model.update data
                end
            end
            super(model,property.name,property.type_name,property)
        end

        def write(model,&block)
            meta = @meta_data[model] 
            if meta
                meta.data.write(model.root,&block)
                model.update meta.data.last_sample
            end
        end

        def reset(model)
            meta = @meta_data[model] 
            if meta
                model.update meta.data.last_sample
            end
        end
    end

    class TaskContextDataModel < ProxyDataModel
        def initialize(task,parent = nil)
            super(parent)
            @input_ports = InputPortsDataModel.new(self)
            @output_ports = OutputPortsDataModel.new(self)
            @properties = PropertiesDataModel.new(self)

            add(@input_ports,"Input Ports","")
            add(@output_ports,"Output Ports","")
            add(@properties,"Properties","")

            task.on_port_reachable do |port_name|
                @output_ports.add(task.port(port_name))
            end

            task.on_property_reachable do |property_name|
                @properties.add(task.property(property_name))
            end
        end
    end

    class TaskContextsDataModel < ProxyDataModel
        def initialize(parent = nil)
            super(parent)
        end
        def add(task)
            model = TaskContextDataModel.new task, self
            super(model,task.name,"",task)
            task.on_state_change do |state|
                data_value(model,state.to_s)
                item_changed(model)
            end
        end
        def context_menu(item,pos,parent_widget)
            return if super
            model = @item_to_model[item]
            data = @meta_data[model]
            task = raw_data(item)
            if task
                ContextMenu.task_state(task,parent_widget,pos)
                true
            end
        end
    end

    #Item Model for vizkit types
    class VizkitItemModel < Qt::AbstractItemModel
        MAX_NUMBER_OF_CHILDS = 100

        def initialize(data,parent = nil)
            super(parent)
            @data_model = data
            @data_model.on_change do |item|
                index = @index[item]
                if index
                    emit dataChanged(index,index(index.row,1,index.parent))
                end
            end

            # we have to save the model index for the parent
            # otherwise qt is complaining that two childs
            # of item have different parents
            @index = Hash.new
        end

        def stop_listening(index)
            item = itemFromIndex(index)
            @data_model.stop_listening(item)
        end

        def context_menu(index,pos,parent)
            item = itemFromIndex(index)
            @data_model.context_menu(item,pos,parent)
        end

        def update(data)
            #   data.root = Typelib.copy(data.root,data)
            #   emit dataChanged(index(0,1),index(rowCount,1))
        end

        def index(row,column,parent = Qt::ModelIndex.new)
            parent_item = itemFromIndex(parent)
            child = @data_model.child(row,parent_item)
            if child
                i = create_index(row, column, child)
                @index[child] ||= i if column == 0
                i
            else
                Qt::ModelIndex.new
            end
        end

        def data(index,role)
            if !index.valid? || role != Qt::DisplayRole && role != Qt::EditRole && role != Qt::ToolTipRole
                return Qt::Variant.new
            end
            item = itemFromIndex(index)
            val = if index.column == 0
                      @data_model.field_name(item)
                  else
                      @data_model.data(item,role)
                  end

            #prevent segfaults
            raise "wrong return value Qt::Variant was expected but got #{val.class}" unless val.is_a? Qt::Variant
            val
        end

        def field_accessor(index)
            if !index.valid?
                return nil
            end
            item = itemFromIndex(index)
            @data_model.field_accessor(item)
        end

        def raw_data(index)
            if !index.valid?
                return nil
            end
            item = itemFromIndex(index)
            @data_model.raw_data(item)
        end

        def itemFromIndex(index)
            return @data_model.root unless index.valid?
            index.internalPointer
        end

        def setData(index,value,role)
            if role != Qt::EditRole || !index.valid?
                return false
            end
            item = itemFromIndex(index)
            if @data_model.set(item,value)
                emit dataChanged(index,index)
                true
            end
        end

        def flags(index)
            if index.valid? 
                if index.column == 0 
                    Qt::ItemIsEnabled
                else
                    item = itemFromIndex(index)
                    @data_model.flags(item)
                end
            else
                0
            end
        end

        def headerData(section,orientation,role)
            return Qt::Variant.new if role != Qt::DisplayRole
            if section == 0
                Qt::Variant.new("Field")
            else
                Qt::Variant.new("Value")
            end
        end

        def parent(index)
            item = itemFromIndex(index)
            parent = @data_model.parent(item)
            if parent
                @index[parent]
            else
                Qt::ModelIndex.new
            end
        end

        def rowCount(index = Qt::ModelIndex.new)
            item = itemFromIndex(index)
            [MAX_NUMBER_OF_CHILDS,@data_model.rows(item)].min
        end

        def columnCount(index)
            2
        end
    end

    def self.setup_tree_view(tree_view)
        @delegator = ItemDelegate.new(tree_view,nil)
        tree_view.setItemDelegate(@delegator)
        tree_view.setSortingEnabled true
        tree_view.setAlternatingRowColors(true)
        tree_view.setContextMenuPolicy(Qt::CustomContextMenu)
        tree_view.connect(SIGNAL('customContextMenuRequested(const QPoint&)')) do |pos|
            index = tree_view.index_at(pos)
            index.model.context_menu(index,pos,tree_view)
        end

        def tree_view.setModel(model)
            super
            connect SIGNAL("collapsed(QModelIndex)") do |index|
                model.stop_listening index
            end
            # no need for expand event
            # auto reconnect if data field are accessed by the TreeView
        end
    end
end


Orocos.initialize
Orocos.load_typekit "base"
t = Types::Base::Samples::RigidBodyState.new
#t = Types::Base::Samples::Frame::FramePair.new

w = Qt::TreeView.new
Vizkit.setup_tree_view(w)
w.resize(640,480)

t = Qt::Timer.new
t.connect SIGNAL(:timeout) do 
    #    w.reset
end
t.start 1000

task = Orocos::Async::TaskContextProxy.new("camera",:wait => true)
data = Vizkit::TaskContextsDataModel.new
data.add(task)
model = Vizkit::VizkitItemModel.new(data)
w.setModel model

#model = Vizkit::PortsItemModel.new
#model.add_port task.port("frame")
#proxy = Qt::SortFilterProxyModel.new
#proxy.setSourceModel model

w.show
Vizkit.exec
