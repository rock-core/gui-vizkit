
module Vizkit
    class WidgetTaskConnector
        def initialize(widget,task,options = Hash.new)
            @widget = widget
            @task = task
            @options = options
            @method_info = if @widget.respond_to? :method_info
                             @widget.method_info
                         else
                             TypelibQtAdapter.new(@widget).method_info
                         end
        end

        def evaluate(&block)
            @self_before_instance_eval = eval "self", block.binding
            instance_exec @task, &block
        end

        def connect(sender,receiver=nil,policy = Hash.new,&block)
            sender_type,sender_str = resolve(sender)
            receiver,policy = if receiver.is_a? Hash
                                  [nil,receiver]
                              else
                                  [receiver,policy]
                              end
            receiver_type,receiver_str =  if block
                                              connect(sender,receiver,policy) if receiver
                                              [:code_block,nil]
                                          else
                                              resolve(receiver)
                                          end

            # dispatch sender and receiver type
            case sender_type
            when :signal
                case receiver_type
                when :port
                    connect_signal_to_port(sender_str,receiver_str,policy)
                when :operation
                    connect_signal_to_operation(sender_str,receiver_str,policy)
                when :code_block
                    widget.connect sender,&block
                else
                    raise ArgumentError,"A qt signal cannot be connect to a #{receiver_type}"
                end
            when :port
                case receiver_type
                when :slot
                    connect_port_to_method(sender_str,receiver_str,policy)
                when :code_block
                    @task.port(sender_str).on_data(policy,&block)
                else
                    raise ArgumentError,"A port cannot be connect to a #{receiver_type}"
                end
            when :event
                case receiver_type
                when :slot
                    connect_event_to_slot(sender_str,receiver_str,policy)
                when :code_block
                    @task.on_event(sender_str.to_sym,&block)
                else
                    raise ArgumentError,"An event cannot be connect to a #{receiver_type}"
                end
            else
                raise ArgumentError,"#{sender_str} cannot act as sender"
            end
        end

        def method_missing(method, *args, &block)
            @self_before_instance_eval.send method, *args, &block
        end

        def PORT(str)
            "5#{str}"
        end

        def OPERATION(str)
            "6#{str}"
        end

        def EVENT(str)
            "7#{str}"
        end

        def PROPERTY(str)
            "8#{str}"
        end

        private

        def normalize_method(signature)
            name = Qt::MetaObject.normalizedSignature(signature).to_s
            name =~ /.* (.*)$/     #remove return type
            name = $1 || name
            name =~ /(.*)const$/  #remove const
            $1 || name
        end


        def method_name(method_signature)
            name = normalize_method(method_signature)
            name =~ /(.*)\(.*\)/
            if $1
                $1
            else
                method_signature
            end
        end

        # @return [Array]
        def method_arity(method_signature)
            method_signature = normalize_method(method_signature)
            name = method_name(method_signature)
            m = @method_info[name].find {|method| method.signature == method_signature}
            if m
                Array(m.argument_types.size)
            else
                if @method_info.has_key? method_signature
                    @method_info[method_signature].map(&:argument_types).map(&:size)
                else
                    Array(@widget.method(method_signature).arity)
                end
            end
        end

        def valid_slot?(slot_name)
            slot_name = normalize_method(slot_name)
            return true if 0 <= @widget.metaObject.indexOfSlot(slot_name)
            return true if @method_info.has_key?(slot_name) && @method_info[slot_name].any?{|m| m.type == Qt::MetaMethod::Slot}
            return true if @widget.methods.include? slot_name
            false
        end

        def validate_slot(slot_name)
            if !valid_slot? slot_name
                raise ArgumentError,"#{slot_name} is not a slot of the widget #{@widget}"
            end
        end

        def validate_slot_arity(signature,arity)
            if !method_arity(signature).include? arity
                raise ArgumentError,"#{signature} has not an arity of #{arity}"
            end
        end

        def valid_signal?(signal_name)
            signal_name = normalize_method(signal_name)
            return true if 0 <= @widget.metaObject.indexOfSignal(signal_name)
            return true if @method_info.has_key?(signal_name) && @method_info[signal_name].any?{|m| m.type == Qt::MetaMethod::Signal}
            false
        end

        def validate_signal(signal_name)
            if !valid_signal? signal_name
                raise ArgumentError,"#{signal_name} is not a slot of the widget #{@widget}"
            end
        end

        def validate_signal_arity(signature,*arity)
            arity.flatten!
            if !method_arity(signature).any?{|s| arity.include? s}
                raise ArgumentError,"#{signature} has not an arity of #{arity}"
            end
        end


        def valid_port?(port_name)
        end

        def valid_operation?(operation_name)
        end

        def valid_property?(property_name)
        end

        def valid_event?(event_name)
        end

        def validat_event(event_name)
        end

        def validate_port(port_name)
        end

        def validate_property(property_name)
        end

        def validate_operation(operation_name)
        end


        def valid_task?(task_name)
        end


        def validate_task(task_name)
        end

        def connect_signal_to_port(signal,port_name,policy)
            Kernel.validate_options policy,:getter => nil,:callback => nil
            callback = policy[:callback]
            port = @task.port(port_name)
            #TODO check that port exists
            getter = policy[:getter]
            getter = if getter
                         validate_slot(getter)
                         #TODO check that types are compatible
                         method_name(getter)
                     end

            if !getter && !method_arity(signal).include?(1)
                raise ArgumentError, "Signal #{signal} is not passing any parameter and there is not :getter defined"
            end
            signal = if signal == method_name(signal)
                         "#{signal}()"
                     else
                         signal
                     end
            @widget.connect SIGNAL(signal) do |*args|
                sample = if getter
                             @widget.send(getter.to_sym)
                         else
                             args.first
                         end
                port.write(sample) do |result,error|
                    if callback
                        message = if error
                                      error.to_s
                                  else
                                      "OK"
                                  end
                        @widget.send(callback.to_sym,message)
                    end
                end
            end
        end

        def connect_signal_to_operation(signal,operation_name,policy)
            puts "signal to operation"
        end

        def connect_port_to_method(port_name,method_name,policy)
            raise ArgumentError,"no method name is given!" unless method_name
            @task.port(port_name).on_data(policy) do |sample|
                @widget.send(method_name,sample)
            end
            #    raise "Cannot connect #{port.full_name} with method #{method_name}. The method as an arity of #{m.arity}"
        end

        def connect_event_to_slot(event,method_name,policy)
            @task.on_event(event) do |*args|
                @widget.send(method_name,*args)
            end
        end

        def resolve(str)
            str =~ /^(\d)(.*)/
                case $1.to_i
                when 1
                    validate_slot($2)
                    validate_slot_arity($2,1)
                    [:slot,$2]
                when 2
                    validate_signal($2)
                    [:signal,$2]
                when 5
                    validate_port($2)
                    [:port,$2]
                when 6
                    validate_operation($2)
                    [:operation,$2]
                when 7
                    validate_event($2)
                    [:event,$2]
                else
                    raise ArgumentError, "Cannot resolve #{str} into PORT, EVENT, OPERATION, SLOT or SIGNAL"
                end
        end
    end
end

