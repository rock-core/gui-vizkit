=begin
** Form generated from reading ui file 'struct_viewer_window.ui'
**
** Created: Fri Jul 30 17:14:08 2010
**      by: Qt User Interface Compiler version 4.5.2
**
** WARNING! All changes made in this file will be lost when recompiling ui file!
=end

class Ui_Form
    attr_reader :formLayout
    attr_reader :verticalLayout
    attr_reader :treeView

    def setupUi(form)
    if form.objectName.nil?
        form.objectName = "form"
    end
    form.resize(400, 473)
    @sizePolicy = Qt5::SizePolicy.new(Qt5::SizePolicy::Expanding, Qt5::SizePolicy::Expanding)
    @sizePolicy.setHorizontalStretch(1)
    @sizePolicy.setVerticalStretch(1)
    @sizePolicy.heightForWidth = form.sizePolicy.hasHeightForWidth
    form.sizePolicy = @sizePolicy
    form.minimumSize = Qt5::Size.new(400, 200)
    form.maximumSize = Qt5::Size.new(16777215, 16777215)
    form.baseSize = Qt5::Size.new(0, 0)
    @formLayout = Qt5::FormLayout.new(form)
    @formLayout.margin = 0
    @formLayout.objectName = "formLayout"
    @formLayout.sizeConstraint = Qt5::Layout::SetNoConstraint
    @formLayout.fieldGrowthPolicy = Qt5::FormLayout::ExpandingFieldsGrow
    @formLayout.formAlignment = Qt5::AlignLeading|Qt5::AlignLeft|Qt5::AlignTop
    @formLayout.horizontalSpacing = 0
    @formLayout.verticalSpacing = 5
    @verticalLayout = Qt5::VBoxLayout.new()
    @verticalLayout.objectName = "verticalLayout"
    @verticalLayout.sizeConstraint = Qt5::Layout::SetDefaultConstraint

    @formLayout.setLayout(0, Qt5::FormLayout::LabelRole, @verticalLayout)

    @treeView = Qt5::TreeView.new(form)
    @treeView.objectName = "treeView"
    @sizePolicy.heightForWidth = @treeView.sizePolicy.hasHeightForWidth
    @treeView.sizePolicy = @sizePolicy
    @treeView.minimumSize = Qt5::Size.new(0, 0)
    @palette = Qt5::Palette.new
    brush = Qt5::Brush.new(Qt5::Color.new(255, 255, 219, 255))
    brush.style = Qt5::SolidPattern
    @palette.setBrush(Qt5::Palette::Active, Qt5::Palette::Base, brush)
    brush1 = Qt5::Brush.new(Qt5::Color.new(255, 255, 174, 255))
    brush1.style = Qt5::SolidPattern
    @palette.setBrush(Qt5::Palette::Active, Qt5::Palette::AlternateBase, brush1)
    @palette.setBrush(Qt5::Palette::Inactive, Qt5::Palette::Base, brush)
    @palette.setBrush(Qt5::Palette::Inactive, Qt5::Palette::AlternateBase, brush1)
    brush2 = Qt5::Brush.new(Qt5::Color.new(255, 255, 255, 255))
    brush2.style = Qt5::SolidPattern
    @palette.setBrush(Qt5::Palette::Disabled, Qt5::Palette::Base, brush2)
    @palette.setBrush(Qt5::Palette::Disabled, Qt5::Palette::AlternateBase, brush1)
    @treeView.palette = @palette
    @treeView.frameShape = Qt5::Frame::StyledPanel
    @treeView.setProperty("showDropIndicator", Qt5::Variant.new(false))
    @treeView.alternatingRowColors = true

    @formLayout.setWidget(1, Qt5::FormLayout::FieldRole, @treeView)


    retranslateUi(form)

    Qt5::MetaObject.connectSlotsByName(form)
    end # setupUi

    def setup_ui(form)
        setupUi(form)
    end

    def retranslateUi(form)
    form.windowTitle = Qt5::Application.translate("Form", "StructViewer", nil, Qt5::Application::UnicodeUTF8)
    end # retranslateUi

    def retranslate_ui(form)
        retranslateUi(form)
    end

end

module Ui
    class Form < Ui_Form
    end
end  # module Ui

