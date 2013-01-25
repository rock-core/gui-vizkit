require 'vizkit'
require 'vizkit/tree_model'

class StructViewer
    module Functions
        def init(parent=nil)
            Vizkit.setup_tree_view treeView
            @data_model = Vizkit::OutputPortsDataModel.new
            @model = Vizkit::VizkitItemModel.new @data_model
            treeView.setModel @model
        end

        def update(data, port_name)
        end

        def config(port,options=Hash.new)
            @data_model.add port
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
