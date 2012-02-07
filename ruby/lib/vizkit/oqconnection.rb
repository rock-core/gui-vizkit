
module Vizkit
    class OQConnection < Qt::Object
        #default values
        class << self
            attr_accessor :update_frequency
            attr_accessor :max_reconnect_frequency
        end
        OQConnection::update_frequency = 8
        OQConnection::max_reconnect_frequency = 1

        attr_reader :port
        attr_reader :reader
        attr_reader :widget
        attr_reader :policy

        def initialize(task,port,options = Hash.new,widget=nil,&block)
            @block = block
            @timer_id = nil
            @last_sample = nil    #save last sample so we can reuse the memory
            @callback_fct = nil
            @using_reduced_update_frequency = false

            if widget.is_a? Method
                @callback_fct = widget
                widget = widget.receiver
            end
            if widget.is_a?(Qt::Widget)
                super(widget,&nil)
            else
                super(nil,&nil)
            end
            @widget = widget

            @local_options, @policy = Kernel.filter_options(options,:update_frequency => OQConnection::update_frequency)
            @port = if port.is_a? String
                        task = TaskProxy.new(task) if task.is_a? String
                        task.port(port)
                    else
                        port
                    end
            raise "Cannot create OQConnection because no port is given" if !@port
            @reader = @port.reader @policy

            #we do not need a timer for replayed connections 
            if @local_options[:update_frequency] <= 0 && @port.is_a?(Orocos::Log::OutputPort)
                @port.org_connect_to nil, @policy do |sample,_|
                    sample = @block.call(sample,@port.full_name) if @block
                    @callback_fct.call sample,@port.full_name if @callback_fct && sample
                    @last_sample = sample
                end
            end
            if widget
                Vizkit.info "Create new OQConnection for #{@port.name} and qt object #{widget.objectName}"
            elsif @callback_fct
                Vizkit.info "Create new OQConnection for #{@port.name} and method #{@callback_fct}"
            elsif @block
                Vizkit.info "Create new OQConnection for #{@port.name} and code block #{@block}"
            else
                raise "Cannot Create OQConnection because no widgte, method or code block is given"
            end
        end

        #returns ture if the connection was established at some point 
        #otherwise false
        def broken?
            reader ? true : false 
        end

        def callback_fct
            return @callback_fct if @callback_fct
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
                Vizkit.info "Found callback_fct #{@callback_fct} for OQConnection connected to port #{@port.full_name}"
                @callback_fct
            else
                @callback_fct = nil
            end
        end

        def update_frequency
            @local_options[:update_frequency]
        end

        def update_frequency=(value)
            @local_options[:update_frequency]= value
            if @timer_id
                killTimer @timer_id
                @timer_id = startTimer(1000/value)
            end
        end

        def timerEvent(event)
            #call disconnect if widget is no longer visible
            #this could lead to some problems if the widget wants to
            #log the data 
            if @widget && @widget.is_a?(Qt::Widget) && !@widget.visible
                Vizkit.info "OQConnection for #{@port.name} and widget #{widget.objectName}. Widget is not visible!" 
                disconnect
                return
            end

            if @port.task.reachable?
                @last_sample ||= @reader.new_sample
                if @using_reduced_update_frequency
                    @using_reduced_update_frequency = false
                    Vizkit.info "OQConnection for #{@port.name}: Port is reachable setting update_frequency back to #{@local_options[:update_frequency]}" 
                    update_frequency = @local_options[:update_frequency]
                end
                while(@reader.read_new(@last_sample))
                    Vizkit.info "OQConnection to port #{@port.full_name} received new sample"
                    if @block
                        @block.call(@last_sample,@port.full_name)
                    end
                    callback_fct.call @last_sample,@port.full_name if callback_fct
                end
            elsif !@using_reduced_update_frequency
                Vizkit.info "OQConnection for #{@port.name}: Port is not reachable reducing update_frequency to #{OQConnection::max_reconnect_frequency}" 
                @using_reduced_update_frequency = true
                update_frequency = OQConnection::max_reconnect_frequency
            end
            #   rescue Exception => e
            #     puts "could not read on #{reader}: #{e.message}"
            #     disconnect
        end

        def disconnect()
            if @timer_id
                killTimer(@timer_id)
                @timer_id = nil
                # @reader.disconnect this leads to some problems with the timerEvent: reason unknown
                @widget.disconnected(@port.full_name) if @widget.respond_to?:disconnected
                Vizkit.info "Disconnect OQConnection connected to port #{@port.full_name}"
            end
        end

        def reconnect()
            Vizkit.info "Reconnect OQConnection to port #{@port.full_name}"
            @timer_id = startTimer(1000/@local_options[:update_frequency]) if !@timer_id
            if @port.task.reachable?
                true
            else
                false
            end
        rescue Exception => e
            STDERR.puts "failed to reconnect: #{e.message}"
            false
        end

        #shadows the connect methods from base object
        #we should use an other name 
        def connect()
            reconnect if !connected?
        end

        def alive?
            return @timer_id && @reader.__valid?
        end

        alias :connected? :alive?
    end

    module OQConnectionIntegration
        def connect_to_widget(widget=nil,options = Hash.new,&block)
            connection = Vizkit::OQConnection.new(self.task.name,self.name, options,widget,&block)
            Vizkit.connections << connection
            connection.connect
        end

        def connect_to(widget=nil, options = Hash.new,&block)
            if widget.is_a?(Hash)
                options = widget
                widget = nil
            end
            if widget.is_a?(Qt::Object) || block_given? || widget.is_a?(Method)
                return connect_to_widget(widget,options,&block)
            else
                return org_connect_to widget,options
            end
            self
        end

        def disconnect_all
            Vizkit.disconnect_from(self)
            org_disconnect_all if respond_to? :org_disconnect_all
        end

        def disconnect_from(widget)
            if widget.is_a?(Qt::Widget)
                Vizkit.disconnect_from(widget)
            else
                org_disconnect_from(widget) if respond_to? :org_disconnect_from
            end
        end
    end

    class PortProxy
        def org_connect_to(input_port, options = Hash.new)
            method_missing(:connect_to,options)
        end
        def org_disconnect_from(input)
            method_missing(:disconnect_from,input)
        end
        def org_disconnect_all
            method_missing(:disconnect_all,nil)
        end
        include OQConnectionIntegration
    end
end

module Orocos
    module Log
        class OutputPort
            alias :org_connect_to :connect_to
            include Vizkit::OQConnectionIntegration
        end
    end
    class OutputPort
        alias :org_connect_to :connect_to
        alias :org_disconnect_all :disconnect_all
        alias :org_disconnect_from :disconnect_from
        include Vizkit::OQConnectionIntegration
    end
end
