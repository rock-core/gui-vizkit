#ifndef __VIZKIT_QVISUALIZATIONTESTWIDGET_HPP__
#define __VIZKIT_QVISUALIZATIONTESTWIDGET_HPP__

#include <vizkit/QVizkitMainWindow.hpp>

namespace vizkit
{
    
/** 
 * Convenience class to simplify the generation of tests for the standard
 * vizkit plugins.
 */
template <class T, class D>
class QVisualizationTestWidget : public QVizkitMainWindow
{
public:
    QVisualizationTestWidget( QWidget* parent = 0, Qt::WindowFlags f = 0 )
	: QVizkitMainWindow(parent, f), viz(new T())
    {
	addPlugin( viz.get() );
    }

    ~QVisualizationTestWidget()
    {
	removePlugin( viz.get() );
    }

    void updateData( const D &data )
    {
	viz->updateData(data);
    }
  
    boost::shared_ptr<T> viz;
};

}

#endif
