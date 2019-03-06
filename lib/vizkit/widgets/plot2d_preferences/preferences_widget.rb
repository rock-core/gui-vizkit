module Vizkit
    module Plot2d
        class PreferencesWidget < Qt::Widget
            class PreferencesItemCB
                def initialize(name, parent = nil)
                    @label = Qt::Label.new(name, parent)
                    @checkbox = Qt::CheckBox.new(parent)
                end

                def selected=(value)
                    @checkbox.checked = value
                end

                def selected
                    @checkbox.checked
                end

                def add_to_grid(layout, row=0, col=0)
                    layout.add_widget(@label,    row, col)
                    layout.add_widget(@checkbox, row, col + 1)
                    row = row + 1
                end
            end

            class PreferencesItemSlider < Qt::Object
                def initialize(name, parent = nil)
                    super(parent)
                    @label = Qt::Label.new(name, parent)
                    @slider = Qt::Slider.new(Qt::Horizontal, parent)
                    @spinner = Qt::SpinBox.new(parent)

                    @slider.set_minimum_width(180)

                    Qt::Object.connect(@slider,  SIGNAL('valueChanged(int)'), @spinner, SLOT('setValue(int)'))
                    Qt::Object.connect(@spinner, SIGNAL('valueChanged(int)'), @slider,  SLOT('setValue(int)'))
                    Qt::Object.connect(@slider,  SIGNAL('valueChanged(int)'), self, SIGNAL('valueChanged(int)'))
                end

                def range=(minmax)
                    @slider.minimum  = minmax[0]
                    @slider.maximum  = minmax[1]
                    @spinner.minimum = minmax[0]
                    @spinner.maximum = minmax[1]
                end

                def value=(value)
                    @slider.value = value
                end

                def value
                    @slider.value
                end

                def add_to_grid(layout, row=0, col=0)
                    layout.add_widget(@label,   row, col)
                    layout.add_widget(@slider,  row, col + 1, 1, 2)
                    layout.add_widget(@spinner, row, col + 3)
                    row = row + 1
                end

                signals 'valueChanged(int)'
            end

            class PreferencesItemSpinner
                def initialize(name, parent = nil)
                    @label = Qt::Label.new(name, parent)
                    @spinner = Qt::DoubleSpinBox.new(parent)
                    @spinner.decimals = 2
                    @spinner.single_step = 0.01
                end

                def range=(minmax)
                    @spinner.minimum = minmax[0]
                    @spinner.maximum = minmax[1]
                end

                def value=(value)
                    @spinner.value = value
                end

                def value
                    @spinner.value
                end

                def add_to_grid(layout, row=0, col=0)
                    layout.add_widget(@label,   row, col)
                    layout.add_widget(@spinner, row, col + 1)
                    row = row + 1
                end
            end

            def initialize(preferences = nil, parent = nil)
                super(parent)

                if preferences
                    @preferences = preferences
                else
                    @preferences = Vizkit::Plot2d::Preferences.new('vizkit', 'plot2d')
                end

                create_ui
            end

            def create_ui
                set_window_title('Plot2d Preferences')

                layout_main = Qt::VBoxLayout.new(self)
                layout_main.add_layout( layout_content = Qt::GridLayout.new )

                @options_cb = Hash[
                    'auto_scroll' => PreferencesItemCB.new('Autoscroll', self),
                    'reuse'       => PreferencesItemCB.new('Reuse widget', self),
                    '2yaxes'      => PreferencesItemCB.new('Use 2 y-axes', self),
                ]

                @options_slider = Hash[
                    'time_window'       => PreferencesItemSlider.new('Time window', self),
                    'time_window_cache' => PreferencesItemSlider.new('Time window cache', self),
                    'update_period'     => PreferencesItemSpinner.new('Update period', self)
                ]

                row = 0
                items = @options_cb.merge(@options_slider)
                items.each do |_,item|
                    row += item.add_to_grid(layout_content, row, 0)
                end
                @options_slider['time_window'].connect(SIGNAL('valueChanged(int)')) do |value|
                    if (value > @options_slider['time_window_cache'].value)
                        @options_slider['time_window_cache'].value = value
                    end
                end
                @options_slider['time_window_cache'].connect(SIGNAL('valueChanged(int)')) do |value|
                    if (value < @options_slider['time_window'].value)
                        @options_slider['time_window'].value = value
                    end
                end

                layout_content.add_item( Qt::SpacerItem.new(1, 10) )

                layout_buttons = Qt::HBoxLayout.new
                layout_buttons.add_widget( bt_save = Qt::PushButton.new('Save', self) )
                layout_buttons.add_widget( bt_load = Qt::PushButton.new('Load', self) )
                layout_buttons.add_stretch
                layout_buttons.add_spacing(20)
                layout_buttons.add_stretch
                layout_buttons.add_widget( bt_apply = Qt::PushButton.new('Apply', self) )
                layout_buttons.add_widget( bt_ok = Qt::PushButton.new('Ok', self) )
                layout_buttons.add_widget( bt_cancel = Qt::PushButton.new('Cancel', self) )
                bt_save.connect(SIGNAL('clicked()')) do
                    apply
                    @preferences.save
                end
                bt_load.connect(SIGNAL('clicked()')) do
                    @preferences.load(true)
                    load
                end
                bt_apply.connect(SIGNAL('clicked()')) do
                    apply
                end
                bt_ok.connect(SIGNAL('clicked()')) do
                    apply
                    close
                end
                bt_cancel.connect(SIGNAL('clicked()')) do
                    close
                end
                bt_save.toolTip   = 'Saves the settings for all future plot2d instances'
                bt_apply.toolTip  = 'Applies the settings to the current plot2d instance'
                bt_ok.toolTip     = 'Applies the settings and exit'
                bt_cancel.toolTip = 'Exits without saving or applying changes'
                layout_main.add_stretch
                layout_main.add_spacing(10)
                layout_main.add_stretch
                layout_main.add_layout(layout_buttons, row)
            end

            def apply
                @preferences.autoscroll        = @options_cb['auto_scroll'].selected
                @preferences.reuse_widget      = @options_cb['reuse'].selected
                @preferences.use_2yaxes        = @options_cb['2yaxes'].selected
                @preferences.time_window       = @options_slider['time_window'].value
                @preferences.time_window_cache = @options_slider['time_window_cache'].value
                @preferences.update_period     = @options_slider['update_period'].value

                emit @preferences.updated()
            end

            def load
                @options_cb['auto_scroll'].selected        = @preferences.autoscroll
                @options_cb['reuse'].selected              = @preferences.reuse_widget
                @options_cb['2yaxes'].selected             = @preferences.use_2yaxes
                @options_slider['time_window'].range       = @preferences.time_window_range
                @options_slider['time_window_cache'].range = @preferences.time_window_cache_range
                @options_slider['update_period'].range     = @preferences.update_period_range
                @options_slider['time_window'].value       = @preferences.time_window
                @options_slider['time_window_cache'].value = @preferences.time_window_cache
                @options_slider['update_period'].value     = @preferences.update_period
            end

            def show
                @preferences.load(false)
                load
                super
            end
        end
    end
end