
#Proxy task for hiding the real task 
#this is useful if the task context is needed before 
#the task was started or if the task was restarted
module Vizkit
  class TaskProxy
    def initialize(task_name)
      @__task_name = task_name
      @__task = Vizkit.use_task? task_name
    end

    def ping
      if !@__task || !@__task.reachable?
        @__task =
          begin Orocos::TaskContext.get(@__task_name)
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
      end
    end

    alias :reachable? :ping
  end
end
