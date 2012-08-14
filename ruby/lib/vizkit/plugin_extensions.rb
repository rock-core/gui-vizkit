
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
    # This module is included in all Qt widgets to make sure that the basic
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
end
