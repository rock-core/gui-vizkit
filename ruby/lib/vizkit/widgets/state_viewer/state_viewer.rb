#!/usr/bin/env ruby

class StateViewer < Qt::Widget

    TaskNamePair = Struct.new :name, :task

    def initialize(parent=nil)
        super
        #add layout to the widget
        @layout = Qt::GridLayout.new
        self.setLayout @layout

        @task_inspector = Vizkit.default_loader.task_inspector 

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
        @font = Qt::Font.new
        @font.setPointSize(7)
        @font.setBold(true)

        @timer = Qt::Timer.new
        @timer.connect(SIGNAL('timeout()')) do 
            @hash_tasks.each_value do |pair|
                begin 
                    if !pair.task || !pair.task.reachable?
                        pair.task =  Vizkit.use_task?(pair.name)
                        pair.task = Orocos::TaskContext.get pair.name unless pair.task
                    end
                rescue Orocos::NotFound,Orocos::CORBAError
                    pair.task = nil
                end
                if pair.task
                    if pair.task.running?
                        update(pair.task.state ,pair.name,@green)
                    else
                        update(pair.task.state ,pair.name,@blue)
                    end
                else
                    update("not reachable",pair.name,@red)
                end
            end
        end
    end

    def default_options
        options = Hash.new
        options[:max_rows] = 6
        options[:update_frequency] = 1
        options
    end

    def options(hash = Hash.new)
        @options ||= default_options
        @options.merge!(hash)
    end

    def add(task)
        pair = TaskNamePair.new
        if task.is_a?(Orocos::TaskContext)
            pair.name = task.name
            pair.task = task
        else 
            pair.name = task.to_s
        end

        if !@hash_tasks.has_key? pair.name
                @hash_tasks[pair.name] = pair
        end
        if !@timer.active
            @timer.start(1/@options[:update_frequency])
        end
    end

    def update(data, port_name, color = @red)
        label = @hash_labels[port_name]
        if !label
            label = Qt::Label.new 
            label.instance_variable_set :@task_name, port_name
            label.instance_variable_set :@task_inspector, @task_inspector
            label.instance_eval do
                def mouseDoubleClickEvent(event)
                    @task_inspector.config @task_name
                    @task_inspector.show
                end
            end
            label.setFont(@font)
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
        label.setPalette color if label.palette != color
    end

    def multi_value?
        true
    end
end

Vizkit::UiLoader.register_ruby_widget("StateViewer",StateViewer.method(:new))
