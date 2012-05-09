require 'utilrb/module/dsl_attribute'

module Vizkit

    # Helper functions for the plugin - system of vizkit.
    # The plugin system handles plugins for vizkit 3d and
    # vizkit.rb (for example widgets for displaying data coming from
    # orocos tasks)
    module PluginHelper

        # Registers a code block which will be executed to map 
        # objects to an array of strings. This mechanism is used 
        # to customize the mapping of objects to searchable strings
        # and goes hand in hand with normalize_obj
        #
        # @see normalize_obj
        # @note The code block will be called for the class object and class instances 
        # @param [Array<Object>] objects n objects or an array of objects for which the given 
        #   code block shall be invoked.
        # @param [CodeBlock] block the code block
        # @example
        #       PluginHelper.register_map_obj(Float) do |obj|
        #               ["Mystring1","MyString2"]
        #       end
        #       Plugin.map_obj(123.2) => ["Mystring1","MyString2"]
        #       Plugin.map_obj("Float",123.2) => ["Mystring1","MyString2"]
        #       Plugin.map_obj("Float") => ["Mystring1","MyString2"]
        #       Plugin.map_obj(Float) => ["Mystring1","MyString2"]
        #
        def self.register_map_obj(*objects,&block)
            @map_obj ||= Hash.new
            objects.each do |object|
                @map_obj[normalize_obj(object,false).first] = block
            end
        end
        
        # Maps an object to an array of strings
        #
        # @see register_map_obj
        # @param [String] klass_name the class name of the object which can be different from the real class name
        # @param [Object] object the object that will be passed to the code block registered via register_map_obj
        # @return [Array<String>] an array of names which can be used to find a plugin able to handle the object
        def self.map_obj(klass_name,object=nil)
            return Array.new unless @map_obj
            return Array.new unless klass_name
            if !object
                normalize_obj(klass_name,false)
            else
                return Array.new unless @map_obj.has_key?(klass_name)
                Array(@map_obj[klass_name].call(object))
            end
        end

        # Normalizes the object to its class names.
        # It is also aware of objects where the class name is replaced
        # by other names like plugins and objects for which a
        # mapping was registered.
        #
        # @see register_map_obj
        # @note This is used to find all strings for these a plugin might be registered 
        #   able to handle the given object.
        # @note There will be no BasicObject for ruby1.8.
        # @return [Array<String>] an array of names.
        # @example
        #   normalize_obj(123) => ["Fixnum", "Integer", "Numeric", "Object", "BasicObject"]
        #   normalize_obj("/base/samples/frame/Frame") => ["/base/samples/frame/Frame", "Typelib::CompoundType", "Typelib::Type", "Object", "BasicObject"]
        #   normalize_obj(Types::Base::Samples::Frame::Frame) => ["/base/samples/frame/Frame", "Typelib::CompoundType", "Typelib::Type", "Object", "BasicObject"]
        #   normalize_obj(Types::Base::Samples::Frame::Frame.new) => ["/base/samples/frame/Frame", "Typelib::CompoundType", "Typelib::Type", "Object", "BasicObject"]
        def self.normalize_obj(object,include_super=true)
            return Array.new unless object
            names = if object.respond_to? :superclass
                        classes object,include_super
                    elsif object.respond_to? :to_str
                        result = normalize_obj(class_from_string(object),include_super)
                        result << object if result.empty?
                        result
                    elsif object.respond_to? :plugin_spec
                        klasses = classes(object.class,include_super)
                        klasses.shift
                        Array(object.plugin_spec.plugin_name) + klasses 
                    else
                        klasses = classes(object.class,include_super)
                        klasses.shift
                        if object.is_a? Qt::Object
                            Array(object.class_name) + klasses
                        else
                            Array(object.class.name) + klasses 
                        end
                    end
            (map_obj(names.first,object)+names).compact
        end

        # Generates an array of strings consisting the class 
        # and all super class names of the given class object.
        # 
        # @param [Class] klass the class
        # @param [true,false] include_super if false no super class names are included 
        # @return [Array<String>] an array of the class and all superclass names
        def self.classes(klass,include_super=true)
            return Array.new unless klass
            raise ArgumentError, "#{klass} is not a class" unless klass.respond_to? :name
            if include_super && klass.respond_to?(:superclass) && klass.superclass && klass != klass.superclass
                Array(klass.name) + classes(klass.superclass)
            else
                Array(klass.name)
            end
        end

        # Converts a ruby Typelib class name to a Typelib class name.
        # This is needed to load the typekit before
        # converting the string into a corresponding class object.
        #
        # @param [String] class_name the name of the ruby class
        # @return [String] the name of the typelib class or nil
        #   if the given string does not match a ruby class name of a typelib
        #   class.
        # @example
        #   to_typelib_name("Types::Base::Angle" => "/base/Angle"
        #
        def self.to_typelib_name(class_name)
            class_name =~ /^Types(::.*::)(\w*)/
            if $1 && $2 
                temp2 = $2
                temp = $1.gsub(/::/,"/")
                temp.downcase + temp2 
            else
                nil
            end
        end

        # Converts a string into the corresponding class object.
        # @note It is also aware of typelib classes.
        # 
        # @param [String] class_name the name of the class.
        # @return [Class] the corresponding class object or nil 
        #   if no class can be found.
        def self.class_from_string(class_name)
            return unless class_name
            return class_name unless class_name.respond_to? :to_str

            if class_name.include?("/")
                typekit = begin 
                              Orocos.load_typekit_for(class_name, false)
                          rescue
                              nil
                          end
                if Orocos.registry.include?(class_name)
                    # convert all types into intermediate if intermediate
                    # is available
                    begin
                        if typekit
                            typekit.intermediate_type_for(class_name)
                        else
                            Orocos.registry.get class_name
                        end
                    rescue ArgumentError
                        Orocos.registry.get class_name
                    end
                else
                    Vizkit.info "Typelib Type #{class_name} cannot be found."
                    nil
                end
            else
                #check if its a ruby const 
                begin
                    m = Kernel                
                    class_name.split("::").each do |name|
                        m = m.const_get(name)
                    end
                    m
                rescue NameError
                    # Converts ruby Typelib Classes to Typelib names
                    # to load the typekit and try again
                    temp = to_typelib_name(class_name)
                    if temp
                        class_from_string(temp)
                    else
                        nil
                    end
                end
            end
        end
    end

    # Holds all the information about a plugin callback. A callback 
    # is a method or code block which is able to handle a specific 
    # object type for example for displaying it.
    # 
    class CallbackSpec 

        # Dummy callback adapter if no code block or method shall be invoked
        class NoCallbackAdapter
            def block_name 
                :NoCallback
            end
            def bind(object)
                method(:call)
            end
            def call(*args, &block)
            end
        end

        # Callback adapter for callbacks specified by a method name
        class MethodNameAdapter
            attr_reader :sym

            def initialize(sym)
                raise ArgumentError, "Cannot initialize MethodNameAdapter: No method is given" unless sym
                @sym = sym
            end

            def to_sym
                sym.to_sym
            end

            # Name of the code block which is used for pretty_print of 
            # the PluginSpec
            # @return [Symbol] the name
            def block_name 
                to_sym
            end

            def bind(object)
                object.method(@sym)
            end

            def call(*args, &block)
                obj = args.shift
                obj.send(@sym, *args, &block)
            end
        end

        # Callback adapter for code blocks not tied to any object
        class UnboundBlockAdapter
            def initialize(block)
                @block = block
            end

            # Binds the code block to an object and returns
            # a new BlockAdapter. The UnboundBlockAdapter is not modified.
            # 
            # @param [Object] object the object
            # @return [BlockAdapter]
            def bind(object)
                BlockAdapter.new(@block, object)
            end

            def call(*args, &block)
                if block
                    args << block
                end
                @block.call(*args)
            
            end

            # Name of the code block which is used for pretty_print of 
            # the PluginSpec
            # @return [Symbol] the name
            def block_name 
                :CodeBlock 
            end
        end

        # Callback adapter for code blocks tied to an object 
        # or code blocks which does not need to be tied.
        class BlockAdapter
            def initialize(block, object=nil)
                @block, @object = block, object
            end
            def call(*args, &block)
                if block
                    args << block
                end
                if @object
                    @block.call(@object, *args)
                else
                    @block.call(*args)
                end
            end

            def bind(object)
                self
            end

            # Name of the code block which is used for pretty_print of 
            # the PluginSpec
            # @return [Symbol] the name
            def block_name 
                :CodeBlock 
            end
        end

        # @return [CallbackAdapter] the callback adapter
        attr_reader :callback

        # @return [String] name of the argument type which can be handled by the code block
        attr_reader :argument           

        # @!method doc(string = nil)
        # Getter and setter for the documentation string.
        #
        # @param [String] string the documentation string.
        # @return [String] documentation string of the callback or
        #    if a documentation string is given self.
        dsl_attribute :doc

        # @!method default(val)
        # Getter and setter for the dsl attribute default specifying 
        # if the callback is a default callback for its argument
        #
        # @param [true,false] val.
        # @return [true,false] true if the callback is a default callback or
        #       if a argument is given self
        dsl_attribute :default
        
        # @!method callback_type(val)
        # Getter and setter for the callback type.
        #
        # @param [Symbol] val the type of the callback.
        # @return [Symbol] type of the callback or if a argument 
        #       is given self
        dsl_attribute :callback_type

        # Creates a new object of CallbackSpec 
        #
        # @param [Object] value the object which can be handled by the callback 
        # @param [callback_type] callback_type the type of the callback :display,:control
        # @param [false,true] default
        # @param [Symbol] method_name name of the method that will be invoked on the plugin 
        #   will be ignored if a block is given 
        # @example
        #   CallbackSpec.new(Float,:display,true) do |obj|
        #       puts obj
        #   end
        def initialize(value,callback_type=nil,default=false,method_name = nil,&block)
            @callback =if !block
                           if method_name.respond_to?(:to_sym)
                               MethodNameAdapter.new(method_name)
                           else
                               NoCallbackAdapter.new
                           end
                       elsif block.kind_of?(Method)
                           UnboundBlockAdapter.new(block)
                       else
                           BlockAdapter.new(block) 
                       end
            @argument = PluginHelper.normalize_obj(value,false).first
            callback_type(callback_type)
            default(default)
        end

        def call(*args)
            @callback.call(*args)
        end

        def match?(*pattern)
            return true if pattern.empty?
            pattern = pattern.first
            pattern, options = Kernel.filter_options(pattern,:callback_type => nil,:argument => nil,:default => nil,:exact => nil)
            raise ArgumentError, "Wrong options #{options}" unless options.empty? 

            if pattern[:callback_type]
                return if pattern[:callback_type] != @callback_type
            end
            if pattern[:default] !=nil
                return if pattern[:default] != @default
            end
            if pattern[:argument]
                # match against all available names for the argument
                names = PluginHelper.normalize_obj(pattern[:argument],!pattern[:exact])
                return if ! names.include?(@argument)
            end
            return true
        end
    end

    class PluginSpec
        attr_reader :plugin_name,:callback_specs
        dsl_attribute :doc,:cplusplus_name,:lib_name,:plugin_type
        dsl_attribute :file_names do |val|
            if !@file_names.include? val
                @file_names + Array(val).compact
            else
                @file_names
            end
        end
        dsl_attribute :extensions do |*blocks|
            blocks.flatten!
            blocks.each do |block|
                block = Module.new(&block) unless block.is_a?(Module)
                @extensions << block
            end
            @extensions
        end

        def initialize(plugin_name)
            PluginHelper.normalize_obj(plugin_name)
            @plugin_name = PluginHelper.normalize_obj(plugin_name,false).first
            @creation_method = nil
            @callback_specs = Array.new
            @created_plugins = Array.new
            @extensions = Array.new
            @file_names = Array.new
            @on_create_hook = nil
        end

        def file_name(name)
            file_names(name)
        end

        # code block will be called once for each
        # plugin after it was created and extended
        def on_create(&block)
            @on_create_hook = block
            self
        end

        def extension(mod=nil,&block)
            extensions(mod || block)
        end

        def creation_method(method=nil,&block)
            if(method || block)
                @creation_method = (method || block)
                if @creation_method.respond_to? :to_sym
                    klass = PluginHelper.class_from_string plugin_name
                    raise "Cannot create class #{plugin_name} to look for creation method #{method}" unless klass
                    if method.to_sym != :new && !klass.method_defined?(method)
                        raise "Class #{plugin_name} has no method called #{method} which is specified as creation method"
                    end
                    @creation_method = klass.method(method)
                end
                self
            else
                @creation_method
            end
        end

        def callback_spec(value,callback_type=nil,default=nil,method_name=nil,&block)
            spec = if value.is_a? CallbackSpec
                       value
                   else
                       CallbackSpec.new(value,callback_type,default,method_name,&block)
                   end
            spec2 = find_callback_spec!({:argument => spec.argument ,:callback_type => spec.callback_type})
            if spec2
                Vizkit.warn "#{plugin_name}: Ignoring callback for #{spec.argument} and callback type #{spec.callback_type}"
                Vizkit.warn "because only one callback per value and callback type is allowed."
                Vizkit.warn "Please remove the register_widget_for #{plugin_name},#{spec.argument} statement from"
                Vizkit.warn file_names
                return self
            end
            @callback_specs << spec
            self
        end

        #returns true if the plugin matches the given pattern
        #:plugin_name
        #:cplusplus_name
        #:argument                 if given callback_type must be given as well
        #:callback_type         if given argument must be given as well
        #:default               if given argument and callback_type must be given as well
        def match?(*pattern)
            return if pattern.empty?
            pattern = pattern.first
            pattern, subpattern= Kernel.filter_options pattern,:plugin_name=> nil,:cplusplus_name => nil
            return if pattern[:plugin_name] && plugin_name != pattern[:plugin_name]
            return if pattern[:cplusplus_name] && cplusplus_name !=  pattern[:cplusplus_name]
            return if !subpattern.empty? && find_all_callback_specs(subpattern).empty?
            true
        end

        def find_all_callback_specs(*pattern)
            return Array.new if pattern.empty? 
            @callback_specs.find_all do |spec|
                spec.match?(*pattern)
            end
        end

        def find_callback_spec!(*pattern)
            return if pattern.empty?
            pattern = pattern.first
            names = PluginHelper.normalize_obj(pattern[:argument])
            names << nil if names.empty?
            pattern = pattern.dup
            pattern[:exact] = true
            specs = Array.new
            names.each do |name|
                pattern[:argument] = name
                result = find_all_callback_specs(pattern)
                if !result.empty?
                    specs = result
                    break
                end
            end
            if specs.size > 1
                raise ArgumentError, "Vizkit faild to find the right plugin callback for plugin #{plugin_name} and search pattern #{pattern.inspect}." + 
                                     " #{specs.size} callbacks were found and vizkit cannot decide which one is right."
            end
            specs.first
        end

        def find_all_callbacks(*pattern)
            find_all_callback_specs(*pattern).map do |spec|
                spec.callback
            end
        end

        def find_callback!(*pattern)
            spec = find_callback_spec!(*pattern)
            return spec.callback if spec 
        end

        def create_plugin(parent=nil)
            raise "Plugin #{plugin_name} cannot be created: No creation method was specified" unless @creation_method 
            plugin = if @creation_method.arity == 1
                         @creation_method.call(parent)
                     else
                         @creation_method.call()
                     end
            extend_plugin(plugin)
            if @on_create_hook
                @on_create_hook.call(plugin)
            end
            plugin
        end

        def created_plugins
            @created_plugins
        end

        def extend_plugin(plugin)
            return unless plugin
            if !plugin.respond_to?:plugin_spec
                if plugin.instance_variable_defined?:@__plugin_spec
                    raise "Cannot add instance variable @__plugin_spec to plugin #{plugin_name} because it is already defined!"
                end
                plugin.instance_variable_set(:@__plugin_spec__,self)
                def plugin.plugin_spec
                    @__plugin_spec__
                end
                def plugin.pretty_print(pp)
                    pp plugin_spec
                end
            end
            @extensions.each do |extension|
                plugin.extend extension
            end
            @created_plugins << plugin 
            plugin
        end

        def pretty_print(pp)
            pp.text "=========================================================="
            pp.breakable
            pp.text "Plugin name: #{plugin_name}"
            pp.breakable
            pp.text "Plugin type: #{plugin_type}"
            pp.breakable
            pp.text "C++ name: #{cplusplus_name}"
            pp.breakable
            pp.text "Lib name: #{lib_name}"
            pp.breakable
            pp.text "file name(s): #{file_names.join(",")}"
            pp.breakable
            if doc
                pp.text @doc
                pp.breakable
            end
            pp.text "Extensions: "
            pp.breakable
            @extensions.each do |ext|
                pp.text "  Module name: #{ext.name||"Unknown"}"
                pp.breakable
                pp.text "    Methods:"
                pp.breakable
                ext.instance_methods.each do |m|
                    pp.text "      #{m.to_s}"
                    pp.breakable
                end
            end
            pp.text "Registered for: "
            pp.breakable
            @callback_specs.each do |spec|
                if spec.argument
                    pp.text "  #{spec.callback.block_name}(#{spec.argument}) #{spec.default ? "-> default" :""}"
                    pp.breakable
                end
            end
        end
    end
end
