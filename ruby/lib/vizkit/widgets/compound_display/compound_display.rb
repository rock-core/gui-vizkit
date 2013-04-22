require 'vizkit'
require 'yaml'
require 'orocos/uri'

# Compound widget for displaying multiple data visualization widgets in a grid layout
# (default dimensions: 3x2). Specific position configurations, e.g. which port 
# gets displayed in which widget at which position) can be saved to and restored
# from YAML files. The grid will be a row_count x col_count matrix. The numbering 
# sequence is left to right, top-down.
#
# Example of a 2x3 widget position layout:
#   0 1 2
#   3 4 5
#
# @author Allan Conquest <allan.conquest@dfki.de>
class CompoundDisplay < Qt::Widget

    slots 'configure_by_yaml(QString)', 'save_yaml(QString)'

    # Flag whether to display the load / save configuration buttons.
    attr_reader :show_menu
    
    def initialize(row_count = 2, col_count = 3, parent = nil)
        super(parent)
        
        @container_hash = Hash.new # holds the container widgets
        @disconnected = false
        
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
            configure_by_yaml
        end
        
        @gui.save_button.connect(SIGNAL :clicked) do
            save_yaml
        end
        
        @gui.disconnect_button.hide # TODO disconnect not fully working.
        #@gui.disconnect_button.connect(SIGNAL :clicked) do
        #    if not @disconnected
        #        @config_hash.each do |idx,_|
        #            disconnect idx
        #        end
        #        @gui.disconnect_button.set_text("Reconnect all")
        #        @disconnected = true
        #    else
        #        @config_hash.each do |idx,_|
        #            connect idx
        #        end
        #        @gui.disconnect_button.set_text("Disconnect all")
        #        @disconnected = false
        #    end
        #end
        
        @gui.reduce_rows_button.hide # TODO grid resize at runtime is buggy
        #@gui.reduce_rows_button.connect(SIGNAL :clicked) do
        #    set_grid_dimensions(row_count-1, col_count)
        #end
        
        self
    end
    
    # Selective configuration of one element at position +pos+.
    # The connection is being established automatically with respect
    # to the configuration.
    def configure(pos, task, port, widget, policy = Hash.new)
        @container_hash[pos].configure(task, port, widget, policy)
        connect(pos)
    end
    
    # Establish a connection between the port and widget specified in config for element at +pos+.
    def connect(pos)
        @container_hash[pos].connect
    end
    
    # Close a connection between the port and widget specified in config for element at +pos+.
    # The content widget gets destroyed but the configuration will remain save until it gets overriden by a new one.
    def disconnect(pos)
        @container_hash[pos].disconnect
    end
    
    # Configures the dimensions of the grid layout. The grid will be a 
    # row_count x col_count matrix. The numbering sequence is left to right, top-down.
    #
    # TODO: Does not work reliably at runtime! => Configure once at startup.
    # 
    # Examples:
    #
    # row_count: 4, col_count: 2:
    #   0 1
    #   2 3
    #   4 5
    #   6 7
    #
    # row_count: 3, col_count: 3
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
                    widget_pos = (row * col_count) + col
                    container = ContainerWidget.new(widget_pos)
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
    #     connection_policy: <option hash>
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
    #     connection_policy:
    #
    def configure_by_yaml(path)
        unless path
            # Display file explorer
            path = Qt::FileDialog.getOpenFileName(self, "Open configuration file", ".", "YAML Files (*.yml *.yaml)")
        end

        begin   
            # Load configuration from YAML
            hash = YAML.load(open(path))
            
            # Sanity checks:
            error = nil
            
            if hash.keys.max > @container_hash.keys.max
                error = "Higher position value in file than #containers available."
            elsif hash.size < @container_hash.size
                error = "More config items in file than containers available."
            end
            
            if error
                msg_box = Qt::MessageBox.new
                msg_box.set_text("Problem with YAML import:")
                msg_box.set_informative_text(error)
                msg_box.exec
                return
            end
            
            # Disconnect, update configuration and connect for each container
            hash.each do |pos, config|
                container = @container_hash[pos]
                container.disconnect
                container.configure_by_obj(config)
                container.connect if config
            end
        rescue Exception => e
            Vizkit.error "A problem occured while trying to open '#{path}': \n#{e.message}"
            Vizkit.error e.backtrace.inspect  
        end
    end
    
    
    #def configure_by_yaml_string
    #    # TODO import from yaml string.
    #end

    # Save complete configuration in YAML format to a file located at +path+.
    def save_yaml(path)
        unless path
            # Display file explorer
            path = Qt::FileDialog.getSaveFileName(self, "Save configuration file", "./myconfig.yml", "YAML Files (*.yml *.yaml)")
        end

        begin
            config_hash = Hash.new
            @container_hash.each do |pos, container|
                config_hash[pos] = container.config
            end
            File.open(path, "w") {|f| f.write(config_hash.to_yaml) }
        rescue Exception => e
            Vizkit.error "A problem occured while trying to write configuration to '#{path}': \n#{e.message}"
        end
    end
    
    def show_menu(flag)
        @show_menu = flag
        @gui.config_menu.set_visible(flag)
        update
    end
    
    def sizeHint
        return Qt::Size.new(700,700)
    end
    
    def resizeEvent(event)
        #puts "Resized to #{event.size.width},#{event.size.height}"
    end
    
end

