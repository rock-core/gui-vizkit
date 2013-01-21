require 'vizkit'
require 'yaml'

# Compound widget for displaying multiple visualization widgets in a grid layout
# (default dimensions: 3x2). Specific position configurations, e.g. which port 
# gets displayed in which widget at which position) can be saved to and restored
# from YAML files. You need one configuration object for each element.
# The grid will be a row_count x col_count matrix. The numbering sequence is 
# left to right, top-down.
#
# Widget position layout:
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
    
    def initialize(row_count = 3, col_count = 2, parent = nil)
        super(parent)
        
        @container_hash = {} # holds the container widgets
        @config_hash = {}
        @disconnected = false
        @replayer = nil
        
        set_window_title("CompoundDisplay")
        resize(600,400)
        layout = Qt::HBoxLayout.new
        set_layout(layout)
        @gui = Vizkit.load(File.join(File.dirname(__FILE__),'compound_display.ui'),self)
        @grid = @gui.grid_layout
        show_menu(true)
        layout.add_widget(@gui)

        set_grid_dimensions(row_count, col_count)
        
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
        
        @gui.reduce_rows_button.connect(SIGNAL :clicked) do
            set_grid_dimensions(row_count-1, col_count)
        end
        
        self
    end
    
    # Selective configuration of one element at position +pos+.
    # The connection is being established automatically with respect
    # to the configuration.
    #
    # +config+ is a CompoundDisplayConfig object.
    def configure(pos, config)
        Kernel.raise "Unsupported config format: #{config.class}. Expecting CompoundDisplayConfig." unless config.is_a? CompoundDisplayConfig
        @config_hash[pos] = config
        connect(pos)
    end
    
    # Establish a connection between the port and widget specified in config for element at +pos+.
    def connect(pos)
        config = @config_hash[pos]
        if config.invalid?
            Vizkit.warn "Invalid configuration for position #{pos}."
            return
        end

        Vizkit.info "Connecting #{config.task}.#{config.port} to #{config.widget} #{config.pull ? "config:pull" : ""}"
        widget = Vizkit.default_loader.send(config.widget)
        container = @container_hash[pos]
        container.set_content_widget(widget)
        container.set_label_text("#{config.task}.#{config.port}")
        
        if @replayer
            task = @replayer.task(config.task)
            port = task.port(config.port)
            #Vizkit.connect_port_to(task, port, config.widget, :pull => config.pull)
            port.connect_to(widget) if task && port
        else
            task = Orocos.name_service.get(config.task)
            port = task.port(config.port)
            Vizkit.connect_port_to(task, port, config.widget, :pull => config.pull) if task && port
        end
    end
    
    # Close a connection between the port and widget specified in config for element at +pos+.
    # The content widget gets destroyed but the configuration will remain save until it gets overriden by a new one.
    def disconnect(pos)
        config = @config_hash[pos]
        Vizkit.disconnect_from config.task
        
        # Destroy old widget 
        if widget = @container_hash[pos].content_widget
            widget.set_parent(nil)
            widget = nil
        end
    end
    
    # Reconfigures the dimensions of the grid layout. The grid will be a 
    # row_count x col_count matrix. The numbering sequence is left to right, top-down.
    # 
    # Examples:
    #
    # row_count: 4, col_count: 2:
    #   0 1
    #   2 3
    #   4 5
    #   6 7
    #
    # row_count: 2, col_count: 3
    #   0 1 2
    #   3 4 5
    #   6 7 8
    #  
    def set_grid_dimensions(row_count, col_count)

        # Remove all parent widgets from grid.
        child = nil
        while(child = @grid.take_at(0)) 
            widget = child.widget
            widget.set_parent(nil)
            widget = nil
            child = nil
        end
        
        # Generate container widgets with label if not yet existent
        counter = 0
        for row in 0..row_count-1 do
            for col in 0..col_count-1 do
                container = nil
                if not @container_hash[counter]
                    container = ContainerWidget.new
                    container.set_label_text("No input")
                    @container_hash[counter] = container
                else
                    container = @container_hash[counter]
                end
                
                # Add parent widget to grid
                @grid.add_widget(container, row, col) # TODO does this make @grid the parent of the widget?
                container.show
                counter = counter + 1
            end
        end
        
        # Delete useless container widgets if any
        @container_hash.delete_if {|pos, conatiner| pos >= counter}
     
    end
    
    # Import configuration from YAML file located at +path+.
    #
    # TODO: Currently, the whole configuration will be replaced.
    #
    # The format of the yaml file is as follows:
    #
    #   ---
    #   <pos>: !ruby/object:CompoundDisplayConfig
    #     task: <task name>
    #     port: <port name>
    #     widget: <widget name>
    #     pull: <pulled connection?>
    #   
    #   <pos>: !ruby/object:CompoundDisplayConfig
    #     task: <task name>
    #     ...
    #
    # Example for the 4th element (bottom center):
    #   
    #   ---
    #   4: !ruby/object:CompoundDisplayConfig
    #     task: front_camera
    #     port: frame
    #     widget: ImageView
    #     pull: false
    #
    def configure_by_yaml(path)
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
    
    
    #def configure_by_yaml_string
    #    # TODO import from yaml string.
    #end
    
    # Enables display of data from logs.
    # +log_replay+ is the Orocos::Log::Replay object you get when you open a logfile.
    #
    # TODO Currently, there is no support for a mixed display of live and log data.
    #
    def replay_mode(log_replay)
        @replayer = log_replay
    end
    
    # Save complete configuration in YAML format to a file located at +path+.
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
class CompoundDisplayConfig
    attr_reader :task, :port, :widget, :pull
    
    def initialize(task, port, widget, pull)
        @task = task # string
        @port = port # string
        @widget = widget
        @pull = pull # bool
    end
    
    def invalid?
        return @task && @port && @widget && @pull && (not task.empty?) && (not port.empty?)
    end
end

class ContainerWidget < Qt::Widget
    attr_reader :label_text
    attr_reader :content_widget
    
    def initialize(label_text = "", content_widget = nil, parent = nil)
        super(parent)
        set_size_policy(Qt::SizePolicy::Preferred, Qt::SizePolicy::Preferred)
        @label_text = label_text
        @layout = Qt::VBoxLayout.new(self)
        
        @label = Qt::Label.new(label_text)
        @label.set_size_policy(Qt::SizePolicy::Preferred, Qt::SizePolicy::Maximum)
        @layout.add_widget(@label)
        
        set_content_widget(content_widget) if content_widget
        self
    end
    
    def set_content_widget(widget)
        if @content_widget
            # Delete existing widget
            @content_widget.set_parent(nil)
            @content_widget = nil
        end
        @content_widget = widget
        @layout.add_widget(@content_widget)
        widget.show
    end
    
    def set_label_text(text)
        @label.set_text(text)
        @label_text = text
    end
end

Vizkit::UiLoader.register_ruby_widget("CompoundDisplay",CompoundDisplay.method(:new))
