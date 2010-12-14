#ifndef GRIDNODE_H
#define GRIDNODE_H
#include <osg/Geode>

namespace vizkit 
{

class GridNode: public osg::Geode
{
    public:
	GridNode();
    protected:
	virtual ~GridNode();
};

}
#endif // GRIDNODE_H
