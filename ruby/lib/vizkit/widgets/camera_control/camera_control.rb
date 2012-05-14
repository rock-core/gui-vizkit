# Main Window setting up the ui
class CameraControlWidget < Qt::Widget 
  def initialize(parent = nil)
    super
    @camera = nil
    @gainMap = Hash.new
    @exposureMap = Hash.new
    @whitebalanceMap = Hash.new
    @gainMap['Manual'] = :GainModeToManual
    @gainMap['Auto'] = :GainModeToAuto
    @exposureMap['Manual'] = :ExposureModeToManual
    @exposureMap['Auto'] = :ExposureModeToAuto
    @exposureMap['Auto once'] = :ExposureModeToAutoOnce
    @exposureMap['External'] = :ExposureModeToExternal
    @whitebalanceMap['Manual'] = :WhitebalModeToManual
    @whitebalanceMap['Auto'] = :WhitebalModeToAuto
    @whitebalanceMap['Auto once'] = :WhitebalModeToAutoOnce

    @layout = Qt::GridLayout.new
    @widget = Vizkit.load File.join(File.dirname(__FILE__),'camera_control.ui'), self
    @layout.addWidget(@widget,0,0)
    self.setLayout @layout

    @widget.slider_fps.connect(SIGNAL('valueChanged(int)')) do |val|
        @widget.spinbox_gain.setValue int
    end
       
    @widget.update_image.connect(SIGNAL('clicked()')) do
        frame = @reader.read
        @widget.image_view.display(frame,"") if frame
    end

    @widget.update_parameter.connect(SIGNAL('clicked()')) do
        @camera.setDoubleAttrib(:FrameRate, @widget.spinbox_fps.value())
        @camera.setIntAttrib(:ExposureValue, @widget.spinbox_exposure.value())
        @camera.setIntAttrib(:GainValue, @widget.spinbox_gain.value())
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
    fillComboBox(@widget.combobox_gain_mode, @gainMap)
    fillComboBox(@widget.combobox_exposure_mode, @exposureMap)
    fillComboBox(@widget.combobox_whitebalance_mode, @whitebalanceMap)
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
      index = 0
      if(@camera.isEnumAttribSet(:GainModeToManual))
          index = getMapIndex(@gainMap, :GainModeToManual)
      else
          index = getMapIndex(@gainMap, :GainModeToAuto)
      end
      @widget.combobox_gain_mode.setCurrentIndex(index)
      index = 0
      if(@camera.isEnumAttribSet(:WhitebalModeToManual))
          index = getMapIndex(@whitebalanceMap, :WhitebalModeToManual)
      elsif(@camera.isEnumAttribSet(:WhitebalModeToAuto))
          index = getMapIndex(@whitebalanceMap, :WhitebalModeToAuto)
      else
          index = getMapIndex(@whitebalanceMap, :WhitebalModeToAutoOnce)
      end
      @widget.combobox_whitebalance_mode.setCurrentIndex(index)
      index = 0
      if(@camera.isEnumAttribSet(:ExposureModeToManual))
          index = getMapIndex(@exposureMap, :ExposureModeToManual)
      elsif(@camera.isEnumAttribSet(:ExposureModeToAuto))
          index = getMapIndex(@exposureMap, :ExposureModeToAuto)
      elsif(@camera.isEnumAttribSet(:ExposureModeToAutoOnce))
          index = getMapIndex(@exposureMap, :ExposureModeToAutoOnce)
      else
          index = getMapIndex(@exposureMap, :ExposureModeToExternal)
      end
      @widget.combobox_exposure_mode.setCurrentIndex(index)
  end

  def getMapIndex(hash, searchValue)
      index = 0
      hash.each_value do |value|
          if(value == searchValue)
              return index;
          end
          index = index + 1
      end
  end

  def fillComboBox(combobox, hash)
      hash.each_pair do |key, value|
          combobox.addItem(key)
      end
  end
end

Vizkit::UiLoader.register_ruby_widget "CameraControl", CameraControlWidget.method(:new)
Vizkit::UiLoader.register_control_for "CameraControl", "camera_base::Task", :config
Vizkit::UiLoader.register_deprecate_plugin_clone("camera_control","CameraControl")

