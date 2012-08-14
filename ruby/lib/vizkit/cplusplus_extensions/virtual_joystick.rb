Vizkit::UiLoader.register_control_for("VirtualJoystick", "/base/MotionCommand2D") do |widget,port,options,block|
    unless port.to_orocos_port.is_a? Orocos::InputPort || block
        raise "VirtualJostick can only be connected to Orocos::InputPorts or code blocks"
    end
    widget.connect(SIGNAL('axisChanged(double,double)')) do |x, y|
        value = Types::Base::MotionCommand2D.new
	value.translation = x
	value.rotation =
	    if x == 0 && y == 0
		0
	    else
		-y.abs() * Math::atan2(y, x.abs())
	    end
        if block 
	    block.call(value)
        else
            Vizkit.warn "No block given: Cannot write motion command!"
        end
    end
end

