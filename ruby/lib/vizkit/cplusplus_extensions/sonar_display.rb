Vizkit::UiLoader::extend_cplusplus_widget_class "SonarDisplay" do
  def default_options()
      options = Hash.new
      return options
  end

  def display(sonar_beam,port_name)
     addSonarBeam(sonar_beam.bearing.rad+Math::PI,sonar_beam.beam.size-8,sonar_beam.beam.to_byte_array[8..-1])
  end
end

Vizkit::UiLoader.register_default_widget_for("SonarDisplay","/base/samples/SonarBeam",:display)
