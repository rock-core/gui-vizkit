#ifndef OLD_VIZKIT_PLUGIN_HH
#define OLD_VIZKIT_PLUGIN_HH
#include "Vizkit3DPlugin.hpp"

//this header is only here for backward compatibillity

namespace vizkit {

template <class T>
class VizPlugin : public Vizkit3DPlugin<T>
{
};

}

#endif