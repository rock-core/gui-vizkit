require 'utilrb/logger'

module Vizkit
  extend Logger::Root('Vizkit', Logger::WARN)

  class UiLoader
    define_widget_for_methods("type",String) do |type|
      type
    end

    define_widget_for_methods("port_type",Orocos::OutputPort,Orocos::Log::OutputPort) do |port|
      port.type_name
    end
    define_widget_for_methods("task",Orocos::TaskContext,Orocos::Log::TaskContext) do |task|
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
  Qt::Application.new(ARGV)
  @@auto_reconnect = 2000       #timer interval after ports are reconnected if they are no longer alive
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
      if value.is_a? Orocos::OutputPort or value.is_a? Orocos::Log::OutputPort
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

  def self.widget_for_options(value,options=Hash.new,&block)
    #if value is a array
    if value.is_a? Array
      result = Array.new
      value.each do |val|
        result << widget_for_options(val, options, &block)
      end
      return result
    end
    local_options,options = Kernel::filter_options(options,@vizkit_local_options)
    widget = @default_loader.widget_for_options(value,local_options)
    setup_widget(widget,value,options,local_options[:type],&block)
  end

  def self.control value, options=Hash.new,&block
    options[:widget_type] = :control
    widget = widget_for_options(value,options,&block)
    if(!widget)
      puts "No widget found for controlling #{value}!"
      return nil
    end
    widget
  end

  def self.display value,options=Hash.new,&block
    options[:widget_type] = :display
    widget = widget_for_options(value,options,&block)
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
       auto_reconnect()   #auto reconnect all ports which have set the auto_reconnect flag to true 
     end
     gc_timer.start(@@auto_reconnect)
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

  #reconnects all connection which have
  #set the flag auto_reconnect to true 
  def self.auto_reconnect()
    @connections.each do |connection|
      if connection.auto_reconnect && (!connection.widget.is_a?(Qt::Widget) || connection.widget.visible) && !connection.alive?
        Vizkit.warn "lost connection to #{connection.port_full_name}. Trying to reconnect." if connection.broken?
        connection.reconnect    
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
      #add default option
      options[:auto_reconnect] = true unless options.has_key? :auto_reconnect
      connection = OQConnection.new([task_name, port_name], options, widget, &block)
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

  #returns the task which shall be used by auto_connect 
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
      attr_accessor :auto_reconnect
    end
    OQConnection::update_frequency = 8
    OQConnection::auto_reconnect = false

    attr_accessor :auto_reconnect
    attr_reader :update_frequency
    attr_reader :port
    attr_reader :widget
    attr_reader :reader

    def initialize(port,options = Hash.new,widget=nil,&block)
      if widget.is_a? Method
        @callback_fct = widget
        widget = widget.receiver
      end
      if widget.is_a?(Qt::Widget)
        super(widget,&nil)
      else
        super(nil,&nil)
      end

      #TODO implement an OutputPort proxy which can handle subfields 
      this_options, @policy = Kernel.filter_options(options,[:update_frequency,:auto_reconnect,:subfield,:type_name])
      default_init, @policy = Kernel.filter_options(@policy, :init => true)
      @policy.merge!(default_init)
      if port.respond_to?(:to_ary)
        @task_name, @port_name = *port
        @port = nil
      else
        @task_name = port.task.name
        @port_name = port.name
        @port = port
      end
      @widget = widget
      @subfield = this_options[:subfield]
      @update_frequency = this_options[:update_frequency] 
      @auto_reconnect = this_options[:auto_reconnect]
      @type_name = this_options[:type_name]
      @update_frequency ||= OQConnection::update_frequency
      @auto_reconnect ||= OQConnection::auto_reconnect
      @block = block
      @reader = nil
      @timer_id = nil
      @last_sample = nil    #save last sample so we can reuse the memory
      @sample_class = nil

      discover_callback_fct
      self
    end

    attr_reader :task_name
    attr_reader :port_name
    def port_full_name
      if @subfield && !@subfield.empty?
        "#{@task_name}.#{@port_name}.#{@subfield.join(".")}"
      else
        "#{@task_name}.#{@port_name}"

      end
    end

    #returns ture if the connection was established at some point 
    #otherwise false
    def broken?
        reader ? true : false 
    end

    #returns ture if the connection was established at some point 
    #otherwise false
    def broken?
        reader ? true : false 
    end

    def discover_callback_fct
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

    def update_frequency=(value)
      @update_frequency = value 
      if @timer_id
        killTimer @timer_id
        @timer_id = startTimer(1000/@update_frequency)
      end
    end

    #TODO implement an OutputPort proxy which can handle subfields 
    def subfield(sample,field=Array.new)
        return sample if !field
        field.each do |f| 
            sample = sample[f]
        end
        sample
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

      while(@reader.read_new(@last_sample))
        sample = subfield(@last_sample,@subfield)
        if @block
          @block.call(sample,port_full_name)
        end
        @callback_fct.call sample,port_full_name if @callback_fct
      end
    rescue Exception => e
      Vizkit.warn "could not read on #{reader}"
      log_exception(e)
      disconnect
    end

    def log_exception(e)
      Vizkit.warn "#{e.message} (#{e.class})"
      Vizkit.log_nest(2) do
          e.backtrace.each do |line|
              Vizkit.warn line
          end
      end
    end


    def disconnect()
      if @timer_id
        killTimer(@timer_id)
        @timer_id = nil
        # @reader.disconnect this leads to some problems with the timerEvent: reason unknown
        @widget.disconnected(port_full_name) if @widget.respond_to?:disconnected
      end
    end

    def reconnect()
      if Orocos::TaskContext.reachable?(@task_name)
        port = Orocos::TaskContext.get(@task_name).port(@port_name)
        @port = port if port
        discover_callback_fct
        @reader = @port.reader @policy
        if @reader
          @last_sample = @reader.new_sample
          @sample_class = @last_sample.class
          @timer_id = startTimer(1000/@update_frequency) if !@timer_id
          return true
        end
      end
      false
    rescue Exception => e
      Vizkit.warn "failed to reconnect"
      log_exception(e)
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
    def initialize(port,options = Hash.new,widget=nil,&block)
      super 
      # do not use a timer if frequency < 0
      if @update_frequency < 0
        @port.org_connect_to nil, @policy do |sample,_|
          sample = @block.call(sample,port_full_name) if @block
          @callback_fct.call sample,port_full_name if @callback_fct && sample
          @last_sample = sample
        end
      end
    end

    def reconnect()
      return true if @update_frequency < 0

      @reader =@port.reader @policy
      if @reader
        @timer_id = startTimer(1000/@update_frequency) if !@timer_id
        return true
      end
      false
    end

    def timerEvent(event)
      disconnect if @widget && @widget.is_a?(Qt::Widget) && !@widget.visible
      while(sample = reader.read_new)
        @last_sample = sample
        sample = subfield(sample,@subfield)
        @block.call(sample,port_full_name) if @block
        begin
          @callback_fct.call sample,port_full_name if @callback_fct && sample
        rescue Exception => e
          Vizkit.warn "failed to call callback function #{@callback_fct}"
          log_exception(e)
        end
      end
    end

    def disconnect()
      if @timer_id
        killTimer(@timer_id)
        @widget.disconnected(port_full_name) if @widget.respond_to?:disconnected
        @timer_id = nil
      end
    end

    def alive?
      return (nil != @timer_id || @update_frequency < 0)
    end

    alias :connected? :alive?
  end

  @connections = Array.new
  @default_loader = UiLoader.new
  @vizkit_local_options = {:widget => nil,:type_name => nil,:reuse => true,:parent =>nil,:widget_type => :display}

  class << self
    # When using Vizkit3D widgets, this is a [task_name, port_name] pair of a
    # data source that should be used to gather transformation configuration.
    # This configuration is supposed to be stored in a
    # /transformer/ConfigurationState data structure.
    #
    # A port can also be set directly in
    # Vizkit.vizkit3d_transformer_configuration
    attr_accessor :vizkit3d_transformer_broadcaster_name
  end
  @vizkit3d_transformer_broadcaster_name = ['transformer_broadcaster', 'configuration_state']

  #returns the instance of the vizkit 3d widget 
  def self.vizkit3d_widget
    @vizkit3d_widget ||= default_loader.create_widget("vizkit::Vizkit3DWidget")
    @vizkit3d_widget
  end
end


