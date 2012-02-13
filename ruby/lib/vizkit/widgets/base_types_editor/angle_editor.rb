#!/usr/bin/env ruby

class AngleEditor < Qt::Widget

    def initialize(parent=nil)
        super
        setWindowTitle("AngleEditor")
        @layout = Qt::GridLayout.new
        self.setLayout @layout
        @callback_angle = nil;
        @angle = nil

        @label = Qt::Label.new
        @label.setText("Angle[Deg]")
        @layout.addWidget(@label,0,0)

        @spin_box = Qt::DoubleSpinBox.new
        @spin_box.setMaximum(180.0)
        @spin_box.setMinimum(-180.0)
        @spin_box.setSingleStep(1.0)
        @layout.addWidget(@spin_box,0,1)

        @button_cancel = Qt::PushButton.new(@widget)
        @button_cancel.setText("Cancel")
        @layout.addWidget(@button_cancel,1,0)
        @button_cancel.connect(SIGNAL("clicked()")) do 
            close()
        end

        @button = Qt::PushButton.new(@widget)
        @button.setText("Ok")
        @layout.addWidget(@button,1,1)
        @button.connect(SIGNAL("clicked()")) do 
            if(@callback_angle)
                Orocos.load_typekit_for("/base/Angle",false)
                angle = @angle ? @angle : Types::Base::Angle.new
                angle.rad = @spin_box.value()*Math::PI/180
                @callback_angle.call(angle)
            else
                puts "No callback function to forward the angle"
            end
        end
    end

    def default_options
        options = Hash.new
    end

    def options(hash = Hash.new)
        @options ||= default_options
        @options.merge!(hash)
    end

    def angle(angle=nil,options=nil,&block)
        @angle = angle
        @callback_angle = block
    end
end

Vizkit::UiLoader.register_ruby_widget("AngleEditor",AngleEditor.method(:new))
Vizkit::UiLoader.register_control_for("AngleEditor",Types::Base::Angle,:angle)
