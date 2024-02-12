Vizkit::UiLoader.register_control_for("VirtualJoystick", "/base/commands/Motion2D") do |widget,port,options,block|
    unless port.to_orocos_port.is_a? Orocos::InputPort || block
        raise "VirtualJostick can only be connected to Orocos::InputPorts or code blocks"
    end

    widget.connect(SIGNAL('axisChanged(double,double)')) do |x, y|
        value = Types.base.commands.Motion2D.new
        # the heading from Motion2D.new here is only almost 0 (2.2469905698352052e-307) due to cpp/ruby, set it to exactly 0 (as Motion2d initializes it in its constructor) to avoud occational NaN
        value.heading.rad = 0
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
            port.write value do
            end
        end
    end
end

