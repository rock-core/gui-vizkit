require File.join(File.dirname(__FILE__),"test_helper")
start_simple_cov("test_typelib_qt_adapter")

require 'vizkit'
require 'minitest/spec'

Orocos.initialize
Orocos.load_typekit "base"
Vizkit.default_loader.add_plugin_path File.join(File.dirname(__FILE__),"..","..","build","test","test_vizkit_widget")
MiniTest::Unit.autorun
include Vizkit

describe WidgetTaskConnector do
    class SandBox < MiniTest::Spec
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

        describe WidgetTaskConnector::ConnectorSlot do
            describe "initialize" do 
                it "must raise if the slot is unknown" do 
                    assert_raises ArgumentError do 
                        WidgetTaskConnector::ConnectorSlot.new(@@widget,"bla")
                    end
                end

                it "must raise if the slot signature is wrong" do 
                    assert_raises ArgumentError do 
                        WidgetTaskConnector::ConnectorSlot.new(@@widget,"setFrame()")
                    end
                end

                it "must raise if the slot is a signal" do 
                    assert_raises ArgumentError do 
                        WidgetTaskConnector::ConnectorSlot.new(@@widget,"frameChanged")
                    end
                end

                it "must accept different signature styles" do 
                    assert WidgetTaskConnector::ConnectorSlot.new(@@widget,"setFrame")
                    assert WidgetTaskConnector::ConnectorSlot.new(@@widget,"void setFrame")
                    assert WidgetTaskConnector::ConnectorSlot.new(@@widget,"setFrame(const base::samples::frame::Frame &)")
                    assert WidgetTaskConnector::ConnectorSlot.new(@@widget,"ruby_method")
                end
            end

            describe "arity" do 
                it "must return the right number of parameters" do 
                    assert_equal 1, WidgetTaskConnector::ConnectorSlot.new(@@widget,"setFrame").arity
                    assert_equal 2, WidgetTaskConnector::ConnectorSlot.new(@@widget,"set2Int").arity
                end
            end

            describe "arity?" do 
                it "must return true if the method supports the given arity" do 
                    assert WidgetTaskConnector::ConnectorSlot.new(@@widget,"setFrame").arity?(1)
                    assert WidgetTaskConnector::ConnectorSlot.new(@@widget,"set2Int").arity?(2)
                end
            end

            describe "argument_types?" do 
                it "must return true if the right argument is given" do 
                    assert WidgetTaskConnector::ConnectorSlot.new(@@widget,"setFrame").argument_types?("base::samples::frame::Frame")
                    assert WidgetTaskConnector::ConnectorSlot.new(@@widget,"set2Int").argument_types?("int","int")
                end
            end

            describe "write" do 
                it "must write a value to the slot" do
                    sample = Types::Base::Samples::Frame::Frame.new.zero!
                    sample.time = Time.now
                    obj = WidgetTaskConnector::ConnectorSlot.new(@@widget,"setFrame")
                    obj.write Hash.new,sample
                    assert_equal sample.time.usec, @@widget.getFrame.time.usec
                end

                it "must write a value if the slot is a ruby method" do
                    sample = Types::Base::Samples::Frame::Frame.new.zero!
                    sample.time = Time.now
                    obj = WidgetTaskConnector::ConnectorSlot.new(@@widget,"ruby_method")
                    obj.write Hash.new,sample
                    assert_equal sample.time.usec, @@widget.instance_variable_get(:@ruby_value).time.usec
                end

                it "must write a value with a given block" do
                    sample = Types::Base::Samples::Frame::Frame.new.zero!
                    sample.time = Time.now
                    obj = WidgetTaskConnector::ConnectorSlot.new(@@widget,"setFrame")
                    a = nil
                    obj.write Hash.new,sample do 
                        a = :called
                    end
                    assert_equal :called,a
                    assert_equal sample.time.usec, @@widget.getFrame.time.usec
                end
            end

            describe "read" do 
                it "must read from a slot" do
                    sample = Types::Base::Samples::Frame::Frame.new.zero!
                    sample.time = Time.now
                    @@widget.setFrame sample
                    obj = WidgetTaskConnector::ConnectorSlot.new(@@widget,"getFrame")
                    assert_equal sample.time.usec, obj.read(Hash.new).time.usec
                end
            end
        end

        describe WidgetTaskConnector::ConnectorSignal do
            describe "initialize" do 
                it "must raise if the signal is unknown" do 
                    assert_raises ArgumentError do 
                        WidgetTaskConnector::ConnectorSignal.new(@@widget,"bla")
                    end
                end

                it "must raise if the signal signature is wrong" do 
                    assert_raises ArgumentError do 
                        WidgetTaskConnector::ConnectorSignal.new(@@widget,"frameChanged(int)")
                    end
                end

                it "must raise if the signal is a slot" do 
                    assert_raises ArgumentError do 
                        WidgetTaskConnector::ConnectorSignal.new(@@widget,"setFrame")
                    end
                end

                it "must accept different signature styles" do 
                    assert WidgetTaskConnector::ConnectorSignal.new(@@widget,"void int2Changed(int,int)")
                    assert WidgetTaskConnector::ConnectorSignal.new(@@widget,"void int2Changed")
                    assert WidgetTaskConnector::ConnectorSignal.new(@@widget,"int2Changed(int,int)")
                    assert WidgetTaskConnector::ConnectorSignal.new(@@widget,"int2Changed")
                end
            end

            describe "write" do 
                it "must reemit the signal if write is called" do
                    value = nil
                    @@widget.connect SIGNAL("intChanged(int)") do |val|
                        value = val
                    end
                    obj = WidgetTaskConnector::ConnectorSignal.new(@@widget,"intChanged")
                    obj.write Hash.new,2
                    assert_equal 2,value
                end
            end

            describe "on_data" do 
                it "must call given block each time the signal is emitted" do
                    obj = WidgetTaskConnector::ConnectorSignal.new(@@widget,"intChanged")
                    value = nil
                    obj.on_data Hash.new do |val|
                        value = val
                    end
                    3.times do |val|
                        @@widget.intChanged val
                        assert_equal val,value
                    end
                end
            end
        end

        describe WidgetTaskConnector::ConnectorPort do
            describe "initialize" do
            end

            describe "read" do 
                it "must read from a port" do
                end
            end

            describe "write" do 
            end

            describe "on_data" do 
            end
        end

        describe WidgetTaskConnector::ConnectorOperation do
            describe "initialize" do
            end

            describe "read" do 
                it "must read from a port" do
                end
            end

            describe "write" do 
            end

            describe "on_data" do 
            end
        end

        describe "connect_to" do 
        end

        describe "resolve" do
            describe "SIGNAL" do
                it "raises if signal is unknown" do 
                    assert_raises ArgumentError do
                        @@connector.send(:resolve,@@connector.SIGNAL("intChanged2(int,int)"))
                    end
                end

                it "returns ConnectorSlot" do 
                    @@connector.send(:resolve,@@connector.SIGNAL("intChanged(int)")).must_be_kind_of WidgetTaskConnector::ConnectorSignal
                end

                it "returns :signal" do 
                    @@connector.send(:resolve,@@connector.SIGNAL("intChanged")).must_be_kind_of WidgetTaskConnector::ConnectorSignal
                end
            end

            describe "SLOT" do
                it "raises if slot is unknown" do 
                    assert_raises ArgumentError do
                        @@connector.send(:resolve,@@connector.SLOT("set(int,int)"))
                    end
                end

                it "returns the :slot" do 
                    @@connector.send(:resolve,@@connector.SLOT("setFrame")).must_be_kind_of WidgetTaskConnector::ConnectorSlot
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

            it "raises if there is no getter and the signal is not passing a parameter" do
                assert_raises ArgumentError do 
                    @@connector.connect @@connector.SIGNAL("frameChanged"),@@connector.PORT("frame"),:getter => nil
                end
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
