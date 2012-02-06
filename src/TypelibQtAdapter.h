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
	std::string opaqueName;
    };
    
    TypelibQtAdapter();
    
    void init();
    
    void initialize();
    
    bool callQtMethod(QObject* obj ,const std::string& methodName, const std::vector< Typelib::Value >& arguments, Typelib::Value returnValue);
    bool callQtMethodWithSignature(QObject* obj ,const std::string& signature, const std::vector<Argument>& arguments, Typelib::Value returnValue);
    
    std::string getMethodSignature(const std::string& methodName);
    std::string getMethodSignatureFromNumber(std::string methodName, int methodNr);
    bool getParameterLists(const std::string& methodName, std::vector<std::vector<std::string> > &ret);
    
    Rice::Object callQtMethodR(Rice::Object methodName, Rice::Object arguments, Rice::Object returnValue);
    Rice::Object callQtMethodWithSignatureR(const std::string& signature, Rice::Object arguments, Rice::Object opaque_names, Rice::Object returnValue);
    Rice::Object getParameterListsR(const std::string& methodName);

private:
    QObject *object;
};

#endif // TYPELIBQTADAPTER_H
