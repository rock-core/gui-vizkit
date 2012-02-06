#!usr/bin/env ruby

module Vizkit
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
    define_control_for_methods("replay",Orocos::Log::Replay) do |klass|
      klass.class
    end
  end
end

module Vizkit
  extend Logger::Root('vizkit.rb', Logger::INFO)

  Qt::Application.new(ARGV)
  def self.app
    $qApp
  end

  def self.default_loader
    @default_loader
  end

  def self.setup_widget(widget,value=nil,options = Hash.new,type = :display,&block)
    return nil if !widget
    widget.config(value,options) if widget.respond_to? :config

    if type == :control
      callback_fct = if widget.respond_to?(:loader)
                       widget.loader.control_callback_fct widget,value
                     end
      widget.method(callback_fct).call(value, options, &block) if(callback_fct && callback_fct != :config)
    else
      if value.respond_to? :connect_to
        value.connect_to widget,options ,&block
        callback_fct = if widget.respond_to?(:loader)
                         widget.loader.callback_fct widget,value
                       end

        if(callback_fct && callback_fct != :config && value.respond_to?(:read))
          sample = value.read
          widget.method(callback_fct).call(sample, value.name) if sample
        end
      end
    end
    widget.show
    widget
  end

  def self.widget_from_options(value,options=Hash.new,&block)
    #if value is a array
    if value.is_a? Array
      result = Array.new
      value.each do |val|
        result << widget_for_options(val, options, &block)
      end
      return result
    end
    local_options,options = Kernel::filter_options(options,@vizkit_local_options)
    widget = @default_loader.widget_from_options(value,local_options)
    setup_widget(widget,value,options,local_options[:type],&block)
  end

  def self.control value, options=Hash.new,&block
    options[:widget_type] = :control
    widget = widget_from_options(value,options,&block)
    if(!widget)
      puts "No widget found for controlling #{value}!"
      return nil
    end
    widget
  end

  def self.display value,options=Hash.new,&block
    options[:widget_type] = :display
    widget = widget_from_options(value,options,&block)
    if(!widget)
      puts "No widget found for displaying #{value}!"
      return nil
    end
    widget
  end

  def self.connections
    @connections
  end

  def self.exec()
    # the garbage collector has to be called manually for now 
    # because ruby does not now how many objects were created from 
    # the typelib side 
     gc_timer = Qt::Timer.new
     gc_timer.connect(SIGNAL(:timeout)) do 
       GC.start
     end
     gc_timer.start(5000)
     $qApp.exec
     gc_timer.stop

  end
  def self.process_events()
    $qApp.processEvents
  end

  def self.load(ui_file,parent = nil)
    @default_loader.load(ui_file,parent)
  end

  def self.disconnect_from(handle)
    case handle
    when Qt::Widget:
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
    when Orocos::OutputPort:
      @connections.delete_if do |connection|
        if connection.port == handle
          connection.disconnect
          true
        else
          false
        end
      end
    else
      raise "Cannot handle #{handle.class}"
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

    task = @use_tasks.find{|task| task.name==task_name && task.has_port?(port_name)} if @use_tasks
    connection = nil;
    if task
      connection = task.port(port_name).connect_to(widget,options,&block)
    else
      connection = OQConnection.new(task_name, port_name, options, widget, &block)
      Vizkit.connections << connection 
    end
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
  def self.use_task?(task_name)
    task = nil
    task = @use_tasks.find{|task| task.name==task_name} if @use_tasks
    task
  end

  class OQConnection < Qt::Object
    #default values
    class << self
      attr_accessor :update_frequency
    end
    OQConnection::update_frequency = 8

    attr_reader :port
    attr_reader :reader
    attr_reader :widget
    attr_reader :policy

    def initialize(task,port,options = Hash.new,widget=nil,&block)
      @block = block
      @timer_id = nil
      @last_sample = nil    #save last sample so we can reuse the memory
      @callback_fct = nil

      if widget.is_a? Method
        @callback_fct = widget
        widget = widget.receiver
      end
      if widget.is_a?(Qt::Widget)
        super(widget,&nil)
      else
        super(nil,&nil)
      end
      @widget = widget

      @local_options, @policy = Kernel.filter_options(options,:update_frequency => OQConnection::update_frequency)
      @port = if port.is_a? String
                task = TaskProxy.new(task) if task.is_a? String
                task.port(port)
              else
                port
              end
      @reader = @port.reader @policy

      #we do not need a timer for replayed connections 
      if @local_options[:update_frequency] <= 0 && @port.is_a?(Orocos::Log::OutputPort)
        @port.org_connect_to nil, @policy do |sample,_|
          sample = @block.call(sample,@port.full_name) if @block
          @callback_fct.call sample,@port.full_name if @callback_fct && sample
          @last_sample = sample
        end
      end
    end

    #returns ture if the connection was established at some point 
    #otherwise false
    def broken?
        reader ? true : false 
    end

    def callback_fct
      return @callback_fct if @callback_fct
      if @widget && @port 
        #try to find callback_fct for port this is not working if no port is given
        if !@callback_fct && @widget.respond_to?(:loader)
          @type_name = @port.type_name if !@type_name
          @callback_fct = @widget.loader.callback_fct @widget.class_name,@type_name
        end

        #use default callback_fct
        @callback_fct ||= :update if @widget.respond_to?(:update)
        if @callback_fct && !@callback_fct.respond_to?(:call)
          @callback_fct = @widget.method(@callback_fct) 
        end
        raise "Widget #{@widget.objectName}(#{@widget.class_name}) has no callback function "if !@callback_fct
      else
        @callback_fct = nil
      end
    end

    def update_frequency
      @local_options[:update_frequency]
    end

    def update_frequency=(value)
      @local_options[:update_frequency]= value
      if @timer_id
        killTimer @timer_id
        @timer_id = startTimer(1000/value)
      end
    end

    def timerEvent(event)
      #call disconnect if widget is no longer visible
      #this could lead to some problems if the widget wants to
      #log the data 
      #
      if @widget && @widget.is_a?(Qt::Widget) && !@widget.visible
        disconnect
        return
      end

      @last_sample ||= @reader.new_sample if @port.task.reachable?
      while(@reader.read_new(@last_sample))
        if @block
          @block.call(@last_sample,@port.full_name)
        end
        callback_fct.call @last_sample,@port.full_name if callback_fct
      end
    rescue Exception => e
      puts "could not read on #{reader}: #{e.message}"
      disconnect
    end

    def disconnect()
      if @timer_id
        killTimer(@timer_id)
        @timer_id = nil
        # @reader.disconnect this leads to some problems with the timerEvent: reason unknown
        @widget.disconnected(@port.full_name) if @widget.respond_to?:disconnected
      end
    end

    def reconnect()
      @timer_id = startTimer(1000/@local_options[:update_frequency]) if !@timer_id
      if @port.task.readable?
        true
      else
        false
      end
    rescue Exception => e
      STDERR.puts "failed to reconnect: #{e.message}"
      false
    end

    #shadows the connect methods from base object
    #we should use an other name 
    def connect()
      reconnect if !connected?
    end

    def alive?
      return @timer_id && @reader.__valid?
    end

    alias :connected? :alive?
  end

  @connections = Array.new
  @default_loader = UiLoader.new
  @vizkit_local_options = {:widget => nil,:type_name => nil,:reuse => true,:parent =>nil,:widget_type => :display}

  #returns the instance of the vizkit 3d widget 
  def self.vizkit3d_widget
    @vizkit3d_widget ||= default_loader.create_widget("vizkit::Vizkit3DWidget")
    @vizkit3d_widget
  end
end
