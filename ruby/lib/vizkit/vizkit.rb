#!/usr/bin/env ruby

module Vizkit
  class UiLoader
    define_widget_for_methods("type",String) do |type|
      type
    end
    define_widget_for_methods("port_type",Orocos::OutputPort,Orocos::Log::OutputPort) do |port|
      port.type_name
    end
  end
end

module Vizkit
  Qt::Application.new(ARGV)
  def self.app
    $qApp
  end

  def self.default_loader
    @default_loader
  end

  def self.control value, options=Hash.new,&block
    widget = nil
    case value
    when Orocos::Log::Replay
      widget = @default_loader.log_control
    when Orocos::TaskContext
      @task_inspector ||= @default_loader.task_inspector
      widget = @task_inspector
    else
        raise "Cannot handle #{value.class}"
    end
    widget.control value, options
    widget.show
    widget
  end

  def self.display value,options=Hash.new,&block
    case value
    when Orocos::OutputPort, Orocos::Log::OutputPort
      widget = @default_loader.widget_for(value)
      if widget 
        widget.setAttribute(Qt::WA_QuitOnClose, false)
      else
        @struct_viewer ||= @default_loader.struct_viewer
        Vizkit.connect(@struct_viewer) unless @struct_viewer.visible
        widget = @struct_viewer
      end
      value.connect_to widget,options ,&block
      widget.show
      return widget
    else
        raise "Cannot handle #{value.class}"
    end
  end

  def self.connections
    @connections
  end

  def self.exec
      $qApp.exec
  end
  def self.process_events()
      $qApp.processEvents
  end
  
  def self.load(ui_file,parent = nil)
    @default_loader.load(ui_file,parent)
  end

  def self.disconnect_from(handle)
    case port
      when Qt::Widget:
          @connections.delete_if do |connection|
            if widget.findChild(Qt::Widget,connection.widget.objectName)
              connection.disconnect
              return true
            end
            false
          end
      when Orocos::OutputPort:
          @connections.delete_if do |connection|
            if connection.port == port
               connection.disconnect
               return true
            end
            false
          end
      else
        raise "Cannot handle #{port.class}"
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
    @connections.each do |connection|
      if widget.findChild(Qt::Widget,connection.widget.objectName)
        connection.reconnect
      end
    end
  end

 #connects all connection to the widget and its children
 #if the connection is not responding
  def self.connect(widget)
    @connections.each do |connection|
      if connection.widget && widget.findChild(Qt::Widget,connection.widget.objectName.to_s)
        connection.connect
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

  class OQConnection < Qt::Object
    #default values
    class << self
      attr_accessor :update_frequency
      attr_accessor :auto_reconnect
    end
    @@update_frequency = 20
    @@auto_reconnect = false

    attr_accessor :auto_reconnect
    attr_reader :update_frequency
    attr_reader :port
    attr_reader :widget
    attr_reader :reader

    def initialize(port,options,widget=nil,&block)
      super(widget,&nil)

      this_options, @policy = Kernel.filter_options(options,[:update_frequency,:auto_reconnect])
      @port = port
      @widget = widget
      @update_frequency = this_options[:update_frequency] 
      @auto_reconnect = this_options[:auto_reconnect]
      @update_frequency ||= @@update_frequency
      @auto_reconnect ||= @@auto_reconnect
      @block = block
      @reader = nil
      @timer_id = nil

      #get call_back_fct
      if widget 
        if widget.respond_to?(:loader)
          @call_back_fct = widget.loader.call_back_fct widget.class_name,port.type_name
        end
      
        @call_back_fct ||= :update if widget.respond_to?(:update)
        @call_back_fct = widget.method(@call_back_fct) if @call_back_fct
        raise "Widget #{widget.objectName}(#{widget.class_name}) has no call back function "if !@call_back_fct
      else
        @call_back_fct = nil
      end

      connect
      self
    end

    def update_frequency=(value)
      @update_frequency = value 
      if @timer_id
        killTimer @timer_id
        @timer_id = startTimer(1000/@update_frequency)
      end
    end

    def timerEvent(event)
      #call disconnect if widget is no longer visible
      #this could lead to some problems if the widget wants to
      #log the data 
      disconnect if @widget && !@widget.visible
      reconnect(true) if auto_reconnect && !alive?
      while(data = reader.read_new)
        data = @block.call(data,@port.full_name) if @block
        @call_back_fct.call data,@port.full_name if @call_back_fct && data
      end
    end

    def disconnect()
      if @timer_id
        killTimer(@timer_id)
        @reader.disconnect
        @widget.disconnected(@port.full_name) if @widget.respond_to?:disconnected
        @timer_id = nil
      end
    end

    def reconnect()
      disconnect
      if Orocos::TaskContext.reachable?(@port.task.name)
         port = Orocos::TaskContext.get(@port.task.name).port(@port.name)
         @port = port if port
         @reader = @port.reader @policy
         if @reader
            @timer_id = startTimer(1000/@update_frequency) if !@timer_id
            return true
         end
      end
      false
    end

    #shadows the connect methods from base object
    #we should use an other name 
    def connect()
      reconnect if !connected?
    end

    def alive?
      return @timer_id && @port.task.reachable?
    end

    alias :connected? :alive?
  end

  class OQLogConnection < OQConnection
    def reconnect()
      @reader =@port.reader @policy
      if @reader
         @timer_id = startTimer(1000/@update_frequency) if !@timer_id
         return true
      end
      false
    end

    def disconnect()
      if @timer_id
        killTimer(@timer_id)
        @widget.disconnected(@port.full_name) if @widget.respond_to?:disconnected
        @timer_id = nil
      end
    end
    
    def alive?
      return (nil != @timer_id)
    end

    alias :connected? :alive?
  end

  @connections = Array.new
  @default_loader = UiLoader.new
end


