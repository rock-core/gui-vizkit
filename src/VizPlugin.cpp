#include <osg/Node>
#include "VizPlugin.hpp"

using namespace vizkit;

VizPluginBase::VizPluginBase()
    : dirty(false)
    , ownNode(0) {}


void VizPluginBase::setMainNode(osg::Node* node) {
    node->setUpdateCallback(this);
    ownNode = node;
}
