#TODO
# - ping and reachable? should have the same behavior like the methods from TaskContext
# - new_sample for log files is not working like the one from Orocos::Port

#Proxy task for hiding the real task 
#this is useful if the task context is needed before 
#the task was started or if the task was restarted
module Vizkit

    #Proxy for Orocos::InputPort Writer and OutputPort Reader which automatically handles reconnects
    class ReaderWriterProxy
        class << self
            def default_policy
                if @default_policy[:port_proxy].is_a? String
                    @default_policy[:port_proxy] = TaskProxy.new(@default_policy[:port_proxy])
                end
                @default_policy
            end
            def default_policy=(value)
                @default_policy = value
            end
        end
        ReaderWriterProxy.default_policy = {:pull => false,:init => true,:port_proxy_periodicity => 0.125,:port_proxy => "port_proxy"}

        #the type of the port is determining if the object is a reader or writer
        #to automatically set up a orogen port proxy task set the hash value :port_proxy to the name of the port_proxy task
        #and :proxy_periodicity to the period in seconds which shall be used from the port_proxy to pull data from port
        #task = name of the task or its TaskContext
        #port = name of the port
        #options = connections policy {:port_proxy => nil, :proxy_periodicity => 0.2, (see Orocos::InputPort/OutputPort)}
        def initialize(task,port,options = Hash.new)
            options =  ReaderWriterProxy.default_policy.merge options
            @local_options,@policy = Kernel.filter_options options, :port_proxy_periodicity => nil,:port_proxy => nil

            @__port = port
            if(@__port.is_a?(String) || @__port.is_a?(Orocos::Port))
                @__port = TaskProxy.new(task).port(@__port)
            end
            @__orogen_port_proxy = if @local_options[:port_proxy].is_a? String
                                       if @local_options[:port_proxy] != @__port.task.name
                                           TaskProxy.new(@local_options[:port_proxy])
                                       end
                                   else
                                       if @local_options[:port_proxy] && @local_options[:port_proxy].name != @__port.task.name
                                           @local_options[:port_proxy]
                                       else
                                           nil
                                       end
                                   end
            @__proxy_connected = false
            __reader_writer(false)
        end

        #returns true if the reader is still valid and the connection active
        #it does not reconnect if it is broken 
        def connected?
            return false if !@__reader_writer 
            if !@__reader_writer.connected?
                if @__reader_writer.is_a? Orocos::OutputReader
                    Vizkit.info "Port reader for #{@__port.full_name} is no longer valid."
                else
                    Vizkit.info "Port writer for #{@__port.full_name} is no longer valid."
                end
                __invalidate
                #check if the task is still reachable
                #if there is a problem with the name service this will disable all reader
                port.task.ping
                false
            else
                #check if the proxy is connected 
                #we do not have to do this every time because the proxy is disconnecting
                #every one if a port gets invalid therefor the first time is enough 
                if @__orogen_port_proxy && !@__proxy_connected 
                    if @__orogen_port_proxy.isConnected(port.task.name,port.name)
                        @__proxy_connected = true
                    else
                        false
                    end
                else
                    true
                end
            end
        end

        #returns a valid reader/writer which can be used for reading/writing or nil if the Task cannot be contacted 
        def __reader_writer(disable_proxy_on_error=true)
            return @__reader_writer if connected?
            return nil if @__reader_writer  #just wait for the proxy to reconnect
            proxy = @__orogen_port_proxy && @__orogen_port_proxy.reachable? 
            proxing = proxy && @__orogen_port_proxy.isProxingPort(@__port.task.name,@__port.name)
            port = if proxing || (proxy &&  @__port.__output?)
                       begin 
                           #check if the port_proxy is already proxing the port 
                           if proxing  
                               port_name = @__orogen_port_proxy.getOutputPortName(@__port.task.name,@__port.name)
                               raise 'cannot get proxy port name for task' unless port_name
                               @__orogen_port_proxy.port(port_name)
                           else
                               # create proxy port
                               options = { :periodicity => @local_options[:port_proxy_periodicity] }
                               options[:keep_last_value] = true if @policy[:init]
                               port = @__port.__port
                               if port.respond_to?(:force_local?) && port.force_local?
                                   @__orogen_port_proxy = nil
                                   port
                               elsif port
                                   @__orogen_port_proxy.proxy_port(port, options)
                               else
                                   nil
                               end
                           end
                       rescue Interrupt
                           raise
                       rescue Exception => e
                           if(disable_proxy_on_error)
                               Vizkit.warn "Disabling proxying for port #{@__port.full_name}: #{e.message}"
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
                   elsif @__orogen_port_proxy && @__port.__output? &&
                         (!@__port.__port.respond_to?(:force_local?) || !@__port.__port.force_local?)
                   else
                       @__orogen_port_proxy = nil
                       @__port.__port
                   end
            if port
                if port.respond_to? :reader
                    @__reader_writer = port.reader @policy
                    @__proxy_connected = false
                    Vizkit.info "Create reader for output port: #{port.full_name}"
                else
                    @__reader_writer = port.writer @policy
                    @__orogen_port_proxy = nil                  # writer ports are never proxied
                    Vizkit.info "Create writer for input port: #{port.full_name}"
                end
                if connected? 
                    @__reader_writer
                else
                    nil
                end
            else
                __invalidate
            end
        rescue Orocos::NotFound, Orocos::CORBAError => e
            Vizkit.warn "ReaderWriterProxy: error while proxing the port: #{e}"
            e.backtrace.each do |line|
                Vizkit.warn "  #{line}"
            end
            __invalidate
            #it seems that there is something wrong with the port 
            #this happens if port is an old object 
            @__port.__invalidate
        end

        def port
            @__port
        end

        def type_name
            @__port.type_name
        end

        def type
            @__port.type
        end

        def new_sample
            @__port.new_sample
        end
        
        def __invalidate
            # for now we can not disconnect the reader writer 
            # beacause orcos.rb does not support this 
            @__reader_writer = nil
        end

        def method_missing(m, *args, &block)
            reader_writer = __reader_writer
            if reader_writer
                reader_writer.send(m, *args, &block)
            elsif Orocos::OutputReader.public_method_defined?(m) || Orocos::InputWriter.public_method_defined?(m)
                Vizkit.warn "ReaderWriterProxy for port #{port.full_name}: ignoring method #{m} because port is not reachable."
                nil
            else
                super(m,*args,&block)
            end
        rescue Orocos::NotFound, Orocos::CORBAError
            connected?
        end
    end

    class ReaderProxy < ReaderWriterProxy
        def initialize(task,port,options = Hash.new)
            temp_options, options = Kernel.filter_options options,:subfield => Array.new,:typelib_type => nil
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
            temp_options, options = Kernel.filter_options options,:subfield => Array.new ,:typelib_type => nil
            raise "Subfields are not supported for WriterProxy #{port.full_name}" if options.has_key?(:subfield) && !options[:subfield].empty?
            super(task,port,options)
            Vizkit.info "Create WriterProxy for #{port.full_name}"
        end
    end

    #Proxy for an Orocos::Port which automatically handles reconnects
    class PortProxy
        #task = name of the task or its TaskContext
        #port = name of the port or its Orocos::Port
        #options = {:subfield => Array,:typelib_type => type of the subfield}
        #
        #if the PortProxy is used for a subfield reader the type_name of the subfield must be given
        #because otherwise the type_name would only be known after the first sample was received 
        def initialize(task, port,options = Hash.new)
            @local_options, options = Kernel::filter_options options,{:subfield => Array.new,:typelib_type => nil}
            @local_options[:subfield] = Array(@local_options[:subfield])

            @__task = if task.is_a? TaskProxy 
                          task
                      else
                          TaskProxy.new(task)
                      end
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
            @__reader_writer = Array.new
            self
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

        def type
            @type ||= if(type = @local_options[:typelib_type]) != nil
                          type
                      elsif @__port || __port
                          if !@local_options[:subfield].empty?
                              @type ||= @__port.type
                              @local_options[:subfield].each do |f|
                                  @type = if @type.respond_to? :deference
                                                    @type.deference
                                                else
                                                    @type[f]
                                                end
                              end
                              @type
                          else
                              @__port.type
                          end
                      elsif
                          raise RuntimeError, "Cannot discover type for PortProxy #{full_name} because the port is not reachable and the option hint ':typelib_type' is not given. " +
                                              "If you are replaying a log file call Vizkit.control before you are using a TaskProxy."
                      end
            @type
        end

        def type_name
            type.name
        end

        def task
            @__task
        end

        #returns true if the underlying port is an input port 
        #if the task is not running it will always return false 
        def __input? 
            port = __port
            if port.respond_to? :writer
               true
            else
               false
            end
        end
        
        #returns true if the underlying port is an output port 
        #if the task is not running it will always return false 
        def __output?
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
            __port.disconnect_from(port)
        end

        def __invalidate
            @__port = nil
            @__reader_writer.each do |reader_writer|
                reader_writer.__invalidate
            end
            nil
        end

	def __valid?
	    @__port != nil
        end

        def __port
            if @__task.reachable? && !@__port
                if(@__task.has_port?(@__port_name))
                    task = @__task.__task
                    if task
                        @__port = task.port(@__port_name) 
                        Vizkit.info "Create Port for: #{@__port.full_name}"
                        # activate log ports 
                        if @__port.respond_to? :tracked=
                            Vizkit.info "Call tracked=true on port #{@__port.full_name}"
                            @__port.tracked=true
                        end
                    end
                else
                    Vizkit.warn "Task #{task().name} has no port #{name}. This can happen for tasks with dynamic ports."
                    __invalidate
                end
            end
            @__port
        rescue Orocos::NotFound, Orocos::CORBAError
            __invalidate
        end

        def writer(policy = Hash.new)
            @__reader_writer << WriterProxy.new(@__task_proxy,self,@local_options.merge(policy))
            @__reader_writer.last
        end

        def reader(policy = Hash.new)
            @__reader_writer << ReaderProxy.new(@__task_proxy,self,@local_options.merge(policy))
            @__reader_writer.last
        end

        def new_sample
            type.new
        end

        def __subfield(sample,field=Array.new)
            return sample if(field.empty? || !sample)
            field.each do |f| 
                sample = sample[f]
                if !sample
                    #if the field name is wrong typelib will raise an ArgumentError
                    Vizkit.warn "Cannot extract subfield for port #{full_name}: Subfield #{f} does not exist (out of index)!"
                    break
                end
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
            elsif Orocos::OutputPort.public_method_defined?(m) || Orocos::InputPort.public_method_defined?(m)
                Vizkit.warn "PortProxy #{full_name}: ignoring method #{m} because port is not reachable."
                __invalidate
            else
                super
            end
        rescue Orocos::NotFound, Orocos::CORBAError => e
            Vizkit.warn "PortProxy #{full_name} got an error: #{e.message}"
            e.backtrace.each do |line|
                Orocos.warn "  #{line}"
            end
            __invalidate
        end
    end

    #Proxy for a TaskContext which automatically handles reconnects 
    #It can also be used to automatically set up a orogen port proxy task which is a orocos Task normally running on the same machine
    #and pulls the data from the robot to not block the graphically interfaces.
    class TaskProxy
        class << self
            #TODO this should probably moved to the coba nameservice 
            attr_accessor  :nameservice_down
            attr_accessor  :do_not_connect_for
            attr_accessor  :last_nameservice_connection
            attr_accessor  :tasks
 
	    def disconnect_all(state = :NotReachable)
		tasks.each do |task|
		    task.__disconnect(state)
                end
	    end

            def check_corba_timeouts
                return unless Orocos::CORBA.call_timeout && Orocos::CORBA.connect_timeout
                if Orocos::CORBA.call_timeout > 3000 || Orocos::CORBA.connect_timeout > 3000
                    Vizkit.warn "Corba call timout is set to #{Orocos::CORBA.call_timeout} and connect timeout to #{Orocos::CORBA::connect_timeout}"
                    Vizkit.warn "This might block your script during connection problems."
                end
            end
        end
        TaskProxy.nameservice_down = false
        TaskProxy.do_not_connect_for = 10
	TaskProxy.tasks = Array.new

        attr_reader :__last_ping
        #Creates a new TaskProxy for an Orogen Task
        #automatically uses the tasks from the corba name service or the log file when added to the local name service
        #task_name = name of the task or its TaskContext
        #code block  = is called every time a TaskContext is created (every connect or reconnect)
        def initialize(task_name,options=Hash.new,&block)
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
            @__options,options = Kernel.filter_options options, :cleanup_nameservice => true
            if !options.empty?
                raise "invalid options #{options} for TaskProxy"
            end
            raise "Cannot create TaskProxy with no name!" if !task_name || task_name.empty? 
            TaskProxy.check_corba_timeouts if TaskProxy.tasks.empty?
	    TaskProxy.tasks << self
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
            __disconnect
            ping
        end

        def __disconnect(state = :NotReachable)
            @__state = state
            @__readers.clear
            @__task = nil
            #invalidate all ports
            @__ports.each_value do |port|
                port.__invalidate
            end
            nil
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

        # check if the task is still reachable 
        # to prevent blocking the nameservice will be used to discover if the task is reachable 
        # after it went down.
        # to check if a running task is no longer reachable the state_reader of the task is used
        def ping()
            return false if @__state == :NoModel || @__state == :ComError #prevents pinging
            reader = @__task.instance_variable_get(:@state_reader)
            if !@__task || (reader && !reader.connected?) || (!reader && !@__task.reachable?)
                begin 
                    if @__task
                        Vizkit.info "Task #{name} is no longer reachable."
                        __disconnect
                    end
                    if !TaskProxy.nameservice_down || (Time.now - TaskProxy.last_nameservice_connection).to_f >= TaskProxy.do_not_connect_for
                        TaskProxy.nameservice_down = false
                        Vizkit.info "Tying to access name service to create TaskContext for: #{name}"
                        @__task = Orocos::TaskContext.get(name)
                        #this is not reached if TaskContext.get is not successfully 
                        Vizkit.info "Create TaskContext for: #{name}"
                        # check if the name service was down
                        # if so we have to reset the port proxy because the connections
                        # are no longer working 
                        # TODO this should be moved to the port proxy 
                        if @__state  == :NameServiceDown && model.name == "port_proxy::Task"
                            Vizkit.warn "resetting port proxy #{name} to ensure valid connections"
                            if !closeAllProxyConnections()
                                Vizkit.error "Cannot reset port proxy. It seems that the updateHook is blocked" 
                                Vizkit.error "Connection might be no longer valid !!!" 
                            end
                        end
                        #we can now change to the state port to monitore if the task is still reachable
                        @__task.state
                        @__connection_code_block.call(self) if @__connection_code_block
                    end
                rescue Orocos::NotInitialized
                    Vizkit.info "TaskProxy #{name} can not be found (Orocos is not initialized and there is no log task called like this)."
                    #Try to get the task from the local name service
                    if nil != (service = Nameservice.get(:Local))
                        @__task = service.resolve(name)
                    end
                rescue Orocos::NotFound
                    #check if the corba name service is still publishing its name and remove it
                    #this prevents blocking of the ruby script
		    begin 
			if @__options[:cleanup_nameservice] && Orocos.task_names.include?(name)
			    Orocos::CORBA.unregister(name)
			    Vizkit.warn "unregistered dangling CORBA name #{name}"
			    @__state = :TaskCrashed
			elsif @__state != :TaskCrashed
			    @__state = :NotReachable
			end
		    rescue Orocos::CORBA::ComError
			# there is something wrong this the name server
			Vizkit.error "ComError while communicating with the nameserver." 			
                        Vizkit.error "Disabling all tasks !!!"
			Vizkit.error "Is the nameserver responding on the wrong network interface?." 			
                    	TaskProxy.disconnect_all(:ComError)
		    end
                    @__task = nil
                rescue Orocos::CORBAError => e
                    Vizkit.error "Corba error nameservice down ?"
                    Vizkit.error "prevent accessing name service for #{TaskProxy::do_not_connect_for} seconds"
                    TaskProxy.last_nameservice_connection = Time.now
                    TaskProxy.nameservice_down = true
                    TaskProxy.disconnect_all(:NameServiceDown)
                rescue Orocos::NoModel
                    Vizkit.warn "No task model for task #{name}."
                    Vizkit.warn "You have to build the orogen component on this machine in order to access the task."
                    __disconnect(:NoModel)
                end
            end
            @__last_ping = @__task != nil
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
            return true if super || Orocos::TaskContext.public_method_defined?(method) ||__task.respond_to?(method)
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
         #       if Orocos::TaskContext.public_method_defined?(m)
                    Vizkit.warn "TaskProxy #{name}: ignoring method #{m} because task is not reachable."
                    nil
         #       else
         # this is bad for remote methods calls
         #           super
         #       end
            else
                if @__task && @__task.has_port?(m.to_s)
                    port(m.to_s,*args)
                else
                    @__task.send(m, *args, &block)
                end
            end
        rescue Orocos::NotFound,Orocos::CORBAError
 	    __disconnect
        end

        alias :reachable? :ping
        alias :__connect :ping
    end
end
