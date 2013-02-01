require File.join(File.dirname(__FILE__),"test_helper")
start_simple_cov("test_widgets")

require 'vizkit'
require 'test/unit'
Orocos.initialize
Orocos.load_typekit "base"

class WidgetTest < Test::Unit::TestCase
    def setup

    end

    #test integration between Vizkit, TaskProxy and Replay
    def test_task_inspector
        widget = Vizkit.default_loader.TaskInspector
        assert(widget)
        assert(widget.plugin_spec)
        widget = Vizkit.default_loader.create_plugin("TaskInspector")
        assert(widget)
        assert(widget.plugin_spec)
        assert_equal("TaskInspector",widget.plugin_spec.plugin_name)
        assert_equal(:ruby_plugin,widget.plugin_spec.plugin_type)
    end

end

