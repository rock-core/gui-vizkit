# Main Window setting up the ui
class CameraControlWidget < Qt::Widget 
  def initialize(parent = nil)
    super
    @camera = nil
    @gainMap = Hash.new
    @exposureMap = Hash.new
    @whitebalanceMap = Hash.new
    @triggerMap = Hash.new
    @gainMap['Manual'] = :GainModeToManual
    @gainMap['Auto'] = :GainModeToAuto
    @exposureMap['Manual'] = :ExposureModeToManual
    @exposureMap['Auto'] = :ExposureModeToAuto
    @exposureMap['Auto once'] = :ExposureModeToAutoOnce
    @exposureMap['External'] = :ExposureModeToExternal
    @whitebalanceMap['Manual'] = :WhitebalModeToManual
    @whitebalanceMap['Auto'] = :WhitebalModeToAuto
    @whitebalanceMap['Auto once'] = :WhitebalModeToAutoOnce
    @triggerMap['Fixed'] = :FrameStartTriggerModeToFixedRate
    @triggerMap['FreeRun'] = :FrameStartTriggerModeToFreerun
    @triggerMap['SyncIn1'] =  :FrameStartTriggerModeToSyncIn1

    @layout = Qt::GridLayout.new
    @widget = Vizkit.load File.join(File.dirname(__FILE__),'camera_control.ui'), self
    @layout.addWidget(@widget,0,0)
    self.setLayout @layout

    @widget.update_image.connect(SIGNAL('clicked()')) do
        frame = @reader.read
        @widget.image_view.display(frame,"") if frame
    end

    @widget.update_parameter.connect(SIGNAL('clicked()')) do
        #if the frame rate was changed we have to stop the camera
        if @camera.getDoubleRangeMin(:FrameRate) != @widget.spinbox_fps.value().to_f
            @camera.stop
            #this is a workaround as long the configure part of camera_base is still
            #in the startHook
            @camera.fps = @widget.spinbox_fps.value().to_f
            @camera.exposure = @widget.spinbox_exposure.value()
            @camera.gain = @widget.spinbox_gain.value()
            @camera.setDoubleAttrib(:FrameRate, @widget.spinbox_fps.value().to_f)
            @camera.start
        else
            @camera.setIntAttrib(:ExposureValue, @widget.spinbox_exposure.value())
            @camera.setIntAttrib(:GainValue, @widget.spinbox_gain.value())
        end

        @camera.setEnumAttrib(@triggerMap[@widget.combobox_trigger_mode.currentText])
        @camera.setEnumAttrib(@gainMap[@widget.combobox_gain_mode.currentText])
        @camera.setEnumAttrib(@exposureMap[@widget.combobox_exposure_mode.currentText])
        @camera.setEnumAttrib(@whitebalanceMap[@widget.combobox_whitebalance_mode.currentText])
    end
  end

  def config(task,options=Hash.new)
    @camera = task
    # setting various status text initializing combo box
    # texts
    @widget.label_camera_name.setText(@camera.getStringAttrib(:ModelName))
    @widget.statusLabel.setText(task.state.to_s)
    setComboBoxValues()

    # setting min max values for sliders
    @widget.slider_fps.setMinimum(@camera.getDoubleRangeMin(:FrameRate))
    @widget.spinbox_fps.setMinimum(@camera.getDoubleRangeMin(:FrameRate))
    @widget.slider_fps.setMaximum(@camera.getDoubleRangeMax(:FrameRate))
    @widget.spinbox_fps.setMaximum(@camera.getDoubleRangeMax(:FrameRate))
    @widget.slider_exposure.setMinimum(@camera.getIntRangeMin(:ExposureValue))
    @widget.spinbox_exposure.setMinimum(@camera.getIntRangeMin(:ExposureValue))
    @widget.slider_exposure.setMaximum(@camera.getIntRangeMax(:ExposureValue))
    @widget.spinbox_exposure.setMaximum(@camera.getIntRangeMax(:ExposureValue))
    @widget.slider_gain.setMinimum(@camera.getIntRangeMin(:GainValue))
    @widget.spinbox_gain.setMinimum(@camera.getIntRangeMin(:GainValue))
    @widget.slider_gain.setMaximum(@camera.getIntRangeMax(:GainValue))
    @widget.spinbox_gain.setMaximum(@camera.getIntRangeMax(:GainValue))

    @widget.slider_fps.setValue(@camera.getDoubleAttrib(:FrameRate))
    @widget.slider_exposure.setValue(@camera.getIntAttrib(:ExposureValue))
    @widget.slider_gain.setValue(@camera.getIntAttrib(:GainValue))

    @reader = @camera.frame.reader :pull => true
  end

  def setComboBoxValues()
      setComboBoxValue(@widget.combobox_gain_mode,@gainMap)
      setComboBoxValue(@widget.combobox_whitebalance_mode,@whitebalanceMap)
      setComboBoxValue(@widget.combobox_exposure_mode,@exposureMap)
      setComboBoxValue(@widget.combobox_trigger_mode,@triggerMap)
  end

  def setComboBoxValue(combobox,value_map)
      value_map.each_pair do |key, value|
          combobox.addItem(key)
      end
      value_map.each_with_index do |pair,index|
          if @camera.isEnumAttribSet(pair[1])
              combobox.setCurrentIndex(index)
              break
          end
      end
  end
end

Vizkit::UiLoader.register_ruby_widget "camera_control", CameraControlWidget.method(:new)
Vizkit::UiLoader.register_control_for "camera_control", "camera_base::Task", :config
