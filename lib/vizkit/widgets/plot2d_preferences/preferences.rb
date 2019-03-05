module Vizkit
    module Plot2D
        class Preferences < Qt::Object
            def initialize(name_org, name_app = "", parent: nil)
                super(parent)

                @settings = Qt::Settings.new(name_org, name_app, parent)

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
                    emit updated()
                end
            end

            def load
                @settings.begin_group('preferences')
                begin
                    @options = Hash[
                        'auto_scroll'             => load_bool('auto_scroll', true),
                        'reuse'                   => load_bool('reuse', true),
                        '2yaxes'                  => load_bool('2yaxes', false),
                        'time_window/value'       => load_int('time_window/value', 30),
                        'time_window_cache/value' => load_int('time_window_cache/value', 60),
                        'time_window/range'       => load_list('time_window/range', [1, 300]),
                        'time_window_cache/range' => load_list('time_window_cache/range', [1, 300]),
                    ]
                    @options_stash = @options.dup
                ensure
                    @settings.end_group
                end
            end

            def set_value(tag, value)
                @options_stash[tag] = value
            end

            def load_value(tag)
                @options_stash[tag]
            end

            def autoscroll
                load_value('auto_scroll')
            end
            
            def autoscroll=(value)
                set_value('auto_scroll', value)
            end

            def reuse_widget
                load_value('reuse')
            end

            def reuse_widget=(value)
                set_value('reuse', value)
            end

            def use_2yaxes
                load_value('2yaxes')
            end

            def use_2yaxes=(value)
                set_value('2yaxes', value)
            end

            def time_window
                load_value('time_window/value')
            end

            def time_window=(value)
                set_value('time_window/value', value)
            end

            def time_window_cache
                load_value('time_window_cache/value')
            end

            def time_window_cache=(value)
                set_value('time_window_cache/value', value)
            end

            def time_window_range
                load_value('time_window/range')
            end

            def time_window_cache_range
                load_value('time_window_cache/range')
            end

            signals 'updated()'

            private :load_bool, :load_int, :load_list, :save_value, :set_value
        end
    end
end