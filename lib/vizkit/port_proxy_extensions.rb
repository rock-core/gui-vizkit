require 'utilrb/object/attribute'

module Orocos
    extend_task 'port_proxy::Task' do
        #returns the Output-/InputPort of the proxy which writes/reads the data from/to the given port
        #raises an exception if the proxy is unable to proxy the given port 
        def proxy_port(port,options=Hash.new)
            #a port which is not reachable cannot be proxied 
            return nil if !port.task.reachable?
            port = port.to_orocos_port
            options, policy = Kernel.filter_options options,
                :periodicity => nil,
                :keep_last_value => false

            if !reachable? 
                raise "Task #{name}: is not reachable. Cannot proxy connection #{port.full_name}"
            end

            if !port.respond_to? :reader
                raise "Port #{port.full_name} cannot be proxied because it is not an OutputPort"
            end

            if !isProxingPort(port.task.basename,port.name)
                load_plugins_for_type(port.orocos_type_name)
                con = Types::PortProxy::ProxyConnection.new
                con.task_name = port.task.basename
                con.port_name = port.name
                con.type_name = port.orocos_type_name
                con.periodicity = options[:periodicity]
                con.keep_last_value = options[:keep_last_value]
                con.check_periodicity = 1.0
                if !createProxyConnection(con)
                    raise "Task #{name}: Cannot generate proxy ports for #{port.full_name}"
                end
                Orocos.info "Task #{name}: Create port_proxy port for #{port.full_name}."
            end

            port_out = self.port(getOutputPortName(port.task.basename,port.name))
            if  port_out.orocos_type_name != port.orocos_type_name
                raise "Task #{name} cannot proxy port #{name} because the already existing proxy port has a different type!"
            end
            port_out
        end

        def delete_proxy_port(port)
            if closeProxyConnection(port.task.basename,port.name)
                Vizkit.info "Delete connection #{port.full_name}"
            else
                Vizkit.warn "Cannot delete connection #{port.full_name}"
            end
        end

        def delete_proxy_ports_for_task(task)
            if closeProxyConnection(port.task.basename,"")
                Vizkit.info "Delete connection for#{port.task.basename}"
            else
                Vizkit.warn "Cannot delete connection #{port.task.basename}"
            end
        end

        def tooling?
            true
        end

        def port(name,options=Hash.new)
            port = super 
            #prevents that the proxy is proxyied by an other proxy task
            def port.force_local?
                true
            end
            port
        end

        def port_full_name(port)
            #we have to generate the name by our self because subfield name have a different 
            #full_name but we want to use the same port of the port proxy
            full_name = "#{port.task.basename}_#{port.name}"
        end

        #loads the plugins (typekit,transport) into the proxy
        def load_plugins_for_type(type_name)
            #workaround for int types --> there is no plugin
            #TODO find a more generic solution
            if(type_name == "int" || type_name == "bool")
                Orocos.info "Task #{self.name}: ignore load_plugins_for_type because of type int"
                return true
            end
            name = Orocos.find_typekit_for(type_name)
            plugins = Orocos.plugin_libs_for_name(name)
            plugins.each do |kit|
                Orocos.info "Task #{self.name}: loading plugin #{kit} for type #{type_name}"
                if !loadTypekit(kit)
                    Orocos.warn "Task #{self.name} failed to load plugin #{kit} to access type #{type_name}! Is the task running on another machine ?"
                    return nil
                end
            end
            true
        rescue Interrupt
            raise
        rescue Exception => e
            Orocos.warn "failed to load plugins for #{type_name} on #{name}: #{e}"
            e.backtrace.each do |line|
                Orocos.warn "  #{line}"
            end
            return nil
        end

        #returns true if the proxy is proxing the given port
        #returns false if the proxy is not proxing the given port 
        def proxy_port?(port)
            return false if !isProxingPort(port.task.basename,port.name)
            true
        end
    end
end

