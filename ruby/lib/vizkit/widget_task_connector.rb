
module Vizkit
    class WidgetTaskConnector
        def initialize(widget,task,options = Hash.new)
            @widget = widget
            @task = task
            @options = options
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

        private
        def connect_signal_to_port(signal,port_name,policy)
            Kernel.validate_options policy,:getter => nil,:callback => nil
            getter = policy[:getter]
            callback = policy[:callback]
            port = @task.port(port_name)
            if getter
                @widget.connect SIGNAL(signal) do |*args|
                    port.write @widget.send(getter.to_sym) do |result,error|
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
                    [:slot,$2]
                when 2
                    [:signal,$2]
                when 5
                    [:port,$2]
                when 6
                    [:operation,$2]
                when 7
                    [:event,$2]
                else
                    raise ArgumentError, "Cannot resolve #{str} into PORT, EVENT, OPERATION, SLOT or SIGNAL"
                end
        end
    end
end

