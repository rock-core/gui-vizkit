require 'vizkit'

Orocos.initialize

widget = Vizkit.default_loader.CompoundDisplay

#widget.save
#widget.set_widget("mytask.myport", "2", nil)

[0,1,2,5].each do |num|
    widget.configure(num, CompoundDisplayConfig.new("front_camera", "frame", "ImageView", false))
end

widget.show
Vizkit.exec

