#prepares the c++ qt widget for the use in ruby with widget_grid

Vizkit::UiLoader::extend_cplusplus_widget_class "RangeView" do
  def default_options()
      options = Hash.new
      options[:time_overlay] = true
      return options
  end

  def save(path)
	saveImage2(path)
  end

  def save_frame(frame,path)
        saveImage3(frame.frame_mode.to_s,frame.pixel_size,frame.size.width,frame.size.height,frame.image.to_byte_array[8..-1],path)
  end

  #diplay is called each time new data are available on the orocos output port
  #this functions translates the orocos data struct to the widget specific format
  def display(range_scan,port_name)
    #check if type is frame_pair
    if !defined? @init
      @options ||= default_options
      @time_overlay_object = addText(-150,-5,0,"time")
      @time_overlay_object.setColor(Qt::Color.new(255,255,0))
      @time_overlay_object.setPosFactor(1,1);
      @time_overlay_object.setRenderOnOpenGl(true)
      @time_overlay_object.setBackgroundColor(Qt::Color.new(0,0,0,40))
      @init = true
      setOpenGL true
    end

    points = Array.new
    angle = range_scan.start_angle
    
    range_scan.ranges.each do |point|
	if point < range_scan.maxRange and point > range_scan.minRange 
		points.push(point/1e3 * Math.cos(angle))
		points.push(point/1e3 * Math.sin(angle))
		points.push 0.0
		angle = angle + range_scan.angular_resolution	
	end
    end
    setRangeScan3(points)
  end
end

Vizkit::UiLoader.register_widget_for("RangeView","/base/samples/LaserScan",:display)
