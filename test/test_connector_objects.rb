require File.join(File.dirname(__FILE__),"test_helper")
start_simple_cov("test_connector_objects")

require 'vizkit'
require 'minitest/spec'

Orocos.initialize
Orocos.load_typekit "base"
Vizkit.default_loader.add_plugin_path File.join(File.dirname(__FILE__),"..","..","build","test","test_vizkit_widget")
MiniTest::Unit.autorun
include Vizkit

describe "ConnectorObjects" do
    class SandBoxConnectorObjects < MiniTest::Spec
        def self.prepare
            @@widget = Vizkit.default_loader.create_plugin("vizkit3d::Vizkit3DWidget")
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
            Vizkit.process_event
        end

        describe ConnectorSlot do
            describe "initialize" do 
                it "must raise if the slot is unknown" do 
                    assert_raises ArgumentError do 
                        ConnectorSlot.new(@@widget,"bla")
                    end
                end

                it "must raise if the slot signature is wrong" do 
                    assert_raises ArgumentError do 
                        ConnectorSlot.new(@@widget,"setFrame()")
                    end
                end

                it "must raise if the slot is a signal" do 
                    assert_raises ArgumentError do 
                        ConnectorSlot.new(@@widget,"frameChanged")
                    end
                end

                it "must accept different signature styles" do 
                    assert ConnectorSlot.new(@@widget,"setFrame")
                    assert ConnectorSlot.new(@@widget,"void setFrame")
                    assert ConnectorSlot.new(@@widget,"setFrame(const base::samples::frame::Frame &)")
                    assert ConnectorSlot.new(@@widget,"ruby_method")
                end
            end

            describe "arity?" do 
                it "must return true if the method supports the given arity" do 
                    assert ConnectorSlot.new(@@widget,"setFrame").arity?(1)
                    assert ConnectorSlot.new(@@widget,"set2Int").arity?(2)
                end
            end

            describe "argument_types?" do 
                it "must return true if the right argument is given" do 
                    assert ConnectorSlot.new(@@widget,"setFrame").argument_types?("base::samples::frame::Frame")
                    assert ConnectorSlot.new(@@widget,"set2Int").argument_types?("int","int")
                end
            end

            describe "write" do 
                it "must write a value to the slot" do
                    sample = Types::Base::Samples::Frame::Frame.new.zero!
                    sample.time = Time.now
                    obj = ConnectorSlot.new(@@widget,"setFrame")
                    obj.write Hash.new,sample
                    assert_equal sample.time.usec, @@widget.getFrame.time.usec
                end

                it "must write a value if the slot is a ruby method" do
                    sample = Types::Base::Samples::Frame::Frame.new.zero!
                    sample.time = Time.now
                    obj = ConnectorSlot.new(@@widget,"ruby_method")
                    obj.write Hash.new,sample
                    assert_equal sample.time.usec, @@widget.instance_variable_get(:@ruby_value).time.usec
                end

                it "must write a value with a given block" do
                    sample = Types::Base::Samples::Frame::Frame.new.zero!
                    sample.time = Time.now
                    obj = ConnectorSlot.new(@@widget,"setFrame")
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
                    obj = ConnectorSlot.new(@@widget,"getFrame")
                    assert_equal sample.time.usec, obj.read(Hash.new).time.usec
                end
            end
        end

        describe ConnectorSignal do
            describe "initialize" do 
                it "must raise if the signal is unknown" do 
                    assert_raises ArgumentError do 
                        ConnectorSignal.new(@@widget,"bla")
                    end
                end

                it "must raise if the signal signature is wrong" do 
                    assert_raises ArgumentError do 
                        ConnectorSignal.new(@@widget,"frameChanged(int)")
                    end
                end

                it "must raise if the signal is a slot" do 
                    assert_raises ArgumentError do 
                        ConnectorSignal.new(@@widget,"setFrame")
                    end
                end

                it "must accept different signature styles" do 
                    assert ConnectorSignal.new(@@widget,"void int2Changed(int,int)")
                    assert ConnectorSignal.new(@@widget,"void int2Changed")
                    assert ConnectorSignal.new(@@widget,"int2Changed(int,int)")
                    assert ConnectorSignal.new(@@widget,"int2Changed")
                end
            end

            describe "write" do 
                it "must reemit the signal if write is called" do
                    value = nil
                    @@widget.connect SIGNAL("intChanged(int)") do |val|
                        value = val
                    end
                    obj = ConnectorSignal.new(@@widget,"intChanged")
                    obj.write Hash.new,2
                    assert_equal 2,value
                end
            end

            describe "on_data" do 
                it "must call given block each time the signal is emitted" do
                    obj = ConnectorSignal.new(@@widget,"intChanged")
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

        describe ConnectorPort do
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

        describe ConnectorOperation do
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

        describe ConnectorProc do
            describe "write" do 
                it "must call the proc" do
                    called = false
                    p = lambda do
                        called = true
                    end
                    obj = ConnectorProc.new(@@widget,p)
                    obj.write Hash.new
                    assert_equal true, called
                end

                it "must call the proc with arguments" do
                    result = false
                    result2 = false
                    p = lambda do |a,b|
                        result,result2 = a,b
                    end
                    obj = ConnectorProc.new(@@widget,p)
                    obj.write(Hash.new,1,2)
                    assert_equal 1, result
                    assert_equal 2, result2
                end
            end
        end
    end
end
