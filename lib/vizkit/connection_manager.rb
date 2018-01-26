module Vizkit
    class ConnectionManager
        def initialize(owner)
            @owner = owner
            @on_data_listeners = Hash.new do |h,key|
                h[key] = Array.new
            end

            @on_reachable_listeners = Hash.new do |h,key|
                h[key] = Array.new
            end
        end

        # returns true if the port is reachable
        # and the listeners are listening
        def connected?(port = nil)
            if port
                listening?(port) && port.reachable?
            else
                @on_data_listeners.keys.each do |key|
                    return false if !connected?(key)
                end
            end
        end

        def find_port_by_name(pname)
            @on_data_listeners.keys.each do |key|
                if key.full_name == pname 
                    return key
                end
            end
            return nil
        end
        
        def listening?(port = nil)
            if port
                @on_data_listeners[port].find do |l|
                    l.listening?
                end
            else
                @on_data_listeners.keys.each do |key|
                    return false if !listening?(key) 
                end
            end
        end

        def disconnect(port=nil, keep_port=true)
            if port
                @on_data_listeners[port].each do |l|
                    l.stop
                end
                
                @on_data_listeners.delete(port) unless keep_port
                
                @on_reachable_listeners[port].each do |l|
                    l.stop
                end
                
                @on_reachable_listeners.delete(port) unless keep_port
                
            else
                @on_data_listeners.keys.each do |key|
                    disconnect(key, keep_port)
                end
            end
        end

        def reconnect(port=nil)
            if port
                @on_data_listeners[port].each do |l|
                    l.start
                end
                @on_reachable_listeners[port].each do |l|
                    l.start
                end
            else
                @on_data_listeners.keys.each do |key|
                    reconnect(key)
                end
            end
        end

        def connect_to(port,callback=nil,options=Hash.new,&block)
            raise "Cannot connect to a code block and callback at the same time" if callback && block && callback != block
            callback ||= block

            Vizkit.info "Create new Connection for #{port.name} and #{callback}"
            listener = port.on_data do |data|
                callback.call data,port.full_name
            end
            @on_data_listeners[port] << listener
            listener
        end
        
    end
end
