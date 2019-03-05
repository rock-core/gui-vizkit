module Vizkit
    module Plot2D
        class Preferences < Qt::Object
            def initialize(name_org, name_app = "", parent: nil, default_opts: Hash.new)
                super(parent)
                
                @settings = Qt::Settings.new(name_org, name_app, parent)

                @options = Hash.new
                @options_stash = Hash.new
                keys = [:auto_scrolling, :time_window, :cached_time_window, :reuse,
                        :use_y_axis2, :time_window_range, :cached_time_window_range];
                keys.each do |key|
                    value = default_opts[key]
                    @options[key] = value
                    @options_stash[key] = value
                end
                @options[:auto_scrolling]           ||= true
                @options[:reuse]                    ||= true
                @options[:use_y_axis2]              ||= false
                @options[:time_window]              ||= 30
                @options[:cached_time_window]       ||= 60
                @options[:time_window_range]        ||= [1, 300]
                @options[:cached_time_window_range] ||= [1, 300]
                
                @tags = Hash[
                    :auto_scrolling           => 'auto_scrolling',
                    :reuse                    => 'reuse_widget',
                    :use_y_axis2              => 'use_y_axis2',
                    :time_window              => 'time_window/value',
                    :cached_time_window       => 'time_window_cache/value',
                    :time_window_range        => 'time_window/range',
                    :cached_time_window_range => 'time_window_cache/range'
                ]

                load(true)
            end

            def load_bool(key, default = @options[key])
                load_value(key, default).to_bool
            end

            def load_int(key, default = @options[key])
                load_value(key, default).to_int
            end

            def load_list(key, default = @options[key], &filter_cast)
                list = load_value(key, default).to_list
                filter_cast ||= ->(elem) {elem.to_int}
                list.map &filter_cast
            end

            def load_value(key, default = @options[key])
                @settings.value(@tags[key], Qt::Variant.new(default))
            end

            def save_value(key, value)
                @settings.set_value(@tags[key], Qt::Variant.new(value))
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

            def load(reset_stash = false)
                @settings.begin_group('preferences')
                begin
                    @options[:auto_scrolling]           = load_bool(:auto_scrolling)
                    @options[:reuse]                    = load_bool(:reuse)
                    @options[:use_y_axis2]              = load_bool(:use_y_axis2)
                    @options[:time_window]              = load_int(:time_window)
                    @options[:cached_time_window]       = load_int(:cached_time_window)
                    @options[:time_window_range]        = load_list(:time_window_range)
                    @options[:cached_time_window_range] = load_list(:cached_time_window_range)
                    if reset_stash
                        @options_stash = @options.dup
                    else
                        @options_stash = @options_stash.map { |key,value|
                            [ key , value ||= @options[key] ]
                        }.to_h
                    end
                ensure
                    @settings.end_group
                end
            end

            def set_value(key, value)
                @options_stash[key.to_sym] = value
            end

            def get_value(key)
                @options_stash[key]
            end

            def autoscroll
                get_value(:auto_scrolling)
            end
            
            def autoscroll=(value)
                set_value(:auto_scrolling, value)
            end

            def reuse_widget
                get_value(:reuse)
            end

            def reuse_widget=(value)
                set_value(:reuse, value)
            end

            def use_2yaxes
                get_value(:use_y_axis2)
            end

            def use_2yaxes=(value)
                set_value(:use_y_axis2, value)
            end

            def time_window
                get_value(:time_window)
            end

            def time_window=(value)
                set_value(:time_window, value)
            end

            def time_window_cache
                get_value(:cached_time_window)
            end

            def time_window_cache=(value)
                set_value(:cached_time_window, value)
            end

            def time_window_range
                get_value(:time_window_range)
            end

            def time_window_cache_range
                get_value(:cached_time_window_range)
            end

            signals 'updated()'

            private :load_bool, :load_int, :load_list, :load_value, :save_value, :set_value, :get_value
        end
    end
end