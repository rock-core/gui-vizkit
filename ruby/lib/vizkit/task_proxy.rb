
#Proxy task for hiding the real task 
#this is useful if the task context is needed before 
#the task was started or if the task was restarted
module Vizkit

    #Proxy for Orocos::InputPort Writer and OutputPort Reader which automatically handles reconnects
    class ReaderWriterProxy
        #the type of the port is determining if the object is a reader or writer
        #to automatically set up a port proxy task set the hash value :port_proxy to the name of the port_proxy task
        #and :proxy_periodicity to the period in seconds which shall be used from the port_proxy to pull data from port
        #task = name of the task or its TaskContext
        #port = name of the port
        #options = connections policy {:port_proxy => nil, :proxy_periodicity => 0.2,(see Orocos::InputPort/OutputPort)}
        def initialize(task,port,options = Hash.new)
            @local_options, @policy = Kernel.filter_options options, :port_proxy => nil,:proxy_periodicity => 0.2

            @task = task
            if(@task.is_a? String || @task.is_a?(Orocos::TaskContext))
                @task = TaskProxy.new(task)
            end

            @remote_port = port
            if(@remote_port.is_a?(String) || @remote_port.is_a?(Orocos::Port))
                @remote_port = @task.port(@remote_port)
            end

            @__task_port_proxy = @local_options[:port_proxy]
            if(@__task_port_proxy.is_a? String)
                @__task_port_proxy = TaskProxy.new(@__task_port_proxy)
            end
            @__task_port_proxy_port = nil

            if @remote_port.is_a? OutputPortProxy
                Vizkit.info "Create ReaderProxy for #{@remote_port.task.name}.#{port.name}"
            else
                Vizkit.info "Create WriterProxy for #{@remote_port.task.name}.#{port.name}"
            end
            @__reader_writer = __reader_writer
        end

        #returns true if the reader is still valid and the connection active
        def __valid?
            #validate reader
            if(@__reader_writer && 
               (!@__reader_writer.port.task.reachable? || (@__reader_writer.respond_to?(:__valid?) && !@__reader_writer.__valid?)))
                @__reader_writer = nil
                @__task_port_proxy_port = nil
                if @remote_port.is_a? OutputPortProxy
                    Vizkit.info "Port reader for #{@remote_port.full_name} is no longer valid."
                else
                    Vizkit.info "Port writer for #{@remote_port.full_name} is no longer valid."
                end
            end

            #validate if there is a oroocs task which is used as port proxy
            if(@__task_port_proxy && @__task_port_proxy_port && !@__task_port_proxy_port.task.reachable?)
                @__reader_writer = nil
                @__task_port_proxy_port = nil
                Vizkit.info "the task: #{@__task_port_proxy.name} which was used as port_proxy is no longer valid."
            end
            (@__reader_writer != nil)
        end

        #returns a valid reader which can be used for reading or nil if the Task cannot be contacted 
        def __reader_writer
            begin
                if !__valid?
                    #we want to use a port porxy between the reader and the orocos task 
                    #this prevents blocking on slow network connections
                    if @__task_port_proxy
                        if @__task_port_proxy.reachable? && @task.reachable? 
                            full_name = @remote_port.task.name+"_"+@remote_port.name

                            #create new port on the proxy if there is none
                            if !@__task_port_proxy.has_port?("in_"+full_name)
                                #TODO load typekits 

                                @__task_port_proxy.createProxyConnection(full_name,@remote_port.type_name,@local_options[:proxy_periodicity])
                                Vizkit.info "Create port_proxy ports: in_#{full_name} and out_#{full_name}."
                            end

                            #connect the proxy to the orocos task
                            port = @remote_port.__port
                            port_proxy_port_in = @__task_port_proxy.port("in_"+full_name)
                            @port_proxy_port_out = @__task_port_proxy.port("out_"+full_name)

                            port_in = port_proxy_port_in.__port
                            port_out = @port_proxy_port_out.__port

                            if port && port_in && port_out
                                #check if the port is of the right type
                                if port.type_name != @port_proxy_port_out.type_name
                                    raise "Port #{@port_proxy_port_out.name} of task #{@__task.name} is of type #{@__port_proxy_port.type_name} but type #{port.type_name} was expected!"
                                end

                                if @remote_port.is_a? OutputPortProxy
                                    port.connect_to port_in ,:pull => true
                                    Vizkit.info "Connecting #{port.full_name} with #{port_proxy_port_in.full_name} "
                                    #get reader to the port 
                                    @__reader_writer = @port_proxy_port_out.reader @policy
                                    Vizkit.info "Create reader for output port: #{@remote_port.full_name} which is shadowed by #{@port_proxy_port_out.full_name}"
                                else
                                    #TODO policy for the connection between proxy and task
                                    port_out.connect_to port
                                    Vizkit.info "Connecting #{port_proxy_port_out.full_name} with #{port.full_name} "
                                    #get writer to the port 
                                    @__reader_writer = @port_proxy_port_in.writer @policy
                                    Vizkit.info "Create writer for input port #{@remote_port.full_name} which is shadowed by #{@port_proxy_port_in.full_name}"
                                end
                            else
                                Vizkit.warn "Failed to connect #{port.full_name} with #{port_proxy_port_in.full_name} "
                                @__reader_writer = nil
                            end
                        end
                    else
                            port = @remote_port.__port
                            if port
                                if @remote_port.is_a? OutputPortProxy
                                    @__reader_writer = port.reader @policy
                                    Vizkit.info "Create reader for output port: #{port.full_name}"
                                else
                                    @__reader_writer = port.writer @policy
                                    Vizkit.info "Create writer for input port: #{port.full_name}"
                                end
                            else
                                @__reader_writer = nil
                            end
                    end
                end
            rescue Orocos::NotFound, Orocos::CORBAError
                @__reader_writer = nil
            end
            @__reader_writer
        end

        def port
            @remote_port
        end

        def method_missing(m, *args, &block)
            begin
                reader_writer = __reader_writer
                reader_writer.send(m, *args, &block) if reader_writer
            rescue Orocos::NotFound, Orocos::CORBAError
                @__reader_writer = nil
            end
        end
    end
    
    class ReaderProxy < ReaderWriterProxy
    end

    class WriterProxy < ReaderWriterProxy
    end

    #Proxy for an Orocos::Port which automatically handles reconnects
    class PortProxy
        #task = name of the task or its TaskContext
        #port = name of the port or its Orocos::Port
        def initialize(task, port)
            @__task_proxy = task
            if(@__task_proxy.is_a?(String) || task.is_a?(Orocos::TaskContext))
                @__task_proxy = TaskProxy.new(task_proxy)
            end

            if(port.is_a? String)
                @__port_name = port
                @__port = nil
            elsif(port.is_a? Orocos::Port)
                @__port_name = port.name
                @__port = port
            else
                raise "Cannot create PortProxy for #{port.class.nane}"
            end
            Vizkit.info "Create PortProxy for: #{@__port.name}"
        end

        #we need this beacuse it can happen that we do not have a real port object 
        def full_name
            "#{task.name}.#{name}"
        end

        def name 
            @__port_name
        end

        def task
            @__task_proxy
        end

        def __port
            begin 
                if @__task_proxy.reachable? && (!@__port || !@__port.task.reachable?)
                    if(@__task_proxy.has_port?(@__port_name))
                        task = @__task_proxy.__task
                        @__port = task.port(@__port_name) if task
                        Vizkit.info "Create Port for: #{@__port.full_name}"
                    else
                        Vizkit.warn "Task #{task.name} has no port #{@__port_name}. This can happen for tasks with dynamic ports."
                        @__port = nil
                    end
                end
            rescue Orocos::NotFound, Orocos::CORBAError
                @__port = nil
            end
            @__port
        end

        def method_missing(m, *args, &block)
            begin 
                @__port.send(m, *args, &block) if __port
            rescue Orocos::NotFound, Orocos::CORBAError
                @__port = nil
            end
        end
    end

    class OutputPortProxy < PortProxy
        def reader(policy = Hash.new)
            ReaderProxy.new(@__task_proxy,self,policy)
        end
    end

    class InputPortProxy < PortProxy
        def writer(policy = Hash.new)
            WriterProxy.new(@__task_proxy,self,policy)
        end
    end

    #Proxy for a TaskContext which automatically handles reconnects 
    #It can also be used to automatically set up a port proxy which is a orocos Task normally running on the same machine
    #and pulls the data from the robot to not block the graphically interfaces.
    class TaskProxy
        attr_accessor :__task

        #Creates a new TaskProxy for an Orogen Task
        #automatically uses the tasks from the corba name service or the log file when added to Vizkit (see Vizkit.use_task)
        #task_name = name of the task or its TaskContext
        #code block  = is called every time a TaskContext is created (every connect or reconnect)
        def initialize(task_name,&block)
            raise "Using a TaskProxy for a TaskProxy is reagarded as programmer error!" if task_name.is_a? TaskProxy

            if task_name.is_a?(Orocos::TaskContext) || task_name.is_a?(Orocos::Log::TaskContext)
                @__task = task_name if task_name.is_a? Orocos::Log::TaskContext
                task_name = task_name.name
            end
            @__task_name = task_name
            @__task ||= Vizkit.use_task? task_name
            @__connection_code_block = block
            @__readers = Hash.new

            Vizkit.info "Create TaskProxy for task: #{name}"
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
                    Vizkit.info "Create TaskContext for: #{name}"
                rescue Orocos::NotFound, Orocos::CORBAError
                    @__task = nil
                end
            end
            @__task != nil
        end

        def __global_reader_for_port(port_name,options=Hash.new)
            if @__readers.has_key?(port_name)
                @__readers[port_name]
            else
                @__readers[port_name] = port(port_name).reader(options)
            end
        end

        def port(name)
            method_missing(name.to_sym)
        end

        def method_missing(m, *args, &block)
            if !ping
                return
            end
            begin
                if @__task.has_port?(m.to_s)
                    port = @__task.send(m, *args, &block)
                    if port.is_a? Orocos::OutputPort
                        OutputPortProxy.new(self,port)
                    else
                        InputPortProxy.new(self,port)
                    end
                else
                    @__task.send(m, *args, &block)
                end
            rescue Orocos::NotFound,Orocos::CORBAError
                @__task = nil
            end
        end

        alias :reachable? :ping
        alias :__connect :ping
    end
end
