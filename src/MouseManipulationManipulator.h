#ifndef MOUSEMANIPULATIONMANIPULATOR_H
#define MOUSEMANIPULATIONMANIPULATOR_H
#include <osgGA/MatrixManipulator>
#include <osgManipulator/Dragger>

namespace enview {

    
/**
* This class implements a Camera manipulator.
* The intention of this class is to NOT move the Camera at all.
* Additionally to not moving the camera this class provides
* an eventhandler which implements picking for Draggers. 
*
* To sum it up, if you use this Class as a Camera maipulator, 
* you will be able to use Dragger. 
*/
class MouseManipulationManipulator: public osgGA::MatrixManipulator
{
    private:
	osg::ref_ptr<osg::Camera> cam;
	osg::Matrixd matrix;
	osgManipulator::PointerInfo pointerInfo;
	osgManipulator::Dragger* activeDragger;

    public:
	MouseManipulationManipulator(osg::Camera *camera) : activeDragger(NULL) {
	    cam = camera;
	}
	
	virtual const char* className() const {
	    return "MouseManipulationManipulator";
	}

	virtual osg::Matrixd getInverseMatrix() const {
	    return osg::Matrixd::inverse(matrix);
	};

	virtual osg::Matrixd getMatrix() const {
	    return matrix;
	}

	virtual void setByInverseMatrix(const osg::Matrixd& matrix) {
	    this->matrix = osg::Matrixd::inverse(matrix);
	};

	virtual void setByMatrix(const osg::Matrixd& matrix) {
	    this->matrix = matrix;
	};    

	virtual bool handle(const osgGA::GUIEventAdapter& ea, osgGA::GUIActionAdapter& us);
};

}
#endif // MOUSEMANIPULATIONMANIPULATOR_H
