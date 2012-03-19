require 'vizkittypelib'
module VizkitPluginExtension
    attr_reader :plugins 

    def load_adapters
        if !Orocos.master_project # Check if Orocos has been initialized
   	    raise RuntimeError, 'you need to call Orocos.initialize before using the Ruby bindings for Vizkit3D'
	end
        @bridges = Hash.new
        @plugins = Hash.new
        @adapter_collection = getRubyAdapterCollection
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
		
                define_method(plugin.getRubyMethod) do |value|
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
        pp.text "Vizkit3d Plugin: #{name}"
        pp.breakable
        pp.text "Library name: #{lib_name}"
        pp.breakable
        pp.text "----------------------------------------------------------"

        pp.breakable 
        pp.text "  Methods:"
        @plugins.each_value do |plugin|
            pp.breakable
            if plugin.getRubyMethod.match(/^update/)
                pp.text "    updateData(#{plugin.expected_ruby_type.name}) (alias of #{plugin.getRubyMethod})" 
            else
                pp.text "    #{plugin.getRubyMethod}(#{plugin.expected_ruby_type.name})"
            end
        end
    end
end

module VizkitPluginLoaderExtension
    def initialize_vizkit_extension
        super

        if !@connected_to_broadcaster
            @port_frame_associations ||= Hash.new
            @connected_transformation_producers ||= Hash.new
            task_name, port_name = Vizkit.vizkit3d_transformer_broadcaster_name
            Orocos.load_typekit 'transformer'
            if task_name
                Vizkit.connect_port_to task_name, port_name, self
                @connected_to_broadcaster = true
            end
        end
    end
    
    def load_plugin(path)
        loader = Qt::PluginLoader.new(path)
        loader.load
        if !loader.isLoaded
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
            path = File.join(path, "lib#{plugin_name}-viz.so")
            if File.file?(path)
                return path
            end
        end
        nil
    end

    # Returns the list of plugins that are available through external libraries
    #
    # The returned value is an array of pairs [lib_name, plugin_name]
    def custom_plugins
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
                    adapters = getListOfExternalPlugins(qt_plugin)
                    adapters.each do |name|
                        libs << [libname, name]
                    end
                end
            end
        end
        libs
    end

    # Returns the list of all available vizkit plugins
    #
    # The returned value is an array of arrays. Builtin plugins are stored as
    # [plugin_name] and custom plugins as [lib_name, plugin_name]. This is so
    # that, in both cases, one can do:
    #
    #   pl = plugins[2]
    #   createPlugin(*pl)
    #
    def plugins
        builtin_plugins.map { |v| [v] } + custom_plugins
    end

    # Creates a vizkit plugin object
    #
    # Builtin plugins, whose list is returned by #builtin_plugins, are created
    # with
    #
    #   createPlugin(plugin_name)
    #
    # External plugins, whose list is returned by #custom_plugins, are created
    # with
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
    def createPlugin(lib_name, plugin_name = nil)
	path = findPluginPath(lib_name)
	
	#try to load build in plugins
	if(!path && !plugin_name)
	    plugin_name = lib_name
	    lib_name = 'vizkit-base'
	    
	    path = findPluginPath(lib_name)
	end
	
	if !path
	    Kernel.raise "#{plugin_name} is not a builtin plugin, nor lib#{lib_name}-viz.so in VIZKIT_PLUGIN_RUBY_PATH."
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
	plugin_name = lib_name unless plugin_name
	lib_name = "lib#{lib_name}-viz.so"

        plugin.extend VizkitPluginExtension
        plugin.instance_variable_set(:@__name__,plugin_name)
        def plugin.name 
            @__name__
        end
        plugin.instance_variable_set(:@__lib_name__,lib_name)
        def plugin.lib_name
            @__lib_name__
        end
        plugin.load_adapters
	plugin.extend(QtTypelibExtension)
        plugin
    end

    # The set of plugins loaded by display-a-type infrastructure. It is a
    # mapping from class name (as declared in #register_ruby_widget) to the
    # corresponding plugin instance
    attribute(:plugins) { Hash.new }

    class << self
        # A mapping from the type names to the plugin widget name (as provided by
        # #register_3d_plugin_for)
        attr_reader :type_to_widget_name
    end
    @type_to_widget_name = Hash.new

    # An association between (task_name, port_name) pairs to the frame in which
    # the data produced by the port is expressed
    attr_reader :port_frame_associations
    
    # The set of transformation producers connected to this widget so far
    #
    # This is a mapping from (task_name, port_name) pairs to a boolean. The
    # boolean is false if the port ever sent wrong data (i.e. of an unexpected
    # frame transform), and true otherwise
    attr_reader :connected_transformation_producers

    # Updates the connections and internal configuration of the Vizkit3D widget
    # to use the transformer configuration information in +data+
    #
    # +data+ is supposed to be a transformer/ConfigurationState value
    def pushTransformerConfiguration(data)
        # Push the data to the underlying transformer
        data.static_transformations.each do |trsf|
            Vizkit.debug "pushing static transformation #{trsf.sourceFrame} => #{trsf.targetFrame}"
            pushStaticTransformation(trsf)
        end
        self.port_frame_associations.clear
        data.port_frame_associations.each do |data_frame|
            port_frame_associations["#{data_frame.task}.#{data_frame.port}"] = data_frame.frame
        end
        data.port_transformation_associations.each do |producer|
            next if @connected_transformation_producers.has_key?([producer.task, producer.port])

            Vizkit.debug "connecting producer #{producer.task}.#{producer.port} for #{producer.from_frame} => #{producer.to_frame}"
            Vizkit.connect_port_to producer.task, producer.port do |data, port_name|
                if data.sourceFrame != producer.from_frame || data.targetFrame != producer.to_frame
                    if @connected_transformation_producers[[producer.task, producer.port]]
                        Vizkit.warn "#{producer.task}.#{producer.port} produced a transformation for"
                        Vizkit.warn "    #{data.sourceFrame} => #{data.targetFrame},"
                        Vizkit.warn "    but I was expecting #{producer.from_frame} => #{producer.to_frame}"
                        Vizkit.warn "  I am ignoring this transformation. You will get this message only once,"
                        Vizkit.warn "  but get a notification if the right transformation is received later."
                        @connected_transformation_producers[[producer.task, producer.port]] = false
                    end
                else
                    if !@connected_transformation_producers[[producer.task, producer.port]]
                        Vizkit.warn "received the expected transformation from #{producer.task}.#{producer.port}"
                        @connected_transformation_producers[[producer.task, producer.port]] = true
                    end
                    Vizkit.debug "pushing dynamic transformation #{data.sourceFrame} => #{data.targetFrame}"
                    pushDynamicTransformation(data)
                end
                data
            end
            @connected_transformation_producers[[producer.task, producer.port]] = true
        end
    end

    # Dispatcher method, that dispatches the data to the different plugins
    def update(data, port_name)
        if @connected_to_broadcaster
            if data.class == Types::Transformer::ConfigurationState
                pushTransformerConfiguration(data)
                return
            end
        end

        widget_name, update_method, filter = VizkitPluginLoaderExtension.type_to_widget_name[data.class.name]
        plugin = plugins[widget_name]

	if !update_method
	    Kernel.raise ArgumentError, "invalid argument #{data} on #{self}"
	end

	#inform widget about the frame for the plugin
        if frame_name = port_frame_associations[port_name]
            Vizkit.debug "#{port_name}: associated to the #{frame_name} frame for plugin #{plugin}"
            setPluginDataFrame(frame_name, plugin)
        else
            Vizkit.debug "no known frame for #{port_name}, displayed by widget #{widget_name} (plugin #{plugin})"
        end
        if filter
            filter.call(plugin,data,port_name)
        else
            plugin.send(update_method,data)
        end
    end
