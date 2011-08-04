require 'vizkittypelib'
module VizkitPluginExtension
    
    def load_adapters
        if !Orocos.master_project # Check if Orocos has been initialized
   	    raise RuntimeError, 'you need to call Orocos.initialize before using the Ruby bindings for Vizkit3D'
	end
        @bridges = Hash.new
        @plugins = Hash.new
        getListOfAvailableAdapter.each do |name|
            plugin = getAdapter(name)
            bridge = TypelibToQVariant.create_bridge
            Qt::Object.connect(bridge, SIGNAL('changeVariant(QVariant&, bool)'), plugin, SLOT('update(QVariant&, bool)'))
            @bridges[plugin.getRubyMethod] = bridge
            @plugins[plugin.getRubyMethod] = plugin
            typename = plugin.getDataType
            # the plugin reports a C++ type name. We need a typelib type name
            typename = Typelib::GCCXMLLoader.cxx_to_typelib(typename)
            expected_ruby_type =
                begin Orocos.typelib_type_for(typename)
                rescue Typelib::NotFound
                    # Make sure we have loaded the typekit that will allow us to handle
                    # this type
                    Orocos.load_typekit_for(typename, true)
                    Orocos.typelib_type_for(typename)
                end

            is_opaque = (expected_ruby_type.name != typename)

            singleton_class = (class << self; self end)
            singleton_class.class_eval do
		attr_accessor :type_to_method
		
                define_method(plugin.getRubyMethod) do |value|
                    value = Typelib.from_ruby(value, expected_ruby_type)
                    bridge.wrap(value, typename, is_opaque)
                end
		
		define_method('updateData') do |value|
		    if(method_name = @type_to_method[value.class])
			puts("Type matches #{method_name}")
			self.send(method_name, value)
		    else
			message = "Expected type(s) "
			
			type_to_method.each do |i,j |
			    message = message + i.name + " "
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
		self.type_to_method[expected_ruby_type] = plugin.getRubyMethod
	    end
        end
    end
end

module VizkitPluginLoaderExtension
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

    def createPlugin(lib_name, plugin_name = nil)
        builtin = getListOfAvailablePlugins
        if builtin.include?(lib_name)
            plugin = createPluginByName(lib_name)
        else
            path = findPluginPath(lib_name)
            if !path
                Kernel.raise "#{lib_name} is not a builtin plugin, nor lib#{lib_name}-viz.so in VIZKIT_PLUGIN_RUBY_PATH. Available builtin plugins are: #{builtin.join(", ")}."
            end
            plugin = load_plugin(path)
            plugin = createExternalPlugin(plugin, plugin_name || "")
            if !plugin
                if plugin_name
                    Kernel.raise "library #{lib_name} does not have any vizkit plugin called #{plugin_name}"
                else
                    Kernel.raise "#{lib_name} either defines no vizkit plugin, or multiple ones (and you must select one explicitely)"
                end
            end
        end

        plugin.extend VizkitPluginExtension
        plugin.load_adapters
        plugin
    end
end

Vizkit::UiLoader.extend_cplusplus_widget_class "vizkit::Vizkit3DWidget" do
    include VizkitPluginLoaderExtension
end

Vizkit::UiLoader.extend_cplusplus_widget_class "vizkit::QVizkitMainWindow" do
    include VizkitPluginLoaderExtension
end
