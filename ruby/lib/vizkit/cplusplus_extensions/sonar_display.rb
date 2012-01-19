Vizkit::UiLoader::extend_cplusplus_widget_class "SonarDisplay" do
  def default_options()
      options = Hash.new
      return options
  end

  def display(sonar_beam,port_name)
      @resolution ||= 0.1
      @number_of_bins ||= 100

      angle = sonar_beam.bearing.rad + Math::PI*0.5 
      angle +=  Math::PI*2 if angle < 0
      data = sonar_beam.beam.to_byte_array[8..-1]
      resolution = sonar_beam.sampling_interval*sonar_beam.speed_of_sound*0.5

      if(@resolution != resolution || @number_of_bins < data.size)
          setUpSonar(72,data.size, 5.0/180*Math::PI,resolution,sonar_beam.beamwidth_vertical)
          @number_of_bins = data.size
          @resolution = resolution
      end

      addSonarBeam(angle,data.size,data)
  end
end

Vizkit::UiLoader.register_default_widget_for("SonarDisplay","/base/samples/SonarBeam",:display)
