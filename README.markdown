# vizkit

A visualization toolkit for Rock using Qt

Vizkit binds C++ and Ruby-based Qt widgets with Rock components and/or data
streams (e.g. logs). The package provides integration for Rock's base widget
collection [gui/rock_widget_collection](https://github.com/rock-core/gui-rock_widget_collection),
and provides as well some widgets of its own - among which the task inspector widget.

* http://rock-robotics.org

## Testing

Individual widgets may provide interactive tests. They are present in
test/widgets/ and can be executed with

~~~
ruby test/widgets/test_plot2d.rb
~~~

During testing, a widget with Yes and No buttons will appear, which will
require you to validate whether the widget behavior is the expected one.

