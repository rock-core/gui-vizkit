
#Proxy task for hiding the real task 
#this is useful if the task context is needed before 
#the task was started or if the task was restarted
module Vizkit

    #Proxy for Orocos::InputPort Writer and OutputPort Reader which automatically handles reconnects
    class ReaderWriterProxy
        #the type of the port is determining if the object is a reader or writer
        #to automatically set up a orogen port proxy task set the hash value :port_proxy to the name of the port_proxy task
        #and :proxy_periodicity to the period in seconds which shall be used from the port_proxy to pull data from port
        #task = name of the task or its TaskContext
        #port = name of the port
        #options = connections policy {:port_proxy => nil, :proxy_periodicity => 0.2, (see Orocos::InputPort/OutputPort)}
        def initialize(task,port,options = Hash.new)
            @local_options, @policy = Kernel.filter_options options, :port_proxy => nil,:proxy_periodicity => 0.2

            @__port = port
            if(@__port.is_a?(String) || @__port.is_a?(Orocos::Port))
                @__port = TaskProxy.new(task).port(@__port)
            end

            @__orogen_port_proxy = @local_options[:port_proxy]
            if(@__orogen_port_proxy.is_a? String)
                @__orogen_port_proxy = TaskProxy.new(@__orogen_port_proxy)
            end
            @__orogen_port_proxy_out = nil

            @__reader_writer = __reader_writer
        end

        #returns true if the reader is still valid and the connection active
        def __valid?
            #validate reader
            if(@__reader_writer && 
               (!@__reader_writer.port.task.reachable? || (@__reader_writer.respond_to?(:__valid?) && !@__reader_writer.__valid?)))
                @__reader_writer = nil
                @__orogen_port_proxy_out = nil
                if @__port.is_a? OutputPortProxy
                    Vizkit.info "Port reader for #{@__port.full_name} is no longer valid."
                else
                    Vizkit.info "Port writer for #{@__port.full_name} is no longer valid."
                end
            end

            #validate if there is a oroocs task which is used as port proxy
            if(@__orogen_port_proxy && @__orogen_port_proxy_out && !@__orogen_port_proxy_out.task.reachable?)
                @__reader_writer = nil
                @__orogen_port_proxy_out = nil
                Vizkit.info "the task: #{@__orogen_port_proxy.name} which was used as port_proxy is no longer valid."
            end
            (@__reader_writer != nil)
        end

        #returns a valid reader which can be used for reading or nil if the Task cannot be contacted 
        def __reader_writer
            begin
                if !__valid?
                    #we want to use a port porxy between the reader and the orocos task 
                    #this prevents blocking on slow network connections
                    if @__orogen_port_proxy
                        if @__orogen_port_proxy.reachable? && port.task.reachable? 
                            full_name = @__port.task.name+"_"+@__port.name

                            #create new port on the proxy if there is none
                            if !@__orogen_port_proxy.has_port?("in_"+full_name)
                                #TODO load typekits 

                                @__orogen_port_proxy.createProxyConnection(full_name,@__port.type_name,@local_options[:proxy_periodicity])
                                Vizkit.info "Create port_proxy ports: in_#{full_name} and out_#{full_name}."
                            end

                            #connect the proxy to the orocos task
                            port = @__port.__port
                            port_proxy_port_in = @__orogen_port_proxy.port("in_"+full_name)
                            @__orogen_port_proxy_out = @__orogen_port_proxy.port("out_"+full_name)

                            port_in = port_proxy_port_in.__port
                            port_out = @__orogen_port_proxy_out.__port

                            if port && port_in && port_out
                                #check if the port is of the right type
                                if port.type_name != @__orogen_port_proxy_out.type_name
                                    raise "Port #{@__orogen_port_proxy_out.name} of task #{port.task.name} is of type #{@__port_proxy_port.type_name} but type #{port.type_name} was expected!"
                                end

                                if @__port.is_a? OutputPortProxy
                                    port.connect_to port_in ,:pull => true
                                    Vizkit.info "Connecting #{port.full_name} with #{port_proxy_port_in.full_name} "
                                    #get reader to the port 
                                    @__reader_writer = @__orogen_port_proxy_out.reader @policy
                                    Vizkit.info "Create reader for output port: #{@__port.full_name} which is shadowed by #{@__orogen_port_proxy_out.full_name}"
                                else
                                    #TODO policy for the connection between proxy and task
                                    port_out.connect_to port
                                    Vizkit.info "Connecting #{port_proxy_port_out.full_name} with #{port.full_name} "
                                    #get writer to the port 
                                    @__reader_writer = @port_proxy_port_in.writer @policy
                                    Vizkit.info "Create writer for input port #{@__port.full_name} which is shadowed by #{@port_proxy_port_in.full_name}"
                                end
                            else
                                Vizkit.warn "Failed to connect #{port.full_name} with #{port_proxy_port_in.full_name} "
                                @__reader_writer = nil
                            end
                        end
                    else
                            port = @__port.__port
                            if port
                                if @__port.is_a? OutputPortProxy
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
            @__port
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
        def initialize(task,port,options = Hash.new)
            temp_options, options = Kernel.filter_options options,:subfield => Array.new ,:type_name => nil
            super
            @local_options.merge! temp_options
            @local_options[:subfield] = @local_options[:subfield].to_a

            if (!@local_options[:subfield].empty?) ^ (@local_options[:type_name] != nil)
                raise "To use subfields the option hash :subfield and :type_name must be set"
            end
            if !@local_options[:subfield].empty?
                Vizkit.info "Create ReaderProxy for subfield #{@local_options[:subfield].join(".")} of port #{port.full_name}"
            else
                Vizkit.info "Create ReaderProxy for #{port.full_name}"
            end
        end

        def type_name
            port.type_name
        end

        def __subfield(sample,field=Array.new)
            return sample if(field.empty? || !sample)
            field.each do |f| 
                sample = sample[f]
            end
            #check if the type is right
            if(sample.respond_to?(:type_name) && sample.type_name != type_name )
                raise "Type miss match. Expected type #{type_name} but got #{sample.type_name} for subfield #{field.join(".")} of port #{port.full_name}"
            end
            sample
        end

        def read(sample = nil)
            __subfield(super,@local_options[:subfield])
        end

        def read_new(sample = nil)
            __subfield(super,@local_options[:subfield])
        end
    end

    class WriterProxy < ReaderWriterProxy
        def initialize(task,port,options = Hash.new)
            super
            Vizkit.info "Create WriterProxy for #{port.full_name}"
        end
    end

    #Proxy for an Orocos::Port which automatically handles reconnects
    class PortProxy
        #task = name of the task or its TaskContext
        #port = name of the port or its Orocos::Port
        def initialize(task, port)
            @__task = task
            if(@__task.is_a?(String) || task.is_a?(Orocos::TaskContext))
                @__task = TaskProxy.new(task_proxy)
            end

            if(port.is_a? String)
                @__port_name = port
                @__port = nil
            elsif(port.is_a? Orocos::Port)
                @__port_name = port.name
                @__port = port
            else
                raise "Cannot create PortProxy for #{port.class.name}"
            end
        end

        #we need this beacuse it can happen that we do not have a real port object 
        #the subfield is not considered because we do not want to use a separate 
        #port on the orogen port_proxy
        def full_name
            "#{task.name}.#{name}"
        end

        def name
            @__port_name
        end

        def task
            @__task
        end

        def __port
            begin 
                if @__task.reachable? && (!@__port || !@__port.task.reachable?)
                    if(@__task.has_port?(@__port_name))
                        task = @__task.__task
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
        #options = {:subfield => Array,:type_name => type_name of the subfield}
        #
        #if the PortProxy is used for a subfield reader the type_name of the subfield must be given
        #because otherwise the type_name would only be known after the first sample was received 
        def initialize(task, port,options = Hash.new)
            super(task,port)
            @local_options, options = Kernel::filter_options options,{:subfield => Array.new,:type_name => nil}
            @local_options[:subfield] = @local_options[:subfield].to_a

            if !@local_options[:subfield].empty?
                Vizkit.info "Create OutputPortProxy for subfield #{@local_options[:subfield].join(".")} of port #{port.full_name}"
            else
                Vizkit.info "Create OutputPortProxy for: #{port.full_name}"
            end
        end

        def reader(policy = Hash.new)
            ReaderProxy.new(@__task_proxy,self,@local_options.merge(policy))
        end

        def type_name
            if(type = @local_options[:type_name]) != nil
                type
            else
                super
            end
        end
    end

    class InputPortProxy < PortProxy
        def initialize(task, port)
            super
            Vizkit.info "Create InputPortProxy for: #{port.full_name}"
        end

        def writer(policy = Hash.new)
            WriterProxy.new(@__task_proxy,self,policy)
        end
    end

    #Proxy for a TaskContext which automatically handles reconnects 
    #It can also be used to automatically set up a orogen port proxy task which is a orocos Task normally running on the same machine
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

        def port(name,options = Hash.new)
            method_missing(name.to_sym)
        end

        def method_missing(m, *args, &block)
            if !ping
                return
            end
            begin
                if @__task.has_port?(m.to_s)
                    port = @__task.send(m, &block)
                    if port.is_a? Orocos::OutputPort
                        OutputPortProxy.new(self,port,*args)
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
