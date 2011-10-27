

#overload for Orocos::OutputPort, Orocos::Log::Outpuport to be compatible with qt widgets
module Orocos
  module Log
    class OutputPort
      alias :org_connect_to :connect_to
      
      def connect_to_widget(widget=nil,options=Hash.new,&block)
        connection = Vizkit::OQLogConnection.new(self, options,widget,&block)
        Vizkit.connections << connection
        connection.connect
        connection 
      end

      #code blocks and methods are called directly from Log::Replay if now widget is given
      def connect_to(widget=nil, options = Hash.new,&block)
        if widget.is_a?(Hash)
          options = widget
          widget = nil
        end
        if(widget && widget.is_a?(Qt::Widget))
          return connect_to_widget(widget,options,&block)
        else
          if(widget && widget.is_a?(Method))
            raise "Cannot connect to a method and a code block at the same time. Call connect_to twice." if block_given?
            return org_connect_to nil,options,&widget.to_proc
          else
            return org_connect_to widget,options,&block
          end
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
      connection = Vizkit::OQConnection.new(self, options,widget,&block)
      Vizkit.connections << connection
      connection.connect
    end

    #sets up a qt timer
    #which calls reader.read with 20Hz if update_frequency is not given
    #TODO if only a code block is given we should use a call back 
    #to get the same behavior like for Log::OutputPort
    def connect_to(widget=nil, options = Hash.new,&block)
      if widget.is_a?(Hash)
        options = widget
        widget = nil
      end
      if widget.is_a?(Qt::Widget) || block_given? || widget.is_a?(Method)
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
