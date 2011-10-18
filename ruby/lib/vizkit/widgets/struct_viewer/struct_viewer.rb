#!/usr/bin/env ruby
require 'vizkit'

class StructViewer < Qt::Widget

  def initialize(parent=nil)
    super
    load File.join(File.dirname(__FILE__),'struct_viewer_window.ui.rb')
    load File.join(File.dirname(__FILE__), '../..', 'tree_modeler.rb')
    @window = Ui_Form.new
    @window.setup_ui(self)
    @brush = Qt::Brush.new(Qt::Color.new(200,200,200))
    @modeler = Vizkit::TreeModeler.new
    @tree_model = @modeler.create_tree_model
    @window.treeView.set_model(@tree_model)
    @window.treeView.set_alternating_row_colors(true)
    @window.treeView.set_sorting_enabled(true)
  end

  def update(data, port_name)
     @modeler.update_sub_tree(data, port_name, @tree_model.invisible_root_item)
     @modeler.set_all_children_editable(@tree_model.invisible_root_item, false)
     @window.treeView.resizeColumnToContents(0)
  end

end

Vizkit::UiLoader.register_ruby_widget("StructViewer",StructViewer.method(:new))
