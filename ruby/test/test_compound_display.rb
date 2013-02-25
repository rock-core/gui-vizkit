require 'vizkit'

Orocos::CORBA.name_service.ip = '127.0.0.1'
Orocos.initialize

widget = Vizkit.default_loader.CompoundDisplay
widget.set_grid_dimensions(1,4)

if ARGV[0]
    replay = Orocos::Log::Replay.open(ARGV[0])
    #widget.configure_by_yaml("myconfig_avalon_obenlinks.yml")
    widget.configure(0, "front_camera", "frame", "ImageView")
    widget.connect(0)
    Vizkit.control replay
else
    widget.configure(5, "message_producer", "messages", "StructViewer")
end    

widget.show
Vizkit.exec
