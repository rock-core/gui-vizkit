require 'orocos/uri'

class Module
    # Shortcut to define the necessary methods so that a module can be used to
    # "subclass" a Qt widget
    #
    # This is done with
    #
    #   require 'vizkit'
    #   module MapView
    #     vizkit_subclass_of 'ImageView'
    #   end
    #   Vizkit::UILoader.register_ruby_widget 'MapView', MapView.method(:new)
    #
    # If some initial configuration is needed, one should define the 'setup'
    # singleton method:
    #
    #   module MapView
    #     vizkit_subclass_of 'ImageView'
    #     def self.setup(obj)
    #       obj.setAspectRatio(true)
    #     end
    #   end
    #
    def vizkit_subclass_of(class_name)
        class_eval do
            def self.new
                widget = Vizkit.default_loader.send(class_name)
                widget.extend self
                widget
            end
            def self.extended(obj)
                if respond_to?(:setup)
                    setup(obj)
                end
            end
        end
    end
end

module Vizkit
    # This module is included in all C++ Qt widgets to make sure that the basic
    # Vizkit API is available on them
    module VizkitCXXExtension
        # Called when a C++ widget is created to do some additional
        # ruby-side initialization
        def initialize_vizkit_extension
            super if defined? super
        end

        def pretty_print(pp)
            plugin_spec.pretty_print(self)
        end

        def registered_for
            loader.registered_for(self)
        end
    end


    # This module is included in all C++ and ruby Qt widgets to support
    # connection management for orocos ports
    module PluginConnections
        class ShowHideEventFilter < ::Qt::Object
            signals 'contextMenuRequest(QContextMenuEvent*)'
        
            def eventFilter(obj,event)
                if event.is_a?(Qt::HideEvent)
                    @on_hide.call if @on_hide
                elsif event.is_a?(Qt::WindowStateChangeEvent)
                    if Qt::WindowMinimized == obj.windowState
                        @on_hide.call if @on_hide
                    else
                        @on_show.call if @on_show
                    end
                elsif event.is_a?(Qt::ShowEvent)
                    @on_show.call if @on_show
                elsif event.is_a?(Qt::CloseEvent)
                    @on_hide.call if @on_hide
                elsif event.is_a?(Qt::ContextMenuEvent)
                    emit contextMenuRequest(event)
                end
                return false
            end

            def on_show(&block)
                @on_show = block
            end

            def on_hide(&block)
                @on_hide = block
            end
        end

        class ConnectionManager < Vizkit::ConnectionManager
            class ConnectionAction < Qt::Action
                attr_reader :uri
                attr_reader :connection_manager
                def initialize(title, uri, connection_manager, parent)
                    super(title, parent)
                    @uri = uri
                    @connection_manager = connection_manager
                    
                    connect(SIGNAL 'triggered(bool)') do |_|
                        handle
                    end
                end
            end
            class DeleteAction < ConnectionAction
                def initialize(uri, connection_manager, parent)
                    super("Delete", uri, connection_manager, parent)
                end
                
                def handle
                    connection_manager.delete(uri.port_proxy)
                end
            end
            class DisconnectAction < ConnectionAction
                def initialize(uri, connection_manager, parent)
                    super("Disconnect", uri, connection_manager, parent)
                end
                
                def handle
                    connection_manager.disconnect(uri.port_proxy)
                end
            end
            class ReconnectAction < ConnectionAction
                def initialize(uri, connection_manager, parent)
                    super("Reconnect", uri, connection_manager, parent)
                end
                
                def handle
                    connection_manager.reconnect(uri.port_proxy)
                end
            end
            
            attr_accessor :disconnect_on_hide
            attr_accessor :allow_multiple_connections
            attr_accessor :provide_own_context_menu

            def initialize(owner)
                super
                @disconnect_on_hide = true
                @allow_multiple_connections = false
                @provide_own_context_menu = false
                                
                @filter = ShowHideEventFilter.new
                # we have to use an event filter because
                # c++ widgets cannot be overloaded
                owner.installEventFilter(@filter)
                @filter.on_hide do
                    disconnect if @disconnect_on_hide
                end
                @filter.on_show do
                    reconnect if @disconnect_on_hide
                end
                @filter.connect(SIGNAL 'contextMenuRequest(QContextMenuEvent*)') do |event|
                    # Does the widget manage its own context menu?
                    unless @provide_own_context_menu
                        # No. Then display connections in a context menu.
                        # The relevant action handles are called
                        # automatically when the action is triggered.
                        menu = Qt::Menu.new(owner)
                        menu.add_menu(connection_menu(menu))
                        #menu.add_action("OtherStuff")
                        ContextMenu.advanced(menu, event.global_pos)
                    else
                        # If the owner provides an own context menu, he has to add the
                        # connection menu to it. Use #connection_menu.
                        #
                        # TODO Currently not possible for C++ widgets.
                    end
                end

            end

            def callback_for(type_name)
                fct = @owner.plugin_spec.find_callback!  :argument => type_name, :callback_type => :display
                if fct
                    fct.bind(@owner)
                else
                    raise Orocos::NotFound,"#{@owner.class_name} has no callback for #{type_name}"
                end
            end

            def connect_to(port,callback=nil,options=Hash.new,&block)
                unless @on_data_listeners[port].empty?
                    Vizkit.warn "You may not register multiple listeners on the same port."
                    return nil
                end
            
                raise_error = lambda do 
                    raise "no callback found for#{port} and #{@owner}"
                end
                if(@owner.respond_to?(:config) && @owner.config(port,options,&block) == :do_not_connect)
                    Vizkit.info "Disable auto connect for #{@owner} because config returned :do_not_connect"
                    nil
                elsif !port.respond_to?(:type?)
                    callback ||= callback_for(port)
                    raise_error.call unless callback
                    callback.call(port)
                else
                    callback ||= if port.type?
                                     callback_for(port.type_name)
                                 else
                                     listener = port.once_on_reachable do
                                         @on_reachable_listeners[port].delete listener
                                         callback = callback_for(port.type_name)
                                         raise_error.call unless callback
                                     end
                                     @on_reachable_listeners[port] << listener
                                 end
                    raise_error.call unless callback
                    Vizkit.info "Create new Connection for #{port.name} and #{@owner || callback}"
                    listener = port.on_data do |data|
                        callback.call data,port.full_name
                    end
                    
                    unless @allow_multiple_connections
                        # Remove all listeners on this port.
                        delete(port)
                    end
                    
                    @on_data_listeners[port] << listener
                    
                    listener
                end
            end
            
            def connect_to_uri(uri,callback=nil,options=Hash.new,&block)
                Kernel.raise("Not a valid uri: #{uri.class}") unless uri.is_a? URI::Orocos
                Kernel.raise("Cannot get port proxy from URI.") unless uri.port_proxy?

                port = uri.port_proxy
                connect_to(port,callback,options,&block)
            end
            
            def has_connection?
                connections.empty?
            end
            
            # Return all ports as URIs where listeners are installed.
            def connections
                list = []
                
                @on_data_listeners.each do |port, listeners|
                    listeners.each do |l|
                        list << URI::Orocos.from_port(port)
                    end
                end
                list
            end
            
            def connection_menu(parent)
                menu = Qt::Menu.new("Connections", parent)
                connections.each do |conn|
                    sub_menu = Qt::Menu.new("#{conn.task_name}:#{conn.port_name}", menu)
                    menu.add_menu(sub_menu)
                    sub_menu.add_action(ReconnectAction.new(conn, self, sub_menu))
                    sub_menu.add_action(DisconnectAction.new(conn, self, sub_menu))
                    sub_menu.add_action(DeleteAction.new(conn, self, sub_menu))
                end
                menu
            end
        end

        def connection_manager
            @connection_manager ||= ConnectionManager.new(self)
        end
    end
end
