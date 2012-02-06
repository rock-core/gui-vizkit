#ifndef OLD_VIZKIT_PLUGIN_HH
#define OLD_VIZKIT_PLUGIN_HH
#include "Vizkit3DPlugin.hpp"

//this header is only here for backward compatibillity

#warning "vizkit/VizPlugin.hpp and vizkit::VizPlugin<T> are deprecated. Use <vizkit/Vizkit3DPlugin> and vizkit::Vizkit3DPlugin<T>, which are drop-in replacements"

namespace vizkit {

template <class T>
class VizPlugin : public Vizkit3DPlugin<T>
{
};

}

#endif
