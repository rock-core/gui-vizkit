#ifndef _COMPOSITE_VIEWER_QOSG_HPP_
#define _COMPOSITE_VIEWER_QOSG_HPP_

#include <QtCore/QTimer>
#include <QtGui/QWidget>
#include <osgViewer/CompositeViewer>
#include <boost/thread/recursive_mutex.hpp>

class QPaintEvent;

//------------------------------------------------------------------------------
class CompositeViewerQOSG : public QWidget, public osgViewer::CompositeViewer
{
    Q_OBJECT

public:
    CompositeViewerQOSG( QWidget * parent = 0, Qt::WindowFlags f = 0 );
    virtual ~CompositeViewerQOSG() {}

    void paintEvent( QPaintEvent * /* event */ );

    /**
    * Is this mutex gets acquired, the rendere will
    * not run and it is save to modify the scene graph
    **/
    boost::recursive_mutex &getRenderLock();

protected:
    boost::recursive_mutex _renderLock;
    QTimer _timer;

}; // CompositeViewerQOSG
#endif // _COMPOSITE_VIEWER_QOSG_HPP_
