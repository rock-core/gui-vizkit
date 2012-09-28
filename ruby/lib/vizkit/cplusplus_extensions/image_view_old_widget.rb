#prepares the c++ qt widget for the use in ruby with widget_grid

Vizkit::UiLoader::extend_cplusplus_widget_class "ImageViewOld" do
    
  #save all images which are displayed to the given folder 
  def save_images_to(folder)
      @folder_path = folder
  end

  def default_options()
      options = Hash.new
      options[:time_overlay] = true
      options[:fps_overlay] = true
      options[:display_first] = true
      options[:openGL] = true
      options[:use_typelib_adapter] = true
      options
  end

  def save(path)
	saveImage2(path)
  end

  def save_frame(frame,path)
    format = File.extname(path).sub!(/\./,"").upcase!
    format = "PNG" unless format
    saveImage3(frame.frame_mode.to_s,frame.pixel_size,frame.size.width,frame.size.height,frame.image.to_byte_array[8..-1],path,format)
  end

  def display2(frame_pair,port_name)
    init
    frame = @options[:display_first] == true ? frame_pair.first : frame_pair.second
    display(frame,port_name)
  end

  def options(hash = Hash.new)
    @options ||= default_options
    @options.merge!(hash)
  end

  def init 
    if !defined? @init
      @options ||= default_options
      openGL(@options[:openGL])
      @time_overlay_object = addText(-150,-5,0,"")
      @time_overlay_object.setColor(Qt::Color.new(255,255,0))
      @time_overlay_object.setPosFactor(1,1);
      @time_overlay_object.setBackgroundColor(Qt::Color.new(0,0,0,40))
      @fps_overlay_object = addText(5,-5,0,"   ")
      @fps_overlay_object.setColor(Qt::Color.new(255,255,0))
      @fps_overlay_object.setBackgroundColor(Qt::Color.new(0,0,0,40))
      @fps_overlay_object.setPosFactor(0,1);
      @folder_path ||= nil
      @isMinimized = false
      connect(SIGNAL("activityChanged(bool)"),self,:setActive)
      @init = true
    end
  end

  def setActive(active)
      if active	== true
          @isMinimized = false
      else
          @fps_overlay_object.setText("")
          @time_overlay_object.setText("")
          @isMinimized = true
      end
  end

  #display is called each time new data are available on the orocos output port
  #this functions translates the orocos data struct to the widget specific format
  def display(frame,port_name)
      init

      if @options[:time_overlay] and  @isMinimized == false
          if frame.time.instance_of?(Time)
              time = frame.time
          else
              time = Time.at(frame.time.seconds,frame.time.microseconds)
          end
          @time_overlay_object.setText(time.strftime("%b %d %Y %H:%M:%S"))
      end
      if @options[:fps_overlay] and @isMinimized == false
          stat = ''
          stat_valid = ''
          stat_invalid = ''
          frame.attributes.each do |x|
              stat =x.data_.to_s if x.name_ == 'StatFps'
              stat_valid =x.data_.to_s if x.name_ == 'StatValidFps'
              stat_invalid =x.data_.to_s if x.name_ == 'StatInValidFps'
          end
          @fps_overlay_object.setText(" stat fps: #{stat},  valid #{stat_valid}, invalid #{stat_invalid}")
      end
      if @options[:use_typelib_adapter]
        @typelib_adapter ||= Vizkit::TypelibQtAdapter.new(self)
        if !@typelib_adapter.call_qt_method("addFrame",frame,nil)
            Vizkit.warn "Cannot reach method addFrame. Disabling TypelibQtAdapter for widget #{self} and falling back to field access."
            @options[:use_typelib_adapter] = false
        end
      else
        addRawImage(frame.frame_mode.to_s,frame.pixel_size,frame.size.width,frame.size.height,frame.image.to_byte_array[8..-1],frame.image.size)
      end
      update2
  end
end

Vizkit::UiLoader.register_widget_for("ImageViewOld","/base/samples/frame/Frame",:display)
Vizkit::UiLoader.register_widget_for("ImageViewOld","/base/samples/frame/FramePair",:display2)
