=begin
** Form generated from reading ui file 'camera_control.ui'
**
** Created: Di. Jun 15 16:05:03 2010
**      by: Qt User Interface Compiler version 4.6.2
**
** WARNING! All changes made in this file will be lost when recompiling ui file!
=end

class Ui_CameraControl
    attr_reader :gridLayoutWidget
    attr_reader :gridLayout
    attr_reader :spinbox_gain
    attr_reader :label_3
    attr_reader :slider_fps
    attr_reader :spinbox_fps
    attr_reader :label
    attr_reader :slider_exposure
    attr_reader :label_2
    attr_reader :slider_gain
    attr_reader :spinbox_exposure
    attr_reader :label_4
    attr_reader :label_6
    attr_reader :combobox_exposure_mode
    attr_reader :combobox_whitebalance_mode
    attr_reader :label_5
    attr_reader :combobox_gain_mode
    attr_reader :label_8
    attr_reader :label_7
    attr_reader :label_camera_name
    attr_reader :statusLabel

    def setupUi(cameraControl)
    if cameraControl.objectName.nil?
        cameraControl.objectName = "cameraControl"
    end
    cameraControl.resize(463, 283)
    @gridLayoutWidget = Qt::Widget.new(cameraControl)
    @gridLayoutWidget.objectName = "gridLayoutWidget"
    @gridLayoutWidget.geometry = Qt::Rect.new(10, 10, 441, 261)
    @gridLayout = Qt::GridLayout.new(@gridLayoutWidget)
    @gridLayout.objectName = "gridLayout"
    @gridLayout.setContentsMargins(0, 0, 0, 0)
    @spinbox_gain = Qt::SpinBox.new(@gridLayoutWidget)
    @spinbox_gain.objectName = "spinbox_gain"

    @gridLayout.addWidget(@spinbox_gain, 4, 2, 1, 1)

    @label_3 = Qt::Label.new(@gridLayoutWidget)
    @label_3.objectName = "label_3"

    @gridLayout.addWidget(@label_3, 2, 0, 1, 1)

    @slider_fps = Qt::Slider.new(@gridLayoutWidget)
    @slider_fps.objectName = "slider_fps"
    @slider_fps.orientation = Qt::Horizontal

    @gridLayout.addWidget(@slider_fps, 2, 1, 1, 1)

    @spinbox_fps = Qt::SpinBox.new(@gridLayoutWidget)
    @spinbox_fps.objectName = "spinbox_fps"

    @gridLayout.addWidget(@spinbox_fps, 2, 2, 1, 1)

    @label = Qt::Label.new(@gridLayoutWidget)
    @label.objectName = "label"

    @gridLayout.addWidget(@label, 3, 0, 1, 1)

    @slider_exposure = Qt::Slider.new(@gridLayoutWidget)
    @slider_exposure.objectName = "slider_exposure"
    @slider_exposure.minimum = 1000
    @slider_exposure.maximum = 100000
    @slider_exposure.orientation = Qt::Horizontal

    @gridLayout.addWidget(@slider_exposure, 3, 1, 1, 1)

    @label_2 = Qt::Label.new(@gridLayoutWidget)
    @label_2.objectName = "label_2"

    @gridLayout.addWidget(@label_2, 4, 0, 1, 1)

    @slider_gain = Qt::Slider.new(@gridLayoutWidget)
    @slider_gain.objectName = "slider_gain"
    @slider_gain.orientation = Qt::Horizontal

    @gridLayout.addWidget(@slider_gain, 4, 1, 1, 1)

    @spinbox_exposure = Qt::SpinBox.new(@gridLayoutWidget)
    @spinbox_exposure.objectName = "spinbox_exposure"
    @spinbox_exposure.minimum = 1000
    @spinbox_exposure.maximum = 1000000

    @gridLayout.addWidget(@spinbox_exposure, 3, 2, 1, 1)

    @label_4 = Qt::Label.new(@gridLayoutWidget)
    @label_4.objectName = "label_4"

    @gridLayout.addWidget(@label_4, 6, 0, 1, 1)

    @label_6 = Qt::Label.new(@gridLayoutWidget)
    @label_6.objectName = "label_6"

    @gridLayout.addWidget(@label_6, 7, 0, 1, 1)

    @combobox_exposure_mode = Qt::ComboBox.new(@gridLayoutWidget)
    @combobox_exposure_mode.objectName = "combobox_exposure_mode"

    @gridLayout.addWidget(@combobox_exposure_mode, 6, 1, 1, 1)

    @combobox_whitebalance_mode = Qt::ComboBox.new(@gridLayoutWidget)
    @combobox_whitebalance_mode.objectName = "combobox_whitebalance_mode"

    @gridLayout.addWidget(@combobox_whitebalance_mode, 7, 1, 1, 1)

    @label_5 = Qt::Label.new(@gridLayoutWidget)
    @label_5.objectName = "label_5"

    @gridLayout.addWidget(@label_5, 8, 0, 1, 1)

    @combobox_gain_mode = Qt::ComboBox.new(@gridLayoutWidget)
    @combobox_gain_mode.objectName = "combobox_gain_mode"

    @gridLayout.addWidget(@combobox_gain_mode, 8, 1, 1, 1)

    @label_8 = Qt::Label.new(@gridLayoutWidget)
    @label_8.objectName = "label_8"

    @gridLayout.addWidget(@label_8, 0, 0, 1, 1)

    @label_7 = Qt::Label.new(@gridLayoutWidget)
    @label_7.objectName = "label_7"

    @gridLayout.addWidget(@label_7, 1, 0, 1, 1)

    @label_camera_name = Qt::Label.new(@gridLayoutWidget)
    @label_camera_name.objectName = "label_camera_name"

    @gridLayout.addWidget(@label_camera_name, 0, 1, 1, 1)

    @statusLabel = Qt::Label.new(@gridLayoutWidget)
    @statusLabel.objectName = "statusLabel"

    @gridLayout.addWidget(@statusLabel, 1, 1, 1, 1)


    retranslateUi(cameraControl)
    Qt::Object.connect(@slider_fps, SIGNAL('valueChanged(int)'), @spinbox_fps, SLOT('setValue(int)'))
    Qt::Object.connect(@spinbox_fps, SIGNAL('valueChanged(int)'), @slider_fps, SLOT('setValue(int)'))
    Qt::Object.connect(@slider_exposure, SIGNAL('valueChanged(int)'), @spinbox_exposure, SLOT('setValue(int)'))
    Qt::Object.connect(@spinbox_exposure, SIGNAL('valueChanged(int)'), @slider_exposure, SLOT('setValue(int)'))
    Qt::Object.connect(@slider_gain, SIGNAL('valueChanged(int)'), @spinbox_gain, SLOT('setValue(int)'))
    Qt::Object.connect(@spinbox_gain, SIGNAL('valueChanged(int)'), @slider_gain, SLOT('setValue(int)'))

    Qt::MetaObject.connectSlotsByName(cameraControl)
    end # setupUi

    def setup_ui(cameraControl)
        setupUi(cameraControl)
    end

    def retranslateUi(cameraControl)
    cameraControl.windowTitle = Qt::Application.translate("CameraControl", "CameraControl", nil, Qt::Application::UnicodeUTF8)
    @label_3.text = Qt::Application.translate("CameraControl", "fps:", nil, Qt::Application::UnicodeUTF8)
    @label.text = Qt::Application.translate("CameraControl", "Exposure Time [sec]:", nil, Qt::Application::UnicodeUTF8)
    @label_2.text = Qt::Application.translate("CameraControl", "Gain:", nil, Qt::Application::UnicodeUTF8)
    @label_4.text = Qt::Application.translate("CameraControl", "Exposure Mode", nil, Qt::Application::UnicodeUTF8)
    @label_6.text = Qt::Application.translate("CameraControl", "Whitebalance Mode:", nil, Qt::Application::UnicodeUTF8)
    @label_5.text = Qt::Application.translate("CameraControl", "Gain Mode", nil, Qt::Application::UnicodeUTF8)
    @label_8.text = Qt::Application.translate("CameraControl", "Camera Name:", nil, Qt::Application::UnicodeUTF8)
    @label_7.text = Qt::Application.translate("CameraControl", "Camera Status:", nil, Qt::Application::UnicodeUTF8)
    @label_camera_name.text = Qt::Application.translate("CameraControl", "none", nil, Qt::Application::UnicodeUTF8)
    @statusLabel.text = Qt::Application.translate("CameraControl", "N/A", nil, Qt::Application::UnicodeUTF8)
    end # retranslateUi

    def retranslate_ui(cameraControl)
        retranslateUi(cameraControl)
    end

end

module Ui
    class CameraControl < Ui_CameraControl
    end
end  # module Ui

