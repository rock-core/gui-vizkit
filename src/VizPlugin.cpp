#include <osg/Group>
#include "VizPlugin.hpp"

using namespace vizkit;

/** this adapter is used to forward the update call to the plugin
 */
struct VizPluginBase::CallbackAdapter : public osg::NodeCallback 
{
    VizPluginBase* plugin;
    CallbackAdapter( VizPluginBase* plugin ) : plugin( plugin ) {}
    void operator()(osg::Node* node, osg::NodeVisitor* nv)
    {
	plugin->updateCallback( node );
	osg::NodeCallback::operator()(node, nv);
    }
};

VizPluginBase::VizPluginBase()
    : dirty( false )
{
    mainNode = new osg::Group();
    nodeCallback = new CallbackAdapter( this );

    mainNode->setUpdateCallback( nodeCallback );
}

osg::ref_ptr<osg::Group> VizPluginBase::getMainNode() const 
{
    return mainNode;
}

const std::string VizPluginBase::getPluginName() const 
{
    return "BaseDataNode";
};

void VizPluginBase::updateCallback(osg::Node* node)
{
    boost::mutex::scoped_lock lockit(updateMutex);

    if( isDirty() )
    {
	updateMainNode(node->asGroup());
	dirty = false;
    }
}

bool VizPluginBase::isDirty() const
{
    return dirty;
}

void VizPluginBase::setDirty() 
{
    dirty = true;
}
