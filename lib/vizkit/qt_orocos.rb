
module Qt
    module WidgetVizkitIntegration
        def connect_to_task(task,options = Hash.new,&block)
            task = if task.is_a? String
                       Orocos::Async.proxy task
                   else
                       task
                   end
            sandbox = Vizkit::WidgetTaskConnector.new(self,task,options)
            sandbox.evaluate &block
        end
    end

    class Widget
        include WidgetVizkitIntegration
    end

    class MainWindow
        include WidgetVizkitIntegration
    end
end

module Orocos
    module QtOutputPort
        def connect_to(widget=nil, options = Hash.new,&block)
            widget,options = if widget.is_a?(Hash)
                                 [nil,widget]
                             else
                                 [widget,options]
                             end

            # connection is to another orocos port or code block in the case of an Orocos Log Port
            if widget.respond_to?(:to_orocos_port) || widget.respond_to?(:find_port) || (!widget && self.is_a?(Orocos::Log::OutputPort))
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
        def connect_to(obj=nil, options = Hash.new,&block)
            obj,options = if obj.is_a?(Hash)
                                 [nil,obj]
                             else
                                 [obj,options]
                             end
            raise ArgumentError,"cannot connect port #{full_name} to a string #{obj}" if obj.is_a? String
            raise ArgumentError,"cannot connect port #{full_name} to#{obj} and code block at the same time" if obj && block

            # connection is to another orocos port
            if obj.respond_to?(:to_orocos_port) || obj.respond_to?(:find_port)
                return org_connect_to obj,options,&block
            end
            widget,callback = if !obj
                                  [nil,block]
                              elsif obj.respond_to?(:call)
                                  if obj.respond_to?(:receiver)
                                      [obj.receiver,obj]
                                  else
                                      [nil,obj]
                                  end
                              else
                                  [obj,nil]
                              end
            if widget.respond_to?(:connection_manager)
                widget.connection_manager.connect_to(self,callback,options,&block)
            else
                raise ArgumentError,"Cannot connect port #{full_name} to #{obj}. No connection manager found!" if obj.is_a?(Qt::Object)
                # use global connection manager
                Vizkit.connection_manager.connect_to(self,callback,options,&block)
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

    class Async::Log::OutputPort
        alias :org_connect_to :connect_to
        remove_method :connect_to

        include QtOrocos
    end

    class Async::PortProxy
        include QtOrocos
    end

    class Async::TaskContextProxy
        alias :org_connect_to :connect_to
        remove_method :connect_to

        def callback_for(widget)
            fct = widget.plugin_spec.find_callback!  :argument => self.class.name, :callback_type => :display
            if fct
                fct.bind(widget)
            else
                raise Orocos::NotFound,"#{widget.class_name} has no callback for #{self.class.name}"
            end
        end

        def connect_to_widget(widget,callback,options,&block)
            if(widget.respond_to?(:config) && widget.config(self,options,&block) == :do_not_connect)
                Vizkit.info "Disable auto connect for widget #{widget} because config returned :do_not_connect"
                nil
            else
                callback ||= callback_for(widget)
                callback.call(self,options)
            end
        end
        include QtOrocos
    end

    class Async::SubPortProxy
        include QtOrocos
    end
end
