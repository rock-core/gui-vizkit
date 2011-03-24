#include "TypelibToQVariant.hpp"
#include <rtt/typelib/TypelibMarshallerBase.hpp>
#include <rice/Constructor.hpp>
#include <typelib_ruby.hh>

using namespace Rice;

QRubyBridge::QRubyBridge(QObject* parent):
  QObject(parent)
{
};

TypelibToQVariant::TypelibToQVariant():
  qruby_bridge(QCoreApplication::instance())
{
  qruby_bridge.setObjectName("__typelib_to_qvariant__");
  rb_bridge = rb_eval_string("$qApp.findChild(Qt::Object,'__typelib_to_qvariant__')");
  qruby_bridge.setObjectName("");
};

void TypelibToQVariant::wrap(Rice::Object obj, Rice::Object expected_type_name, bool is_opaque)
{
  Typelib::Value val = typelib_get(obj.value());
  VALUE typeName = expected_type_name.value();
  if (is_opaque)
  {
    void* cxx_type = orogen_transports::getOpaqueValue(StringValuePtr(typeName), val);
    QVariant qVar = qVariantFromValue(cxx_type);
    qruby_bridge.setVariant(qVar, true);
  }
  else
  {
    QVariant qVar = qVariantFromValue(val.getData());
    qruby_bridge.setVariant(qVar, false);
  }
}

Rice::Object TypelibToQVariant::getBridge()
{
  return Object(rb_bridge);
}

Rice::Object createBridge()
{
  Object rb_type_to_variant = rb_eval_string("TypelibToQVariant.new");
  Object rb_bridge = rb_type_to_variant.call("bridge");
  rb_bridge.iv_set("@typelib_to_qvariant",rb_type_to_variant); 
  rb_bridge.instance_eval("def wrap(obj, expected_type_name, is_opaque); @typelib_to_qvariant.wrap(obj, expected_type_name, is_opaque);self;end");
  return rb_bridge;
}

extern "C"
void Init_vizkittypelib()
{
  Data_Type<TypelibToQVariant> rbcQConverter =
    define_class<TypelibToQVariant>("TypelibToQVariant")
    .define_constructor(Constructor<TypelibToQVariant>())
    .define_singleton_method("create_bridge",&createBridge)
    .define_method("wrap", &TypelibToQVariant::wrap)
    .define_method("bridge", &TypelibToQVariant::getBridge);
}
