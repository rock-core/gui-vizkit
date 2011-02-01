
class ActuatorControl
  module Functions
    def control(task_context,options=Hash.new)
      connect(slider1,SIGNAL('valueChanged(int)'),spinBox,SLOT("setValue(int)"))
      pushButton.connect(SIGNAL(:clicked),self,:button_clicked)
      @task_context = task_context
      #     @writer = task_context.name_orocos_port.writer 
    end

    def button_clicked
      #     sample = @writer.new_sample
      #     sample.field1 = 123
      #      @writer.write(sample)
      puts '123'
    end
  end 

  def self.create_widget(parent = nil)
    form = Vizkit.load(File.join(File.dirname(__FILE__),'actuator_control.ui'),parent)
    form.extend Functions
    form
  end
end

Vizkit::UiLoader.register_ruby_widget('ActuatorControl',ActuatorControl.method(:create_widget))
