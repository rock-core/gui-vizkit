#include <linux/types.h>
#include <rtt/typelib/TypelibMarshallerBase.hpp>
#include <iostream>

#include <rtt/typelib/TypelibMarshallerBase.hpp>
#include <rice/Constructor.hpp>
#include <rice/Array.hpp>
#include <typelib_ruby.hh>
#include <rtt/base/ChannelElementBase.hpp>
#include "TypelibQtAdapter.h"
#include <QtCore>

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

typedef std::vector< std::pair<orogen_transports::TypelibMarshallerBase*, orogen_transports::TypelibMarshallerBase::Handle*> > TypelibHandles;
static void* getOpaqueValue(TypelibHandles& typelib_handles, std::string const& expected_type, Typelib::Value value)
{
    orogen_transports::TypelibMarshallerBase* typelib_marshaller =
        orogen_transports::getMarshallerFor(expected_type);

    orogen_transports::TypelibMarshallerBase::Handle* handle =
        typelib_marshaller->createHandle();
    typelib_marshaller->setTypelibSample(handle, reinterpret_cast<uint8_t*>(value.getData()), true);

    void* cxx_data = typelib_marshaller->getOrocosSample(handle);
    typelib_handles.push_back( std::make_pair(typelib_marshaller, handle) );
    return cxx_data;
}

bool TypelibQtAdapter::callQtMethod(
        QObject* obj,
        const std::string& signature,
        const std::vector< TypelibQtAdapter::Argument >& arguments,
        TypelibQtAdapter::Argument ret)
{
    const QMetaObject *metaObj = obj->metaObject();
    int methodIndex = metaObj->indexOfMethod(signature.c_str());
    if(methodIndex == -1)
	throw std::runtime_error(std::string("QObject ") + obj->objectName().toStdString() + std::string(" has no method with signature ") + signature);
    
    QMetaMethod metaMethod = metaObj->method(methodIndex);
    QList<QByteArray> parameterTypes = metaMethod.parameterTypes();
    if(arguments.size() != static_cast<unsigned int>(parameterTypes.size()))
    {
	throw Typelib::DefinitionMismatch("Number of arguments do not match");
    }


    TypelibHandles typelib_handles;
    QGenericReturnArgument qtRet;
    std::vector<QGenericArgument> qtArgs;
    qtArgs.resize(10);
    for (unsigned int i = 0; i < arguments.size(); ++i)
    {
	void *cxx_data = getOpaqueValue(typelib_handles, arguments[i].cxxTypename, arguments[i].value);
	qtArgs[i] = QGenericArgument(parameterTypes[i], cxx_data);
    }
    if(ret.value.getData())
    {
        void* cxx_data = getOpaqueValue(typelib_handles, ret.cxxTypename, ret.value);
	qtRet = QGenericReturnArgument(metaMethod.typeName(), cxx_data);
    }
    bool successful =
        metaMethod.invoke(obj, qtRet,
                qtArgs[0], qtArgs[1], qtArgs[2], qtArgs[3], qtArgs[4], qtArgs[5],
                qtArgs[6], qtArgs[7], qtArgs[8], qtArgs[9]);

    // We need to refresh the return value. The other are always considered
    // in-only (at least for now)
    if (ret.value.getData())
        typelib_handles.back().first->refreshTypelibSample(typelib_handles.back().second);
    for (unsigned int i = 0; i < typelib_handles.size(); ++i)
        typelib_handles[i].first->deleteHandle(typelib_handles[i].second);
    return successful;
}

Rice::Object TypelibQtAdapter::callQtMethodR(
        const std::string& signature,
        Object _arguments,
        Object _argumentTypes,
        Object returnValue,
        Object returnType)
{
    Rice::Array arguments(_arguments);
    Rice::Array argumentTypes(_argumentTypes);

    std::vector<Argument> args;
    Rice::Array::iterator arg_type_it = argumentTypes.begin();
    for(Rice::Array::iterator it = arguments.begin(); it != arguments.end(); ++it)
    {
	Argument arg;
	arg.value = typelib_get(it->value());
	arg.cxxTypename = Rice::String(*arg_type_it).c_str();
	args.push_back(arg);
	++arg_type_it;
    }
    
    Argument ret; 
    if(!returnValue.is_nil())
    {
	ret.value = typelib_get(returnValue.value());
	ret.cxxTypename = Rice::String(returnType).c_str();
    }

    if(!callQtMethod(object, signature, args, ret))
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
    .define_method("getQtObject", &TypelibQtAdapter::initialize);
}
