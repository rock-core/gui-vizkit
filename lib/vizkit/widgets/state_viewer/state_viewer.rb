#!/usr/bin/env ruby

class StateViewer < Qt::Widget
    def initialize(parent=nil)
        super
        #add layout to the widget
        @layout = Qt::GridLayout.new
        self.setLayout @layout

        @task_inspector = Vizkit.default_loader.TaskInspector 

        @hash_labels = Hash.new
        @tasks = Array.new
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
        @font.setPointSize(9)
        @font.setBold(true)
    end

    def default_options
        options = Hash.new
        options[:max_rows] = 6
        options
    end

    def options(hash = Hash.new)
        @options ||= default_options
        @options.merge!(hash)
    end

    def add(task,options=Hash.new)
        task = if task.is_a?(Orocos::Async::TaskContextProxy)
                   task
               else
                   Orocos::Async.proxy(task)
               end
        @tasks << task
        task.on_state_change do |state|
            if(task.running?)
                update(state,task.name,@green)
            else
                update(state,task.name,@blue)
            end
        end
        task.on_unreachable do
            update("UNREACHABLE",task.name,@red)
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
                    @task_inspector.add_task @task_name
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
Vizkit::UiLoader.register_control_for("StateViewer",Orocos::Async::TaskContextProxy,:add)
#Vizkit::UiLoader.register_control_for("StateViewer",Vizkit::TaskProxy,:add)
