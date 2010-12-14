#ifndef DATANODE_H
#define DATANODE_H

#include <osg/NodeCallback>
#include <base/time.h>
#include <boost/thread/mutex.hpp>
#include <Eigen/Core>
#include <yaml-cpp/yaml.h>
#include <osg/Node>

namespace vizkit 
{

class VizPluginBase 
    : public osg::NodeCallback
{
    public:
        VizPluginBase();

        virtual bool isDirty() const {
            return dirty;
        }

	void setDirty() {
	    dirty = true;
	}

	osg::Node *getNode() {
	    return ownNode.get();
	};
        osg::Node *getMainNode() const {
            return ownNode.get();
        }

        void setMainNode(osg::Node* node);	

	virtual void operator()(osg::Node* node, osg::NodeVisitor* nv) {
	    {
		boost::mutex::scoped_lock lockit(updateMutex);
	    
                if( isDirty() )
                {
                    operatorIntern(node, nv);
                    dirty = false;
                }
	    }
	    osg::NodeCallback::operator()(node, nv);
	};
	
	virtual const std::string getPluginName() const {
	  return "BaseDataNode";
	};
	virtual void saveData(YAML::Emitter& emitter) const {};
	virtual void loadData(const YAML::Node& yamlNode) {};

    protected:
	boost::mutex updateMutex;
        bool dirty;
        osg::ref_ptr<osg::Node> ownNode;
	virtual void operatorIntern(osg::Node* node, osg::NodeVisitor* nv) = 0;
};

template <class T>
class VizPlugin : public VizPluginBase
{
    public:
	void updateData(const T &data) {
	    boost::mutex::scoped_lock lockit(this->updateMutex);
            dirty = true;
	    updateDataIntern(data);
	};
	
    protected:
	virtual void updateDataIntern(const T &data) = 0;
};

}
#endif
