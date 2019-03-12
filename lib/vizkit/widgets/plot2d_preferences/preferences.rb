module Vizkit
    module Plot2d
        class Preferences < Qt::Object
            def initialize(name_org, name_app = "", parent: nil, default_opts: Hash.new)
                super(parent)
                
                @settings = Qt::Settings.new(name_org, name_app, parent)

                @tags = Hash[
                    :auto_scrolling           => 'auto_scrolling',
                    :reuse                    => 'reuse_widget',
                    :use_y_axis2              => 'use_y_axis2',
                    :time_window              => 'time_window/value',
                    :cached_time_window       => 'time_window_cache/value',
                    :time_window_range        => 'time_window/range',
                    :cached_time_window_range => 'time_window_cache/range',
                    :update_period            => 'update_period/value',
                    :update_period_range      => 'update_period/range',
                ]
                @options = Hash.new
                load_from_hash(default_opts)
                @options[:auto_scrolling]           ||= true
                @options[:reuse]                    ||= true
                @options[:use_y_axis2]              ||= false
                @options[:time_window]              ||= 30
                @options[:cached_time_window]       ||= 60
                @options[:update_period]            ||= 0.25
                @options[:time_window_range]        ||= [1, 300]
                @options[:cached_time_window_range] ||= [1, 300]
                @options[:update_period_range]      ||= [0.02, 1]

                load
            end

            def load_bool(key, default = @options[key])
                load_value(key, default).to_bool
            end

            def load_int(key, default = @options[key])
                load_value(key, default).to_int
            end

            def load_float(key, default = @options[key])
                load_value(key, default).to_float
            end

            def load_list(key, default = @options[key], &filter_cast)
                list = load_value(key, default).to_list
                filter_cast ||= ->(elem) {elem.to_int}
                list.map &filter_cast
            end

            def load_list_float(key, default = @options[key])
                load_list(key, default) do |elem|
                    elem.to_f
                end
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
                    @options.each do |key,value|
                        save_value(key, value)
                    end
                    @options = @options.dup
                ensure
                    @settings.end_group
                    emit updated()
                end
            end

            def load_from_hash(hash)
                hash.each do |key,value|
                    @options[key] = value if @tags.has_key?(key)
                end
            end

            def load
                @settings.begin_group('preferences')
                begin
                    @options[:auto_scrolling]           = load_bool(:auto_scrolling)
                    @options[:reuse]                    = load_bool(:reuse)
                    @options[:use_y_axis2]              = load_bool(:use_y_axis2)
                    @options[:time_window]              = load_int(:time_window)
                    @options[:cached_time_window]       = load_int(:cached_time_window)
                    @options[:update_period]            = load_float(:update_period)
                    @options[:time_window_range]        = load_list(:time_window_range)
                    @options[:cached_time_window_range] = load_list(:cached_time_window_range)
                    @options[:update_period_range]      = load_list_float(:update_period_range)
                ensure
                    @settings.end_group
                end
            end

            def set_value(key, value)
                @options[key.to_sym] = value
            end

            def get_value(key)
                @options[key]
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

            def update_period=(value)
                set_value(:update_period, value)
            end

            def update_period
                get_value(:update_period)
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

            def update_period_range
                get_value(:update_period_range)
            end

            signals 'updated()'

            private :load_bool, :load_int, :load_list, :load_list_float,
                    :load_value, :save_value, :set_value, :get_value
        end
    end
end