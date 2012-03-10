require 'TypelibQtAdapter'

module Vizkit
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
	# The return value of the method will be save in return_value
	def call_qt_method(method_name, parameters, return_value)
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
		    begin
			# the plugin reports a C++ type name, convert from Ruby
			typename = Typelib::GCCXMLLoader.cxx_to_typelib(param)
			if !Orocos.registered_type?(param)
			    Orocos.load_typekit_for(typename, true) 
			end
			
			ruby_typelib_name = Orocos.typelib_type_for(typename)
			ruby_typelib_names << ruby_typelib_name

			parameters_cxx << Typelib.from_ruby(parameters[i], ruby_typelib_name)
                    rescue Interrupt
                        raise
		    rescue Exception => e  
			matches = false
			break;
		    end
		    
		    param_list_typelib << typename
		end
		
		if(matches)
		    #get the correct method signature for qt
		    #as it would be very complex to build it from the parameters, we just
		    #fetch it from qt, as we allready verified that out
		    #parameters are correct.
		    signature = adapter.getMethodSignatureFromNumber(method_name, params_idx)
		    return adapter.callQtMethodWithSignature(signature, parameters_cxx, param_list_typelib, return_value)
		end
	    end
            false
	end
	
    end  

end
module QtTyplelibExtension
    def method_missing(m, *args, &block)
        @qt_object_adapter ||= Vizkit::TypelibQtAdapter.new(self) 
        if(!@qt_object_adapter.call_qt_method(m.to_s, args, nil))
            Vizkit.info "cannot find slot #{m.to_s} for #{self.class.name}."
            if self.is_a? Qt::Widget
                Vizkit.info "calling super for method #{m.to_s}"
                return super
            elsif self.is_a? Qt::Object
                #calling super on a Qt::Object will lead to a seg fault
                Vizkit.warn "calling #{m.to_s} on #{self.class.name} failed. Wrong method name?"
                Vizkit.warn "avilable methods:"
                Vizkit.warn @qt_object_adapter.method_list.join("; ")
                raise NoMethodError.new("undefined mehtod '#{m.to_s}' for #{self.class.name}")
            else
                Vizkit.info "calling super for method #{m.to_s}"
                return super
            end
        else
            Vizkit.info "calling slot #{m.to_s} on #{self.class.name}"
        end
    end
end


