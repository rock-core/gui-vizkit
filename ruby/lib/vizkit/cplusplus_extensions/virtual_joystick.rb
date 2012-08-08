Vizkit::UiLoader.register_control_for("VirtualJoystick", "/base/MotionCommand2D") do |widget,value,options,block|
    widget.connect(SIGNAL('axisChanged(double,double)')) do |x, y|
        value = Types::Base::MotionCommand2D.new
	value.translation = x
	value.rotation =
	    if x == 0 && y == 0
		0
	    else
		-y.abs() * Math::atan2(y, x.abs())
	    end
	block.call(value)
    end
end

