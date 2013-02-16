require 'utilrb/qt/variant/from_ruby.rb'
require 'utilrb/qt/mime_data/mime_data.rb'
require 'orocos/uri'

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

        def self.config_name_service(name_service,parent,pos)
            menu = Qt::Menu.new(parent)
            menu.add_action(Qt::Action.new("set ip", parent))

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

            if task.current_state == :PRE_OPERATIONAL
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
            if task.model
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
            elsif editor.is_a? Qt::ComboBox
                model.setData(index,Qt::Variant.new(editor.currentText),Qt::EditRole)
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

    # Typelib data model which is used by the item model to display the
    # underlying data. 
    class TypelibDataModel
        # Internal structure to hold information about a subfield
        class MetaData < Struct.new(:parent,:row,:field)
            # value of the field
            def val
                parent[field.first]
            rescue TypeError
                Vizkit.warn "got a TypeError for #{field.last}"
                "TypeError"
            end

            # type of the field
            def field_type
                field.last
            end

            # symbol or number to access the field from
            # its parent
            def field_accessor
                field.first
            end

            # name of the field
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

        # A TypelibDataModel
        #
        # @param [Typelib::Type] root_item underlying Typelib data
        # @param [ProxyDataModel] parent Parent of the Typelib type which should be set
        #    if the Typelib type belongs to a more complex data structure build with the help
        #    of ProxyDataModel
        # @param [Hash] options The options
        # @option options [TrueClass,FalseClass] :editable Indicates if the model can be modified by the user
        # @option options [TrueClass,FalseClass] :enabled Indicates if the model is enabled
        # @option options [TrueClass,FalseClass] :accept Indicates if the parent shall be called to accept changes
        # @option options [TrueClass,FalseClass] :no_data Indicates if the model has valid data 
        def initialize(root_item,parent = nil, options=Hash.new)
            @root = root_item
            @meta_data = Hash.new
            @modified_by_user = false
            @parent = parent
            @options = Kernel::validate_options options,:enabled => true,:accept => false, :editable => false,:no_data => false
        end

        # returns true if the model was modified by the user
        # the modification flag will be deleted the next time
        # update is called
        #
        # @return [TrueClass,FalseClass]
        def modified_by_user?
            !!@modified_by_user
        end

        def context_menu(item,pos,parent)
            false
        end

        def on_changed(&block)
            @on_changed = block
        end

        def on_added(&block)
            @on_added = block
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
                            #this is fine because item will always have the same id
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
            return unless data
            @options[:no_data] = false
            @modified_by_user = false
            Typelib.copy(@root,Typelib.from_ruby(data,@root.class))
            item_changed
        end

        # indicates that an item has changed
        def item_changed
            return unless @on_changed
            number_of_elements = rows()-1
            0.upto(number_of_elements) do |i|
                @on_changed.call child(i,@root)
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

        # encodes the underlying data of the given item as Qt::Variant
        def data(item,role=Qt::DisplayRole)
            data = @meta_data[item]
            return Qt::Variant.new unless data
            item_val = data.val
            val = if role == Qt::DisplayRole
                      return Qt::Variant.new("no data") if @options[:no_data]
                      if item_val.is_a? Typelib::Type
                          item_val.class.name
                      else
                          if item_val.is_a?(Float) || item_val.is_a?(Fixnum) ||
                              item_val.is_a?(TrueClass) || item_val.is_a?(FalseClass)
                              item_val
                          elsif item_val.is_a? Time
                              "#{item_val.strftime("%-d %b %Y %H:%M:%S")}.#{item_val.usec.to_s}"
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

        def flags(column,item)
            return 0 if !@options[:enabled]
            return Qt::ItemIsEnabled | Qt::ItemIsSelectable | Qt::ItemIsDragEnabled if column == 0
            if @options[:editable]
                item_val = @meta_data[item].val
                if !item_val.is_a?(Typelib::Type) && rows(item) == 0
                    Qt::ItemIsEnabled | Qt::ItemIsEditable
                else
                    Qt::ItemIsEnabled
                end
            else
                0
            end
        end

        def stop_listening(item=nil)
        end

        def sort(value = :ascending_order)
        end

        def mime_data(item)
            0
        end
    end

    class SimpleTypelibDataModel < TypelibDataModel
        # Internal structure to hold information about a subfield
        class MetaData < TypelibDataModel::MetaData
            def val
                v = Typelib.to_ruby parent
                if parent.class.name == "/bool"
                    if v == 0
                        false
                    else
                        true
                    end
                else
                    v
                end
            end
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
                  elsif item_val.is_a? TrueClass
                    value.toString == "True"
                  elsif item_val.is_a? FalseClass
                    value.toString == "True"
                  end
            return false if val == nil
            Typelib.copy(@root,Typelib.from_ruby(val,@root.class))

            # set modified flag
            @modified_by_user = true
        end

        def child(row,item = @root)
            if row == 0 && item.object_id == @root.object_id
                child = "#{@root.object_id}".to_sym
                @meta_data[child] ||= MetaData.new(@root,row,[@root.class.name,@root.class])
                child
            else
                nil
            end
        end

        def rows(item=@root)
            if item.object_id == @root.object_id
                1
            else
                0
            end
        end
    end


    # A ProxyDataModel is used to combine multiple TypelibDataModel into one
    # model for tree view display. Thereby it is allowed to add a
    # ProxyDataModel to another ProxyDataModel.
    class ProxyDataModel
        attr_accessor :root
        attr_accessor :options
        MetaData = Struct.new(:name,:value,:data,:listener)

        # A ProxyDataModel
        #
        # @param [ProxyDataModel] parent Parent of the ProxyDataModel which should be set
        #    if the ProxyDataModel type belongs to another ProxyDataModel
        def initialize(parent = nil)
            @root = Hash.new
            @item_to_model = Hash.new         # maps items to their model
            @meta_data = Hash.new
            @parent = parent
            @editable = false
            @options = {:enabled => true}
        end

        def on_changed(&block)
            @on_changed = block
        end

        def on_added(&block)
            @on_added = block
        end
        
        def item_changed(item)
            @on_changed.call item if @on_changed && item.object_id != @root.object_id
            number_of_elements = rows(item)-1
            0.upto(number_of_elements) do |i|
                c =  child(i,item)
                item_changed c if c && c.is_a?(ProxyDataModel)
            end
        end

        # calls stop_listening on all childs of the given item
        # and stop on the listener belonging to item
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

        def add?(name)
            if @root.has_key? name
                false
            else
                true
            end
        end

        def sort(value=:ascending_order)
            options[:sort] = value
            @root.each_value do |model|
                model.sort value
                item_changed model
            end
        end

        # Adds a model to the ProxyDataModel
        #
        # @param [TypelibDataModel,ProxyDataModel] model The model
        # @param [String] name The name which is displayed for the root node of the added model
        # @param [#to_s] value The value which is displayed for the root node
        # @param [Object] data underlying data object which is returned by raw_data
        # @param [Orocos::Async::EventListener] listener Event listener which is updating the added model
        def add(model,name,value,data=nil,listener=nil)
            return false unless add?(name)
            raise "no name" until name
            model = if model
                        model
                    else
                        ProxyDataModel.new self
                    end

            model.on_changed do |item|
                @on_changed.call(item) if @on_changed
            end
            model.on_added do |parent,row|
                @on_added.call(parent,row) if @on_added
            end
            model.parent = self
            @root[name] = model
            @meta_data[model] = MetaData.new(name,value,data,listener)
            @on_changed.call(self) if @on_changed
            @on_added.call(self,rows-1) if @on_added
            true
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
                    case options[:sort]
                    when :ascending_order
                        @root[@root.keys.sort[row]]
                    when :descending_order
                        @root[@root.keys.sort.reverse[row]]
                    else
                        @root[@root.keys[row]]
                    end
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
                    raise ArgumentError, "cannot find given item #{item}"
                end
            end
        end

        def parent(item=@root)
            return @parent if item.object_id == @root.object_id
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
            raise ArgumentError, "no item given" unless item
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
                elsif role == Qt::BackgroundRole && item.modified_by_user?
                    Qt::Variant.new(Qt::red)
                elsif role == Qt::DisplayRole
                    Qt::Variant.new(@meta_data[item].value.to_s)
                else
                    Qt::Variant.new
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

        def flags(column,item)
            return 0 if !@options[:enabled]
            model = @item_to_model[item]
            if model
                model.flags(column,item)
            else
                return 0 if !item.options[:enabled]
                if options[:editable] && column == 1
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
            else
                false
            end
        end

        def mime_data(item)
            model = @item_to_model[item]
            if model
                model.mime_data(item)
            else
                0
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
            sample = port.new_sample.zero!
            super(TypelibDataModel.new(sample,self,:no_data => true),port.name,port.type_name,port)
        rescue Orocos::TypekitTypeNotFound => e
            super(nil,port.name,e.message,port)
        end
    end


    class DataProducingObjectModel < ProxyDataModel
        DIRECTLY_DISPLAYED_RUBY_TYPES = [String,Numeric,Symbol,Time]
        def add(object,name=nil,value=nil,data=nil)
            if name
                return super(object,name,value,data)
            end
            return false unless add?(object.name)
            model = nil
            listener = object.on_reachable do
                message = object.type.name
                begin
                    sample = object.new_sample.zero!
                    rb_sample = Typelib.to_ruby(sample)
                    listener2 = if DIRECTLY_DISPLAYED_RUBY_TYPES.any? { |rt| rt === rb_sample }
                                    model = SimpleTypelibDataModel.new(sample, self,@type_policy)
                                    on_update(object) do |data|
                                        data_value(model,data.to_s)
                                        model.update data
                                    end
                                else
                                    model = TypelibDataModel.new(sample, self,@type_policy)
                                    on_update(object) do |data|
                                        model.update data
                                    end
                                end
                    listener2.stop
                rescue Orocos::TypekitTypeNotFound => e
                    message = e.message
                end
                ProxyDataModel.instance_method(:add).bind(self).call(model,object.name,message,object,listener2)
                listener.stop
            end
        end
    end

    class OutputPortsDataModel < DataProducingObjectModel

        def initialize(parent = nil)
            super
            @type_policy = {:enabled => true,:editable => false,:no_data => true}
        end

        def on_update(object, &block)
            object.on_data(&block)
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

        def mime_data(item)
            port,subfield = port_from_index(item)
            port = if port && !subfield.empty?
                       port.sub_port(subfield)
                   else
                       port
                   end
            return 0 unless port
            val = Qt::MimeData.new
            val.setText URI::Orocos.from_port(port).to_s
            val
        end

        def context_menu(item,pos,parent_widget)
            port,subfield = port_from_index(item)
            return false unless port
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

        def flags(column,item)
            if column != 0 || !@options[:enabled] || @item_to_model[item]
                super
            else
                Qt::ItemIsEnabled | Qt::ItemIsSelectable | Qt::ItemIsDragEnabled
            end
        end
    end

    class PropertiesDataModel < DataProducingObjectModel

        def initialize(parent = nil)
            super
            options[:editable] = true
            @type_policy = {:enabled => true,:editable => true,:accept => true}
        end

        def on_update(object, &block)
            object.on_change(&block)
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
                port = task.port(port_name)
                p = proc do
                        if port.reachable?
                            if port.input?
                                @input_ports.add(port)
                            elsif port.output?
                                @output_ports.add(port)
                            else
                                raise "Port #{port} is neither an input nor an output port"
                            end
                        else
                            Orocos::Async.event_loop.once 0.1,&p
                        end
                end
                p.call
            end

            task.on_property_reachable do |property_name|
                @properties.add(task.property(property_name))
            end
            @task = task
        end

        def write(model,&block)
            if model == @properties
                0.upto(@properties.rows) do |i|
                    child = @properties.child(i)
                    @properties.write child
                end
            end
        end

        def reset(model)
            if model == @properties
                0.upto(@properties.rows) do |i|
                    child = @properties.child(i)
                    @properties.reset child
                end
            end
        end

        def flags(column,item)
            return 0 if !@options[:enabled]
            model = @item_to_model[item]
            if model
                model.flags(column,item)
            else
                return 0 if !item.options[:enabled]
                if item == @properties && column == 1
                    Qt::ItemIsEnabled | Qt::ItemIsEditable
                else
                    Qt::ItemIsEnabled
                end
            end
        end
    end

    class TaskContextsDataModel < ProxyDataModel
        def initialize(parent = nil,options=Hash.new)
            super(parent)
            options = Kernel.validate_options options,:use_basename => false
            @options = @options.merge options
        end

        def add(model,name=nil,value=nil,data=nil)
            if !name
                task = model
                name = if @options[:use_basename]
                           task.basename
                       else
                           task.name
                       end
                return false unless add?(name)
                model = TaskContextDataModel.new task, self
                super(model,name,"",task)
                task.on_state_change do |state|
                    data_value(model,state.to_s)
                    item_changed(model)
                end
                task.on_unreachable do
                    data_value(model,"UNREACHABLE")
                    model.options[:enabled] = false
                    item_changed(model)
                end
                task.on_reachable do
                    model.options[:enabled] = true
                end
            else
                return super(model,name,value,data)
            end
            true
        end

        def context_menu(item,pos,parent_widget)
            return true if super
            model = @item_to_model[item]
            data = @meta_data[model]
            task = raw_data(item)
            if task.respond_to? :current_state
                ContextMenu.task_state(task,parent_widget,pos)
                true
            end
        end
    end

    class NameServiceDataModel < TaskContextsDataModel
        def initialize(parent,name_service)
            super(parent,:use_basename => true)
            name_service.on_task_added do |task_name|
                add(name_service.proxy(task_name)) if add?(task_name)
            end
        end
         
        def add?(name)
            super Orocos.name_service.basename(name)
        end
    end

    class NameServicesDataModel < TaskContextsDataModel
        def initialize(parent = nil)
            super(parent)
        end
        def add(name_service)
            if name_service.is_a? Orocos::NameServiceBase
                raise ArgumentError,"name_service #{name_service} is not a Orocos::Async::NameServiceBase"
            elsif name_service.is_a? Orocos::Async::NameServiceBase
                return false unless add? name_service.name
                model = NameServiceDataModel.new self,name_service
                name_service.on_error do |error|
                    data_value(model,error.to_s)
                    model.options[:enabled] = false
                    item_changed model
                end
                super(model,name_service.name,"",name_service)
            else
                super
            end
        end
        def context_menu(item,pos,parent_widget)
            model = @item_to_model[item]
            data = @meta_data[model]
            obj = raw_data(item)
            if obj.is_a? Orocos::Async::NameServiceBase
                false
            else
                super
            end
        end
    end

    class LogAnnotationDataModel < ProxyDataModel
        def initialize(annotation,parent = nil)
            super parent
            @samples = ProxyDataModel.new self
            add(@samples,"Samples",annotation.samples.size,nil)
        end
    end

    class GlobalMetaDataModel < ProxyDataModel
        def initialize(log_replay,parent = nil)
            super parent
            log_replay.annotations.each do |annotation|
                model = LogAnnotationDataModel.new annotation, self
                add(model,annotation.stream.name,annotation.stream.type_name,model)
            end
        end
    end

    class LogOutputPortDataModel < ProxyDataModel
        def initialize(port,parent = nil)
            super parent
            options[:enabled]= if port.number_of_samples == 0
                                   false
                               else
                                   true
                               end
            @samples = ProxyDataModel.new self
            @first_sample = ProxyDataModel.new self
            @last_sample = ProxyDataModel.new self
            @meta = ProxyDataModel.new self
            port.metadata.each_pair do |key,value|
                model = ProxyDataModel.new @meta
                @meta.add(model,key,value,nil)
            end
            add(@meta,"Meta Data","",nil)
            add(@samples,"Samples",port.number_of_samples,nil)
            add(@first_sample,"First Sample",port.first_sample_pos,nil)
            add(@last_sample,"Last Sample",port.last_sample_pos,nil)
        end
    end

    class LogTaskDataModel < OutputPortsDataModel
        def initialize(task,parent = nil)
            super parent
            options[:enabled] = false

            add(nil,"Properties")
            task.each_property do |props|
                props.each do |prop|
                    model = TypelibDataModel.new prop.read,self,:no_data => true
                    prop.on_change do |data|
                        model.update(data)
                    end
                    add(model,prop.name,prop.type_name,prop)
                end
            end

            task.each_port do |ports|
                ports.each do |port|
                    model = LogOutputPortDataModel.new port,self
                    add(model,port.name,port.type_name,port)
                    options[:enabled] = true if port.number_of_samples > 0
                end
            end
        end

        def port_from_index(index)
            port,_ = super
            return [nil,nil] unless port
            # we have to return a PortProxy here
            task = Orocos::Async::Log::TaskContext.new(port.task)
            task = Orocos::Async::TaskContextProxy.new(task.name,:use => task,:wait => true)
            port = task.port(port.name)
            [port,[]]
        end
    end

    class LogReplayDataModel < ProxyDataModel
        def initialize(log_replay,parent = nil)
            super(parent)
            @global_meta_data = GlobalMetaDataModel.new log_replay,self
            add(@global_meta_data,"-Global Meta Data-","",@global_meta_data)
            log_replay.tasks.each do |task|
                task = Orocos::Async::Log::TaskContext.new(task)
                model = LogTaskDataModel.new task,self
                add(model,task.name,task.file_path,task)
            end
        end
    end

    #Item Model for vizkit types
    class VizkitItemModel < Qt::AbstractItemModel
        MAX_NUMBER_OF_CHILDS = 100

        def initialize(data,parent = nil)
            super(parent)
            @data_model = data
            @data_model.on_changed do |item|
                index = @index[item]
                if index
                    emit dataChanged(index,index(index.row,1,index.parent))
                end
            end
            @data_model.on_added do |parent,row|
                index = @index[parent]
                index = if index
                            index
                        else
                            Qt::ModelIndex.new
                        end
                if index.isValid || parent == @data_model
                    beginInsertRows(index,row,row)
                    endInsertRows()
                end
            end

            # we have to save the model index for the parent
            # otherwise qt is complaining that two childs
            # of item have different parents
            @index = Hash.new
            @header = ["Field","Value"]
            setSupportedDragActions(Qt::CopyAction)
        end

        def header(field1,field2)
            @header = [field1,field2]
        end

        def stop_listening(index)
            item = itemFromIndex(index)
            @data_model.stop_listening(item)
        end

        def sort(column,order)
            if order == Qt::AscendingOrder
                @data_model.sort(:ascending_order)
            else
                @data_model.sort(:descending_order)
            end
            @index.clear
            reset
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
            return Qt::Variant.new if !index.valid?
            item = itemFromIndex(index)
            val = if index.column == 0
                      if role == Qt::DisplayRole
                          @data_model.field_name(item)
                      else
                          Qt::Variant.new
                      end
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
                item = itemFromIndex(index)
                @data_model.flags(index.column,item)
            else
                0
            end
        end

        def headerData(section,orientation,role)
            return Qt::Variant.new if role != Qt::DisplayRole
            if section == 0
                Qt::Variant.new(@header[0])
            else
                Qt::Variant.new(@header[1])
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

        def mimeData(indexes)
            return 0 if indexes.empty? || !indexes.first.valid?
            item = itemFromIndex(indexes.first)
            if item
                #store mime data otherwise it gets collected
                #this object will be deleted by qt
                @data_model.mime_data(item)
            else
                0
            end
        end

        def mimeTypes
            ["text/plain"]
        end
    end

    def self.setup_tree_view(tree_view)
        delegator = ItemDelegate.new(tree_view,nil)
        tree_view.setItemDelegate(delegator)
        tree_view.setSortingEnabled true
        tree_view.setAlternatingRowColors(true)
        tree_view.setContextMenuPolicy(Qt::CustomContextMenu)
        tree_view.setDragEnabled(true)
        tree_view.connect(SIGNAL('customContextMenuRequested(const QPoint&)')) do |pos|
            index = tree_view.index_at(pos)
            index.model.context_menu(index,pos,tree_view) if index.model
        end

        def tree_view.setModel(model)
            raise ArgumentError,"wrong model type" unless model.is_a? Qt::AbstractItemModel
            super
            connect SIGNAL("collapsed(QModelIndex)") do |index|
                model.stop_listening index
            end
            # no need for expand event
            # auto reconnect if data field are accessed by the TreeView
        end
    end
end
