require 'vizkit'

widget = Vizkit.default_loader.CompoundDisplay

widget.save
widget.set_widget("mytask.myport", "2", nil)

widget.show
Vizkit.exec

