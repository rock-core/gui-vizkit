require 'eigen'

Vizkit::UiLoader.extend_cplusplus_widget_class "OrientationView" do 
  def update(sample,port_name)
      if sample.respond_to?(:orientation) # pose and rigid body state
          sample = sample.orientation
      end

      if !sample.kind_of?(Eigen::Quaternion)
          # The base typelib plugin is not loaded, do the convertions by ourselves
          sample = Eigen::Quaternion.new(sample.re, *sample.im.to_a)
      end

      angles = sample.to_euler(2,1,0)
      setPitchAngle(angles.y)
      setRollAngle(angles.z)
      setHeadingAngle(angles.x)
  end
end

Vizkit::UiLoader.register_default_widget_for("OrientationView",'/base/samples/RigidBodyState',:update)
Vizkit::UiLoader.register_widget_for("OrientationView",'/base/Orientation',:update)
Vizkit::UiLoader.register_widget_for("OrientationView",'/base/RigidBodyState',:update)
Vizkit::UiLoader.register_widget_for("OrientationView",'/base/samples/RigidBodyState',:update)
Vizkit::UiLoader.register_widget_for("OrientationView",'/base/Pose',:update)
