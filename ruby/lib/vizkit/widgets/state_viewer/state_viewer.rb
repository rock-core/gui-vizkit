#!/usr/bin/env ruby

class StateViewer < Qt::Widget

    def initialize(parent=nil)
        super
        #add layout to the widget
        @layout = Qt::GridLayout.new
        self.setLayout @layout

        @hash_labels = Hash.new
        @hash_tasks = Hash.new
        @options = default_options
        @row = 0
        @col = 0

        @red = Qt::Palette.new
        @green = Qt::Palette.new
        @blue = Qt::Palette.new
        @red.setColor(Qt::Palette::Window,Qt::Color.new(255,0,0))
        @green.setColor(Qt::Palette::Window,Qt::Color.new(0,255,0))
        @blue.setColor(Qt::Palette::Window,Qt::Color.new(0,0,255))

        @timer = Qt::Timer.new
        @timer.connect(SIGNAL('timeout()')) do 
            @hash_tasks.each_value do |task|
                update(task.state,task.name)
            end
        end
    end

    def default_options
        options = Hash.new
        options[:max_rows] = 3
        options[:update_frequency] = 1
        options
    end

    def options(hash = Hash.new)
        @options ||= default_options
        @options.merge!(hash)
    end

    def add(task)
        if !@hash_tasks.has_key? task.name
            @hash_tasks[task.name] = task
        end
        if !@timer.active
            @timer.start(1/@options[:update_frequency])
        end
    end

    def update(data, port_name)
        label = @hash_labels[port_name]
        if !label
            label = Qt::Label.new 
            label.setAutoFillBackground true
            @hash_labels[port_name] = label
            @layout.addWidget(label,@row,@col)
            @row += 1
            if @row == @options[:max_rows]
                @row = 0
                @col += 1
            end
        end

        label.setText(port_name.to_s + " : " + data.to_s)

        if data.to_s == "stopped"
            label.setPalette(@red) 
        elsif data.to_s == "unknown"
            label.setPalette(@blue) 
        else
            label.setPalette(@green) 
        end
    end
end

Vizkit::UiLoader.register_ruby_widget("StateViewer",StateViewer.method(:new))
