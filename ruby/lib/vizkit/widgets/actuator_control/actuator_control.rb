class ActuatorControl
	module Functions
		def initialise
			# Connection betwenn the Signal and slot of sliders and spinbox is done using QT designer
     			surge_slider.connect(SIGNAL('valueChanged(int)'),self,:surgevalue)
			sway_slider.connect(SIGNAL('valueChanged(int)'),self,:swayvalue)
			heave_slider.connect(SIGNAL('valueChanged(int)'),self,:heavevalue)
			roll_slider.connect(SIGNAL('valueChanged(int)'),self,:rollvalue)
			pitch_slider.connect(SIGNAL('valueChanged(int)'),self,:pitchvalue)
			yaw_slider.connect(SIGNAL('valueChanged(int)'),self,:yawvalue)

       			activateGui_checkBox.connect(SIGNAL('stateChanged(int)'),self,:activate_gui)   
       			pwmCtrl_checkBox.connect(SIGNAL('stateChanged(int)'),self,:pwmCtrl)   
       			speedCtrl_checkBox.connect(SIGNAL('stateChanged(int)'),self,:speedCtrl)  
			
			# A local storage variable before sending the Gui output
			@op_message = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
			puts "now follows the op_message"
			puts @op_message
			puts "done"
                        puts @op_message.methods	
			#@op_mode    = 0
			# A flag for checking whether activate_gui_control check box is checked or not
			@_activategui = false
		end

    		def control(task_context,options=Hash.new) 			
			@task_context = task_context
      			@writer = task_context.actuator_command.writer 

			# Timer for sending command to Motor
			@send_timer = Qt::Timer.new(self)
			@send_timer.connect(SIGNAL(:timeout),self,:send_GuiValue)
    		end

		def activate_gui(_activatekey)
			if (_activatekey == 0 )
				@_activategui = false
				@send_timer.stop if @send_timer
			elsif (_activatekey == 2 )
				@_activategui = true
				@send_timer.start(50) if @send_timer
			end
			
			# Slider
			surge_slider.setEnabled(@_activategui);
			sway_slider.setEnabled(@_activategui);
			heave_slider.setEnabled(@_activategui);			
			roll_slider.setEnabled(@_activategui);
			pitch_slider.setEnabled(@_activategui);
			yaw_slider.setEnabled(@_activategui);
			# Spinbox
			surge_spinBox.setEnabled(@_activategui);
			sway_spinBox.setEnabled(@_activategui);
			heave_spinBox.setEnabled(@_activategui);
			roll_spinBox.setEnabled(@_activategui);
			pitch_spinBox.setEnabled(@_activategui);
			yaw_spinBox.setEnabled(@_activategui);
		end

		def pwmCtrl(_ctrlKey)
			if (_ctrlKey == 2)
				@op_mode = 0				 
	       		end
       		end

	       	def speedCtrl(_ctrlKey)
       			if (_ctrlKey == 2)
				@op_mode = 1				
       			end
	       	end

  		def surgevalue(_surgevalue)
			@op_message[0] = _surgevalue
     		end    
  		def swayvalue(_swayvalue)
      			@op_message[1] = _swayvalue
          	end    
	      	def heavevalue(_heavevalue)
        	       	@op_message[2] = _heavevalue
	      	end    
 		def rollvalue(_rollvalue)
         		@op_message[3] = _rollvalue
 		end    
 		def pitchvalue(_pitchvalue)
      			@op_message[4] = _pitchvalue
	       	end    
 		def yawvalue(_yawvalue)
           		@op_message[5] = _yawvalue
 		end    

 		def update(input_gui, port_name)			
			
			target = input_gui.target.to_a
			#mode = input_gui.mode.to_a
	      		# Reading the value from the joystick
	      		_surgevalue 	= ( target[0] * 100 )
	      		_swayvalue 	= ( target[1] * 100 )
	      		_heavevalue 	= ( target[2] * 100 )
	      		_rollvalue 	= ( target[3] * 100 )
	      		_pitchvalue 	= ( target[4] * 100 )
	      		_yawvalue 	= ( target[5] * 100 )

			#_surgemode 	= mode[0]
			#_swaymode 	= mode[1]
			#_heavemode 	= mode[2]
			#_rollmode 	= mode[3]
			#_pitchmode 	= mode[4]
			#_yawmmmode 	= mode[5]


	      		# Setting the joystick value to the gui
			if (@_activategui == false)
		      		surge_slider.setValue(_surgevalue)
	      			sway_slider.setValue(_swayvalue)
	  			heave_slider.setValue(_heavevalue)
				roll_slider.setValue(_rollvalue)
				pitch_slider.setValue(_pitchvalue)
				yaw_slider.setValue(_yawvalue)			
                                @writer.write input_gui if @writer
			end
	       	end     

		def send_GuiValue
			output_gui = @writer.new_sample
			for i in 0..5 do
				output_gui.target.push(@op_message[i].to_f / 100)
				output_gui.mode.push(:DM_UNINITIALIZED)
			end
			# Send Gui value
			@writer.write output_gui
		end			
  	end 	
	
	def self.create_widget(parent = nil)		
    		form = Vizkit.load(File.join(File.dirname(__FILE__),'actuator_control.ui'),parent)			
    		form.extend Functions	
                form.initialise
    		form
  	end
end

Vizkit::UiLoader.register_ruby_widget('ActuatorControl',ActuatorControl.method(:create_widget))
Vizkit::UiLoader.register_widget_for('ActuatorControl','/base/actuators/Command')

