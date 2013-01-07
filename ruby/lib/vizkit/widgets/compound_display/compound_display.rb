require 'vizkit'
require 'yaml'

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

    slots 'configure_by_yaml(QString)', 'save_yaml(QString)'

    # Config hash: {<position> => <config_object>}
    attr_reader :config_hash
    
    # Flag whether to display the load / save configuration buttons.
    attr_reader :show_menu
            
    def initialize(parent=nil)
        super
        set_window_title("CompoundDisplay")
        resize(600,400)
        layout = Qt::HBoxLayout.new
        set_layout(layout)
        @gui = Vizkit.load(File.join(File.dirname(__FILE__),'compound_display.ui'),self)
        show_menu(true)
        layout.add_widget(@gui)
        @config_hash = Hash.new
        
        ## Configure configuration import / export
        @gui.load_button.connect(SIGNAL :clicked) do
            @config_load_path = Qt::FileDialog.getOpenFileName(self, "Open configuration file", ".", "YAML Files (*.yml *.yaml)")
            if @config_load_path
                configure_by_yaml(@config_load_path)
            end
        end
        
        @gui.save_button.connect(SIGNAL :clicked) do
            @config_save_path = Qt::FileDialog.getSaveFileName(self, "Save configuration file", "./myconfig.yml", "YAML Files (*.yml *.yaml)")
            if @config_save_path
                save_yaml(@config_save_path)
            end
        end
        
        self
    end
    
    def configure(pos, config)
        Kernel.raise "Unsupported config format: #{config.class}. Expecting CompoundDisplayConfig." unless config.is_a? CompoundDisplayConfig
        @config_hash[pos] = config
        #connect(pos) # TODO COMMENT IN AGAIN!!!
    end
    
    def connect(pos)
        config = @config_hash[pos]
        Vizkit.info "Connecting #{config.task}.#{config.port} to #{config.widget} #{config.pull ? "config:pull" : ""}"
        widget = Vizkit.default_loader.send(config.widget)
        parentw = @gui.send("widget_#{pos}")
        parentw.layout.add_widget(widget)
        label = @gui.send("label_#{pos}")
        label.set_text("#{port.task.name}.#{port.name}")
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
        label = @gui.send("label_#{pos}")
        label.set_text("#{port.task.name}.#{port.name}")
        widget.show
        port.connect_to(widget)
    end
    
    # Import yaml from file. Update all submitted elements at once (not necessarily every element of the CompoundDisplay).
    # TODO specify format.
    def configure_by_yaml(path)
        ctr = 0
        begin        
            @config_hash = YAML.load_stream(open(path))
            @config_hash.each do |idx,config|
                #configure idx, config
                connect idx
            end
        rescue Exception => e
            Vizkit.error "A problem occured while trying to open '#{path}': \n#{e.message}"
            
            Vizkit.error e.backtrace.inspect  
        end
    end
    
    
    def configure_by_yaml_string
        # TODO import from yaml string.
    end
    
    def save_yaml(path)
        begin
            File.open(path, "w") {|f| f.write(@config_hash.to_yaml) }
        rescue Exception => e
            Vizkit.error "A problem occured while trying to write configuration to '#{path}': \n#{e.message}"
        end
    end
    
    def show_menu(flag)
        @show_menu = flag
        @gui.config_menu.set_visible(flag)
        update
    end

end

# Configuration model for one element of the CompoundDisplay.
# You need one config object for each element.
class CompoundDisplayConfig
    attr_reader :task, :port, :widget, :pull
    
    def initialize(task, port, widget, pull)
        @task = task # string
        @port = port # string
        @widget = widget
        @pull = pull # bool
    end
end

Vizkit::UiLoader.register_ruby_widget("CompoundDisplay",CompoundDisplay.method(:new))
