require 'vizkit'

Orocos::CORBA.name_service.ip = '127.0.0.1'
Orocos.initialize

widget = Vizkit.default_loader.CompoundDisplay

#[0,1,2,5].each do |num|
#    widget.configure(num, CompoundDisplayConfig.new("front_camera", "frame", "ImageView", false))
#end




replay = Orocos::Log::Replay.open(ARGV[0])

#task = Orocos.name_service.get 'front_camera'

#widget.show_menu false
widget.replay_mode(replay)

#0.upto(5).each do |num|
    widget.configure(0, CompoundDisplayConfig.new("camera", "frame", "ImageView", false))
    widget.configure(1, CompoundDisplayConfig.new("uw_portal", "rigid_body_state", "OrientationView", false))
    #debugger
    #widget.connect_port_object(num, replay.tasks.first.frame) # TODO access task by string
#end

Vizkit.control replay

widget.show
Vizkit.exec

