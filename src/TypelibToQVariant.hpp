
#ifndef TYPELIBTOQVARIANT_H
#define TYPELIBTOQVARIANT_H

#include <QtCore>
#include <smoke.h>
#include <rice/Class.hpp>
#include <rice/Data_Object.hpp>
#include "rice/Constructor.hpp"
#include "rice/Data_Type.hpp"
#include <iostream>
#include <typelib_ruby.hh>
#include <rtt/typelib/TypelibMarshallerBase.hpp> 

class QRubyBridge : public QObject
{
  Q_OBJECT

  signals:
  void changeVariant(QVariant &);

  public:
  QRubyBridge(QObject* parent = NULL);

  void setVariant(QVariant const& qvariant)
  {
    this->qvariant = qvariant;
    emit changeVariant(this->qvariant);
  };

  public slots:
  QVariant getVariant(){return qvariant;};

  protected:
  QVariant qvariant;
};

class TypelibToQVariant
{
 public:
   TypelibToQVariant();
   void wrap(Rice::Object, Rice::Object);
   Rice::Object getBridge();

  private:
   QRubyBridge qruby_bridge;
   VALUE rb_bridge;
};
#endif
