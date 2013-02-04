require File.join(File.dirname(__FILE__),"test_helper")
start_simple_cov("test_widget_task_connector")

require 'vizkit'
require 'minitest/spec'

Orocos.initialize
Orocos.load_typekit "base"
Vizkit.default_loader.add_plugin_path File.join(File.dirname(__FILE__),"..","..","build","test","test_vizkit_widget")
MiniTest::Unit.autorun
include Vizkit

describe WidgetTaskConnector do
    class SandBoxWidgetTaskConnector < MiniTest::Spec
        def self.prepare
            @@widget = Vizkit.default_loader.TestVizkitWidget
            @@widget.extend Vizkit::QtTypelibExtension
            @@task = Orocos::Async.proxy "test_task"
            @@connector = Vizkit::WidgetTaskConnector.new(@@widget,@@task)
            @@ruby_task = Orocos::RubyTaskContext.new("test_task")
            @@ruby_task.create_property("prop1","/base/samples/RigidBodyState")
            @@ruby_task.create_input_port("int_port","int")
            @@ruby_task.create_input_port("frame","/base/samples/frame/Frame")
            @@ruby_task.create_output_port("oframe","/base/samples/frame/Frame")
            #make sure the task and port is connected
            @@task.wait
            @@task.port("int_port").wait
            @@task.port("frame").wait
            @@task.port("oframe").wait
            def @@widget.ruby_method(value)
                @ruby_value = value
            end
        end

        prepare
        before do
            @@widget.disconnect
            @@widget.close
            @@ruby_task.frame.disconnect_all
            @@ruby_task.int_port.disconnect_all
            Vizkit.process_events
        end

        describe "resolve" do
            describe "SIGNAL" do
                it "raises if signal is unknown" do 
                    assert_raises ArgumentError do
                        @@connector.send(:resolve,@@connector.SIGNAL("intChanged2(int,int)"))
                    end
                end

                it "returns ConnectorSlot" do 
                    @@connector.send(:resolve,@@connector.SIGNAL("intChanged(int)")).must_be_kind_of ConnectorSignal
                end

                it "returns :signal" do 
                    @@connector.send(:resolve,@@connector.SIGNAL("intChanged")).must_be_kind_of ConnectorSignal
                end
            end

            describe "SLOT" do
                it "raises if slot is unknown" do 
                    assert_raises ArgumentError do
                        @@connector.send(:resolve,@@connector.SLOT("set(int,int)"))
                    end
                end

                it "returns the :slot" do 
                    @@connector.send(:resolve,@@connector.SLOT("setFrame")).must_be_kind_of ConnectorSlot
                end
            end
        end

        describe "connect" do
            before do 
                @@widget.disconnect
                @@widget.close
                @@ruby_task.frame.disconnect_all
                @@ruby_task.int_port.disconnect_all
                Vizkit.process_events
            end

            it "directly connect signal to port" do
                @@connector.connect @@connector.SIGNAL("intChanged(int)"),@@connector.PORT("int_port")
                @@widget.intChanged(2)
                Vizkit.process_events
                Orocos::Async.steps
                assert_equal 2,@@ruby_task.int_port.read_new
            end

            it "uses a getter function" do 
                @@connector.connect @@connector.SIGNAL("frameChanged"),@@connector.PORT("frame"),:getter => @@connector.SLOT("const base::samples::frame::Frame getFrame()const")
                sample = Types::Base::Samples::Frame::Frame.new.zero!
                sample.time = Time.now
                @@widget.setFrame sample
                Vizkit.process_events
                @@widget.frameChanged
                Vizkit.process_events
                Orocos::Async.steps
                assert_equal sample.time.usec,@@ruby_task.frame.read_new.time.usec
            end

            it "uses a getter function (signal signature is not fully defined)" do 
                @@connector.connect @@connector.SIGNAL("frameChanged"),@@connector.PORT("frame"),:getter => @@connector.SLOT("getFrame")
                sample = Types::Base::Samples::Frame::Frame.new.zero!
                sample.time = Time.now
                @@widget.setFrame sample
                Vizkit.process_events
                @@widget.frameChanged
                Vizkit.process_events
                Orocos::Async.steps
                assert_equal sample.time.usec,@@ruby_task.frame.read_new.time.usec
            end

            it "connect a port to slot" do 
                @@connector.connect @@connector.PORT("oframe"),@@connector.SLOT("setFrame")
                Orocos::Async.steps

                sample = Types::Base::Samples::Frame::Frame.new.zero!
                sample.time = Time.now
                @@ruby_task.oframe.write sample
                sleep 0.11
                Orocos::Async.steps
                assert_equal sample.time.usec,@@widget.getFrame.time.usec
            end

            it "raises if types are not compatible" do 
            #    @@connector.send(:connect_signal_to_port,"intChanged(int)","int_port",Hash.new)
            end
        end
    end
end
