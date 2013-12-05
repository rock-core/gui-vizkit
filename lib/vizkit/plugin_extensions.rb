
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
            def eventFilter(obj,event)
                if event.is_a?(Qt::HideEvent)
                    @on_hide.call if @on_hide
                elsif event.is_a?(Qt::WindowStateChangeEvent)
                    window = obj
                    # Some objects are not windows, but we do want the window
                    # state. Look for a window in the hierarchy
                    while window && !window.respond_to?(:windowState)
                        window = window.parent
                    end
                    if window
                        if Qt::WindowMinimized == window.windowState
                            @on_hide.call if @on_hide
                        else
                            @on_show.call if @on_show
                        end
                    end
                elsif event.is_a?(Qt::ShowEvent)
                    @on_show.call if @on_show
                elsif event.is_a?(Qt::CloseEvent)
                    @on_hide.call if @on_hide
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
            attr_accessor :disconnect_on_hide

            def initialize(owner)
                super
                @disconnect_on_hide = true
                @filter = ShowHideEventFilter.new

                # we have to use an event filter because
                # c++ widgets cannot be overloaded
                owner.installEventFilter(@filter) if owner.is_a? Qt::Object
                @filter.on_hide do
                    disconnect if @disconnect_on_hide
                end
                @filter.on_show do
                    reconnect if @disconnect_on_hide
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
                    @on_data_listeners[port] << listener
                    listener
                end
            end
        end

        def connection_manager
            @connection_manager ||= ConnectionManager.new(self)
        end
    end
end
