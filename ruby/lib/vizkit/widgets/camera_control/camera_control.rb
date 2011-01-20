require 'Qt4'

require 'orocos'
require File.join(File.dirname(__FILE__),'camera_control.ui')

#include Orocos
#Orocos.initialize

# Main Window setting up the ui
class CameraControlWidget < Qt::Widget

  slots 'fpsChanged()','exposureChanged()','gainChanged()', 'gainModeChanged(QString)', 'exposureModeChanged(QString)', 'whitebalanceModeChanged(QString)'
  @camera = nil
  # Sets up the window and connects
  # signals and slots
  # tries to connect to the camera
  # task and configures and starts it
  def initialize(parent = nil)
    super
    setFixedSize(460, 280)
    
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

    @control = Ui_CameraControl.new
    @control.setupUi self
       
    #connecting signals slots
    connect(@control.slider_fps, SIGNAL('sliderReleased()'), self, SLOT('fpsChanged()'))
    connect(@control.slider_exposure, SIGNAL('sliderReleased()'), self, SLOT('exposureChanged()'))
    connect(@control.slider_gain, SIGNAL('sliderReleased()'), self, SLOT('gainChanged()'))
    connect(@control.spinbox_fps, SIGNAL('valueChanged(int)'), self, SLOT('fpsChanged()'))
    connect(@control.spinbox_exposure, SIGNAL('valueChanged(int)'), self, SLOT('exposureChanged()'))
    connect(@control.spinbox_gain, SIGNAL('valueChanged(int)'), self, SLOT('gainChanged()'))
    connect(@control.combobox_gain_mode, SIGNAL('activated(QString)'), self, SLOT('gainModeChanged(QString)'))
    connect(@control.combobox_exposure_mode, SIGNAL('activated(QString)'), self, SLOT('exposureModeChanged(QString)'))
    connect(@control.combobox_whitebalance_mode, SIGNAL('activated(QString)'), self, SLOT('whitebalanceModeChanged(QString)'))
  end

  def control(task,options=Hash.new)
    @camera = task
    # setting various status text initializing combo box
    # texts
    @control.label_camera_name.setText(@camera.getStringAttrib(:ModelName))
    @control.statusLabel.setText("Connected")
    fillComboBox(@control.combobox_gain_mode, @gainMap)
    fillComboBox(@control.combobox_exposure_mode, @exposureMap)
    fillComboBox(@control.combobox_whitebalance_mode, @whitebalanceMap)
    setComboBoxValues()
    # setting min max values for sliders
    @control.slider_fps.setMinimum(@camera.getDoubleRangeMin(:FrameRate))
    @control.spinbox_fps.setMinimum(@camera.getDoubleRangeMin(:FrameRate))
    @control.slider_fps.setMaximum(@camera.getDoubleRangeMax(:FrameRate))
    @control.spinbox_fps.setMaximum(@camera.getDoubleRangeMax(:FrameRate))
    @control.slider_exposure.setMinimum(@camera.getIntRangeMin(:ExposureValue))
    @control.spinbox_exposure.setMinimum(@camera.getIntRangeMin(:ExposureValue))
    @control.slider_exposure.setMaximum(@camera.getIntRangeMax(:ExposureValue))
    @control.spinbox_exposure.setMaximum(@camera.getIntRangeMax(:ExposureValue))
    @control.slider_gain.setMinimum(@camera.getIntRangeMin(:GainValue))
    @control.spinbox_gain.setMinimum(@camera.getIntRangeMin(:GainValue))
    @control.slider_gain.setMaximum(@camera.getIntRangeMax(:GainValue))
    @control.spinbox_gain.setMaximum(@camera.getIntRangeMax(:GainValue))
    # setting actual values taken from the camera
    @control.spinbox_fps.setValue(@camera.getDoubleAttrib(:FrameRate))
    @control.spinbox_exposure.setValue(@camera.getIntAttrib(:ExposureValue))
    @control.spinbox_gain.setValue(@camera.getIntAttrib(:GainValue))
  end

  def setComboBoxValues()
    index = 0
    if(@camera.isEnumAttribSet(:GainModeToManual))
      index = getMapIndex(@gainMap, :GainModeToManual)
    else
      index = getMapIndex(@gainMap, :GainModeToAuto)
    end
    @control.combobox_gain_mode.setCurrentIndex(index)
    index = 0
    if(@camera.isEnumAttribSet(:WhitebalModeToManual))
      index = getMapIndex(@whitebalanceMap, :WhitebalModeToManual)
    elsif(@camera.isEnumAttribSet(:WhitebalModeToAuto))
      index = getMapIndex(@whitebalanceMap, :WhitebalModeToAuto)
    else
      index = getMapIndex(@whitebalanceMap, :WhitebalModeToAutoOnce)
    end
    @control.combobox_whitebalance_mode.setCurrentIndex(index)
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
    @control.combobox_exposure_mode.setCurrentIndex(index)
  end

  def gainModeChanged(value)
    @camera.setEnumAttrib(@gainMap[value])
  end

  def exposureModeChanged(value)
    @camera.setEnumAttrib(@exposureMap[value])
  end

  def whitebalanceModeChanged(value)
    @camera.setEnumAttrib(@whitebalanceMap[value])
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

  # called when the fps slider was moved
  def fpsChanged()
    @camera.setDoubleAttrib(:FrameRate, @control.spinbox_fps.value())
    print "Changed frame rate to: #{@control.spinbox_fps.value()}\n"
  end

  def exposureChanged()
    @camera.setIntAttrib(:ExposureValue, @control.spinbox_exposure.value())
    print "Changed exposure to: #{@control.spinbox_exposure.value()}\n"
  end

  def gainChanged()
    @camera.setIntAttrib(:GainValue, @control.spinbox_gain.value())
    print "Changed gain to: #{@control.spinbox_gain.value()}\n"
  end
  
  def self.default_control_widget
    ['camera::CameraTask']
  end

end

Vizkit::UiLoader.register_ruby_widget "CameraControl", CameraControlWidget.method(:new)
