begin 
require 'TypelibQtAdapter'
rescue Exception => e
    #no logger is available at this point so create one 
    log = Logger.new(STDOUT)
    log.error "!!! Vizkit is not fully build and installed !!!"
    raise e
end

module Vizkit
    class TypelibQtCallError < RuntimeError
    end

    class TypelibQtAdapter
        attr_reader :adapter
        attr_reader :qt_object
        attr_reader :method_info

        MethodInfo = Struct.new :name, :signature, :return_type, :argument_types
	
	def initialize(qt_object)
            @qt_object = qt_object
	    @adapter = get_adapter(qt_object)
            populate_method_info_hash
	end	

        def populate_method_info_hash
            @method_info = Hash.new
            meta_object = qt_object.metaObject
            meta_object.method_count.times do |i|
                meta_method = meta_object.method(i)
                name = meta_method.signature.gsub(/\(.*/, '')
                return_type = meta_method.type_name
                return_type = nil if return_type.empty?

                method_info[name] ||= Array.new
                method_info[name] << MethodInfo.new(
                    name,
                    meta_method.signature,
                    return_type,
                    meta_method.parameter_types)
            end
        end
	
	# This method returns a TypelibQtAdapter for the given qt object
	# this adapter is needed to call function on the qt object with
	# typelib types as arguments
	def get_adapter(qt_object)
	    adapter = ::TypelibQtAdapter.new()

	    fetcher = $qApp.findChild(Qt::Object, "QObjectFetcherInstanceName")
	    fetcher.setObject(qt_object)
	    adapter.getQtObject()
	    
	    adapter
	end

        #Returns a list of all methods which can be invoked by the adapter 
        def method_list
            return method_info.map(&:signature)
        end

        # Given a C++ type name registered in the signature of a Qt invokable
        # method, return the corresponding typelib type that should be used to
        # call it.
        #
        # @param [String] cxx_typename the requested C++ type name
        # @return [(Type,Type),nil] the typelib types that represent the C++
        #   type and the corresponding non-opaque type. They are the same for
        #   non-opaques. nil if the types cannot be resolved
        def self.find_typelib_type(cxx_typename)
            typename = Typelib::GCCXMLLoader.cxx_to_typelib(cxx_typename)
            typelib_type =
                begin Orocos.typelib_type_for(typename)
                rescue Typelib::NotFound
                end
            typelib_type ||= 
                begin
                    Orocos.load_typekit_for(typename, true) 
                    Orocos.typelib_type_for(typename)
                rescue Orocos::TypekitTypeNotFound
                rescue Typelib::NotFound
                end

            return Orocos.registry.get(typename), typelib_type
        end

        # Given a ruby value and a requested C++ type name, finds which typelib
        # type name should be used to pass to Qt and convert the value to this
        # type
        #
        # @param [Typelib::Type] ruby_value the ruby value to be converted
        # @param [String] cxx_typename the requested C++ type name
        # @return [(String,Type),nil] the typelib type name and the converted
        #   ruby value. Returns nil if the typelib type corresponding to
        #   cxx_typename is not known.
        def self.ruby_value_to_qt(cxx_typename, ruby_value)
            cxx_type, typelib_type = find_typelib_type(cxx_typename)
            if cxx_type
                return cxx_type, typelib_type, Typelib.from_ruby(ruby_value, typelib_type)
            end
        end
	
	# This method calls a method on the qt_object associated with
	# the given adapter. 
	# The specified method will be called with the given parameters
	# which have to be of type Typelib::Value
	#
        # The method will return true if the call was successfully otherwise false
	# The return value of the method will be save in return_value
        # 
	def call_qt_method(method_name, parameters)
            parameters = Array(parameters)
	    adapter = @adapter

            if !(qt_methods = method_info[method_name])
                return false
            end
	    
	    qt_methods.each do |method_info|
		next if method_info.argument_types.size != parameters.size

                typelib_return_value = nil
                cxx_return_type = nil
		typelib_arguments = []
                cxx_argument_types = []
		
		successful = method_info.argument_types.each_with_index do |cxx_typename, i|
                    cxx_type, typelib_type, typelib_value =
                        TypelibQtAdapter.ruby_value_to_qt(cxx_typename, parameters[i])
                    break(nil) if !cxx_type
                    typelib_arguments << typelib_value
                    cxx_argument_types << Typelib::Registry.rtt_typename(cxx_type)
		end
                next if !successful
                if method_info.return_type
                    cxx_return_type, typelib_return_type = TypelibQtAdapter.find_typelib_type(method_info.return_type)
                    if cxx_return_type
                        typelib_return_value = typelib_return_type.new
                    else next
                    end
                end
		
                cxx_return_typename =
                    if cxx_return_type then Typelib::Registry.rtt_typename(cxx_return_type)
                    end
                begin
                    successful = adapter.callQtMethod(method_info.signature,
                                                typelib_arguments,
                                                cxx_argument_types,
                                                typelib_return_value,
                                                cxx_return_typename)
                    if successful
                        return true, typelib_return_value
                    else return false
                    end
                rescue Exception => e
                    raise TypelibQtCallError, e, e.backtrace
                end
	    end
            false
	end
    end  

    module QtTypelibExtension
        def method_list
            @qt_object_adapter ||= Vizkit::TypelibQtAdapter.new(self) 
            @qt_object_adapter.method_list
        end

        def method_missing(m, *args, &block)
            if m == :metaObject
                return super
            end

            @qt_object_adapter ||= Vizkit::TypelibQtAdapter.new(self)
            successful, return_type =
                begin
                    @qt_object_adapter.call_qt_method(m.to_s, args)
                rescue TypelibQtCallError => e
                    # backtrace = caller
                    # backtrace = ["#{backtrace[0].gsub(/in `\w+'/, "exception from C++ method #{plugin_spec.plugin_name}::#{m.to_s}")}"] + backtrace[1..-1]
                    raise e, e.message, e.backtrace
                rescue 
                    [false,nil]
                end

            if successful
                # Should be the return value
                return_type
            else
                # check if any parameter is a typelib object because this would cause a segfault if 
                # the superclass is a Qt::Object
                if args.any? { |arg| arg.is_a? Typelib::Type}
                    Kernel.raise NoMethodError.new "undefined method '#{m}' for #{self}"
                else
                    super
                end
            end
        end
    end
end