# Configuration model for one element of the CompoundDisplay.
class CompoundDisplayConfig
    attr_reader :task, :port, :widget, :connection_policy
    
    def initialize(task = nil, port = nil, widget = nil, policy = Hash.new)
        @task = task.force_encoding("utf-8") # string
        @port = port.force_encoding("utf-8") # string
        @widget = widget.force_encoding("utf-8") # string
        @connection_policy = policy # hash
    end
    
    def invalid?
        return @task.nil? || @port.nil? || @widget.nil? || @connection_policy.nil? || @task.empty? || @port.empty?
    end
end

class ContainerWidget < Qt::Widget
    attr_reader :label_text
    attr_reader :content_widget
    attr_reader :position
    attr_reader :config
    
    def initialize(pos, config=nil, parent = nil)
        super(parent)
        @config = config
        #set_size_policy(Qt::SizePolicy::Expanding, Qt::SizePolicy::Expanding)
        set_size_policy(Qt::SizePolicy::MinimumExpanding, Qt::SizePolicy::MinimumExpanding)
        @position = pos
        
        @listener = nil
        
        @default_label_text = "#{@position}: No input"
        @label_text = @default_label_text
        
        @layout = Qt::VBoxLayout.new(self)
        
        @label = Qt::Label.new(label_text)
        @label.set_size_policy(Qt::SizePolicy::Preferred, Qt::SizePolicy::Maximum)
        @layout.add_widget(@label)
        
        set_accept_drops(true)

        set_content_widget(content_widget) if content_widget
        
        self
    end
    
    def configure(task, port, widget, policy = Hash.new)
        @config = CompoundDisplayConfig.new(task, port, widget, policy)
    end
    
    def configure_by_obj(config)
        @config = config
    end
    
    def connect
        if @config.invalid?
            Vizkit.error "Invalid configuration for position #{@position}: #{@config}"
            return
        end
        
        disconnect

        puts "Connecting #{@config.task}.#{@config.port} to #{@config.widget}"
        widget = Vizkit.default_loader.create_plugin(@config.widget)
        set_content_widget(widget)

        task = Orocos::Async.proxy(@config.task)
        port = task.port(@config.port)
        
        @listener.stop if @listener
        @listener = port.connect_to(widget) if task && port #Vizkit.connect_port_to(config.task, config.port, widget, config.connection_policy) #port.connect_to(widget) if task && port
        set_label_text("#{@config.task}.#{@config.port}")
    end
    
    def disconnect
        @listener.stop if @listener
        @listener = nil
        
        # Destroy old widget if any
        if widget = @content_widget
            widget.set_parent(nil)
            widget = nil
        end

        set_label_text(@default_label_text)
    end
    
    def set_content_widget(widget)
        disconnect
        @content_widget = widget
        @layout.add_widget(widget)
        widget.show
    end
    
    def set_label_text(text)
        @label.set_text(text)
        @label_text = text
    end
    
    def set_position(pos)
        @position = pos
    end
    
    def widget_selection(pos, type_name)
        menu = Qt::Menu.new(self)

        # Determine applicable widgets for the output port
        widgets = Vizkit.default_loader.find_all_plugin_names(:argument=>type_name, :callback_type => :display,:flags => {:deprecated => false})

        widgets.uniq!
        widgets.each do |w|
            menu.add_action(Qt::Action.new(w, parent))
        end
        # Display context menu at cursor position.
        action = menu.exec(pos)
        action.text if action
    end
    
    ## reimplemented methods
    
    def sizeHint
        #if @content_widget
        #    @content_widget.size_hint
        #else 
        #    Qt::Size.new(100, 100)
        #end
        Qt::Size.new(100, 100)
    end
    
    def dragEnterEvent(event)
        event.accept_proposed_action
        if event.mime_data.has_format("text/plain")
            event.accept_proposed_action
        else
            msg_box = Qt::MessageBox.new
            msg_box.set_text("Bad format!")
            msg_box.set_standard_buttons(Qt::MessageBox::Ok)
            msg_box.set_informative_text("The only supported format is text/plain. Submit a valid Orocos URI.")
            event.ignore
        end
        nil
    end
    
    def dropEvent(event)
        text = event.mime_data.text
        unless text
            Vizkit.warn "No text dropped"
            return
        end
        
        begin
            msg_box = Qt::MessageBox.new
            msg_box.set_text("Bad drop text!")
            msg_box.set_standard_buttons(Qt::MessageBox::Ok)

            uri = URI.parse(text)

            unless uri.is_a? URI::Orocos
                msg_box.set_informative_text("Not a valid Orocos URI: '#{text}'")
                msg_box.exec
                return
            end
            
            # Display context menu at drop point to choose from available display widgets
            widget_name = widget_selection(map_to_global(event.pos), uri.port_proxy.type_name)
            return unless widget_name
            
            configure(uri.task_name, uri.port_name, widget_name)
            connect

            event.accept_proposed_action
        rescue ArgumentError => e
            msg_box.set_informative_text("Received an ArgumentError while parsing URI '#{text}'")
            msg_box.set_detailed_text("Error message: #{e.message}")
            msg_box.exec
        rescue URI::InvalidURIError => e
            msg_box.set_informative_text("Invalid URI: '#{text}'")
            msg_box.set_detailed_text("Error message: #{e.message}")
            msg_box.exec
        end
        
        nil
    end
end

Vizkit::UiLoader.register_ruby_widget("CompoundDisplay",CompoundDisplay.method(:new))
