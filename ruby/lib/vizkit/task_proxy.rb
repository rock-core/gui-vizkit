
#Proxy task for hiding the real task 
#this is useful if the task context is needed before 
#the task was started or if the task was restarted
module Vizkit

    #the reader proxy is meant for graphical interfaces
    #if an update_frequency is given the reader will start a new 
    #thread to read from the port to not block the main thread
    class ReaderProxy
        def initialize(task_proxy,port_name,buffer_size=1,update_frequency=0)
            @task_proxy = task_proxy
            if(@task_proxy.is_a? String)
                @task_proxy = TaskProxy.new(task_proxy)
            end

            @__reader = nil
            @port_name = port_name
            @buffer_size = buffer_size
            @update_frequency = update_frequency

            @buffer = Array.new
            @thread = Thread.new{}

            @timer = Qt::Timer.new
            @timer.connect(SIGNAL('timeout()')) do 
                if @thread.alive?
                    if @thread.key? :sample
                        @buffer.shift if @buffer.size >= @buffer_size
                        @buffer.push @thread[:sample]
                    end
                    @thread = Thread.new(__reader()) do |reader|
                        begin
                            Thread.current[:sample] = reader.read if reader
                        rescue Orocos::NotFound
                            self
                        end
                    end
                end
            end
            @timer.start(1/@update_frequency) if update_frequency > 0
        end

        def __reader
            if @task_proxy.ping && !@__reader
                @__reader = @task_proxy.port(port_name).reader :pull => true, :type => :buffer,:size => @buffer_size
            end
            @__reader
        end

        def read
            if @update_frequency == 0
                if __reader
                    begin
                        __reader.read
                    rescue Orocos::NotFound
                        nil
                    end
                else
                    nil
                end
            else
                if !@buffer.empty?
                    @buffer.shift
                else
                    nil
                end
            end
        end
    end

    class TaskProxy
        attr_accessor :__task

        def initialize(task_name,&block)
            if task_name.is_a?(Orocos::TaskContext) || task_name.is_a?(Orocos::Log::TaskContext)
                @__task = task_name if task_name.is_a? Orocos::Log::TaskContext
                task_name = task_name.name
            end
            @__task_name = task_name
            @__task ||= Vizkit.use_task? task_name
            @__connection_code_block = block
            @__readers = Hash.new
        end

        #code block is called every time a new connection is set up
        def __on_connect(&block)
            @__connection_code_block = block
        end

        def name
            @__task_name
        end

        def __reconnect()
            @task = nil
            ping
        end

        def ping
            if !@__task || !@__task.reachable?
                begin 
                    @__readers.clear
                    @__task = Orocos::TaskContext.get(@__task_name)
                    @__connection_code_block.call if @__connection_code_block
                rescue Orocos::NotFound, Orocos::CORBAError
                    @__task = nil
                end
            end
            @__task != nil
        end

        def __reader_for_port(port_name,options=Hash.new)
            if ping && !@__readers[port_name]
                default_policy, policy = Kernel.filter_options options, :init => true
                policy.merge(default_policy)
                begin 
                    @__readers[port_name] = port(port_name).reader(default_policy)
                rescue Orocos::NotFound,Orocos::CORBAError
                end
            end
            @__readers[port_name]
        end

        def method_missing(m, *args, &block)
            if !ping
                return
            end

            begin
                @__task.send(m, *args, &block)
            rescue Orocos::NotFound,Orocos::CORBAError
                @__task = nil
            end
        end

        alias :reachable? :ping
        alias :__connect :ping
    end
end
