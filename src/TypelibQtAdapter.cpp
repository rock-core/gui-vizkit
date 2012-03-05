#include "TypelibQtAdapter.h"
#include <rtt/typelib/TypelibMarshallerBase.hpp>
#include <Qt/qmetaobject.h>
#include <Qt/qbytearray.h>
#include <iostream>
#include <Qt/qcoreapplication.h>

#include <rtt/typelib/TypelibMarshallerBase.hpp>
#include <rice/Constructor.hpp>
#include <rice/Array.hpp>
#include <typelib_ruby.hh>

using namespace Rice;

QObjectFetcher *QObjectFetcher::instance;

QObjectFetcher::QObjectFetcher()
{
    QCoreApplication *app = QCoreApplication::instance();
    QObject *object = app->findChild<QObject *>(QString::fromStdString("QObjectFetcherInstanceName"));   
    if(object)
	throw std::runtime_error("Another instance of the QObjectFetcher allready exists");

    this->setParent(app);
    this->setObjectName("QObjectFetcherInstanceName");
    object_pointer = NULL;
}

QObject* QObjectFetcher::getInstance()
{
    if(!instance)
    {
	instance = new QObjectFetcher();
    }
    
    return instance;
}


QObjectFetcher* QObjectFetcher::getQObjectFetcher()
{
    QCoreApplication *app = QCoreApplication::instance();
    QObject *object = app->findChild<QObject *>(QString::fromStdString("QObjectFetcherInstanceName"));   
    if(!object)
	throw std::runtime_error("Could not get qt object fetcher");
    
    return dynamic_cast<QObjectFetcher *>(object);
}


void QObjectFetcher::setObject(QObject* obj)
{
    object_pointer = obj;
}

QObject* QObjectFetcher::getObject()
{
    if(!object_pointer)
	throw std::runtime_error("No object set");
	
    return  object_pointer;
}


TypelibQtAdapter::TypelibQtAdapter()
{
    QObjectFetcher::getInstance();
}

void TypelibQtAdapter::initialize()
{    
    QObjectFetcher *fetcher = dynamic_cast<QObjectFetcher *>(QObjectFetcher::getInstance());    
    object = fetcher->getObject();
    
    if(!object)
	throw std::runtime_error("Could not get qt object");
}


std::string TypelibQtAdapter::getMethodSignature(const std::string& methodName)
{
    if(!object)
	throw std::runtime_error("Requested method signature without passing Qt object");
    
    std::string method = methodName + "(";
    
    const QMetaObject *metaObj = object->metaObject();
    for(int i = 0; i < metaObj->methodCount(); i++)
    {
	std::string signature = metaObj->method(i).signature();
	if(!signature.compare(0, method.size(), method))
	{
	    QList<QByteArray> params = metaObj->method(i).parameterTypes();
	    for(QList<QByteArray>::iterator it = params.begin(); it != params.end();it++)
	    {
		std::cout << (*it).data() << std::endl;
	    }
	    return signature;
	}
    }
    
    throw std::runtime_error("No method " + methodName + " found ");

    return "";
}

std::string TypelibQtAdapter::getMethodSignatureFromNumber(std::string methodName, int methodNr)
{
    if(!object)
	throw std::runtime_error("Requested method signature without passing Qt object");
    
    const QMetaObject *metaObj = object->metaObject();
    std::string method = methodName + "(";
    
    int cnt = 0;
    
    for(int i = 0; i < metaObj->methodCount(); i++)
    {
	std::string signature = metaObj->method(i).signature();
	if(!signature.compare(0, method.size(), method))
	{
	    if(cnt == methodNr)
		return signature;
	}
    }

    throw std::runtime_error("Invalid signature requested for " + methodName);
    
    return "";
}


bool TypelibQtAdapter::getParameterLists(const std::string& methodName, std::vector<std::vector<std::string> > &ret)
{
    if(!object)
	throw std::runtime_error("Requested method signature without passing Qt object");

    const QMetaObject *metaObj = object->metaObject();

    std::string method = methodName + "(";
    
    bool found = false;
    
    for(int i = 0; i < metaObj->methodCount(); i++)
    {
	std::string signature = metaObj->method(i).signature();
	if(!signature.compare(0, method.size(), method))
	{
	    found = true;
	    std::vector<std::string> paramList;
	    QList<QByteArray> params = metaObj->method(i).parameterTypes();
	    for(QList<QByteArray>::iterator it = params.begin(); it != params.end();it++)
	    {
		paramList.push_back(it->data());
	    }
	    ret.push_back(paramList);
	}
    }
    
    return found;
}

