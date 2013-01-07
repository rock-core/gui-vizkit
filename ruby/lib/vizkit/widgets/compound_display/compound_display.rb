require 'vizkit'

# Compound widget for displaying up to six visualization widgets in a 3x2 grid.
# Grid 'layouts', i.e. specific position configurations, can be saved to and
# restored from YAML files.
#
# Widget positions:
#   0 1 2
#   3 4 5
#
# @author Allan Conquest <allan.conquest@dfki.de>
class CompoundDisplay < Qt::Widget

    slots 'save()', 'setWidget(int, QString, QWidget)'
    
    # Config hash: {<position> => <config_object>}
    attr_reader :config_hash
            
    def initialize(parent=nil)
        super
        set_window_title("CompoundDisplay")
        resize(600,400)
        layout = Qt::HBoxLayout.new
        set_layout(layout)
        @gui = Vizkit.load(File.join(File.dirname(__FILE__),'compound_display.ui'),self)
        layout.add_widget(@gui)
        @config_hash = Hash.new
        self
    end
    
    def configure(pos, config)
        raise "Unsupported config format: #{config.class}. Expecting CompoundDisplayConfig." if not config.is_a? CompoundDisplayConfig
        @config_hash[pos] = config
        connect(pos)
    end
    
    def connect(pos)
        config = @config_hash[pos]
        Vizkit.info "Connecting #{config.task}.#{config.port} to #{config.widget} #{config.pull ? "config:pull" : ""}"
        widget = Vizkit.default_loader.send(config.widget)
        widget.set_parent(@gui.send("widget_#{pos}")) # place widget at desired position
        Vizkit.info "Got widget #{widget}"
        widget.show
        Vizkit.connect_port_to(config.task, config.port, config.widget, :pull => config.pull)
    end
    
    def connect_port_object(pos, port)
        # TODO port is a real task context port object. may be problematic with qt slots.
        #      only for debugging at the moment ...
        config = @config_hash[pos]
        widget = Vizkit.default_loader.send(config.widget)
        parentw = @gui.send("widget_#{pos}")
        parentw.layout.add_widget(widget)
        widget.show
        port.connect_to(widget)
    end
    def save
        puts "DEBUG: Saving configuration"
    end
    
    def set_widget(src, pos, widget=nil)
        puts "DEBUG: Displaying src: #{src} at position #{pos} in widget #{widget}"
        # TODO deprecated?
    end

end

# Configuration model for one element of the CompoundDisplay.
# You need one config object for each element.
class CompoundDisplayConfig
    attr_accessor :task, :port, :widget, :pull
    
    def initialize(task, port, widget, pull)
        @task = task # string
        @port = port # string
        @widget = widget
        @pull = pull # bool
    end
end

Vizkit::UiLoader.register_ruby_widget("CompoundDisplay",CompoundDisplay.method(:new))
