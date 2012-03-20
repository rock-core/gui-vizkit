#!/usr/bin/env ruby
require 'vizkit'
require File.join('vizkit','tree_modeler.rb')

class VizkitInfoViewer
    module Functions
        def init(parent=nil)
            @brush = Qt::Brush.new(Qt::Color.new(200,200,200))
            @tree_view = Vizkit::TreeModeler.new(treeView)
            @tree_view.model.set_horizontal_header_labels(["OQConnection","Status"])
            @item_hash = Hash.new
        end

        def update(oqconnections, name)
            return if !isVisible
            oqconnections.each_with_index do |connection,i|
                @tree_view.update(connection,nil,@tree_view.root,false,i)
            end
            @tree_view.set_all_children_editable(@tree_view.model.invisible_root_item, false)
            treeView.resizeColumnToContents(0)
        end

        def auto_update(connections)
            @connections = connections
            update(connections,nil)
            @timer = Qt::Timer.new
            @timer.connect(SIGNAL('timeout()')) do
                update(@connections,nil)
            end
            @timer.start(1000)
        end
    end

    def self.create_widget(parent=nil)
        widget = Vizkit.load(File.join(File.dirname(__FILE__),'vizkit_info_viewer.ui'),parent)
        widget.extend Functions
        widget.init parent
        widget
    end
end

Vizkit::UiLoader.register_ruby_widget("VizkitInfoViewer",VizkitInfoViewer.method(:create_widget))
