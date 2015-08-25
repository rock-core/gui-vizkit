#!/usr/bin/env ruby

begin
require 'thread'
require 'Qt4'
require  File.join(File.dirname(__FILE__),'qt_bugfix')
require 'qtuitools'
rescue Exception => e
    #no logger is available at this point so create one 
    log = Logger.new(STDOUT)
    log.error "!!! Cannot load Qt4 ruby bindings !!!"
    raise e
end
require 'delegate'
require 'rexml/document'
require 'rexml/xpath'

module Vizkit
    #because of the shadowed method load we have to use DelegateClass
    class UiLoader < DelegateClass(Qt::UiLoader)
        include PluginAccessorCommon
        attr_accessor :plugin_specs

        class << self
            attr_accessor :current_loader_instance
            attr_accessor :current_file_path

            def current_loader_instance
                raise "No Uiloader. Call Vizkit.default_loader to create one!" if !@current_loader_instance
                @current_loader_instance
            end

            def register_ruby_widget(widget_name,create_method=nil,&block)
                current_loader_instance.register_plugin(widget_name,:ruby_plugin,create_method,&block)
            end

            def register_3d_plugin(ruby_name,lib_name=nil,plugin_name=nil)
                lib_name = lib_name || ruby_name
                plugin_name = plugin_name || ruby_name
                spec = current_loader_instance.register_plugin(ruby_name,:vizkit3d_plugin) do |parent|
                    widget = Vizkit.vizkit3d_widget
                    widget.show # if widget.hidden?
                    if !widget.respond_to? :createPlugin
                        raise "Extension for Vizkit3d widget was not loaded. Cannot create any Vizkit3dPlugin"
                    end
                    widget.createPlugin(lib_name,plugin_name,spec)
                end
                spec.cplusplus_name(plugin_name).lib_name(lib_name)
            end
            def extend_cplusplus_widget_class(class_name,&block)
                spec = current_loader_instance.register_plugin(class_name,:cplusplus_widget) do |parent|
                    widget = current_loader_instance.create_widget(class_name,parent,true,true)
                    raise RuntimeError, "There is no widget called #{class_name} available. Check spelling" unless widget
                    UiLoader.redefine_widget_class_name(widget,class_name)
                    widget
                end
                spec.extension(VizkitCXXExtension)
                spec.extension(block)
                spec.cplusplus_name(class_name)
                spec.on_create do |plugin|
                    plugin.initialize_vizkit_extension
                end
            end

            #interface for ruby extensions
            def register_plugin_for(plugin_name,value,callback_type,default=nil,callback_fct=nil,&block)
                current_loader_instance.register_plugin_for(plugin_name,value,callback_type,default,callback_fct,&block)
            end
            def register_widget_for(widget_name,value,callback_fct=nil,&block)
                register_plugin_for(widget_name,value,:display,nil,callback_fct,&block)
            end
            def register_default_widget_for(widget_name,value,callback_fct=nil,&block)
                register_plugin_for(widget_name,value,:display,true,callback_fct,&block)
            end
            def register_control_for(widget_name,value,callback_fct=nil,&block)
                register_plugin_for(widget_name,value,:control,nil,callback_fct,&block)
            end
            def register_default_control_for(widget_name,value,callback_fct=nil,&block)
                register_plugin_for(widget_name,value,:control,true,callback_fct,&block)
            end
            def register_default_3d_plugin_for(widget_name,type_name,display_method = nil,&block)
                register_plugin_for(widget_name,type_name,:display,true,display_method,&block)
            end
            def register_3d_plugin_for(widget_name,type_name,display_method = nil,&block)
                register_plugin_for(widget_name,type_name,:display,nil,display_method,&block)
            end

            #redefines the widget class name of a widget 
            #this is needed because the qt loader does not set it right
            #after the widget was loaded
            def redefine_widget_class_name(widget,class_name)
                if class_name && (widget.class_name == "Qt::Widget" || widget.class_name == "Qt::MainWindow")
                    widget.instance_variable_set(:@real_class_name,class_name)
                    def widget.class_name;@real_class_name;end
                    def widget.className;@real_class_name;end
                end
            end

            def register_deprecate_plugin_clone(clone_name,name,message="[Depricated Plugin Name] #{clone_name}. Use #{name}",&block)
                current_loader_instance.register_deprecate_plugin_clone(clone_name,name,message,&block)
            end
            
            def deprecate_plugin_spec(spec,message=nil,&block)
                current_loader_instance.deprecate_plugin_spec(spec,message,&block)
            end
        end
        
        def initialize(parent = nil)
            super(Qt::UiLoader.new(parent))
            # This should NOT be here. If that is required, then one that wants
            # to use Vizkit should be required to load/initialize it FIRST
            #
            # Keep it there for backward compatibility though :(
            if !Orocos.loaded?
                Vizkit.warn "one must call Orocos.load before using Vizkit.default_loader"
                Orocos.load
            end
            @plugin_specs = Hash.new

            load_extensions(File.join(File.dirname(__FILE__),"cplusplus_extensions"))
            load_extensions(File.join(File.dirname(__FILE__),"widgets"))

            paths = plugin_paths().uniq
            paths.each do|path|
                if File.directory?(path)
                    Vizkit.info "Load extension from #{path}"
                    load_extensions(path)
                else
                    Vizkit.info "No Directory! Cannot load extensions from #{path}."
                end
            end
        end

        def add_plugin_path(path)
            return if plugin_paths.include? path
            super
            load_extensions(path)
        end

        def load_extensions(*paths)
            paths.flatten!
            paths.each do |path|
                if ::File.file?(path) 
                    UiLoader.current_loader_instance = self
                    UiLoader.current_file_path = path
                    begin 
                        Kernel.load path if !path.match(/.ui.rb$/) && ::File.extname(path) ==".rb"
                    rescue Interrupt
                        raise
                    rescue Exception => e
                        Vizkit.warn "Cannot load vizkit extension #{path}"
                        Vizkit.warn e.message
                        e.backtrace.each do |line|
                            Vizkit.warn line
                        end
                    end
                elsif ::File.directory?(path)
                    load_extensions ::Dir.glob(::File.join(path,"**","*.rb"))
                else
                    # Check if we can find the file in $LOAD_PATH and by adding .rb
                    paths.each do |file|
                        $LOAD_PATH.each do |path|
                            if File.file?(full_path = File.join(path, file))
                                load_extensions(full_path)
                                return
                            elsif File.file?(full_path = "#{full_path}.rb")
                                load_extensions(full_path)
                                return
                            end
                        end
                    end
                    warn "Qt designer plugin file or directory does not exist: #{path.inspect}!"
                end
            end
        end

        def register_plugin(plugin_name,plugin_type,creation_method=nil,&block)
            if @plugin_specs[plugin_name] 
                raise "Plugin #{plugin_name} is already registered!"
            end
            spec = PluginSpec.new(plugin_name).creation_method(creation_method,&block).plugin_type(plugin_type)
            spec.extension(PluginConnections)
            raise "Cannot register plugin. Plugin name is nil" unless spec.plugin_name
            add_plugin_spec(spec)
        end

        def deprecate_plugin_spec(spec,message=nil,&block)
            if(block||message)
                spec.instance_eval do 
                    alias :old_create_plugin :create_plugin
                end
                spec.instance_variable_set :@__deprecate_message,message
                spec.instance_variable_set :@__deprecate_block,block
                def spec.create_plugin(parent=nil)
                    Vizkit.warn @__deprecate_message if @__deprecate_message
                    @__deprecate_block.call if @__deprecate_block
                    old_create_plugin(parent)
                end
                #set all callbacks to false
                spec.callback_specs.each do|calls|
                    calls.default(false)
                end
                #add deprecate flag
                spec.flags(spec.flags.merge({:deprecated => true}))
                add_plugin_spec spec
            end
            spec
        end

        def register_deprecate_plugin_clone(clone_name,name,message=nil,&block)
            spec = find_plugin_spec!({:plugin_name => name})
            if !spec
                raise "Cannot register deprecate plugin clone #{clone_name} for #{name}. #{name} is not a registered plugin."
            end
            if find_plugin_spec!({:plugin_name => clone_name})
                raise "Cannot register deprecate plugin clone #{clone_name} for #{name}. #{clone_name} is already registered."
            end
            clone_spec = spec.clone
            clone_spec.instance_variable_set(:@plugin_name, clone_name)
            clone_spec.flags(clone_spec.flags.merge({:clone_of => name}))
            deprecate_plugin_spec(clone_spec,message,&block)
            add_plugin_spec clone_spec
        end

        def register_plugin_for(plugin_name,values,callback_type,default=nil,callback_fct=nil,&block)
            if !callback_fct && !block
                raise ArgumentError, "#register_plugin_for(#{plugin_name}, #{values}, #{callback_type}) with neither a callback method name nor a block"
            end

            spec = find_plugin_spec!({:plugin_name => plugin_name})
            if !spec
                raise "Cannot register #{callback_fct||block} for #{plugin_name}. #{plugin_name} is not a registered plugin."
            end
            
            values = Array(values)
            specs = Array.new
            values.each do |value|
                spec2 = find_plugin_spec!(:callback_type => callback_type,:argument => value)
                #delete old default
                if spec2 
                    spec2 = spec2.find_callback_spec!(:callback_type => callback_type,:argument=> value)
                    if default
                        spec2.default(false)
                    else
                        # check if the argument of the found spec is for a parent class type
                        if spec2.argument != PluginHelper.normalize_obj(value,false).first
                            default = true
                        end
                    end
                else
                    default = true
                end
                spec.callback_spec(value,callback_type,default,callback_fct,&block).file_name(UiLoader.current_file_path)
                specs << spec.callback_specs.last
            end
            values.size == 1 ? specs.first : specs
        end

        #creates a widget and all its children from an ui file
        def load(ui_file,parent=nil)
            if parent and not parent.is_a? Qt::Widget
                Kernel.raise("You can only set a QWidget as parent. You tried: #{parent}")
            end
            
            file = Qt::File.new(ui_file)
            file.open(Qt::File::ReadOnly)

            form = nil
            Dir.chdir File.dirname(ui_file) do 
                form = __getobj__.load(file,parent)
            end
            return unless form 

            mapping = map_objectName_className(ui_file)
            extend_widgets form, mapping

            #check that all widgets are available 
            mapping.each_key do |k|
                if !form.respond_to?(k.to_s) && form.objectName != k
                    Vizkit.warn "Widgte #{k} of class #{mapping[k]} could not be loaded! Is this Qt Designer Widget installed?"
                end
            end
            form
        end

        #work around
        #metaObject.className is always QWidget for qt4-ruby1.8 4.4.5
        #therefore we have to pass the ui file to get the mapping
        #this error disappears on newer versions
        def map_objectName_className(ui_file)
            doc = REXML::Document.new File.new ui_file
            mapping = Hash.new
            REXML::XPath.each( doc, "//widget")do |ele|
                mapping[ele.attributes["name"]] = ele.attributes["class"]
            end
            mapping
        end

        #extends the widget and all its children 
        #this is needed for cases where the widget was loaded via 
        #an ui file
        def extend_widgets(widget,mapping,children=true)
            class_name = mapping[widget.objectName]
            if class_name
                UiLoader.redefine_widget_class_name widget,class_name
                spec = find_plugin_spec!({:plugin_name => class_name})
                spec.extend_plugin(widget) if spec
            end
            return widget unless children

            #extend childs and add accessor for QObject
            #find will find children recursive 
            #objectNames are unique for widgets if the ui file was 
            #generated with the qt designer therefore we can put them to the toplevel
            #warning: ruby objects have the wrong parent
            children = widget.findChildren(Qt::Object)
            children.each do |child|
                if child.objectName && child.objectName.size > 0
                    extend_widgets child, mapping,false
                    (class << widget; self;end).send(:define_method,child.objectName){child}
                end
            end
            widget
        end

        def widget?(name)
            return unless name
            availableWidgets.include? name
        end

        def create_plugin(class_name,parent=nil,reuse=false,raise_=true)
            spec = find_plugin_spec!({:plugin_name => class_name})
            return unless spec
            #check if there is already a widget of the same type
            #which can handle multiple values 
            if reuse
                spec.created_plugins.each do |plugin| 
                    return plugin if(plugin.respond_to?(:multi_value?) && plugin.multi_value?)
                end
            end
            plugin = spec.create_plugin(parent)
            plugin.setObjectName class_name if plugin.is_a?(Qt::Object) && !plugin.objectName
            plugin
        end

        # compatibility method
        def create_widget(name,parent=nil,reuse=true,internal=false)
            unless internal
                Vizkit.warn "[DEPRECATATION] 'create_widget' is deprecated use 'create_plugin' instead."
                create_plugin(name,parent,reuse)
            else
                super(name,parent)
            end
        end

        #creates a plugin which can handle the given type
        #if reuse is set to ture it will first try to
        #return a plugin which is already created and can 
        #handle multiple values of the the given value 
        def create_plugin_for(value,callback_type,parent=nil,reuse=false)
            name = find_plugin_name!(:argument => value,:callback_type => callback_type)
            create_plugin(name,parent,reuse) if name 
        end

        #returns an array of plugin specs matching the given pattern
        #
        #if registered is set to false the mehtod will 
        #search for not registered cplusplus widgets if no spec can be found
        #and automatically register this widget if one can be found
        #
        #:plugin_name
        #:cplusplus_name
        #:value                 if given callback_type must be given as well
        #:callback_type         if given value must be given as well
        #:default               if given value and callback_type must be given as well
        #:registered            if set to true the method will not search for 
        #                       not registered c++ widgets and automatically register them 
        #
        def find_all_plugin_specs(*pattern)
            return Array.new if pattern.empty?
            pattern = pattern.first
            if pattern.size == 1 && pattern[:plugin_name]
                spec = @plugin_specs[pattern[:plugin_name]]
                return Array(spec) if spec 
                #try to find a cplusplus widget which is not registered 
                #and register it 
                if widget?(pattern[:plugin_name])
                    result = Array(UiLoader.extend_cplusplus_widget_class(pattern[:plugin_name]))
                    return result
                end
            end
            @plugin_specs.values.find_all do |spec|
                spec.match?(pattern)
            end
        end
        
        # Return all plugin specs
        def all_plugin_specs
            @plugin_specs.values
        end

        def find_plugin_spec!(*pattern)
            return if pattern.empty?
            pattern = pattern.first
            if pattern.size == 1 && pattern[:plugin_name]
                return find_all_plugin_specs(pattern).first
            end

            names = PluginHelper.normalize_obj(pattern[:argument])
            names << nil if names.empty?
            pattern = pattern.dup
            pattern[:exact] = true
            pattern[:default] = true if !pattern.has_key?(:default)
            specs = Array.new
            names.each do |name|
                pattern[:argument] = name
                result = find_all_plugin_specs(pattern)
                if !result.empty?
                    specs = result
                    break
                end
            end
            if specs.size > 1
                raise ArgumentError.new "Found more than on PluginSpec for the given pattern"
            end
            specs.first
        end

        #returns the plugin names which can handle the given value
        def find_all_plugin_names(*pattern)
            find_all_plugin_specs(*pattern).map do |spec|
                spec.plugin_name
            end
        end

        def find_plugin_name!(*pattern)
            spec = find_plugin_spec!(*pattern)
            spec.plugin_name if spec
        end

        # Ruby 1.9.3's Delegate has a different behaviour than 1.8 and 1.9.2. This
        # is breaking the class definition, as some method calls gets undefined.
        #
        # Backward compatibility fix.
        def method_missing(*args, &block)
            #check if we can find a cplusplus widget matching the name
            if widget? args[0].to_s
                spec = find_all_plugin_specs(:plugin_name => args[0].to_s).first
                return spec.create_plugin(*args[1..-1]) if spec
            end
            begin
                __getobj__.send(*args, &block)
            rescue  NoMethodError => e
                Vizkit.error "#{args.first} is not plugin of the ui loader"
                Vizkit.error "The following plugins are registered:"
                names = available_plugins.sort
                Vizkit.error names.join(", ")
                Kernel.raise e 
            end
        end

        alias :addPluginPath :add_plugin_path
    end
end

