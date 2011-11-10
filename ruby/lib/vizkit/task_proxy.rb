
#Proxy task for hiding the real task 
#this is useful if the task context is needed before 
#the task was started or if the task was restarted
module Vizkit
    class TaskProxy
        def initialize(task_name,&block)
            @__task_name = task_name
            @__task = Vizkit.use_task? task_name
            @__connection_code_block = block
        end

        #code block is called every time a new connection is set up
        def __on_connect(&block)
            @__connection_code_block = block
        end

        def __reconnect()
            @task = nil
            ping
        end

        def ping
            if !@__task || !@__task.reachable?
                begin 
                    @__task = Orocos::TaskContext.get(@__task_name)
                    @__connection_code_block.call if @__connection_code_block
                rescue Orocos::NotFound
                    @__task = nil
                end
            end
            @__task != nil
        end

        def method_missing(m, *args, &block)
            if !ping
                return
            end

            begin
                @__task.send(m, *args, &block)
            rescue Orocos::NotFound
                @__task = nil
            end
        end

        alias :reachable? :ping
        alias :__connect :ping
    end
end
