
module Vizkit
    class OQConnection < Qt::Object
        #default values
        class << self
            attr_accessor :update_frequency
            attr_accessor :max_reconnect_frequency
        end
        OQConnection::update_frequency = 8
        OQConnection::max_reconnect_frequency = 0.5

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
            @port = if port.is_a? Vizkit::PortProxy
                        port
                    else
                        PortProxy.new task,port,options
                    end
            raise "Cannot create OQConnection because no port is given" if !@port
            @reader = @port.reader @policy
            if widget
                Vizkit.info "Create new OQConnection for #{@port.name} and qt object #{widget}"
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
            if @widget && @widget.respond_to?(:visible) && !@widget.visible
                Vizkit.info "OQConnection for #{@port.name} and widget #{widget.objectName}. Widget is not visible!" 
                disconnect
                return
            end

            if @reader.__reader_writer
                @last_sample ||= @reader.new_sample
                if @using_reduced_update_frequency
                    @using_reduced_update_frequency = false
                    Vizkit.info "OQConnection for #{@port.name}: Port is reachable setting update_frequency back to #{@local_options[:update_frequency]}" 
                    self.update_frequency= @local_options[:update_frequency]
                end
                while(sample = @reader.read_new(@last_sample))
                    Vizkit.info "OQConnection to port #{@port.full_name} received new sample"
                    if @block
                        @block.call(sample,@port.full_name)
                    end
                    callback_fct.call sample,@port.full_name if callback_fct
                end
            elsif !@using_reduced_update_frequency
                Vizkit.info "OQConnection for #{@port.name}: Port is not reachable reducing update_frequency to #{OQConnection::max_reconnect_frequency}" 
                @using_reduced_update_frequency = true
                self.update_frequency = OQConnection::max_reconnect_frequency
            end
        rescue Exception => e
            Vizkit.warn "could not read on #{reader}: #{e.message}"
            disconnect
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
            Vizkit.info "(Re)connect OQConnection to port #{@port.full_name}"
            @timer_id = startTimer(1000/@local_options[:update_frequency]) if !@timer_id
            if @port.task.reachable?
                true
            else
                false
            end
        rescue Exception => e
            Vizkit.warn "failed to reconnect: #{e.message}"
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
            connection = Vizkit::OQConnection.new(self.task.name,self, options,widget,&block)
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
        alias :org_connect_to :connect_to
        alias :org_disconnect_from :disconnect_from
        remove_method :connect_to,:disconnect_from
        def org_disconnect_all
            method_missing(:disconnect_all)
        end
        include OQConnectionIntegration
    end
end

module Orocos
    module Log
        class OutputPort
            alias :org_connect_to :connect_to
            remove_method :connect_to
            include Vizkit::OQConnectionIntegration
        end
    end
    class OutputPort
        alias :org_connect_to :connect_to
        alias :org_disconnect_all :disconnect_all
        alias :org_disconnect_from :disconnect_from
        remove_method :connect_to,:disconnect_from
        include Vizkit::OQConnectionIntegration
    end
end
