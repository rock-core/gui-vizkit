require 'TypelibQtAdapter'

module Vizkit
    class TypelibQtAdapter
	
	# This method returns a TypelibQtAdapter for the given qt object
	# this adapter is needed to call function on the qt object with
	# typelib types as arguments
	def get_adapter(qt_object)
	    real_name = qt_object.objectName()
	    real_parent = qt_object.parent()

	    name = "TypelibQtAdapterUniqueName"
	    qt_object.setObjectName(name)
	    qt_object.setParent($qApp)
	    adapter = ::TypelibQtAdapter.new()
	    adapter.getQtObject(name)
	    
	    qt_object.setObjectName(real_name)
	    qt_object.setParent(real_parent)
	    
	    adapter
	end
	
	# This method calls a method on the qt_object associated with
	# the given adapter. 
	# The specified method will be called with the given parameters
	# which have to be of type Typelib::Value
	#
	# The return value of the method will be save in return_value
	def call_qt_method(adapter, method_name, parameters, return_value)
	    parameter_lists = adapter.getParameterLists(method_name)

	    if(!parameter_lists)
		return nil
	    end
	    
	    success = nil
	    
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
		    
		    param_list_typelib << typename
		end
		
		if(matches)
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