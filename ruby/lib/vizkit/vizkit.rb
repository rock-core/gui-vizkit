#!usr/bin/env ruby

module Vizkit
  extend Logger::Root('Vizkit', Logger::WARN)

  class UiLoader
    define_widget_for_methods("type",String) do |type|
      type
    end

    define_widget_for_methods("port_type",Orocos::OutputPort,Orocos::Log::OutputPort,PortProxy) do |port|
      port.type_name
    end
    define_widget_for_methods("task",Orocos::TaskContext,Orocos::Log::TaskContext,TaskProxy) do |task|
      task.class
    end
    define_widget_for_methods("annotations",Orocos::Log::Annotations) do |klass|
      klass.class
    end

    define_control_for_methods("task",Orocos::TaskContext) do |task|
      task.model.name
    end
    define_control_for_methods("port",Orocos::InputPort,PortProxy) do |port|
      port.type_name
    end
    define_control_for_methods("replay",Orocos::Log::Replay) do |klass|
      klass.class
    end
  end
end

module Vizkit
  extend Logger::Root('vizkit.rb', Logger::WARN)

  if !ENV['VIZKIT_NO_GUI']
      Qt::Application.new(ARGV)
  end

  def self.app
    $qApp
  end

  def self.default_loader
    @default_loader ||= UiLoader.new
  end

  def self.setup_widget(widget,value=nil,options = Hash.new,type = :display,&block)
    return nil if !widget
    config_result = widget.config(value,options,&block) if widget.respond_to? :config

    if type == :control
      if widget.respond_to?(:loader) && callback_fct = widget.loader.control_callback_fct(widget,value)
        callback_fct.call(widget, value, options, &block)
      end
    else
      if type == :display && value.respond_to?(:connect_to) && config_result != :do_not_connect
        value.connect_to widget,options ,&block
      end
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
    local_options,options = Kernel::filter_options(options,@vizkit_local_options)
    value_temp = if value.is_a? Typelib::Type
                     value.class.name
                 else
                     value
                 end
    widget = default_loader.widget_from_options(value_temp,local_options)
    setup_widget(widget,value,options,local_options[:widget_type],&block)
  end

  def self.control value, options=Hash.new,&block
    options[:widget_type] = :control
    value_temp = if value.is_a? Typelib::Type
                     value.class.name
                 else
                     value
                 end
    widget = widget_from_options(value_temp,options,&block)
    if(!widget)
      Vizkit.warn "No widget found for controlling #{value}!"
      return nil
    end
    widget
  end

  def self.display value,options=Hash.new,&block
    options[:widget_type] = :display
    value_temp = if value.is_a? Typelib::Type
                     value.class.name
                 else
                     value
                 end
    widget = widget_from_options(value_temp,options,&block)
    if(!widget)
      Vizkit.warn "No widget found for displaying #{value}!"
      return nil
    end
    widget
  end

  def self.connections
    @connections
  end

  class ShortCutFilter < Qt::Object
    def eventFilter(obj,event)
      if event.is_a?(Qt::KeyEvent)
        #if someone is pressing ctrl i show a debug window
        if event.key == 73 && event.modifiers == Qt::ControlModifier
          @vizkit_info_viewer ||= Vizkit.default_loader.VizkitInfoViewer
          @vizkit_info_viewer.auto_update(Vizkit.connections)
          @vizkit_info_viewer.show
        end
      end
      return false
    end
  end
  def self.exec()
     #install event filter
     obj = ShortCutFilter.new
     $qApp.installEventFilter(obj)

    # the garbage collector has to be called manually for now 
    # because ruby does not now how many objects were created from 
    # the typelib side 
     gc_timer = Qt::Timer.new
     gc_timer.connect(SIGNAL(:timeout)) do 
       GC.start
     end
     gc_timer.start(5000)

     if !ReaderWriterProxy.default_policy[:port_proxy]
         $qApp.exec
     elsif Orocos::CORBA.initialized?
         proxy =  ReaderWriterProxy.default_policy[:port_proxy]
         proxy.__change_name("port_proxy_#{ENV["USERNAME"]}_#{Process.pid}")
         output = if @port_proxy_log || Vizkit.logger.level < Logger::WARN
                    "%m-%p.txt"
                  else
                      nil
                  end
         Orocos.run "port_proxy::Task" => proxy.name, :output => output do
             proxy.start
             #wait unti the proxy is running 
             while !proxy.running?
                 sleep(0.01)
             end
             $qApp.exec
         end
     else
         $qApp.exec
     end
     gc_timer.stop
  end

  def self.process_events()
    $qApp.processEvents
  end

  def self.load(ui_file,parent = nil)
    default_loader.load(ui_file,parent)
  end

  def self.disconnect_from(handle)
    case handle
    when Qt::Widget then
      @connections.delete_if do |connection|
        if connection.widget.is_a?(Qt::Object) && handle.findChild(Qt::Widget,connection.widget.objectName)
          connection.disconnect
          true
        else
          if(connection.widget == handle)
            connection.disconnect
            true
          else
            false
          end
        end
      end
    else
      @connections.delete_if do |connection|
        if connection.port == handle
          connection.disconnect
          true
        else
          false
        end
      end
    end
  end

  def self.connect_all()
    @connections.each do |connection|
      connection.connect
    end
  end

  def self.reconnect_all()
    @connections.each do |connection|
      connection.reconnect()
    end
  end

  #reconnects all connection to the widget and its children
  #even if the connection is still alive
  def self.reconnect(widget,force=false)
    if widget.is_a?(Qt::Object)
      @connections.each do |connection|
        if connection.widget.is_a?(Qt::Object) && widget.findChild(Qt::Object,connection.widget.objectName)
          connection.reconnect
        end
      end
    else
      @connections.each do |connection|
          connection.reconnect if connection.widget == widget
      end
    end
  end

  #connects all connection to the widget and its children
  #if the connection is not responding
  def self.connect(widget)
    if widget.is_a?(Qt::Object)
      @connections.each do |connection|
        if connection.widget.is_a?(Qt::Object) 
          if connection.objectName() && widget.findChild(Qt::Object,connection.widget.objectName) || connection.widget == widget
            connection.connect
          end
        end
      end
    else
      @connections.each do |connection|
        connection.connect if connection.widget == widget
      end
    end
  end

  #disconnects all connections to widgets 
  def self.disconnect_all
    @connections.each do |connection|
      connection.disconnect
    end
    @connections = Array.new
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
    connection = OQConnection.new(task_name, port_name, options, widget, &block)
    connection.connect
    Vizkit.connections << connection 
    connection 
  end

  # cal-seq:
  #   Vizkit.use_tasks(task1,task2,...)
  #
  # For all connections which will be created via connect_port_to are the tasks
  # used as preferred source. If no suitable task is found connect_port_to will fall
  # back to the corba name server 
  #
  # This is use full if someone wants to use tasks which are replayed
  def self.use_tasks(tasks)
      @use_tasks = Array(tasks).flatten
  end

  #returns the task which shall be used by vizkit  
  #this is usefull for log replay
  def self.log_task(task_name)
    task = nil
    task = @use_tasks.find{|task| task.name==task_name} if @use_tasks
    task
  end

  def self.use_log_task?(task_name)
      log_task(task_name) != nil
  end

  @connections = Array.new
  @vizkit_local_options = {:widget => nil,:reuse => true,:parent =>nil,:widget_type => :display}
  ReaderWriterProxy.default_policy = {:port_proxy => TaskProxy.new("port_proxy"), :init => true}

  class << self
    # When using Vizkit3D widgets, this is a [task_name, port_name] pair of a
    # data source that should be used to gather transformation configuration.
    # This configuration is supposed to be stored in a
    # /transformer/ConfigurationState data structure.
    #
    # A port can also be set directly in
    # Vizkit.vizkit3d_transformer_configuration
    attr_accessor :vizkit3d_transformer_broadcaster_name
    attr_accessor :port_proxy_log
  end
  @vizkit3d_transformer_broadcaster_name = ['transformer_broadcaster', 'configuration_state']
  @port_proxy_log = false

  #returns the instance of the vizkit 3d widget 
  def self.vizkit3d_widget
    @vizkit3d_widget ||= default_loader.create_widget("vizkit::Vizkit3DWidget")
    @vizkit3d_widget
  end

  # Make sure that orocos.rb is properly initialized. This must be called in
  # each widget that require an Orocos component "behind the scenes"
  def self.ensure_orocos_initialized
    if !Orocos.initialized?
      Orocos.initialize
    end
  end
end
