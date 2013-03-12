#!/usr/bin/env ruby

require 'vizkit'
require 'vizkit/tree_view'

class TaskInspector
    def self.create_widget(parent = nil)
        form = Vizkit.load(File.join(File.dirname(__FILE__),'task_inspector_window.ui'),parent)
        form.extend Functions
        form.init
        corba_dialog ||= Vizkit.load(File.join(File.dirname(__FILE__),'add_corba_name_service.ui'),parent)
        corba_dialog.connect(SIGNAL("accepted()")) do
            form.add_name_service(Orocos::Async::CORBA::NameService.new(corba_dialog.ip.text))
        end
        form.actionAdd_name_service.connect SIGNAL("triggered()") do 
            corba_dialog.show
        end

        #populate widget menu
        Vizkit.default_loader.plugin_specs.keys.sort.each do |name|
            # do not add qt base widgets
            next if name[0] == "Q" && Qt.const_defined?(name[1..-1])
            action = form.menuWidgets.addAction(name)
            action.connect SIGNAL("triggered()") do
                w = Vizkit.default_loader.create_plugin name
                w.show
            end
        end

        form
    end

    module Functions
        def default_options()
            options = Hash.new
            options[:interval] = 1000   #update interval in msec
            return options
        end

        def enable_tooling=(value)
        end
        def enable_tooling
        end

        def treeView
            @treeView
        end

        def init
            Vizkit.setup_tree_view treeView
            @model = Vizkit::VizkitItemModel.new
            treeView.setModel @model
        end

        def add_task(task,options=Hash.new)
            obj = if task.is_a? String
                      Orocos::Async::TaskContextProxy.new task
                  elsif task.is_a? Orocos::Async::TaskContextProxy
                      task
                  else
                      Orocos::Async::TaskContextProxy.new task.name
                  end
            item1 = Vizkit::TaskContextItem.new obj
            item2 = Vizkit::TaskContextItem.new obj,:item_type => :value
            @model.appendRow([item1,item2])
        end

        def add_name_service(service,options=Hash.new)
            item1 = Vizkit::NameServiceItem.new service
            item2 = Vizkit::NameServiceItem.new service,:item_type => :value
            @model.appendRow([item1,item2])
        end
    end
end

Vizkit::UiLoader.register_ruby_widget("TaskInspector",TaskInspector.method(:create_widget))
Vizkit::UiLoader.register_default_widget_for("TaskInspector",Orocos::TaskContext,:add_task)

#Vizkit::UiLoader.register_default_widget_for("TaskInspector",Vizkit::TaskProxy,:config)
#Vizkit::UiLoader.register_default_widget_for("TaskInspector",Orocos::Log::TaskContext,:config)
#Vizkit::UiLoader.register_default_control_for("TaskInspector",Orocos::TaskContext,:config)
#Vizkit::UiLoader.register_default_control_for("TaskInspector",Vizkit::TaskProxy,:config)

#Vizkit::UiLoader.register_deprecate_plugin_clone("task_inspector","TaskInspector")