bool TypelibQtAdapter::callQtMethodWithSignature(QObject* obj, const std::string& signature, const std::vector< TypelibQtAdapter::Argument >& arguments, Typelib::Value returnValue)
{
    const QMetaObject *metaObj = obj->metaObject();

    int methodIndex = metaObj->indexOfMethod(signature.c_str());
    if(methodIndex == -1)
    {
	throw std::runtime_error(std::string("QObject ") + obj->objectName().toStdString() + std::string(" has no method with signature ") + signature);
    }
    
    QMetaMethod metaMethod = metaObj->method(methodIndex);
    
    QList<QByteArray> parameterTypes = metaMethod.parameterTypes();

    if(arguments.size() != parameterTypes.size())
    {
	throw Typelib::DefinitionMismatch("Number of arguments do not match");
    }

    std::vector<QGenericArgument> args;
    args.resize(10);

    args[0] = QGenericArgument(0);
    
    std::vector<QGenericArgument>::iterator argIt = args.begin();
    std::vector<Argument>::const_iterator ait = arguments.begin();
    for(QList<QByteArray>::const_iterator qit = parameterTypes.begin(); qit != parameterTypes.end(); qit++)
    {	
	void *cxx_data = orogen_transports::getOpaqueValue(ait->opaqueName, (ait)->value);
	*argIt = QGenericArgument(qit->data(), cxx_data);

// 	std::cout << "opaque name " << ait->opaqueName << " typelib name " << ait->value.getType().getName() << std::endl;
	//TODO delete cxx_data
	
	argIt++;
	ait++;
    }

    QGenericReturnArgument retArg;
    
    if(returnValue.getData())
    {
	retArg = QGenericReturnArgument(returnValue.getType().getName().c_str(), returnValue.getData());
    }

    return metaMethod.invoke(obj, retArg, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]);
}


bool TypelibQtAdapter::callQtMethod(QObject* obj, const std::string& methodName, const std::vector<Typelib::Value >& arguments, Typelib::Value returnValue)
{

    const QMetaObject *metaObj = obj->metaObject();
    std::cout << "Available methods :" << std::endl;
    for(int i = 0; i < metaObj->methodCount(); i++)
    {
	std::cout << metaObj->method(i).signature() << std::endl;
	std::cout << metaObj->method(i).tag() << std::endl;
    }
    
    std::string method = methodName + "(";
    
    //iterate over arguments to create correct name
    std::vector<Typelib::Value >::const_iterator a_it = arguments.begin();
    for(;a_it != arguments.end(); a_it++)
    {
	std::cout << "Argument name: " << a_it->getType().getName() << " " << a_it->getType().getBasename() << std::endl;
	//TODO for this to work propperly, we need a way to get the cxx name from the typelib name
	method += a_it->getType().getName();
    }
    
    method += ")";
    
    //TODO build correct method name
    int methodIndex = metaObj->indexOfMethod((method).c_str());
    if(methodIndex == -1)
    {
	std::cout << "Available methods :" << std::endl;
	for(int i = 0; i < metaObj->methodCount(); i++)
	{
	    std::cout << metaObj->method(i).signature() << std::endl;
	    std::cout << metaObj->method(i).tag() << std::endl;
	}
	
	throw std::runtime_error(std::string("QObject ") + obj->objectName().toStdString() + std::string(" has no method ") + methodName);
    }
    
    QMetaMethod metaMethod = metaObj->method(methodIndex);
    

    
    QList<QByteArray> parameterTypes = metaMethod.parameterTypes();

    if(arguments.size() != parameterTypes.size())
    {
	throw Typelib::DefinitionMismatch("Number of arguments do not match");
    }

    std::vector<QGenericArgument> args;
    args.resize(10);

    args[0] = QGenericArgument(0);
    
    std::cout << "Argument types are : ";
    std::vector<QGenericArgument>::iterator argIt = args.begin();
    std::vector<Typelib::Value >::const_iterator ait = arguments.begin();
    for(QList<QByteArray>::const_iterator qit = parameterTypes.begin(); qit != parameterTypes.end(); qit++)
    {
	std::cout << qit->data() ;
	(ait)->getType();
	if(std::string(qit->data()) != (ait)->getType().getName() )
	{
	    throw Typelib::TypeException(std::string("Argument type of Method ") + std::string(qit->data()) + std::string(" does not match given argument type ") + (ait)->getType().getName() );
	}
	
	*argIt = QGenericArgument((ait)->getType().getName().c_str(), (ait)->getData());
	
	argIt++;
	ait++;
    }

    QGenericReturnArgument retArg;
    
    if(returnValue.getData())
    {
	retArg = QGenericReturnArgument(returnValue.getType().getName().c_str(), returnValue.getData());
    }

    //all checks done, let's call the method
    return metaMethod.invoke(obj, retArg, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]);
}

