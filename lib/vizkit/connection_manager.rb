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
              puts "#{key.full_name} #{pname}"
                if key.full_name == pname
                    return key
                end
            end
            return nil
        end

        def listening?(port = nil)
            if port
                listening_to_port?(port)
            else
                listening_to_all_ports?
            end
        end

        def listening_to_port?(port)
            @on_data_listeners[port].any?(&:listening?)
        end

        def listening_to_all_ports?
            @on_data_listeners.keys.all? do |port|
                listening_to_port?(port)
            end
        end

        def disconnect(port = nil, keep_port: true)
            if port
                disconnect_connections_from_port(port)
                remove_port(port) unless keep_port
            else
                disconnect_connections_from_all_ports
                remove_all_ports unless keep_port
            end
        end

        def disconnect_connections_from_port(port)
            @on_data_listeners[port].each(&:stop)
            @on_reachable_listeners[port].each(&:stop)
        end

        def remove_port(port)
            disconnect_connections_from_port(port)
            @on_data_listeners.delete(port)
            @on_reachable_listeners.delete(port)
        end

        def disconnect_connections_from_all_ports
            @on_data_listeners.keys.each do |port|
                disconnect_connections_from_port(port)
            end
        end

        def remove_all_ports
            disconnect_connections_from_all_ports
            @on_data_listeners.clear
            @on_reachable_listeners.clear
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
