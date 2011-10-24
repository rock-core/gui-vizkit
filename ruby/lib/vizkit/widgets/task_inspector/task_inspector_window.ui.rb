=begin
** Form generated from reading ui file 'task_inspector_window.ui'
**
** Created: Mo. Okt 24 15:01:47 2011
**      by: Qt User Interface Compiler version 4.6.3
**
** WARNING! All changes made in this file will be lost when recompiling ui file!
=end

class Ui_Form
    attr_reader :formLayout
    attr_reader :horizontalLayout_3
    attr_reader :setPropButton
    attr_reader :cancelPropButton
    attr_reader :treeView

    def setupUi(form)
    if form.objectName.nil?
        form.objectName = "form"
    end
    form.resize(406, 498)
    @sizePolicy = Qt::SizePolicy.new(Qt::SizePolicy::Expanding, Qt::SizePolicy::Expanding)
    @sizePolicy.setHorizontalStretch(1)
    @sizePolicy.setVerticalStretch(1)
    @sizePolicy.heightForWidth = form.sizePolicy.hasHeightForWidth
    form.sizePolicy = @sizePolicy
    form.minimumSize = Qt::Size.new(400, 200)
    form.maximumSize = Qt::Size.new(16777215, 16777215)
    form.baseSize = Qt::Size.new(0, 0)
    @formLayout = Qt::FormLayout.new(form)
    @formLayout.margin = 0
    @formLayout.objectName = "formLayout"
    @formLayout.sizeConstraint = Qt::Layout::SetNoConstraint
    @formLayout.fieldGrowthPolicy = Qt::FormLayout::ExpandingFieldsGrow
    @formLayout.formAlignment = Qt::AlignLeading|Qt::AlignLeft|Qt::AlignTop
    @formLayout.horizontalSpacing = 0
    @formLayout.verticalSpacing = 5
    @horizontalLayout_3 = Qt::HBoxLayout.new()
    @horizontalLayout_3.objectName = "horizontalLayout_3"
    @horizontalLayout_3.setContentsMargins(0, -1, -1, 0)
    @setPropButton = Qt::PushButton.new(form)
    @setPropButton.objectName = "setPropButton"
    @setPropButton.checkable = false

    @horizontalLayout_3.addWidget(@setPropButton)

    @cancelPropButton = Qt::PushButton.new(form)
    @cancelPropButton.objectName = "cancelPropButton"

    @horizontalLayout_3.addWidget(@cancelPropButton)


    @formLayout.setLayout(2, Qt::FormLayout::FieldRole, @horizontalLayout_3)

    @treeView = Qt::TreeView.new(form)
    @treeView.objectName = "treeView"
    @sizePolicy.heightForWidth = @treeView.sizePolicy.hasHeightForWidth
    @treeView.sizePolicy = @sizePolicy
    @treeView.minimumSize = Qt::Size.new(0, 0)
    @palette = Qt::Palette.new
    brush = Qt::Brush.new(Qt::Color.new(255, 255, 219, 255))
    brush.style = Qt::SolidPattern
    @palette.setBrush(Qt::Palette::Active, Qt::Palette::Base, brush)
    brush1 = Qt::Brush.new(Qt::Color.new(255, 255, 174, 255))
    brush1.style = Qt::SolidPattern
    @palette.setBrush(Qt::Palette::Active, Qt::Palette::AlternateBase, brush1)
    @palette.setBrush(Qt::Palette::Inactive, Qt::Palette::Base, brush)
    @palette.setBrush(Qt::Palette::Inactive, Qt::Palette::AlternateBase, brush1)
    brush2 = Qt::Brush.new(Qt::Color.new(255, 255, 255, 255))
    brush2.style = Qt::SolidPattern
    @palette.setBrush(Qt::Palette::Disabled, Qt::Palette::Base, brush2)
    @palette.setBrush(Qt::Palette::Disabled, Qt::Palette::AlternateBase, brush1)
    @treeView.palette = @palette
    @treeView.frameShape = Qt::Frame::StyledPanel
    @treeView.setProperty("showDropIndicator", Qt::Variant.new(false))
    @treeView.alternatingRowColors = true

    @formLayout.setWidget(3, Qt::FormLayout::FieldRole, @treeView)


    retranslateUi(form)

    Qt::MetaObject.connectSlotsByName(form)
    end # setupUi

    def setup_ui(form)
        setupUi(form)
    end

    def retranslateUi(form)
    form.windowTitle = Qt::Application.translate("Form", "Task Inspector", nil, Qt::Application::UnicodeUTF8)
    @setPropButton.text = Qt::Application.translate("Form", "Set properties", nil, Qt::Application::UnicodeUTF8)
    @cancelPropButton.text = Qt::Application.translate("Form", "Cancel", nil, Qt::Application::UnicodeUTF8)
    end # retranslateUi

    def retranslate_ui(form)
        retranslateUi(form)
    end

end

module Ui
    class Form < Ui_Form
    end
end  # module Ui

