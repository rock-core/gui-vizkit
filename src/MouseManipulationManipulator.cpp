#include "MouseManipulationManipulator.h"
#include <osgManipulator/Selection>
#include <osgManipulator/TrackballDragger>
#include <osgManipulator/CommandManager>
#include <osgGA/GUIEventHandler> 
#include <osgUtil/LineSegmentIntersector>
#include <osgViewer/View>

namespace enview {

bool MouseManipulationManipulator::handle(const osgGA::GUIEventAdapter& ea, osgGA::GUIActionAdapter& aa) {
    return false;

    	typedef osgUtil::LineSegmentIntersector::Intersections::iterator intersectIter;
	typedef osg::NodePath::iterator npIter;

	bool deleteDragger = false;
	
	osgViewer::View* view = dynamic_cast<osgViewer::View*>(&aa);
	if (view) {

	    switch (ea.getEventType()) {

		case osgGA::GUIEventAdapter::PUSH: {

		    osgUtil::LineSegmentIntersector::Intersections intersections;
		    pointerInfo.reset();

			if (view->computeIntersections(ea.getX(), ea.getY(), intersections)) {

			    pointerInfo.setCamera(cam.get());
			    pointerInfo.setMousePosition(ea.getX(), ea.getY());

			    for (intersectIter iter = intersections.begin(); 
				iter != intersections.end(); 
				++iter) {
				pointerInfo.addIntersection(iter->nodePath, iter->getLocalIntersectPoint());
			    }

			    for (npIter iter = pointerInfo._hitList.front().first.begin(); 
				iter != pointerInfo._hitList.front().first.end(); 
				++iter) {       

				if (osgManipulator::Dragger* dragger = 
				    dynamic_cast<osgManipulator::Dragger*>(*iter)) {
				    dragger->handle(pointerInfo, ea, aa);
				    activeDragger = dragger;
				    return false;
				}
			    }
			}
		}
		break;

		case osgGA::GUIEventAdapter::RELEASE:
		    deleteDragger = true;
		case osgGA::GUIEventAdapter::DRAG:
		    if (activeDragger) {
			    pointerInfo._hitIter = pointerInfo._hitList.begin();
			    pointerInfo.setCamera(cam.get());
			    pointerInfo.setMousePosition(ea.getX(), ea.getY());
			    activeDragger->handle(pointerInfo, ea, aa);
			    if(deleteDragger)
				activeDragger = NULL;
			    return false;
		    }
		    break;
		default:
		    break;

	    } 
    }
    return false;
}	

}
