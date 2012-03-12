Vizkit::UiLoader.register_control_for("VirtualJoystick", "/base/MotionCommand2D") do |widget,value,options,block|
    widget.connect(SIGNAL('axisChanged(double,double)')) do |x, y|
        value = Types::Base::MotionCommand2D.new
	value.translation = x
	value.rotation = - y.abs() * Math::atan2(y, x.abs())
	block.call(value)
    end
end

