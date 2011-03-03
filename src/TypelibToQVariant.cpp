#include "TypelibToQVariant.hpp"

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

void TypelibToQVariant::wrap(Rice::Object obj, Rice::Object expected_type_name)
{
  Typelib::Value val = typelib_get(obj.value());
  VALUE typeName = expected_type_name.value();
  void* cxx_type = orogen_transports::getOpaqueValue(StringValuePtr(typeName), val);
  QVariant qVar = qVariantFromValue(cxx_type);
  qruby_bridge.setVariant(qVar);
}

Rice::Object TypelibToQVariant::getBridge()
{
  return Object(rb_bridge);
}

Rice::Object createBridge()
{
  Object rb_type_to_variant = rb_eval_string("TypelibToQVariant.new");
  Object rb_bridge = rb_type_to_variant.instance_eval("bridge");
  rb_bridge.iv_set("@typelib_to_qvariant",rb_type_to_variant); 
  rb_bridge.instance_eval("def wrap(obj, expected_type_name); @typelib_to_qvariant.wrap(obj, expected_type_name);self;end");
  return rb_bridge;
}

extern "C"
void Init_typelib_to_qvariant()
{
  Data_Type<TypelibToQVariant> rbcQConverter =
    define_class<TypelibToQVariant>("TypelibToQVariant")
    .define_constructor(Constructor<TypelibToQVariant>())
    .define_singleton_method("create_bridge",&createBridge)
    .define_method("wrap", &TypelibToQVariant::wrap)
    .define_method("bridge", &TypelibToQVariant::getBridge);
}
