require 'vizkit'

Orocos::CORBA.name_service.ip = '127.0.0.1'
Orocos.initialize

widget = Vizkit.default_loader.CompoundDisplay

if ARGV[0]
    replay = Orocos::Log::Replay.open(ARGV[0])
    widget.replay_mode(replay)
    widget.configure_by_yaml("myconfig_avalon_obenlinks.yml")
    widget.configure(0, CompoundDisplayConfig.new("front_camera", "frame", "ImageView", false))
    #widget.configure(1, CompoundDisplayConfig.new("uw_portal", "rigid_body_state", "OrientationView", false))
    Vizkit.control replay
else
    widget.configure(5, CompoundDisplayConfig.new("message_producer", "messages", "StructViewer", false))
end    

widget.show
Vizkit.exec