end

Vizkit::UiLoader.extend_cplusplus_widget_class "vizkit::Vizkit3DWidget" do
    include VizkitPluginLoaderExtension
    include QtTypelibExtension
end

Vizkit::UiLoader.extend_cplusplus_widget_class "vizkit::QVizkitMainWindow" do
    include VizkitPluginLoaderExtension
end

Vizkit::UiLoader.register_3d_plugin('TrajectoryVisualization', 'TrajectoryVisualization', nil)
Vizkit::UiLoader.register_3d_plugin_for('TrajectoryVisualization', "/base/Vector3d", :updateTrajectory)
Vizkit::UiLoader.register_3d_plugin_for('TrajectoryVisualization', "Eigen::Vector3", :updateTrajectory)
Vizkit::UiLoader.register_3d_plugin('RigidBodyStateVisualization', 'RigidBodyStateVisualization', nil)
Vizkit::UiLoader.register_3d_plugin_for('RigidBodyStateVisualization', "/base/samples/RigidBodyState", :updateRigidBodyState)
Vizkit::UiLoader.register_3d_plugin('LaserScanVisualization', 'LaserScanVisualization', nil)
Vizkit::UiLoader.register_3d_plugin_for('LaserScanVisualization', "/base/samples/LaserScan", :updateLaserScan)
