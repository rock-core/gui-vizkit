#TODO
# - ping and reachable? should have the same behavior like the methods from TaskContext
# - new_sample for log files is not working like the one from Orocos::Port

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
        # Default policy is configured in vizkit.rb

        #the type of the port is determining if the object is a reader or writer
        #to automatically set up a orogen port proxy task set the hash value :port_proxy to the name of the port_proxy task
        #and :proxy_periodicity to the period in seconds which shall be used from the port_proxy to pull data from port
        #task = name of the task or its TaskContext
        #port = name of the port
        #options = connections policy {:port_proxy => nil, :proxy_periodicity => 0.2, (see Orocos::InputPort/OutputPort)}
        def initialize(task,port,options = Hash.new)
            options = ReaderWriterProxy.default_policy.merge options
            @local_options, @policy = Kernel.filter_options options, :port_proxy => nil,:port_proxy_periodicity => 0.2

            @__port = port
            if(@__port.is_a?(String) || @__port.is_a?(Orocos::Port))
                @__port = TaskProxy.new(task).port(@__port)
            end

            @__orogen_port_proxy = @local_options[:port_proxy]
            if(@__orogen_port_proxy.is_a? String)
                @__orogen_port_proxy = TaskProxy.new(@__orogen_port_proxy)
            end
        
            if @__orogen_port_proxy && @__orogen_port_proxy.name == @__port.task.name
                Vizkit.warn "ReaderWriterProxy: Orogen Port_Proxy #{@__orogen_port_proxy.name} would connect to its self. Therefore disabling PortProxy for port #{@__port.full_name}."
                @__orogen_port_proxy = nil
            end

            __reader_writer(false)
        end

        #returns true if the reader is still valid and the connection active
        #it does not reconnect if it is broken 
        def __valid?
            return false if !@__reader_writer

            if !@__reader_writer.port.task.reachable?
               if @__reader_writer.is_a? Orocos::OutputReader
                   Vizkit.info "Port reader for #{@__port.full_name} is no longer valid."
               else
                   Vizkit.info "Port writer for #{@__port.full_name} is no longer valid."
               end
               disconnect
               @__reader_writer = nil
               return false
            end

            #validate if there is a orocos task which is used as port proxy
            if(@__orogen_port_proxy && !@__orogen_port_proxy.proxy_port?(@__port))
                Vizkit.info "Task: #{@__orogen_port_proxy.name} is no longer proxing port #{port}."
                @__reader_writer = nil
                return false
            end
            return true
        end

        def disconnect
            return if !@__port
            if @__orogen_port_proxy && !@__port
                Vizkit.info "Calling disconnect_proxy_port for #{@__port.full_name}."
                @__orogen_port_proxy.delete_proxy_port(@__port)
            end
            @__reader_writer.disconnect if @__reader_writer
        end

        #returns a valid reader which can be used for reading or nil if the Task cannot be contacted 
        def __reader_writer(disable_proxy_on_error=true)
            return @__reader_writer if __valid?
            return nil if !type_name

            if  !@__port.task.reachable? 
                Vizkit.info "Port #{@__port.full_name} is not reachable"
                @__reader_writer = nil
                return @__reader_writer
            end 

            port = if @__orogen_port_proxy
                       begin 
                           raise "force_local? is set to true" if @__port.respond_to?(:force_local?) && @__port.force_local?
                           raise "Proxy #{@__orogen_port_proxy.name} is not reachable" if !@__orogen_port_proxy.reachable? 
                           options = { :periodicity => @local_options[:port_proxy_periodicity] }
                           if @policy[:init]
                               options[:keep_last_value] = true
                           end

                           options = options.merge(@policy)
                           real_port = @__port.to_orocos_port
                           if real_port.kind_of?(Orocos::OutputPort) && !options.has_key?(:pull)
                               options[:pull] = true
                           end
                           @__orogen_port_proxy.proxy_port(@__port, options)
                       rescue Interrupt
                           raise
                       rescue Exception => e
                           if(disable_proxy_on_error)
                               Vizkit.warn "Disabling proxying of port #{@__port.full_name}: #{e.message}"
                               e.backtrace.each do |line|
                                   Vizkit.warn "  #{line}"
                               end
                               @__orogen_port_proxy = nil
                               @__port.__port
                            else
                               Vizkit.info "cannot proxy port #{@__port.full_name}: #{e.message}"
                               e.backtrace.each do |line|
                                   Vizkit.info "  #{line}"
                               end
                               return nil
                            end
                       end
                   else
                       @__port.__port
                   end
            if port
                if port.respond_to? :reader
                    @__reader_writer = port.reader @policy
                    Vizkit.info "Create reader for output port: #{port.full_name}"
                else
                    @__reader_writer = port.writer @policy
                    Vizkit.info "Create writer for input port: #{port.full_name}"
                end
            else
                @__reader_writer = nil
            end
            @__reader_writer
        rescue Orocos::NotFound, Orocos::CORBAError => e
            Vizkit.warn "ReaderWriterProxy: error while proxuing the port: #{e}"
            e.backtrace.each do |line|
                Vizkit.warn "  #{line}"
            end
            @__reader_writer = nil
        end

        def port
            @__port
        end

        def type_name
            @__port.type_name
        end

        def new_sample
            @__port.new_sample
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
            @local_options[:subfield] = Array(@local_options[:subfield])

            if !@local_options[:subfield].empty?
                Vizkit.info "Create ReaderProxy for subfield #{@local_options[:subfield].join(".")} of port #{port.full_name}"
            else
                Vizkit.info "Create ReaderProxy for #{port.full_name}"
            end
        end

        def __subfield(sample,field=Array.new)
            port.__subfield(sample,field)
        end

        def read(sample = nil)
            if sample
                __port = port.__port
                return nil if !__port
                if __port.type_name != type_name
                    @__last_sample ||= __port.new_sample
                    sample =__subfield(super(@__last_sample),@local_options[:subfield])
                    return sample
                end
            end
            __subfield(super(sample),@local_options[:subfield])
        end

        def read_new(sample = nil)
            if sample
                __port = port.__port
                return nil if !__port
                if __port.type_name != type_name
                    @__last_sample ||= __port.new_sample
                    sample =__subfield(super(@__last_sample),@local_options[:subfield])
                    return sample
                end
            end
            __subfield(super(sample),@local_options[:subfield])
        end
    end

    class WriterProxy < ReaderWriterProxy
        def initialize(task,port,options = Hash.new)
            temp_options, options = Kernel.filter_options options,:subfield => Array.new ,:type_name => nil
            raise "Subfields are not supported for WriterProxy #{port.full_name}" if options.has_key?(:subfield) && !options[:subfield].empty?
            super(task,port,options)
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
            @local_options, options = Kernel::filter_options options,{:subfield => Array.new,:type_name => nil,:port_proxy => nil}
            @local_options[:subfield] = Array(@local_options[:subfield])

            @__task = TaskProxy.new(task)
            raise "Cannot create PortProxy if no task is given" if !@__task

            if(port.is_a? String)
                @__port_name = port
                @__port = nil
            elsif(port.is_a? PortProxy)
                @__port_name = port.name
                @__port = port.instance_variable_get(:@__port)
                @local_options[:subfield] = port.instance_variable_get(:@local_options)[:subfield]+@local_options[:subfield]
            else
                @__port_name = port.name
                @__port = port
            end

            if !@local_options[:subfield].empty?
                Vizkit.info "Create PortProxy for subfield #{@local_options[:subfield].join(".")} of port #{full_name}"
            else
                Vizkit.info "Create PortProxy for: #{full_name}"
            end
            __port
            if @__port.respond_to?(:force_local?) && @__port.force_local?
                Vizkit.info "No port proxy is used for port #{@__port.full_name}"
                @local_options[:port_proxy] = nil 
            end
        end

        #returns the Orocos::InputPort or Orocos::OutputPort object
        #or raises an error if the task is not reachable
        def to_orocos_port
            port = __port
            raise "Cannot return Orocos Port because task #{task.name} is not reachable" if !port
            port
        end

        #we need this beacuse it can happen that we do not have a real port object 
        #the subfield is not considered because we do not want to use a separate 
        #port on the orogen port_proxy
        def full_name
            if @local_options[:subfield].empty?
                "#{task.name}.#{name}"
            else
                "#{task.name}.#{name}.#{@local_options[:subfield].join(".")}"
            end
        end

        def name
            @__port_name
        end

        def type_name
            @type_name ||= if(type = @local_options[:type_name]) != nil
                               type
                           elsif @__port || __port
                               if !@local_options[:subfield].empty?
                                   @new_sample ||= @__port.new_sample.zero!
                                   sample = @new_sample
                                   @local_options[:subfield].each do |f|
                                       sample = if f.is_a? Fixnum 
                                                    sample.element_t
                                                elsif sample.respond_to? :raw_get_field
                                                    sample.raw_get_field(f)
                                                else
                                                    sample[f]
                                                end
                                   end
                                   if sample.respond_to? :name
                                       sample.name
                                   elsif sample.class.respond_to? :name
                                       sample.class.name
                                   else
                                       sample.class
                                   end
                               else
                                   @__port.type_name
                               end
                           elsif
                               nil
                           end
            @type_name
        end

        def task
            @__task
        end

        #returns true if the underlying port is an input port 
        #if the task is not running it will always return false 
        def input? 
            port = __port
            if port.respond_to? :writer
               true
            else
               false
            end
        end
        
        #returns true if the underlying port is an output port 
        #if the task is not running it will always return false 
        def output?
            port = __port
            if port.respond_to? :reader
               true
            else
               false
            end
        end

        def connect_to(port,policy = Hash.new)
            raise "Cannot connect port #{full_name} to #{full_name} because task #{task.name} is not reachable!" if !task.reachable?
            raise "Cannot connect port #{full_name} to #{full_name} because task #{port.task.name} is not reachable!" if !port.task.reachable?
            __port.connect_to(port,policy)
        end

        def disconnect_from(port,policy = Hash.new)
            raise "Cannot disconnect port #{full_name} from #{full_name} because task #{task.name} is not reachable!" if !task.ping
            raise "Cannot disconnect port #{full_name} from #{full_name} because task #{port.task.name} is not reachable!" if !port.task.reachable?
            pp port
            __port.disconnect_from(port)
        end

        def __port
            if @__task.reachable? && (!@__port || !@__port.task.reachable?)
                if(@__task.has_port?(@__port_name))
                    task = @__task.__task
                    if task
                        @__port = task.port(@__port_name) 
                        Vizkit.info "Create Port for: #{@__port.full_name}"
                        if @__port.respond_to? :tracked=
                            Vizkit.info "Call tracked=true on port #{@__port.full_name}"
                            @__port.tracked=true
                        end
                    end
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
            WriterProxy.new(@__task_proxy,self,@local_options.merge(policy))
        end

        def reader(policy = Hash.new)
            ReaderProxy.new(@__task_proxy,self,@local_options.merge(policy))
        end

        def new_sample
            if type_name.respond_to?(:new)
		#the type is a class
                return nil
            elsif type_name.respond_to? :to_str
                if @__port && @__port.type_name == type_name
                    @__port.new_sample
                else
                    if @new_sample
                        @new_sample.class.registry.get(type_name).new
                    else
                        if !Orocos.registry.include? type_name
                            Vizkit.info "load typekit for #{type_name}"
                            Orocos.load_typekit_for type_name
                        end
                        Orocos.registry.get(type_name).new
                    end
                end
            else
                nil
            end
        end

        def __subfield(sample,field=Array.new)
            return sample if(field.empty? || !sample)
            begin
                field.each do |f| 
                    sample = sample[f]
                end
            rescue ArgumentError => e
                Vizkit.info "Cannot extract subfield for port #{port.full_name}: Subfield does not exist!"
                sample = nil
            end
            #check if the type is right
            if(sample.respond_to?(:type_name) && sample.type_name != type_name )
                raise "Type miss match. Expected type #{type_name} but got #{sample.type_name} for subfield #{field.join(".")} of port #{full_name}"
            end
            sample
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
            Vizkit.warn "PortProxy #{full_name} got an error: #{e.message}"
            e.backtrace.each do |line|
                Orocos.warn "  #{line}"
            end
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
            if task_name.is_a?(Orocos::TaskContext) || task_name.is_a?(Orocos::Log::TaskContext)
                @__task = task_name if task_name.is_a? Orocos::Log::TaskContext
                task_name = task_name.name
            elsif task_name.is_a? TaskProxy
                @__task = task_name.instance_variable_get(:@__task)
                task_name = task_name.name
            end
            @__task_name = task_name
            @__connection_code_block = block
            @__readers = Hash.new
            @__ports = Hash.new
            @__state = :NotReachable
            Vizkit.info "Create TaskProxy for task: #{name}"

            #needed to automatically track log task
            ping if Vizkit.use_log_task? name
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

        def __change_name(name)
            if self.name != name
                @__task_name = name
                __reconnect
            end
        end

        def ping
            if !@__task || !@__task.reachable?
                begin 
                    if @__task
                        Vizkit.info "Task #{name} is no longer reachable."
                        proxy = ReaderWriterProxy.default_policy[:port_proxy]
                        proxy.delete_proxy_ports_for_task(name) if proxy && self != proxy && proxy.reachable?
                    end

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

                rescue Orocos::NotInitialized
                    Vizkit.info "TaskProxy #{name} can not be found (Orocos is not initialized and there is no log task called like this)."
                    @__task = nil
                rescue Orocos::NotFound, Orocos::CORBAError
                    @__task = nil
                rescue Orocos::NoModel
                    @__task = nil 
                    @__state = :NoModel 
                end
            end
            @__task != nil
        end

        def each_port(options = Hash.new,&block)
            task = __task
            if task
                task.each_port do |port|
                    pport = port(port.name,options)
                    block.call(pport)
                end
            end
        end

        def respond_to?(method)
            return true if super || Orocos::TaskContext.public_instance_methods.include?(method.to_s) ||__task.respond_to?(method)
            false
        end

        def port(name,options = Hash.new)
            #all ports are cached
            #ports which are used to read subfields are regarded 
            #as new port
            full_name = if options.has_key? :subfield 
                            name + Array(options[:subfield]).join("_")
                        else
                            name
                        end
            if @__ports.has_key?(full_name)
                @__ports[full_name]
            else
                @__ports[full_name] = PortProxy.new(self,name,options)
            end
        end

        def state
            if ping
                @__task.state
            else
                @__state
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
