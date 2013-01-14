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
        
        @widget_hash = {}
        @disconnected = false
        @replayer = nil
        
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
        
        @gui.disconnect_button.connect(SIGNAL :clicked) do
            if not @disconnected
                @config_hash.each do |idx,_|
                    disconnect idx
                end
                @gui.disconnect_button.set_text("Reconnect all")
                @disconnected = true
            else
                @config_hash.each do |idx,_|
                    connect idx
                end
                @gui.disconnect_button.set_text("Disconnect all")
                @disconnected = false
            end
        end
        
        self
    end
    
    def configure(pos, config)
        Kernel.raise "Unsupported config format: #{config.class}. Expecting CompoundDisplayConfig." unless config.is_a? CompoundDisplayConfig
        @config_hash[pos] = config
        connect(pos)
    end
    
    def connect(pos)
        config = @config_hash[pos]
        Vizkit.info "Connecting #{config.task}.#{config.port} to #{config.widget} #{config.pull ? "config:pull" : ""}"
        widget = Vizkit.default_loader.send(config.widget)
        parentw = @gui.send("widget_#{pos}")
        @widget_hash[pos] = widget
        parentw.layout.add_widget(widget)
        label = @gui.send("label_#{pos}")
        label.set_text("#{config.task}.#{config.port}")
        Vizkit.info "Got widget #{widget}"
        widget.show
        
        if @replayer
            task = @replayer.task(config.task)
            port = task.port(config.port)
            #Vizkit.connect_port_to(task, port, config.widget, :pull => config.pull)
            port.connect_to(widget)
        else
            task = Orocos.name_service.get(config.task)
            port = task.port(config.port)
            Vizkit.connect_port_to(task, port, config.widget, :pull => config.pull)
        end
    end
    
    def disconnect(pos)
        config = @config_hash[pos]
        Vizkit.disconnect_from config.task
        @widget_hash[pos].set_parent(nil)
        @widget_hash[pos] = nil
    end
    
    #def connect_port_object(pos, port)
    #    # TODO port is a real task context port object. may be problematic with qt slots.
    #    #      only for debugging at the moment ...
    #    config = @config_hash[pos]
    #    widget = Vizkit.default_loader.send(config.widget)
    #    parentw = @gui.send("widget_#{pos}")
    #    parentw.layout.add_widget(widget)
    #    label = @gui.send("label_#{pos}")
    #    label.set_text("#{port.task.name}.#{port.name}")
    #    widget.show
    #    port.connect_to(widget)
    #end
    
    # Import yaml from file. Update all submitted elements at once (not necessarily every element of the CompoundDisplay).
    # TODO specify format.
    def configure_by_yaml(path)
        ctr = 0
        begin   
            # disconnect ports of old configuration     
            @config_hash.each do |idx,config|
                disconnect idx
            end
            
            # update configuration
            @config_hash = YAML.load(open(path))
            
            # connect ports of new configuration
            @config_hash.each do |idx,config|
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
    
    def replay_mode(log_replay)
        @replayer = log_replay
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
