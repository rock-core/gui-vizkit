require 'TypelibQtAdapter'

module Vizkit
    class TypelibQtAdapter
	@adapter = nil
	
	def initialize(qt_object)
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
		return nil
	    end
	    
	    success = nil

	    #go through the returned parameter lists and check if they
	    #match the given parameters
	    parameter_lists.each_index do |params_idx|
		typlib_names = []
	    
		params = parameter_lists[params_idx]
		
		if(params.size != parameters.size)
		    next
		end
		
		param_list_typelib = []
		ruby_typelib_names = []

		matches = true
		
		params.each_index do |i|
		    param = params[i]

		    begin
			# the plugin reports a C++ type name. We need a typelib type name
			typename = Typelib::GCCXMLLoader.cxx_to_typelib(param)
			if !Orocos.registered_type?(param)
			    Orocos.load_typekit_for(typename, true) 
			end
			
			ruby_typelib_name = Orocos.typelib_type_for(typename)
			ruby_typelib_names << ruby_typelib_name

			if(parameters[i].class.name != ruby_typelib_name.name)
			    matches = false
			    break;
			end
		    rescue Exception => e  
# 			puts e.message  			
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
		    
		    parameters_cxx = []
		    parameters.each_index do |p|
			parameters_cxx << Typelib.from_ruby(parameters[p], ruby_typelib_names[p])
		    end
		    
		    success = adapter.callQtMethodWithSignature(signature, parameters_cxx, param_list_typelib, return_value)
		    break
		end
	    end

	    success
	end
	
    end  

end
module QtTyplelibExtension
    def method_missing(m, *args, &block)
	if(@do_forward)
	    super
	else
	    @do_forward = true
	    begin
		if(!@qt_object_adapter)
		    @qt_object_adapter = Vizkit::TypelibQtAdapter.new(self) 
		end
		
		if(!@qt_object_adapter.call_qt_method(m.to_s, args, nil))
		    return super
		end
	    ensure
		@do_forward = nil
	    end
	end
    end      
end


