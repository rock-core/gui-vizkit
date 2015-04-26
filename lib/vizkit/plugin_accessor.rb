module Vizkit
    # Implements the accessors for plugins
    # if a plugin called "vizkit::Viz" or "vizkit.Viz" is added 
    # it can be accessed via plugin_accessor.vizkit.Viz and is stored 
    # as plugin_accessor.plugin_specs["vizkit::Viz"] and plugin_specs.vizkit.plugin_specs["Viz"]
    module PluginAccessorCommon
        def available_plugins
            @plugin_specs.keys
        end

        def plugin?(class_name)
            class_name = PluginHelper.normalize_obj(class_name,false).first
            available_plugins.include?(class_name)
        end

        def add_plugin_spec(spec,name=spec.plugin_name)
            @plugin_specs[name] = spec
            names = name.sub(/::/,".").split(".")
            if names.size > 1
                accessor = if self.respond_to? names.first 
                            self.send(names.first)
                        else
                            accessor = PluginAccessor.new(names.first)
                            accessor.instance_variable_set(:@uiloader,@uiloader||self)
                            instance_variable_set("@#{names.first}",accessor)
                            (class << self;self;end).send(:define_method,names.first) do 
                                instance_variable_get("@#{names.first}")
                            end
                            accessor
                        end
                name = names[1..-1].join(".")
                accessor.add_plugin_spec(spec,name)
            else
                (class << self;self;end).send(:define_method,name) do |*parent|
                    reuse = if parent.size >= 2
                                parent[1]
                            else
                                false
                            end
                    (@uiloader||self).create_plugin(spec.plugin_name,parent.first,reuse)
                end
            end
            spec
        end
    end

    class PluginAccessor
        include PluginAccessorCommon

        attr_accessor :plugin_specs
        def initialize(namespace)
            @namespace = namespace
            @plugin_specs = Hash.new
        end
        def method_missing(*args, &block)
            begin
                super
            rescue  NoMethodError => e
                Vizkit.error "#{args.first} is not plugin of the ui loader"
                Vizkit.error "The following plugins are registered under the namespace #{@namespace}"
                names = available_plugins.sort
                Vizkit.error names.join(", ")
                Kernel.raise e 
            end
        end
    end
end

