
#Proxy task for hiding the real task 
#this is useful if the task context is needed before 
#the task was started or if the task was restarted
module Vizkit
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
                rescue Orocos::NotFound
                    @__task = nil
                end
            end
            @__task != nil
        end

        def __reader_for_port(port_name,options=Hash.new)
            if ping && !@__readers[port_name]
                @__readers[port_name] = port(port_name).reader options
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
