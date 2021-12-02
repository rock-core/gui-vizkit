#!usr/bin/env ruby

module Qt
    class Application
        def self.new(*args)
            if $qApp
                raise "trying to construct more than one QApplication. Note that doing \"require 'vizkit'\" creates one"
            end

            super
        end
    end
end

module Vizkit
    extend Logger::Root('Vizkit', Logger::WARN)

    #register mapping to find plugins for a specific object
    PluginHelper.register_map_obj("Orocos::Async::PortProxy","Orocos::Async::SubPortProxy") do |port|
        if port.respond_to? :type_name
            PluginHelper.normalize_obj(port.type_name)-["Object","BasicObject"]
        else
            [port]
        end
    end
    PluginHelper.register_map_obj("Orocos::TaskContext") do |task|
        PluginHelper.classes(task.model) if task.respond_to?(:model) && task.model
    end
    PluginHelper.register_map_obj("Orocos::Async::TaskContextProxy") do |task|
        PluginHelper.classes(task.model) if task.respond_to?(:model) && task.model
    end

    if !ENV['VIZKIT_NO_GUI']
        old_lang = ENV['LC_ALL']
        ENV['LC_ALL'] = 'C'
        if !$qApp
            Qt::Application.new(ARGV)
        end
        ENV['LC_ALL'] = old_lang
    end

    def self.app
        $qApp
    end

    def self.default_loader
        @default_loader ||= UiLoader.new
        @default_loader
    end

    def self.setup_widget(widget,value=nil,options = Hash.new,type = :display,&block)
        return nil if !widget
        if type == :control || !value.respond_to?(:connect_to)
            widget.config(value,options,&block) if widget.respond_to?(:config)
            if widget.respond_to?(:plugin_spec)
                block = if block || !value.respond_to?(:writer)
                            block
                        else
                            writer = value.writer
                            Proc.new {|val|writer.write(val)}
                        end
                callback_fct = widget.plugin_spec.find_callback!(:argument => value,:callback_type => type)
                if callback_fct && (!callback_fct.respond_to?(:to_sym) || callback_fct.to_sym != :config)
                    callback_fct = callback_fct.bind(widget)
                    callback_fct.call(value, options, &block)
                end
            end
        else
            value.connect_to widget,options ,&block
        end
        widget.show if widget.is_a? Qt::Widget #respond_to is not working because qt is using method_missing
        widget
    end

    def self.widget_from_options(value,options=Hash.new,&block)
        if value.is_a? Array
            result = Array.new
            value.each do |val|
                result << widget_from_options(val, options, &block)
            end
            return result
        end
        opts,options = Kernel::filter_options(options,@vizkit_local_options)
        widget = if opts[:widget].respond_to? :to_str
                     default_loader.create_plugin(opts[:widget],opts[:parent],opts[:reuse])
                 else
                     if opts[:widget]
                         opts[:widget]
                     else
                         default_loader.create_plugin_for(value,opts[:widget_type],opts[:parent],opts[:reuse])
                     end
                 end
        setup_widget(widget,value,options,opts[:widget_type],&block)
    end

    def self.control value, options=Hash.new,&block
        options[:widget_type] = :control
        widget = widget_from_options(value,options,&block)
        if(!widget)
            Vizkit.warn "No widget found for controlling #{value}!"
            return nil
        end
        widget
    end

    def self.task_inspector
        @task_inspector ||= begin
                                task = default_loader.TaskInspector
                                raise "Cannot find plugin TaskInspector" unless task
                                task.add_name_service Orocos::Async.name_service
                                task
                            end
    end

    def self.display value,options=Hash.new,&block
        value = value.to_proxy
        options[:widget_type] = :display
        widget = widget_from_options(value,options,&block)
        Vizkit.warn "No widget found for displaying #{value}!" if(!widget)
        widget
    end

    class ShortCutFilter < Qt::Object
        def eventFilter(obj,event)
            if event.is_a?(Qt::KeyEvent)
                #if someone is pressing ctrl i show a debug window
                if event.key == 73 && event.modifiers == Qt::ControlModifier
                    @vizkit_info_viewer ||= Vizkit.default_loader.VizkitInfoViewer
                    @vizkit_info_viewer.show
                end
            end
            return false
        end
    end
    def self.exec(async_period: 0.01)
        #install event filter
        obj = ShortCutFilter.new
        $qApp.installEventFilter(obj)

        timer = Qt::Timer.new
        timer.connect SIGNAL("timeout()") do
            Orocos::Async.step
        end
        timer.start Integer(async_period * 1000)

        $qApp.exec
    end

    def self.process_events()
        $qApp.processEvents
    end

    def self.step
        $qApp.processEvents
        Orocos::Async.step
    end

    def self.load(ui_file,parent = nil)
        default_loader.load(ui_file,parent)
    end

    def self.proxy(name,options=Hash.new)
        Orocos::Async.proxy name,options
    end

    def self.get(name,options=Hash.new)
        Orocos::Async.get name,options
    end

    def self.connect_all()
        @connections.each do |connection|
            connection.connect
        end
    end

    #disconnects all connections to widgets
    def self.disconnect_all
    end

    # call-seq:
    #   Vizkit.connect_port_to 'corridor_planner', 'plan', widget
    #   Vizkit.connect_port_to 'corridor_planner', 'plan' do |value|
    #     ...
    #   end
    #
    # Asks vizkit to connect the given task,port pair on either a widget, and/or
    # through a block. The return value is the connection object which can be used to disconnect
    # and reconncet the widget/ block.
    #
    # Unlike Orocos::OutputPort#connect_to, this expects a task and port name,
    # i.e. can be called even though the remote task is not started yet
    # This is use full if tasks are replayed from a logfile
    def self.connect_port_to(task_name, port_name, widget = nil, options = Hash.new, &block)
        if widget.kind_of?(Hash)
            widget, options = nil, widget
        end
        widget = if widget.respond_to? :to_str
                     default_loader.create_plugin(widget.to_str)
                 else
                     widget
                 end
        port = Orocos::Async.proxy(task_name).port(port_name)
        l = port.on_reachable do
            begin
                port.connect_to widget,options,&block
                l.stop # stop listener
            rescue Exception => e
                Vizkit.warn "error while connecting #{port.name} with widget: #{e}"
            end
        end
    end

    @vizkit_local_options = {:widget => nil,:reuse => true,:parent =>nil,:widget_type => :display}

    class << self
        # When using Vizkit3D widgets, this is a [task_name, port_name] pair of a
        # data source that should be used to gather transformation configuration.
        # This configuration is supposed to be stored in a
        # /transformer/ConfigurationState data structure.
        #
        # A port can also be set directly in
        # Vizkit.vizkit3d_transformer_configuration
        attr_accessor :vizkit3d_transformer_broadcaster_name

        # Allow to set the vizkit3d widget to a custom one. If it is not set by the
        # user Vizkit will automatically create one if accessed.
        attr_accessor :vizkit3d_widget
    end
    @vizkit3d_transformer_broadcaster_name = ['transformer_broadcaster', 'configuration_state']

    #returns the instance of the vizkit 3d widget
    def self.vizkit3d_widget
        @vizkit3d_widget ||= default_loader.create_plugin("vizkit3d::Vizkit3DWidget")
    end

    # Make sure that orocos.rb is properly initialized. This must be called in
    # each widget that require an Orocos component "behind the scenes"
    def self.ensure_orocos_initialized
        if !Orocos.initialized?
            Orocos.initialize
        end
    end

    #returns an instance to a connection manager handing the connections
    #between code blocks and orocos ports
    def self.connection_manager
        @connection_manager ||= Vizkit::ConnectionManager.new($qApp)
    end
end