Rice::Object TypelibQtAdapter::callQtMethodR(Rice::Object methodName, Rice::Object arguments, Rice::Object returnValue)
{
    Rice::Array argsArray(arguments);

    std::vector<Typelib::Value> args;
    
    for(Rice::Array::iterator it = argsArray.begin(); it != argsArray.end(); ++it)
    {
	args.push_back(typelib_get(it->value()));
    }
    
    Typelib::Value ret;
    if(!returnValue.is_nil())
	ret = typelib_get(returnValue.value());


    VALUE methodVal = methodName.value();  
    std::string method = StringValuePtr(methodVal);

    if(!callQtMethod(object, method, args, ret))
	return Rice::Nil;
    
    return Rice::True;
}

Object TypelibQtAdapter::getMethodListR()
{
    Rice::Array arr;
    const QMetaObject *metaObj = object->metaObject();
    for(int i = 0; i < metaObj->methodCount(); i++)
    {
	std::string signature = metaObj->method(i).signature();
	arr.push(signature);
    }
    return arr;
}

Object TypelibQtAdapter::getParameterListsR(const std::string& methodName)
{
    std::vector<std::vector<std::string> > ret;
    
    if(!getParameterLists(methodName, ret))
	return Rice::Nil;
    
    Rice::Array arr;
    
    for(std::vector<std::vector<std::string> >::iterator it = ret.begin(); it != ret.end(); it++)
    {
	Rice::Array paramList;
	
	for(std::vector<std::string>::iterator pit = it->begin(); pit != it->end(); pit++)
	{
	    paramList.push(*pit);
	}
	arr.push(paramList);
    }
    return arr;
}

Rice::Object TypelibQtAdapter::callQtMethodWithSignatureR(const std::string& signature, Object arguments, Object opaque_names, Object returnValue)
{
    Rice::Array argsArray(arguments);
    Rice::Array opaqueArray(opaque_names);

    std::vector<Argument> args;
    
    Rice::Array::iterator opaque_it = opaqueArray.begin();
    
    for(Rice::Array::iterator it = argsArray.begin(); it != argsArray.end(); ++it)
    {
	Argument arg;
	VALUE val = opaque_it->value();
	arg.opaqueName = StringValuePtr(val);
	arg.value = typelib_get(it->value());
	args.push_back(arg);
	
	++opaque_it;
    }
    
    Typelib::Value ret; 
    if(!returnValue.is_nil())
	ret = typelib_get(returnValue.value());

    if(!callQtMethodWithSignature(object, signature, args, ret))
	return Rice::Nil;
    
    return Rice::True;
}


extern "C"
void Init_TypelibQtAdapter()
{
  Rice::Data_Type<TypelibQtAdapter> rb_adapter =
    define_class<TypelibQtAdapter>("TypelibQtAdapter")
    .define_constructor(Constructor<TypelibQtAdapter>())
    .define_method("callQtMethod", &TypelibQtAdapter::callQtMethodR)
    .define_method("callQtMethodWithSignature", &TypelibQtAdapter::callQtMethodWithSignatureR) 
    .define_method("getQtObject", &TypelibQtAdapter::initialize)
    .define_method("getMethodList", &TypelibQtAdapter::getMethodListR)
    .define_method("getMethodSignature", &TypelibQtAdapter::getMethodSignature, (Arg("methodName")))
    .define_method("getMethodSignatureFromNumber", &TypelibQtAdapter::getMethodSignatureFromNumber, (Arg("methodName"), Arg("number")))
    .define_method("getParameterLists", &TypelibQtAdapter::getParameterListsR, (Arg("methodName")));
    
}
