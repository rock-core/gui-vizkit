#!/usr/bin/env ruby

class StructViewer < Qt::Widget

  def initialize(parent=nil)
    super
    load File.join(File.dirname(__FILE__),'struct_viewer_window.ui.rb')
    load File.join(File.dirname(__FILE__),'tree_modeler.rb')
    @window = Ui_Form.new
    @window.setupUi(self)
    @modeler = TreeModeler.new
    @tree_model = modeler.createTreeModel
    @window.treeView.setModel(@tree_model)
    @window.treeView.setAlternatingRowColors(true)
    @window.treeView.setSortingEnabled(true)
    #@brush = Qt::Brush.new(Qt::Color.new(200,200,200))
  end

  def update(data, port_name)
     modeler.generateTree(data, port_name, @tree_model)
  end

end

Vizkit::UiLoader.register_ruby_widget("StructViewer",StructViewer.method(:new))
