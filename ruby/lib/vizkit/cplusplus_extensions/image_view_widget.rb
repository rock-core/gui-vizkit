#prepares the c++ qt widget for the use in ruby with widget_grid

Vizkit::UiLoader::extend_cplusplus_widget_class "ImageView" do
  
  def default_options()
      options = Hash.new
      options[:time_overlay] = true
      options[:display_first] = true
      options
  end
    
  def init
      if !defined? @init
          @options ||= default_options
          #connect(SIGNAL("activityChanged(bool)"),self,:setActive)
          @init = true
      end
  end

  def display2(frame_pair,port_name)
      init
      frame = @options[:display_first] == true ? frame_pair.first : frame_pair.second
      display(frame,port_name)
  end

  #display is called each time new data are available on the orocos output port
  #this functions translates the orocos data struct to the widget specific format
  def display(frame,port_name)
      init

      if @options[:time_overlay]
          if frame.time.instance_of?(Time)
              time = frame.time
          else
              time = Time.at(frame.time.seconds,frame.time.microseconds)
          end
          addTextWrapper(time.strftime("%F %H:%M:%S"), :bottomright, Qt::Color.new(Qt::black), false)
      end

      @typelib_adapter ||= Vizkit::TypelibQtAdapter.new(self)
      if !@typelib_adapter.call_qt_method("setFrame",frame)
          Vizkit.warn "Cannot reach method setFrame."
          Vizkit.warn "This happens if an old log file is replayed and the type has changed."
          Vizkit.warn "Call rock-convert to update the logfile."
      end
      update2
  end

  def addTextWrapper(text, location, color, persistent)
      locationMap = {:topleft => 0,
          :topright => 1,
          :bottomleft => 2,
          :bottomright => 3}
      addText(text, locationMap[location], color, persistent)
  end

end

Vizkit::UiLoader.register_default_widget_for("ImageView","/base/samples/frame/Frame",:display)
Vizkit::UiLoader.register_default_widget_for("ImageView","/base/samples/frame/FramePair",:display2)

