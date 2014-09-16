module Vizkit
    class ConnectorObject
        # # all getter must support read
        # def read(options,*args,&block)
        # end

        # # all receiver must support write
        # def write(options,*args,&block)
        # end

        # # all souces must support on_data
        # def on_data(options,&block)
        # end

        def initialize
            @supports_options = true
        end

        # used to filter underlaying method specs
        def arity=(value)
        end

        # returns true if the given arity is supported
        def arity?(value)
            true
        end

        # returns true if the given arguments are supported
        def argument_types?(*value)
            true
        end

        # used to filter underlaying method specs
        def argument_types=(*value)
        end

        def return_type
            nil
        end

        def argument_types
            []
        end

        def name
            @name
        end

        # returns true if the object supports options for writing or reading
        def options?
            @supports_options
        end

        def connect_to(receiver,options)
            objects,options = Kernel.filter_options options,:getter => nil,:callback => nil,:write_options => Hash.new,:getter_options => Hash.new
            getter = objects[:getter]
            callback = objects[:callback]
            write_opt= objects[:write_options]
            getter_opt= objects[:getter_options]

            # options are for the writing part if the source does not support
            # options
            if !options? && write_opt.empty?
                write_opt = options
                options = Hash.new
            end

            raise ArgumentError, "#{name} cannot be used as :source object" unless respond_to?(:on_data)
            raise ArgumentError, "#{receiver.name} cannot be used as :receiver object" unless receiver.respond_to?(:write)
            raise ArgumentError, "#{getter.name} cannot be used as :getter object" if getter && !getter.respond_to?(:read)
            if callback
                raise ArgumentError, "#{callback.name} cannot be used as :callback object" if !callback.respond_to?(:write)
                raise ArgumentError, "Callback #{callback.name} must have an arity of 1" if !callback.arity?(1)
                callback.arity = 1
                if callback.argument_types? "/std/string"
                    callback.argument_types = "std/string"
                elsif callback.argument_types? "QString"
                    callback.argument_types = "QString"
                else
                    raise ArgumentError, "Callback #{callback.name} must have QString or /std/string as argument type"
                end
            end

           # TODO check types and arity
           # type = if getter
           #             return_type
           #             getter.argument_types
           #             getter.return_type
           #             receiver.argument_types
           #         else
           #             return_type
           #             receiver.argument_types
           #         end

            # connect objects
            p = proc do |result,error|
                if callback
                    message = if error
                                  error.to_s
                              else
                                  "OK"
                              end
                    callback.write(write_opt,message){}
                end
            end
            on_data options do |*args|
                if getter
                    getter.read getter_opt,*args do |*args|
                        receiver.write(write_opt,*args,&p)
                    end
                else
                    receiver.write(write_opt,*args,&p)
                end
            end
        end
    end

    class ConnectorSlot < ConnectorObject

        def initialize(widget,signature,options = Hash.new)
            super()
            @supports_options = false
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
                    arguments = Array.new([@widget.method(name).arity,0].max,:ruby)
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
                        break if value[index] != type
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

        def normalize_qt_args(*args)
            args.map do |arg|
                if arg.is_a? Symbol
                    arg.to_s
                else
                    arg
                end
            end
        end

        def write(options,*args,&block)
            args = normalize_qt_args *args
            s = spec(false)
            result = @widget.send(s.name,*args)
            block.call(result) if block
            result
        end

        # no different in the case of slots and signals
        def read(options,*args,&block)
            args = normalize_qt_args *args
            write(options,*args,&block)
        end
    end

    class ConnectorSignal < ConnectorSlot
        def populate_specs(signature)
            @specs = find_method_specs(signature,Qt::MetaMethod::Signal)
            raise ArgumentError,"#{signature} is not a valid signal signature for widget #{@widget}" if @specs.empty?
        end

        def on_data(options,&block)
            Kernel.validate_options options
            s = spec(false)
            @widget.connect SIGNAL(s.signature),&block
        end
    end

    class ConnectorOperation < ConnectorObject
        def initialize(task,signature,options)
            super()
            @task = task
            @name = signature
        end

        def arity=(value)
        end

        def arity?(value)
            true
        end

        def argument_types?(*value)
        end

        def argument_types=(*value)
        end

        def argument_types
        end

        def write(options,*args,&block)
            if block
                @operations = @task.operation(@name) do |opt,error|
                    if error
                        block.call(nil,error) if block
                    else
                        result = opt.callop *args
                        block.call(result,error) if block
                    end
                end
            else
                @task.operation(@name).callop *args
            end
        end

        def read(options,*args,&block)
            write(options,*args,&block)
        end
    end

    class ConnectorPort < ConnectorObject
        def initialize(task,signature,options)
            super()
            @port = task.port(signature)
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
            raise ArgumentError,"got #{args.size} number of arguments. Ports only support one argument for writing" unless args.size == 1
            arg = args.first
            arg = if arg.is_a?(Qt::Variant) && arg.to_ruby?
                      arg.to_ruby
                  else
                      arg
                  end
            @port.write arg,options,&block
        end

        def on_data(options,&block)
            @port.on_data options, &block
        end
    end

    class ConnectorProperty < ConnectorObject
        def initialize(task,signature,options)
            super()
            @property = task.property(signature)
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
            @property.name
        end

        def read(options,*args,&block)
            raise ArgumentError,"wrong number of arguments" unless args.size == 0
            @property.read options,&block
        end

        def write(options,*args,&block)
            raise ArgumentError,"got #{args.size} number of arguments. Ports only support one argument for writing" unless args.size == 1
            @property.write args.first,&block
        end

        def on_data(options,&block)
            @property.on_change options, &block
        end
    end

    class ConnectorEvent < ConnectorObject
        def initialize(task,signature,options)
            super()
            @supports_options = false
            @task = task
            @name = signature
            @task.validate_event @name.to_sym
        end

        def write(options,*args,&block)
            @task.emit @name.to_sym,*args
            block.call if block
            nil
        end

        def on_data(options,&block)
            Kernel.validate_options options
            @task.on_event @name.to_sym,&block
        end
    end

    class ConnectorProc < ConnectorObject
        def initialize(task,proc_,options = Hash.new)
            super()
            @supports_options = false
            @task=task
            @proc = proc_
            @name = "code block"
        end

        def arity=(value)
            raise ArgumentError,"no siganture has an airty of #{value}" unless arity?(value)
            self
        end

        def arity?(value)
            @proc.arity == value
        end

        def argument_types?(*value)
            if arity?(value.size)
                true
            else
                false
            end
        end

        def argument_types=(*value)
            raise ArgumentError,"no siganture has the given arguments #{value}" unless argument_types?(*value)
            self
        end

        def write(options,*args,&block)
            result = @proc.call(*args)
            block.call(result) if block
            result
        end

        # no different between read and write
        alias :read :write
    end
end
