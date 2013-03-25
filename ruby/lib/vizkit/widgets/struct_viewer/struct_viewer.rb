require 'vizkit'
require 'vizkit/tree_view'

class StructViewer
    module Functions
        def init(parent=nil)
            Vizkit.setup_tree_view treeView
            @model = Vizkit::VizkitItemModel.new
            treeView.setModel @model
        end

        def update(data, port_name)
        end

        def child?(text)
            0.upto @model.rowCount-1 do |row|
                item = @model.item(row,0)
                return true if item.text == text
            end
            false
        end

        def config(port,options=Hash.new)
            return if child? port.full_name
            port1,port2 = if port.output?
                              [Vizkit::OutputPortItem.new(port,:full_name => true), Vizkit::OutputPortItem.new(port,:item_type => :value)]
                          elsif port.input?
                              [Vizkit::InputPortItem.new(port,:full_name => true), Vizkit::IntputPortItem.new(port,:item_type => :value)]
                          end
            @model.appendRow [port1,port2]
            port1.expand
            port2.expand
            treeView.resizeColumnToContents 0
            treeView.resizeColumnToContents 1
            # data handling is done by the data model
            :do_not_connect
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
Vizkit::UiLoader.register_default_widget_for("StructViewer",Typelib::Type,:update)
