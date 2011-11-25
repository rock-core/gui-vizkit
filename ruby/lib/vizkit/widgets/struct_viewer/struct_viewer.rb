#!/usr/bin/env ruby
require 'vizkit'
require File.join(File.dirname(__FILE__), '../..', 'tree_modeler.rb')

class StructViewer < Qt::Widget

  def initialize(parent=nil)
    super
    load File.join(File.dirname(__FILE__),'struct_viewer_window.ui.rb')
    @window = Ui_Form.new
    @window.setup_ui(self)
    @brush = Qt::Brush.new(Qt::Color.new(200,200,200))
    @tree_view = Vizkit::TreeModeler.new
    @tree_view.setup_tree_view(@window.treeView)
  end

  def update(data, port_name)
     @tree_view.update(data, port_name )
     @tree_view.set_all_children_editable(@tree_view.model.invisible_root_item, false)
     @window.treeView.resizeColumnToContents(0)
  end

  #add a default value 
  def config(port)
      #add place holder
     @tree_view.update("no data", "#{port.task.name}.#{port.name}")
  end
end

Vizkit::UiLoader.register_ruby_widget("StructViewer",StructViewer.method(:new))
Vizkit::UiLoader.register_widget_for("StructViewer","/base/samples/frame/Frame", :update)
