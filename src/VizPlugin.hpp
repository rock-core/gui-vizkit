#ifndef __VIZKIT_VIZPLUGIN_HPP__ 
#define __VIZKIT_VIZPLUGIN_HPP__ 

#include <osg/NodeCallback>
#include <osg/Group>

#include <boost/thread/mutex.hpp>
#include <yaml-cpp/yaml.h>

namespace vizkit 
{

/** 
 * Interface class for all visualization plugins based on vizkit. All plugins
 * provide an osg::Group() node, which can be added to an osg render tree for
 * visualisation using getMainNode().
 *
 * The dirty handling works as such, that whenever the class is flagged dirty,
 * the virtual updateMainNode() function will be called when it is safe to
 * modify the node. Any plugin needs to implement this function to update the
 * visualisation. The osg node must not be modified at any other time.
 *
 * The updateMainNode() is guarded by a mutex, so it is generally a good idea to
 * guard any updates to the internal state of the plugin, that is required
 * within the updateMainNode(). Note that updateMainNode() is most likely called
 * from a different thread context than the rest.
 */
class VizPluginBase 
{
    public:
        VizPluginBase();

	/** @return true if the plugins internal state has been updated */
	virtual bool isDirty() const;

	/** mark the internal state as modified */
	void setDirty();

	/** @return a pointer to the internal Group that is used to maintain the
         * plugin's nodes */
	osg::ref_ptr<osg::Group> getVizNode() const;

	/** @return the name of the plugin, it's needed to save the 
         *  configuration data in a YAML file */
	virtual const std::string getPluginName() const;

	/** override this method to save configuration data. Always call the
	 * superclass as well.
	 * @param[out] emitter object which can be used to emit yaml structure
	 *  containing configuration options
	 */
	virtual void saveData(YAML::Emitter& emitter) const {};

	/** override this method to load configuration data. Always call the
	 * superclass as well.
	 * @param[in] yamlNode object which contains previously saved
	 *  configuration options
	 */
	virtual void loadData(const YAML::Node& yamlNode) {};

    protected:
	/** override this function to update the visualisation.
	 * @param node contains a point to the node which can be modified.
	 */
	virtual void updateMainNode(osg::Node* node) = 0;

	/** override this method to provide your own main node.
	 * @return node derived from osg::Group
	 */ 
	virtual osg::ref_ptr<osg::Node> createMainNode();

	/** lock this mutex outside updateMainNode if you update the internal
	 * state of the visualization.
	 */ 
	boost::mutex updateMutex;

    private:
	class CallbackAdapter;
	osg::ref_ptr<osg::NodeCallback> nodeCallback;
	void updateCallback(osg::Node* node);

        osg::ref_ptr<osg::Node> mainNode;
        osg::ref_ptr<osg::Group> vizNode;
	bool dirty;
};

template <typename T> class VizPlugin;

/**
 * Convenience template that adds type-specific handling to VizPluginBase
 *
 * Use this if you want a single visualization plugin to support multiple types
 * at the same time:
 *
 * <code>
 *
 *   class MyVisualizer
 *      : public VizPlugin<FirstType>,
 *      , public VizPluginAddType<SecondType>
 *   {
 *      void updateDataIntern(FirstType const&);
 *      void updateDataIntern(SecondType const&);
 *   }
 *
 */
template <typename T>
class VizPluginAddType
{
    template <typename Type> friend class VizPlugin;

    protected:
	/** overide this method and set your internal state such that the next
	 * call to updateMainNode will reflect that update.
	 * @param data data to be updated
	 */
	virtual void updateDataIntern(const T &data) = 0;
};

/** 
 * convinience class template that performs the locking of incoming data.
 * Derive from this class if you only have a single datatype to visualise, that
 * can be easily copied.
 */
template <class T>
class VizPlugin : public VizPluginBase,
    public VizPluginAddType< T >
{
    public:
	/** updates the data to be visualised and marks the visualisation dirty
	 * @param data const ref to data that is visualised
	 */
        template<typename Type>
	void updateData(const Type &data) {
	    boost::mutex::scoped_lock lockit(this->updateMutex);
	    this->setDirty();
	    dynamic_cast<VizPluginAddType<Type>*>(this)->updateDataIntern(data);
	};
};

/** @deprecated adapter item for legacy visualizations. Do not derive from this
 * class for new designs. Use VizPlugin directly instead.
 */
template <class T>
class VizPluginAdapter : public VizPlugin<T>
{
    protected:
	virtual void operatorIntern( osg::Node* node, osg::NodeVisitor* nv ) = 0;

        VizPluginAdapter()
	    : groupNode(new osg::Group())
        {
        }

	osg::ref_ptr<osg::Node> createMainNode()
	{
	    return groupNode;
	}

	void updateMainNode( osg::Node* node )
	{
	    // NULL for nodevisitor is ok here, since its not used anywhere
	    operatorIntern( node, NULL );
	}

	void setMainNode( osg::Node* node )
	{
	    groupNode->addChild( node );
	}

    protected:
	osg::ref_ptr<osg::Group> groupNode;
	osg::ref_ptr<osg::Node> ownNode;
};

}
#endif
