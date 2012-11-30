#!/usr/bin/env ruby

require 'vizkit'

require File.join(File.dirname(__FILE__), 'task_inspector_window.ui.rb')
require 'vizkit/tree_modeler'

class TaskInspector
    def self.create_widget(parent = nil)
        form = Vizkit.load(File.join(File.dirname(__FILE__),'task_inspector_window.ui'),parent)
        form.extend Functions
        form.init
        form
    end

    module Functions
        def default_options()
            options = Hash.new
            options[:interval] = 1000   #update interval in msec
            return options
        end

        def enable_tooling=(value)
            @tree_view.enable_tooling=value
        end
        def enable_tooling
            @tree_view.enable_tooling
        end

        def init
            buttonFrame.hide
            @brush = Qt::Brush.new(Qt::Color.new(200,200,200))
            @tree_view = Vizkit::TreeModeler.new(treeView)

            @tasks = Array.new
            @read_obj = false
            @black_list = Array.new

            setPropButton.connect(SIGNAL('clicked()')) do
                @tree_view.update_dirty_items
                buttonFrame.hide
            end

            cancelPropButton.connect(SIGNAL('clicked()')) do
                @tree_view.unmark_dirty_items
                buttonFrame.hide
            end

            @timer = Qt::Timer.new(self)
            @timer.connect(SIGNAL('timeout()')) do 
                if visible
                    @tasks.each_with_index do |task,index|
                        @tree_view.update(task,nil,@tree_view.root,false,index)
                    end

                    if !@tree_view.dirty_items.empty?
                        buttonFrame.show 
                    else
                        treeView.resizeColumnToContents(0)
                    end
                end
            end
        end

        def force_update=(value)
            @tree_view.force_update=value
        end

        def config(task,options=Hash.new)
            #do not add the task if it is already there
            task_name = if task.respond_to? :to_str
                          task.to_str
                        else
                          task.name
                        end
            return if @black_list.include?(task_name)
            result = @tasks.find do |t| 
                t.name == task_name
            end
            return if result 

            task = if !task.is_a? Vizkit::TaskProxy  
                       Vizkit::TaskProxy.new(task_name)
                   else
                       task
                   end
            if !enable_tooling && task.respond_to?(:tooling?) && task.tooling?
                @black_list << task_name
                Vizkit.info "Adding task #{task.name} to the black list because it is tooling."
                return
            end

            @tasks << task
            options = default_options.merge(options)
            @tree_view.update(task,nil,@tree_view.root,false,@tasks.size-1)
            @timer.start(options[:interval])
        end

        def multi_value?
            true
        end
    end
end

Vizkit::UiLoader.register_ruby_widget("TaskInspector",TaskInspector.method(:create_widget))
Vizkit::UiLoader.register_default_widget_for("TaskInspector",Orocos::TaskContext,:config)
#Vizkit::UiLoader.register_default_widget_for("TaskInspector",Vizkit::TaskProxy,:config)
Vizkit::UiLoader.register_default_widget_for("TaskInspector",Orocos::Log::TaskContext,:config)
Vizkit::UiLoader.register_default_control_for("TaskInspector",Orocos::TaskContext,:config)
#Vizkit::UiLoader.register_default_control_for("TaskInspector",Vizkit::TaskProxy,:config)

Vizkit::UiLoader.register_deprecate_plugin_clone("task_inspector","TaskInspector")
