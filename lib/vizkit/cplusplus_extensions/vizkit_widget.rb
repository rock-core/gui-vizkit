require 'vizkit/vizkittypelib'
module Vizkit
module VizkitPluginExtension
    attr_reader :plugins 

    def load_adapters(plugin_spec)
        if !Orocos.initialized? # Check if Orocos has been initialized
   	    raise RuntimeError, 'you need to call Orocos.initialize before using the Ruby bindings for Vizkit3D'
	end
        @bridges = Hash.new
        @plugins = Hash.new
        
        plugins[plugin_spec.plugin_name] = self
        @adapter_collection = getRubyAdapterCollection
        return if !@adapter_collection
        @adapter_collection.getListOfAvailableAdapter.each do |name|
            plugin = @adapter_collection.getAdapter(name)
            bridge = TypelibToQVariant.create_bridge
            Qt::Object.connect(bridge, SIGNAL('changeVariant(QVariant&, bool)'), plugin, SLOT('update(QVariant&, bool)'))
            @bridges[plugin.getRubyMethod] = bridge
            @plugins[plugin.getRubyMethod] = plugin
            cxx_typename = plugin.getDataType
            # the plugin reports a C++ type name. We need a typelib type name
            typename = Typelib::GCCXMLLoader.cxx_to_typelib(cxx_typename)
            if !Orocos.registered_type?(cxx_typename)
                Orocos.load_typekit_for(typename, true) 
            end
            expected_ruby_type = Orocos.typelib_type_for(typename)
            is_opaque = (expected_ruby_type.name != typename)

            singleton_class = (class << self; self end)
            singleton_class.class_eval do
		attr_accessor :type_to_method
		
                define_method(plugin.getRubyMethod) do |*args|
		    value, _ = *args
                    value = Typelib.from_ruby(value, expected_ruby_type)
                    bridge.wrap(value, typename, is_opaque)
                end
		
		define_method('updateData') do |value|
		    if(method_name = @type_to_method[value.class.name])
			self.send(method_name, value)
		    else
			message = "Expected type(s) "
			
			type_to_method.each do |i,j |
			    message = message + i + " "
			end
			message = message + "but got #{value.class.name}"
			raise ArgumentError, message
		    end
                end		
            end
	    if(!self.type_to_method)
		self.type_to_method = Hash.new()
	    end
	    if(plugin.getRubyMethod.match("update"))
		self.type_to_method[expected_ruby_type.name] = plugin.getRubyMethod
	    end

            plugin.instance_variable_set(:@expected_ruby_type,expected_ruby_type)
            def plugin.expected_ruby_type
                @expected_ruby_type
            end
        end
    end

    def pretty_print(pp)
        pp.text "=========================================================="
        pp.breakable
        pp.text "Vizkit3d Plugin: #{name} (#{class_name})"
        pp.breakable
        pp.text "Ruby Name: #{ruby_class_name}"
        pp.breakable
        pp.text "Library name: #{lib_name}"
        pp.breakable
        
        pp.text "----------------------------------------------------------"
        pp.breakable 
        pp.text "  Methods:"
        methods = method_list-["destroyed(QObject*)", "destroyed()", "deleteLater()", "_q_reregisterTimers(void*)", "getRubyAdapterCollection()"]
        methods.each do |method|
            pp.breakable
            pp.text "    " + method 
        end
        #begin
        #backward compatibility
        if @plugins.size > 1
            pp.breakable
            pp.breakable
            pp.text "!!! The vizkit3d plugin is using an old mechanism to update the data" 
            pp.breakable
            pp.text "!!! Please update to the new mechanism see" 
            pp.breakable
                pp.text "!!! http://www.rock-robotics.org/documentation/graphical_user_interface/450_vizkit3d.html"
            pp.breakable
            pp.text "  Bridge Methods:"
        end
            
        @plugins.each_pair do |key,plugin|
            if plugin != self
                pp.breakable
                pp.text "    " + "#{key} (#{plugin.expected_ruby_type})" 
                pp.breakable
                pp.text "    " + "updateData (#{plugin.expected_ruby_type})" 
            end
        end
        #end
        pp.breakable 
    end
