
module Vizkit
    class WidgetTaskConnector
        class ConnectorObject
            def arity
            end

            def arity=(value)
            end

            def arity?(value)
            end

            def argument_types?(*value)
            end

            def argument_types=(*value)
            end

            def argument_types
            end

            def name
            end

            def read(options,*args,&block)
            end

            def write(options,*args,&block)
            end

            def on_data(options,&block)
            end

            def connect_to(obj,options)
                Kernel.validate_options options,:getter_obj => nil,:callback_obj => nil
                getter = options[:getter_obj]
                callback = options[:callback_obj]
                if !getter
                    if !arity?(1)
                        raise ArgumentError, "#{self.class} #{name} is not passing one parameter and there is no :getter slot defined"
                    end
                    self.arity = 1
                end
                if callback
                    if !callback.arity?(1)
                        raise ArgumentError, "Callback #{callback.name} has not an arity of one"
                    end
                    callback.arity = 1
                    if callback.argument_type? "/std/string"
                        callback.argument_type = "std/string"
                    elsif callback.argument_type? "QString"
                        callback.argument_type = "QString"
                    else
                        raise ArgumentError, "Callback slot #{callback.name} has a wrong argument type"
                    end
                end
                opt = Hash.new
                p = proc do |result,error|
                    if callback
                        message = if error
                                      error.to_s
                                  else
                                      "OK"
                                  end
                        callback.write(opt,message){}
                    end
                end
                on_data opt do |*args|
                    if getter
                        getter.read opt do |*args|
                            obj.write(opt,*args,&p)
                        end
                    else
                        obj.write(opt,*args,&p) 
                    end
                end
            end
        end

        class ConnectorSlot < ConnectorObject
            def initialize(widget,signature,options = Hash.new)
                @widget = widget
                @method_info = if @widget.respond_to? :method_info
                                   @widget.method_info
                               else
                                   TypelibQtAdapter.new(@widget).method_info
                               end
                populate_specs(signature)
            end

            def populate_specs(signature)
                @specs = find_method_specs(signature,Qt::MetaMethod::Slot)
                raise ArgumentError,"#{signature} is not a valid slot signature for widget #{@widget}" if @specs.empty?
            end

            def method_name(signature)
                name = normalize_signature(signature)
                name =~ /(.*)\(.*\)/
                    if $1
                        $1
                    else
                        signature
                    end
            end

            def normalize_signature(signature)
                name = Qt::MetaObject.normalizedSignature(signature).to_s
                name =~ /.* (.*)$/     #remove return type
                name = $1 || name
                name =~ /(.*)const$/  #remove const
                $1 || name
            end


            def find_method_specs(signature,type=nil)
                signature = normalize_signature signature
                name = method_name(signature)
                specs = if @method_info.has_key? signature
                            @method_info[signature]
                        elsif @method_info.has_key? name
                            @method_info[name].find_all {|method| method.signature == signature}
                        else
                            []
                        end
                if !specs.empty?
                    if type
                        specs.find_all{|s| s.type == type}
                    else
                        specs
                    end
                else
                    if @widget.respond_to?(name.to_sym) && (!type || type == Qt::MetaMethod::Slot)
                        arguments = Array.new(@widget.method(name).arity,:ruby)
                        [TypelibQtAdapter::MethodInfo.new(name,name,:ruby,arguments,Qt::MetaMethod::Slot)]
                    else
                        []
                    end
                end
            end

            # raises if there is more than one spec for the object 
            # filter out first
            def spec(first = false)
                raise "there is no spec" if @specs.empty?
                raise "there are more than one spec" if @specs.size > 1 if !first
                @specs.first
            end

            def arity
                spec(true)
                return @specs.first.argument_types.size if @specs.size == 1
                @specs.map {|spec|types.argument_types.size}
            end

            def arity=(value)
                spec(true)
                raise ArgumentError,"no siganture has an airty of #{value}" unless arity?(value)
                specs.delete_if do |spec|
                    spec.argument_types.size != value
                end
                self
            end

            def arity?(value)
                !!@specs.find do |spec|
                    spec.argument_types.size == value
                end
            end

            def argument_types?(*value)
                value.flatten!
                !!@specs.find do |spec|
                    if spec.argument_types.size != value.size
                        next
                    else
                        spec.argument_types.each_with_index do |type,index|
                            break if value[index] != type
                        end or next
                        true
                    end
                end
            end

            def argument_types=(*value)
                raise ArgumentError,"no siganture has the given arguments #{value}" unless argument_types?(*value)
                specs.delete_if do |spec|
                    if spec.argument_types.size != value.size
                        true
                    else
                        spec.argument_types.each_with_index do |type,index|
                            break if values[index] != type
                        end or break true
                        false
                    end
                end
                self
            end

            def argument_types
                spec(true)
                types = @specs.collect each do |spec|
                    spec.argument_types
                end
                types.flatten if types.size == 1
            end

            def specs
                @specs
            end

            def name
                spec(true)
                @specs.first.name
            end

            def write(options,*args,&block)
                s = spec(false)
                result = @widget.send(s.name,*args)
                block.call(*result) if block
                result
            end

            # no different in the case of slots and signals
            def read(options,*args,&block)
                write(options,*args,&block)
            end

            def on_data(options,&block)
                raise ArgumentError, "Slots cannot be used as source !"
            end

        end

        class ConnectorSignal < ConnectorSlot
            def populate_specs(signature)
                @specs = find_method_specs(signature,Qt::MetaMethod::Signal)
                raise ArgumentError,"#{signature} is not a valid signal signature for widget #{@widget}" if @specs.empty?
            end

            def on_data(options,&block)
                s = spec(false)
                @widget.connect SIGNAL(s.signature),&block
            end
        end

        class ConnectorOperation < ConnectorObject
            def initialize(task,operation,options)

            end

            def arity
            end

            def arity=(value)
            end

            def arity?(value)
            end

            def argument_types?(*value)
            end

            def argument_types=(*value)
            end

            def argument_types
            end

            def name
            end

            def write(options,*args,&block)
                raise ArgumentError,"wrong number of arguments" unless args.size == 1
            end

            def read(options,*args,&block)
                raise ArgumentError,"wrong number of arguments" unless args.size == 1
            end

            def on_data(options,&block)
                raise ArgumentError, "Operations cannot be used as source !"
            end
        end

        class ConnectorPort < ConnectorObject
            def initialize(task,signature)
                @task = task
                @port = task.port(signature)
            end

            def arity
                1
            end

            def arity=(value)
                raise ArgumentError "only an arity of one is supported for ports" unless value == 1
            end

            def arity?(value)
                value == 1
            end

            def argument_types?(*value)
            end

            def argument_types=(*value)
            end

            def argument_types
            end

            def name
                @port.name
            end

            def read(options,*args,&block)
                raise ArgumentError,"wrong number of arguments" unless args.size == 0
                @port.read options,&block
            end

            def write(options,*args,&block)
                raise ArgumentError,"wrong number of arguments" unless args.size == 1
                @port.write args.first,&block
            end

            def on_data(options,&block)
                @port.on_data &block
            end
        end

        def initialize(widget,task,options = Hash.new)
            @widget = widget
            @task = task
            @options = options
        end

        def evaluate(&block)
            @self_before_instance_eval = eval "self", block.binding
            instance_exec @task, &block
        end

        def connect(sender,receiver=nil,options= Hash.new)
            Kernel.validate_options options,:callback,:getter
            source = resolve(sender)
            receiver,options= if receiver.is_a? Hash
                                  [nil,receiver]
                              else
                                  [receiver,options]
                              end
            receiver = resolve(receiver)

            new_options = Hash.new
            new_options[:getter_obj] = resolve(options[:getter]) if options[:getter]
            new_options[:callback_obj] = resolve(options[:callback]) if options[:callback]
            source.connect_to receiver,new_options
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
        # converts the given string into a list of object which meed the given signature
        # @return [Array(Spec)]
        def resolve(signature)
            signature =~ /^(\d)(.*)/
                case $1.to_i
                when 1
                    ConnectorSlot.new(@widget,$2)
                when 2
                    ConnectorSignal.new(@widget,$2)
                when 5
                    ConnectorPort.new(@task,$2)
                when 6
                    ConnectorOperation.new(@task,$2)
                when 7
                    ConnectorEvent.new(@task,$2)
                else
                    raise ArgumentError,"#{signature} has an invalid type identifyer #{$1}"
                end
        end
    end
end

