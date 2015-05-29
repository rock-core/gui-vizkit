#!/usr/bin/env ruby

class StateViewer < Qt::Widget
    def initialize(parent=nil)
        super
        #add layout to the widget
        @layout = Qt::GridLayout.new(self)
        @layout.spacing = 0

        @hash_labels = Hash.new
        @tasks = Array.new
        @options = default_options
        @row = 0
        @col = 0

        @red = Qt::Palette.new
        @green = Qt::Palette.new
        @blue = Qt::Palette.new
        @red.setColor(Qt::Palette::Window,Qt::Color.new(0xFF,0x44,0x44))
        @green.setColor(Qt::Palette::Window,Qt::Color.new(0x99,0xCC,0x00))
        @blue.setColor(Qt::Palette::Window,Qt::Color.new(0x33,0xB5,0xE5))

        self.set_size_policy(Qt::SizePolicy::Preferred, Qt::SizePolicy::Minimum)
    end

    def task_inspector
        @task_inspector ||= Vizkit.default_loader.TaskInspector 
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

    def self.create_state_label(task_name, task_inspector)
        label = Qt::Label.new 
        label.margin = 5
        singleton_class = (class << label; self end)
        singleton_class.class_eval do
            define_method :mouseDoubleClickEvent do |event|
                task_inspector.add_task task_name
                task_inspector.show
            end
        end
        label.setAutoFillBackground true
        label
    end

    def add_label_to_layout(label)
        @layout.addWidget(label,@row,@col)
        @row += 1
        if @row == @options[:max_rows]
            @row = 0
            @col += 1
        end
    end

    def label_for(task_name)
        if !(label = @hash_labels[task_name])
            label = self.class.create_state_label(task_name, task_inspector)
            @hash_labels[task_name] = label
            add_label_to_layout(label)
        end
        label
    end

    def update(data, task_name, color = @red)
        label = label_for(task_name)
        label.setText("<b>#{task_name}</b>: #{data}")
        if label.palette != color
            label.setPalette color 
        end
    end

    def multi_value?
        true
    end
end

Vizkit::UiLoader.register_ruby_widget("StateViewer",StateViewer.method(:new))
Vizkit::UiLoader.register_control_for("StateViewer",Orocos::Async::TaskContextProxy,:add)
#Vizkit::UiLoader.register_control_for("StateViewer",Vizkit::TaskProxy,:add)
