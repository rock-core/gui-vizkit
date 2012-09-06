# Main Window setting up the ui
class LogMarkerViewer < Qt::Widget 
  def initialize(parent = nil)
    super
    @logger = nil
    @layout = Qt::GridLayout.new
    @widget = Vizkit.load File.join(File.dirname(__FILE__),'log_marker_viewer.ui'), self
    @layout.addWidget(@widget,0,0)
    @current_index = -1;
    self.setLayout @layout
    @log_control = Vizkit.default_loader.find_created_plugins("LogControl").first
    @widget.list.connect(SIGNAL("doubleClicked(QModelIndex)")) do |index|
        if @log_control    
            @log_control.seek_to @markers[index.row].time
        end
    end
  end

  def config2(annotations,options=Hash.new)
    @markers = Orocos::Log::LogMarker.parse(annotations.samples)
    @markers.each do |marker|
        time = "#{marker.time.hour}:#{marker.time.min}:#{marker.time.sec}"
        time += " "* (8-time.size)
        if marker.index >= 0
            @widget.list.addItem("#{time}: #{" "*3*marker.index}#{marker.type}(#{marker.index}):  #{marker.comment}")
        else
            @widget.list.addItem("#{time}: +++ #{marker.type}: #{marker.comment} ++++")
        end

    end

    #prove of concept to get the widget 
    #widget =  loader.created_controls_for(Orocos::Log::Replay)
    #puts widget.first.ruby_class_name
  end
end

Vizkit::UiLoader.register_ruby_widget "LogMarkerViewer", LogMarkerViewer.method(:new)
Vizkit::UiLoader.register_widget_for "LogMarkerViewer", Orocos::Log::Annotations, :config2
