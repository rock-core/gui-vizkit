#ifndef TYPELIBQTADAPTER_H
#define TYPELIBQTADAPTER_H
#include <string>
#include <vector>
#include <typelib/value.hh>
#include <QObject>
#include <rice/Object.hpp>

class QObjectFetcher: public QObject
{
    Q_OBJECT
private:
    QObject * object_pointer;
    QObjectFetcher();
    
    static QObjectFetcher *instance;
    
public:    
    static QObjectFetcher *getQObjectFetcher();
    
    QObject *getObject();
    
    public slots:
	static QObject *getInstance();
	void setObject(QObject *obj);
};

class TypelibQtAdapter
{
public:
    class Argument
    {
    public:
	Typelib::Value value;
	std::string cxxTypename;
    };

    TypelibQtAdapter();
    
    void init();
    
    void initialize();
    
    bool callQtMethod(
            QObject* obj,
            const std::string& signature,
            const std::vector< TypelibQtAdapter::Argument >& arguments,
            TypelibQtAdapter::Argument ret);
    
    Rice::Object callQtMethodR(
            const std::string& signature,
            Rice::Object _arguments,
            Rice::Object _argumentTypes,
            Rice::Object returnValue,
            Rice::Object returnType);

private:
    QObject *object;
};

#endif // TYPELIBQTADAPTER_H