end


module VizkitPluginLoaderExtension
    def initialize_vizkit_extension
        super
        @use_transformer_broadcaster = true
        @load_transformer_config_from_broadcaster = true
        Vizkit.ensure_orocos_initialized
        if !@connected_to_broadcaster
            @port_frame_associations ||= Hash.new
            @connected_transformation_producers ||= Hash.new
            task_name, port_name = Vizkit.vizkit3d_transformer_broadcaster_name
            begin
                Orocos.load_typekit 'transformer'
                if task_name
                    Vizkit.connect_port_to task_name, port_name, self
                    @connected_to_broadcaster = true
                end
            rescue Orocos::NotFound => e
                Vizkit.warn e
            end
        end
        @grid = createPlugin("vizkit3d","GridVisualization")
        @grid.setPluginName("Grid")
    end

    def grid
        @grid
    end

    def setGrid(val)
        @grid.enabled = val
    end

    def isGridEnabled
        @grid.enabled
    end

    def load_plugin(path)
        loader = Qt::PluginLoader.new(path)
        loader.load
        if !loader.isLoaded
            Vizkit.error "Cannot load Vizkit3D pluign #{path}. Library seems to be incompatible to the qt loader. Have you created a plugin factory?"
            Kernel.raise "Cannot load #{path}. Last error is: #{loader.errorString}"
        end
        plugin_instance = loader.instance
        if plugin_instance == nil
            Kernel.raise "Could not load plugin #{loader.fileName}. Last error is #{loader.errorString}"
        end
        plugin_instance
    end

    def findPluginPath(plugin_name)
        path = if !ENV['VIZKIT_PLUGIN_RUBY_PATH']
                   "/usr/local/lib:/usr/lib"
               else
                   ENV['VIZKIT_PLUGIN_RUBY_PATH']
               end
        path.split(':').each do |path|
            p = File.join(path, "lib#{plugin_name}-viz.so")
            return p if File.file?(p)
            p = File.join(path, "lib#{plugin_name}-viz.bundle")
            return p if File.file?(p)
        end
        nil
    end

    # Returns the list of plugins that are available
    #
    # The returned value is an array of pairs [lib_name, plugin_name]
    def plugins
        libs = Array.new
        path = if !ENV['VIZKIT_PLUGIN_RUBY_PATH']
                   "/usr/local/lib:/usr/lib"
               else
                   ENV['VIZKIT_PLUGIN_RUBY_PATH']
               end
        path.split(':').each do |path|
            next unless File::directory? path
            Dir::foreach(path) do |lib|
                if lib =~ /^lib(.*)-viz.so$/
                    qt_plugin =
                        begin load_plugin(File.join(path, lib))
                        rescue Exception => e
                            STDERR.puts "WARN: cannot load vizkit plugin library #{File.join(path, lib)}: #{e.message}"
                            next
                        end

                    libname = $1
                    adapters = qt_plugin.getAvailablePlugins
                    adapters.each do |name|
                        libs << [libname, name]
                    end
                end
            end
        end
        libs
    end

    # For backward compatibility only
    def custom_plugins
	plugins
    end

    # Creates a vizkit plugin object
    #
    # Plugins, whose list is returned by #custom_plugins, are created with
    #
    #   createPlugin(lib_name, plugin_name)
    #
    # Where +lib_name+  is the name of the plugin library without the "lib" and
    # "-viz.so" parts. For instance, a package that installs a library called
    # <tt>libvfh_star-viz.so</tt> will do
    #
    #   createPlugin("vfh_star", "VFHTree")
    #
    # Moreover, if the library only provides one plugin, the plugin name can be
    # omitted
    #
    #   createPlugin("vfh_star")
    #
    def createPlugin(lib_name, plugin_name = nil, plugin_spec = PluginSpec.new(plugin_name))
	path = findPluginPath(lib_name)
	if !path
	    Kernel.raise "cannot find lib#{lib_name}-viz.so in VIZKIT_PLUGIN_RUBY_PATH."
	end
	plugin = load_plugin(path)
	if !plugin_name
	    if plugin.getAvailablePlugins.size > 1
		Kernel.raise "#{lib_name} either defines multiple plugins (and you must select one explicitely)"
	    else
		plugin_name = plugin.getAvailablePlugins.first
	    end
	end

	if !plugin.getAvailablePlugins.include?(plugin_name)
	    if plugin.getAvailablePlugins.include?("#{plugin_name}Visualization")
		plugin_name = "#{plugin_name}Visualization"
	    else
		Kernel.raise "library #{lib_name} does not have any vizkit plugin called #{plugin_name}, available plugins are: #{plugin.getAvailablePlugins.join(", ")}"
	    end
	end
	plugin = plugin.createPlugin(plugin_name)
	addPlugin(plugin)

        plugin.extend VizkitPluginExtension
        plugin.load_adapters(plugin_spec)

	plugin.extend(QtTypelibExtension)
        extendUpdateMethods(plugin,plugin_spec)
        plugin
    end

    # An association between (task_name, port_name) pairs to the frame in which
    # the data produced by the port is expressed
    attr_reader :port_frame_associations

    # The set of transformation producers connected to this widget so far
    #
    # This is a mapping from (task_name, port_name) pairs to a boolean. The
    # boolean is false if the port ever sent wrong data (i.e. of an unexpected
    # frame transform), and true otherwise
    attr_reader :connected_transformation_producers

    # @deprecated renamed to push_transformer_configuration
    def pushTransformerConfiguration(data)
        push_transformer_configuration(data)
    end

    # Controls whether the transformer configuration should be loaded from a
    # running transformer broadcaster component
    #
    # This controls only the static and dynamic transformations. The
    # port-to-frame associations are still loaded from the broadcaster unless
    # {use_transformer_broadcaster?} is false
    #
    # @see load_transformer_config_from_broadcaster?, load_transformer_config
    attr_predicate :load_transformer_config_from_broadcaster?, true

    # Controls whether transformation configuration should be loaded from the transformer broadcaster
    #
    # @see load_transformer_config_from_broadcaster?
    attr_predicate :use_transformer_broadcaster?, true

    # Updates the connections and internal configuration of the Vizkit3D widget
    # to use the transformer configuration information in +data+
    #
    # +data+ is supposed to be a transformer/ConfigurationState value
    def push_transformer_configuration(data)
        if load_transformer_config_from_broadcaster?
            # Convert the broadcaster's configuration to a transformer configuration
            # object
            conf = Transformer::Configuration.new
            # Push the data to the underlying transformer
            data.static_transformations.each do |trsf|
                conf.static_transform trsf.position, trsf.orientation,
                    trsf.sourceFrame => trsf.targetFrame
            end
            data.port_transformation_associations.each do |producer|
                conf.dynamic_transform "#{producer.task}.#{producer.port}",
                    producer.from_frame => producer.to_frame
            end
            apply_transformer_configuration(conf)
        end

        self.port_frame_associations.clear
        data.port_frame_associations.each do |data_frame|
            port_frame_associations["#{data_frame.task}.#{data_frame.port}"] = data_frame.frame
        end
    end

    def listen_to_transformation_producer(trsf)
        return if @connected_transformation_producers.has_key?(trsf.producer)

        task, *port = trsf.producer.split('.')
        port = port.join(".")
        Vizkit.debug "connecting producer task #{task}, port #{port} for #{trsf.from} => #{trsf.to}"
        producer_name = task.gsub(/.*\//, '')
        Vizkit.connect_port_to producer_name, port do |data, port_name|
            if data.sourceFrame != trsf.from || data.targetFrame != trsf.to
                if @connected_transformation_producers[trsf.producer]
                    Vizkit.warn "#{task}.#{port} produced a transformation for"
                    Vizkit.warn "    #{data.sourceFrame} => #{data.targetFrame},"
                    Vizkit.warn "    but I was expecting #{trsf.from} => #{trsf.to}"
                    Vizkit.warn "  I am ignoring this transformation. You will get this message only once,"
                    Vizkit.warn "  but get a notification if the right transformation is received later."
                    @connected_transformation_producers[trsf.producer] = false
                end
            else
                if !@connected_transformation_producers[trsf.producer]
                    Vizkit.warn "received the expected transformation from #{task}.#{port}"
                    @connected_transformation_producers[trsf.producer] = true
                end
                Vizkit.debug "pushing dynamic transformation #{data.sourceFrame} => #{data.targetFrame}"
                # target and source are exchanged because the transformer defines its transformations as Source_In_Target
                setTransformation(data.targetFrame.dup,data.sourceFrame.dup,data.position.to_qt,data.orientation.to_qt)
            end
            data
        end
    end

    def apply_transformer_configuration(conf, apply_examples: true)
        conf.each_static_transform do |trsf|
            Vizkit.debug "pushing static transformation #{trsf.from} => #{trsf.to}"
            # target and source are exchanged because the transformer defines its transformations as Source_In_Target
            setTransformation(trsf.to.dup,trsf.from.dup,trsf.translation.to_qt,trsf.rotation.to_qt)
        end
        conf.each_dynamic_transform do |trsf|
            listen_to_transformation_producer(trsf)
            @connected_transformation_producers[trsf.producer] = true
        end
        if apply_examples
            conf.each_example_transform do |trsf|
                setTransformation(trsf.to.dup, trsf.from.dup, trsf.translation.to_qt, trsf.rotation.to_qt)
            end
        end
    end

    def load_transformer_configuration(path)
        conf = Transformer::Configuration.new
        conf.load(path)
        apply_transformer_configuration(conf)
    end

    def update(data, port_name)
        if @connected_to_broadcaster
            if use_transformer_broadcaster? && data.class == Types::Transformer::ConfigurationState
                pushTransformerConfiguration(data)
                return
            end
        end
    end

    def extendUpdateMethods(plugin,plugin_spec)
        fcts = plugin_spec.find_all_callbacks(:callback_type => :display).find_all{|spec|spec.respond_to?(:to_sym)}
	if !fcts
	    Vizkit.info "no callback functions registered for Vizkit3D plugin #{plugin_spec.plugin_name} (c++ name: #{plugin_spec.cplusplus_name}) from #{plugin_spec.lib_name}"
            return
	end
        fcts.each do |fct|
            # define the code block for the new method
            block = lambda do |*args|
                if args.size < 1 || args.size > 2
                    Vizkit.error "#{fct.to_s}: wrong parameters"
                    puts "usage: #{fct.to_s}(data [, port_name]), the port_name is optional but necessary to receive transformations."
                    return
                end
                data = args[0] if args[0]
                port_name = args[1] if args[1]

                #inform widget about the frame for the plugin
                widget = Vizkit.vizkit3d_widget
                if frame_name = widget.port_frame_associations[port_name]
                    Vizkit.debug "#{port_name}: associated to the #{frame_name} frame for plugin #{plugin}"
                    widget.setPluginDataFrame(frame_name, plugin)
                else
                    Vizkit.debug "no known frame for #{port_name}, displayed by widget #{plugin_spec.plugin_name} (plugin #{plugin})"
                end
                super data
            end

            plugin.class.instance_eval do 
                define_method(fct.to_sym, block)
            end
        end
    end
end
end

Vizkit::UiLoader.extend_cplusplus_widget_class "vizkit3d::Vizkit3DWidget" do
    include Vizkit::VizkitPluginLoaderExtension
    include Vizkit::QtTypelibExtension
end
Vizkit::UiLoader.register_widget_for("vizkit3d::Vizkit3DWidget","/transformer/ConfigurationState", :update)
