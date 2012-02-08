
#Proxy task for hiding the real task 
#this is useful if the task context is needed before 
#the task was started or if the task was restarted
module Vizkit
    #Proxy for Orocos::InputPort Writer and OutputPort Reader which automatically handles reconnects
    class ReaderWriterProxy
        def self.default_policy=(policy=Hash.new)
            @@default_policy=policy
        end
        def self.default_policy
            @@default_policy
        end
        ReaderWriterProxy::default_policy = {:init => true}

        #the type of the port is determining if the object is a reader or writer
        #to automatically set up a orogen port proxy task set the hash value :port_proxy to the name of the port_proxy task
        #and :proxy_periodicity to the period in seconds which shall be used from the port_proxy to pull data from port
        #task = name of the task or its TaskContext
        #port = name of the port
        #options = connections policy {:port_proxy => nil, :proxy_periodicity => 0.2, (see Orocos::InputPort/OutputPort)}
        def initialize(task,port,options = Hash.new)
            options = ReaderWriterProxy.default_policy.merge options
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
            __reader_writer
        end

        #returns true if the reader is still valid and the connection active
        def __valid?
            if @__port.is_a?(Orocos::Log::OutputPort) || @__port.__port.is_a?(Orocos::Log::OutputPort)
                return @__reader_writer != nil
            end

            #validate reader
            if(@__reader_writer && 
               (!@__reader_writer.port.task.reachable? || (@__reader_writer.respond_to?(:__valid?) && !@__reader_writer.__valid?)))
                if @__reader_writer.is_a? Orocos::OutputReader
                    Vizkit.info "Port reader for #{@__port.full_name} is no longer valid."
                else
                    Vizkit.info "Port writer for #{@__port.full_name} is no longer valid."
                end
                @__reader_writer = nil
                @__orogen_port_proxy_out = nil
            end

            #validate if there is a orocos task which is used as port proxy
            if(@__orogen_port_proxy && @__orogen_port_proxy_out && !@__orogen_port_proxy_out.task.reachable?)
                @__reader_writer = nil
                @__orogen_port_proxy_out = nil
                Vizkit.info "the task: #{@__orogen_port_proxy.name} which was used as port_proxy is no longer valid."
            end
            (@__reader_writer != nil)
        end

        #returns a valid reader which can be used for reading or nil if the Task cannot be contacted 
        def __reader_writer
            return @__reader_writer if __valid?
            return nil if !type_name

            if @__port.is_a?(Orocos::Log::OutputPort) || @__port.__port.is_a?(Orocos::Log::OutputPort)
                @__reader_writer = @__port.reader @policy
                return @__reader_writer
            end

            if !@__orogen_port_proxy
                #we do not want to use a port porxy between the reader and the orocos task 
                #which is preventing blocking on slow network connections
                port = @__port.__port
                if port
                    if port.is_a? Orocos::OutputPort
                        @__reader_writer = port.reader @policy
                        Vizkit.info "Create reader for output port: #{port.full_name}"
                    else
                        @__reader_writer = port.writer @policy
                        Vizkit.info "Create writer for input port: #{port.full_name}"
                    end
                else
                    @__reader_writer = nil
                end
                return @__reader_writer
            end

            #we want to use a port porxy between the reader and the orocos task 
            #which is preventing blocking on slow network connections
            #TODO this could be moved to the proxy_task TaskContext
            if !@__orogen_port_proxy.reachable? || !@__port.task.reachable? 
                Vizkit.info "Orogen PortProxy #{@__orogen_port_proxy.name} is not reachable"
                #tasks are not reachable at the moment
                @__reader_writer = nil
                return @__reader_writer
            end 

            full_name = @__port.task.name+"_"+@__port.name

            #create new port on the proxy and load the typkit if there is none
            if !@__orogen_port_proxy.has_port?("in_"+full_name)
                typekit = Orocos::find_typekit_for(@__port.type_name)
                if !typekit
                    Vizkit.warn "Cannot find typekit for #{@__port.type_name}"
                    return nil
                end
                begin 
                    typekit = Orocos::find_typekit_full_path(typekit)
                rescue Exception => e
                    Vizkit.warn "ReaderWriterProxy: #{e}"
                    return nil
                end
                Vizkit.info "ReaderWriterProxy: Ask the orogen port_proxy task #{@__orogen_port_proxy.name} to load the typekit #{typekit}"
                if !@__orogen_port_proxy.loadTypekit(typekit)
                    Vizkit.warn "PortProxy reported that the typekit #{typkit} cannot be loaded! Is the port_proxy running on another machine?"
                    return nil
                end
                if !@__orogen_port_proxy.createProxyConnection(full_name,@__port.type_name,@local_options[:proxy_periodicity])
                    raise "PortProxy could not generate dynmic ports for #{full_name}"
                end
                Vizkit.info "Create port_proxy ports: in_#{full_name} and out_#{full_name}."
            end

            #connect the proxy to the orocos task
            port = @__port.__port

            port_proxy_port_in = @__orogen_port_proxy.port("in_"+full_name)
            @__orogen_port_proxy_out = @__orogen_port_proxy.port("out_"+full_name)

            port_in = port_proxy_port_in.__port
            port_out = @__orogen_port_proxy_out.__port

            if !port || !port_in || !port_out
                Vizkit.warn "Failed to connect #{port.full_name} with #{port_proxy_port_in.full_name} "
                @__reader_writer = nil
                return @__reader_writer
            end

            #check if the port is of the right type
            if port.type_name != @__orogen_port_proxy_out.type_name
                raise "Port #{@__orogen_port_proxy_out.name} of task #{port.task.name} is of type #{@__port_proxy_port.type_name} but type #{port.type_name} was expected!"
            end

            #delete proxy policy otherwise we get an infinit loop
            policy =@policy.dup
            policy[:port_proxy] = nil
            if port.is_a? Orocos::OutputPort
                port.connect_to port_in ,:pull => true
                Vizkit.info "Connecting #{port.full_name} with #{port_proxy_port_in.full_name} "
                #get reader to the port 
                @__reader_writer = @__orogen_port_proxy_out.reader policy
                Vizkit.info "Create reader for output port: #{@__port.full_name} which is shadowed by #{@__orogen_port_proxy_out.full_name}"
            else
                #TODO policy for the connection between proxy and task
                port_out.connect_to port
                Vizkit.info "Connecting #{port_out.full_name} with #{port.full_name} "
                #get writer to the port 
                @__reader_writer = port_proxy_port_in.writer policy
                Vizkit.info "Create writer for input port #{@__port.full_name} which is shadowed by #{port_proxy_port_in.full_name}"
            end
            @__reader_writer
        rescue Orocos::NotFound, Orocos::CORBAError => e
            Vizkit.Warn "ReaderWriterProxy: Got an error #{e}"
            @__reader_writer = nil
        end

        def port
            @__port
        end

        def type_name
            @__port.type_name
        end

        def method_missing(m, *args, &block)
            reader_writer = __reader_writer
            if reader_writer
                reader_writer.send(m, *args, &block)
            elsif Orocos::OutputReader.public_instance_methods.include?(m.to_s) || Orocos::InputWriter.public_instance_methods.include?(m.to_s)
                Vizkit.warn "ReaderWriterProxy for port #{port.full_name}: ignoring method #{m} because port is not reachable."
                @__reader_writer = nil
            else
                super(m,*args,&block)
            end
        rescue Orocos::NotFound, Orocos::CORBAError
            @__reader_writer = nil
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
        #options = {:subfield => Array,:type_name => type_name of the subfield}
        #
        #if the PortProxy is used for a subfield reader the type_name of the subfield must be given
        #because otherwise the type_name would only be known after the first sample was received 
        def initialize(task, port,options = Hash.new)
            @local_options, options = Kernel::filter_options options,{:subfield => Array.new,:type_name => nil}
            @local_options[:subfield] = @local_options[:subfield].to_a

            @__task = task
            if(@__task.is_a?(String) || @__task.is_a?(Orocos::TaskContext))
                @__task = TaskProxy.new(task)
            end
            raise "Cannot create PortProxy if no task is given" if !@__task

            if(port.is_a? String)
                @__port_name = port
                @__port = nil
            elsif(port.is_a? Orocos::Port)
                @__port_name = port.name
                @__port = port
            else
                raise "Cannot create PortProxy for #{port.class.name}"
            end

            if !@local_options[:subfield].empty?
                Vizkit.info "Create PortProxy for subfield #{@local_options[:subfield].join(".")} of port #{full_name}"
            else
                Vizkit.info "Create PortProxy for: #{full_name}"
            end
            __port
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

        def type_name
            if(type = @local_options[:type_name]) != nil
                type
            elsif @__port || __port
                @__port.type_name
            elsif
                nil
            end
        end

        def task
            @__task
        end

        def __port
            if @__task.reachable? && (!@__port || !@__port.task.reachable?)
                if(@__task.has_port?(@__port_name))
                    task = @__task.__task
                    @__port = task.port(@__port_name) if task
                    Vizkit.info "Create Port for: #{@__port.full_name}"
                else
                    Vizkit.warn "Task #{task().name} has no port #{name}. This can happen for tasks with dynamic ports."
                    @__port = nil
                end
            end
            @__port
        rescue Orocos::NotFound, Orocos::CORBAError
            @__port = nil
        end

        def writer(policy = Hash.new)
            WriterProxy.new(@__task_proxy,self,policy)
        end

        def reader(policy = Hash.new)
            if __port.is_a? Orocos::Log::OutputPort
                return @__port.reader policy
            end
            ReaderProxy.new(@__task_proxy,self,@local_options.merge(policy))
        end

        def method_missing(m, *args, &block)
            if __port
                @__port.send(m, *args, &block)
            elsif Orocos::OutputPort.public_instance_methods.include?(m.to_s) || Orocos::InputPort.public_instance_methods.include?(m.to_s)
                Vizkit.warn "PortProxy #{full_name}: ignoring method #{m} because port is not reachable."
                @__port = nil
            else
                super
            end
        rescue Orocos::NotFound, Orocos::CORBAError => e
            Vizkit.warn "PortProxy #{full_name} got an Error: #{e}"
            @__port = nil
        end
    end

    #Proxy for a TaskContext which automatically handles reconnects 
    #It can also be used to automatically set up a orogen port proxy task which is a orocos Task normally running on the same machine
    #and pulls the data from the robot to not block the graphically interfaces.
    class TaskProxy
        #Creates a new TaskProxy for an Orogen Task
        #automatically uses the tasks from the corba name service or the log file when added to Vizkit (see Vizkit.use_task)
        #task_name = name of the task or its TaskContext
        #code block  = is called every time a TaskContext is created (every connect or reconnect)
        def initialize(task_name,&block)
            task_name if task_name.is_a? TaskProxy #just return the same TaskProxy if task_name is already one 

            if task_name.is_a?(Orocos::TaskContext) || task_name.is_a?(Orocos::Log::TaskContext)
                @__task = task_name if task_name.is_a? Orocos::Log::TaskContext
                task_name = task_name.name
            end
            @__task_name = task_name
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

        def __task
            ping
           @__task
        end

        def ping
            if !@__task || !@__task.reachable?
                begin 
                    @__readers.clear
                    @__task = if Vizkit.use_log_task? name
                                  Vizkit.info "TaskProxy #{name } is using an Orocos::Log::TaskContext as underlying task"
                                  Vizkit.log_task name
                              else
                                  task = Orocos::TaskContext.get(name)
                                  Vizkit.info "Create TaskContext for: #{name}"
                                  task
                              end
                    @__connection_code_block.call if @__connection_code_block
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
            if @__task.is_a? Orocos::Log::TaskContext
                @__task.port(name)
            else
                PortProxy.new(self,name,options)
            end
        end

        def method_missing(m, *args, &block)
            if !ping
                if Orocos::TaskContext.public_instance_methods.include?(m.to_s)
                    Vizkit.warn "TaskProxy #{name}: ignoring method #{m} because task is not reachable."
                    @__task = nil
                else
                    super
                end
            else
                if @__task && @__task.has_port?(m.to_s)
                    port(m.to_s,*args)
                else
                    @__task.send(m, *args, &block)
                end
            end
        rescue Orocos::NotFound,Orocos::CORBAError
            @__task = nil
        end

        alias :reachable? :ping
        alias :__connect :ping
    end
end
