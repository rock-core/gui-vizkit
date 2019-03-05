module Vizkit
    module Plot2D
        class Preferences
            def initialize(name_org, name_app = "")

                @settings = Qt::Settings.new(name_org, name_app)

                load
            end

            def load_bool(tag, default=false)
                @settings.value(tag, Qt::Variant.new(default)).to_bool
            end

            def load_int(tag, default=0)
                @settings.value(tag, Qt::Variant.new(default)).to_int
            end

            def load_list(tag, default=[0,1], &filter_cast)
                list = @settings.value(tag, Qt::Variant.new(default)).to_list
                filter_cast ||= ->(elem) {elem.to_int}
                list.map &filter_cast
            end

            def save_value(tag, value)
                @settings.set_value(tag, Qt::Variant.new(value))
            end
            
            def save
                @settings.begin_group('preferences')
                begin
                    @options_stash.each do |key,value|
                        save_value(key, value)
                    end
                    @options = @options_stash.dup
                ensure
                    @settings.end_group
                end
            end

            def load
                @settings.begin_group('preferences')
                begin
                    @options = Hash[
                        'auto_scroll'             => load_bool('auto_scroll'),
                        'reuse'                   => load_bool('reuse'),
                        '2yaxes'                  => load_bool('2yaxes'),
                        'time_window/value'       => load_int('time_window/value'),
                        'time_window_cache/value' => load_int('time_window_cache/value'),
                        'time_window/range'       => load_list('time_window/range', [0.1, 300]),
                        'time_window_cache/range' => load_list('time_window_cache/range', [0.1, 300]),
                    ]
                    @options_stash = @options.dup
                ensure
                    @settings.end_group
                end
            end

            def hold=(value)
                if [true, false].include? value
                    @on_hold = value
                else
                    @on_hold = false
                    stderr.puts '[Warning] Plot2D::Vizkit::Preferences.hold= received a nonboolean value and will default to false'
                end
            end

            def on_hold?
                @on_hold
            end

            def set_value(tag, value)
                @options_stash[tag] = value
                if !on_hold?
                    @settings.begin_group('preferences')
                    begin
                        save_value(tag, value)
                        @options[tag] = @options_stash[tag]
                    ensure
                        @settings.end_group
                    end
                end
            end

            def autoscroll
                @options['auto_scroll']
            end
            
            def autoscroll=(value)
                set_value('auto_scroll', value)
            end

            def reuse_widget
                @options['reuse']
            end

            def reuse_widget=(value)
                set_value('reuse', value)
            end

            def use_2yaxes
                @options['2yaxes']
            end

            def use_2yaxes=(value)
                set_value('2yaxes', value)
            end

            def time_window
                @options['time_window/value']
            end

            def time_window=(value)
                set_value('time_window/value', value)
            end

            def time_window_cache
                @options['time_window_cache/value']
            end

            def time_window_cache=(value)
                set_value('time_window_cache/value', value)
            end

            def time_window_range
                @options['time_window/range']
            end

            def time_window_cache_range
                @options['time_window_cache/range']
            end

            private :load_bool, :load_int, :load_list, :save_value, :set_value
        end
    end
end