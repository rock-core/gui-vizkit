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
	
	def initialize(qt_object)
            @qt_object = qt_object
	    @adapter = get_adapter(qt_object)
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
            @adapter.getMethodList
        end
	
	# This method calls a method on the qt_object associated with
	# the given adapter. 
	# The specified method will be called with the given parameters
	# which have to be of type Typelib::Value
	#
        # The method will return true if the call was successfully otherwise false
	# The return value of the method will be save in return_value
        # 
	def call_qt_method(method_name, parameters, return_value)
            parameters = Array(parameters)
	    adapter = @adapter
	    
	    parameter_lists = adapter.getParameterLists(method_name)
	    if(!parameter_lists)
		return false
	    end
	    
	    #go through the returned parameter lists and check if they
	    #match the given parameters
	    parameter_lists.each_with_index do |params, params_idx|
		typlib_names = []
	    
		if(params.size != parameters.size)
		    next
		end
		
		param_list_typelib = []
		ruby_typelib_names = []

		matches = true
		
		parameters_cxx = []
		params.each_with_index do |param, i|
                    # the plugin reports a C++ type name, convert from Ruby
                    typename = Typelib::GCCXMLLoader.cxx_to_typelib(param)
                    if !Orocos.registered_type?(param)
                        begin
                            Orocos.load_typekit_for(typename, true) 
                        rescue Orocos::TypekitTypeNotFound
                            matches = false
                            break
                        end
                    end
			
                    ruby_typelib_name = Orocos.typelib_type_for(typename)
                    ruby_typelib_names << ruby_typelib_name

                    parameters_cxx << Typelib.from_ruby(parameters[i], ruby_typelib_name)
		    param_list_typelib << typename
		end
		
		if matches
		    #get the correct method signature for qt
		    #as it would be very complex to build it from the parameters, we just
		    #fetch it from qt, as we allready verified that out
		    #parameters are correct.
		    signature = adapter.getMethodSignatureFromNumber(method_name, params_idx)
                    begin
                        return adapter.callQtMethodWithSignature(signature, parameters_cxx, param_list_typelib, return_value)
                    rescue Exception => e
                        raise TypelibQtCallError, e, e.backtrace
                    end
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
            @qt_object_adapter ||= Vizkit::TypelibQtAdapter.new(self) 
            result =
                begin @qt_object_adapter.call_qt_method(m.to_s, args, nil)
                rescue TypelibQtCallError => e
		    backtrace = caller
		    if respond_to?(:plugin_spec)
			backtrace = ["#{backtrace[0].gsub(/in `\w+'/, "exception from C++ method #{plugin_spec.plugin_name}::#{m.to_s}")}"] + backtrace[1..-1]
		    end
                    raise e, e.message, backtrace
                end

            if result
                # Should be the return value
                nil
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
