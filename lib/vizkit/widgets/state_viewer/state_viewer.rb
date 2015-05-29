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

    # Whether labels are laid out row-first or column-first
    #
    # In row-first mode, a row is first filled with a maximum set by
    # {row_first=}, and then a new row is created
    #
    # In column-first mode, a column is first filled with a maximum set by
    # {col_first=}, and then a new column is created
    #
    # The default is to be column-first
    def row_first?
        !@options[:max_rows]
    end

    # Make the widget lay itself out row-first
    #
    # After this call, the widget will fill a row with 'value' labels before
    # going to the next row. The default is col-first
    #
    # Note that calling this method does not re-layout the existing labels. New
    # labels will be added starting at the last label added
    #
    # @see row_first? max_rows=
    def max_cols=(value)
        @options.delete(:max_rows)
        @options[:max_cols] = value
    end

    # Make the widget lay itself out column-first
    #
    # After this call, the widget will fill a column with 'value' labels before
    # going to the next column. This is the default
    #
    # Note that calling this method does not re-layout the existing labels. New
    # labels will be added starting at the last label added
    #
    # @see row_first? max_cols=
    def max_rows=(value)
        @options.delete(:max_cols)
        @options[:max_rows] = value
    end

    # Add a new label to the layout and return its position
    #
    # Where the label is added is controlled by the max_cols or max_rows
    # setting.
    #
    # @see row_first? max_col= max_row=
    # @return [(Integer,Integer)] the row and column of the new label
    def add_label_to_layout(label)
        row, col = @row, @col
        @layout.addWidget(label,row,col)
        if row_first?
            @col += 1
            if @col == @options[:max_cols]
                @col = 0
                @row += 1
            end
        else
            @row += 1
            if @row == @options[:max_rows]
                @row = 0
                @col += 1
            end
        end

        return row, col
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
