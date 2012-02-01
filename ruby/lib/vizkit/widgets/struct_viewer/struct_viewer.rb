#!/usr/bin/env ruby
require 'vizkit'
require File.join(File.dirname(__FILE__), '../..', 'tree_modeler.rb')
require File.join(File.dirname(__FILE__),'struct_viewer_window.ui.rb')

class StructViewer
    module Functions
        def init(parent=nil)
            @brush = Qt::Brush.new(Qt::Color.new(200,200,200))
            @tree_view = Vizkit::TreeModeler.new(treeView)
            @item_hash = Hash.new
        end

        def update(data, port_name)
            if !@item_hash[port_name]
                @item_hash[port_name],item2 = @tree_view.update(nil,port_name,@tree_view.root,false,@item_hash.size)
                item2.setText(data.class.name)
            end
            @tree_view.update(data,nil,@item_hash[port_name])
            @tree_view.set_all_children_editable(@tree_view.model.invisible_root_item, false)
            treeView.resizeColumnToContents(0)
        end

        #add a default value 
        def config(port,options=Hash.new)
            return if options[:subfield]
            #encode some values 
            #otherwise tree_view is not able to open a new widget for an embedded type 
            task = Vizkit::TaskProxy.new port.task
            #add place holder
            item,item2 = @tree_view.update(nil,port.task.name,@tree_view.root,false,@item_hash.size)
            @tree_view.encode_data(item,task)
            @tree_view.encode_data(item2,task)

            item3 = item.child(item.rowCount-1,0)
            item4 = item.child(item.rowCount-1,1)
            item3.setText(port.name)
            item4.setText(port.type_name)
            @tree_view.encode_data(item3,port.class)
            @tree_view.encode_data(item4,port.class)
            @item_hash["#{port.task.name}.#{port.name}"] = item3
        end

        def multi_value?
            true
        end
    end

    def self.create_widget(parent=nil)
        widget = Vizkit.load(File.join(File.dirname(__FILE__),'struct_viewer_window.ui'),parent)
        widget.extend Functions
        widget.init parent
        widget
    end
end

Vizkit::UiLoader.register_ruby_widget("StructViewer",StructViewer.method(:create_widget))
#Vizkit::UiLoader.register_widget_for("StructViewer","/base/samples/frame/Frame", :update)
