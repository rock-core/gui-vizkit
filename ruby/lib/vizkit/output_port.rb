
#overload for Orocos::OutputPort, Orocos::Log::Outpuport to be compatible with qt widgets
module OQConnectionOutputPort
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

module Vizkit
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
        include OQConnectionOutputPort
    end
end

module Orocos
    module Log
        class OutputPort
            alias :org_connect_to :connect_to
            include OQConnectionOutputPort
        end
    end
    class OutputPort
        alias :org_connect_to :connect_to
        alias :org_disconnect_all :disconnect_all
        alias :org_disconnect_from :disconnect_from
        include OQConnectionOutputPort
    end
end
