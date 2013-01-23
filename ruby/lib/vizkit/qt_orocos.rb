module Orocos
    module QtOutputPort
        def connect_to(widget=nil, options = Hash.new,&block)
            widget,options = if widget.is_a?(Hash)
                                 [nil,widget]
                             else
                                 [widget,options]
                             end

            # connection is to another orocos port
            if widget.respond_to?(:to_orocos_port) || widget.respond_to?(:find_port)
                return org_connect_to widget,options,&block
            end

            Vizkit.warn "deprecation: use Async API to connect the port #{full_name} to a widget or code block"
            # create a PortProxy and connect to it
            task = begin
                       Orocos::Async.get(self.task.name)
                   rescue Orocos::NotFound => e
                       Vizkit.warn "failed to automatically use the Async API"
                       raise e
                   end
            port = Orocos::Async.proxy(self.task.name,:use => task).port(self.name,:wait => true)
            port.connect_to(widget,options,&block)
            self
        end
    end

    module QtOrocos
        def connect_to(widget=nil, options = Hash.new,&block)
            widget,options = if widget.is_a?(Hash)
                                 [nil,widget]
                             else
                                 [widget,options]
                             end

            # connection is to another orocos port
            if widget.respond_to?(:to_orocos_port) || widget.respond_to?(:find_port)
                return org_connect_to widget,options,&block
            end

            # connection is to a widget,method or code block
            callback,widget = if widget.respond_to?(:plugin_spec)
                                  fct = widget.plugin_spec.find_callback!  :argument => type_name, :callback_type => :display
                                  if fct
                                      [fct.bind(widget),widget]
                                  else
                                      [nil,widget]
                                  end
                              elsif widget.respond_to?(:call)
                                  if widget.respond_to?(:receiver)
                                      [widget,widget.receiver]
                                  else
                                      [widget,nil]
                                  end
                              end

            raise ArgumentError, "cannot connect to widget #{widget.class_name} and code block at the same time." if callback && block
            raise ArgumentError, "cannot connect to widget #{widget.class_name}. no callback for #{type_name}" if !callback && widget

            if(widget.respond_to?(:config) && widget.config(self,options,&block) == :do_not_connect)
                Vizkit.info "Disable auto connect for widget #{widget} because config returned :do_not_connect"
                nil
            else
                callback ||= block
                raise ArgumentError, "cannot connect. no code block." if !callback

                Vizkit.info "Create new Connection for #{name} and #{widget || callback}"
                on_data do |data|
                    callback.call data,full_name
                end
            end
        end
    end

    class OutputPort
        alias :org_connect_to :connect_to
        remove_method :connect_to

        include QtOutputPort
    end

    class Log::OutputPort
        alias :org_connect_to :connect_to
        remove_method :connect_to

        include QtOutputPort
    end

    class Async::PortProxy
        include QtOrocos
    end

    class Async::SubPortProxy
        include QtOrocos
    end
end
