#include "GridNode.hpp"
#include <osg/Geometry>
#include <osg/ShapeDrawable>

namespace vizkit 
{

GridNode::GridNode()
{
    float size = 50.0f;
    float interval = 1.0f;
    
    // Create an object to store geometry in.
    osg::ref_ptr<osg::Geometry> geom = new osg::Geometry;
    
    // Create an array of four vertices.
    osg::ref_ptr<osg::Vec3Array> v = new osg::Vec3Array;
    geom->setVertexArray( v.get() );

    // draw grid lines
    float x = - size*0.5f;
    while( x <= size*0.5f ) {
        v->push_back( osg::Vec3(-size/2.0f, x, 0.01f));
        v->push_back( osg::Vec3(size/2.0f, x, 0.01f));
        v->push_back( osg::Vec3(x, -size/2.0f, 0.01f));
        v->push_back( osg::Vec3(x, size/2.0f, 0.01f));
        x += interval;
    }
    // draw concentric circles
    float r;
    for(r=0;r<size/2;r+=interval) {
	float xp = (2*3.14152)/(r*100);
        for(float x=0;x<(2*3.14152);x+=2*xp) {
            v->push_back( osg::Vec3(cos(x)*r, sin(x)*r, 0.01f) );
            v->push_back( osg::Vec3(cos(x+xp)*r, sin(x+xp)*r, 0.01f) );
        }
    }

    // set colors
    osg::ref_ptr<osg::Vec4Array> c = new osg::Vec4Array;
    geom->setColorArray( c.get() );
    geom->setColorBinding( osg::Geometry::BIND_OVERALL );
    c->push_back( osg::Vec4( .8f, 0.7f, 0.4f, .5f ) );

    // Draw a four-vertex quad from the stored data.
    geom->addPrimitiveSet(
	    new osg::DrawArrays( osg::PrimitiveSet::LINES, 0, v->size() ) );

    // switch off lighting for this node
    osg::StateSet* stategeode = this->getOrCreateStateSet();
    stategeode->setMode( GL_LIGHTING, osg::StateAttribute::OFF );

    this->addDrawable( geom.get() );
}

GridNode::~GridNode()
{

}


}
