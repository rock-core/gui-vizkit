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
                w.show if w.respond_to? :show
            end
        end

        form
    end

    module Functions
        attr_reader :model,:treeView

        def init
            Vizkit.setup_tree_view treeView
            @model = Vizkit::VizkitItemModel.new
            treeView.setModel @model
        end

        def add_task(task,options=Hash.new)
            obj = if task.is_a? String
                      Orocos::Async.proxy task
                  elsif task.is_a? Orocos::Async::TaskContextProxy
                      task
                  else
                      Orocos::Async.proxy task.name
                  end
            item1 = Vizkit::TaskContextItem.new obj
            item2 = Vizkit::TaskContextItem.new obj,:item_type => :value
            @model.appendRow([item1,item2])
        end

        def add_name_service(service,options=Hash.new)
            if service.respond_to?(:on_name_service_added) # This is a "global" name service
                service.on_name_service_added do |new_ns|
                    add_name_service(new_ns)
                end
                service.on_name_service_removed do |removed_ns|
                    to_remove = []
                    @model.rowCound.times do |i|
                        item = @model.item(i, 0)
                        if item.respond_to?(:name_service) && item.name_service = removed_ns
                            to_remove << i
                        end
                    end
                    to_remove.reverse.each do |idx|
                        @model.takeRow(idx)
                    end
                end
            else
                item1 = Vizkit::NameServiceItem.new service
                item2 = Vizkit::NameServiceItem.new service,:item_type => :value
                @model.appendRow([item1,item2])
                service.once_on_task_added do |name|
                    treeView.expand(item1.index)
                end
            end
        end
    end
end

Vizkit::UiLoader.register_ruby_widget("TaskInspector",TaskInspector.method(:create_widget))
Vizkit::UiLoader.register_default_widget_for("TaskInspector",Orocos::Async::TaskContextProxy,:add_task)

