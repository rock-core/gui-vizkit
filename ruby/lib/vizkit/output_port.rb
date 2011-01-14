

#overload for Orocos::OutputPort, Orocos::Log::Outpuport to be compatible with qt widgets
module Orocos
  module Log
    class OutputPort
      alias :org_connect_to :connect_to
      
      def connect_to_widget(widget=nil,options=Hash.new,&block)
        Vizkit.connections << Vizkit::OQLogConnection.new(self, options,widget,&block)
      end

      def connect_to(widget=nil, options = Hash.new,&block)
        if widget.is_a?(Hash)
          options = widget
          widget = nil
        end
        if widget.is_a?(Qt::Widget)
          return connect_to_widget(widget,options,&block)
        else
          return org_connect_to widget,options
        end
        self
      end
    end
  end

  class OutputPort
    alias :org_connect_to :connect_to
    alias :org_disconnect_all :disconnect_all
    alias :org_disconnect_from :disconnect_from
    
    def connect_to_widget(widget=nil,options = Hash.new,&block)
      Vizkit.connections << Vizkit::OQConnection.new(self, options,widget,&block)
    end

    def connect_to(widget=nil, options = Hash.new,&block)
      if widget.is_a?(Hash)
        options = widget
        widget = nil
      end
      if widget.is_a?(Qt::Widget)
        return connect_to_widget(widget,options,&block)
      else
        return org_connect_to widget,options
      end
      self
    end

    def disconnect_all
      Vizkit.disconnect_from(self)
      org_disconnect_all
    end

    def disconnect_from(widget)
      if widget.is_a?(Qt::Widget)
        Vizkit.disconnect_from(widget)
      else
        org_disconnect_from(widget)
      end
    end
  end
 

end
