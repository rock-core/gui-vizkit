require File.join(File.dirname(__FILE__),"test_helper")
start_simple_cov("test_typelib_qt_adapter")

require 'vizkit'
require 'minitest/spec'

Orocos.initialize
Orocos.load_typekit "base"
Vizkit.default_loader.add_plugin_path File.join(File.dirname(__FILE__),"..","..","build","test","test_vizkit_widget")
MiniTest::Unit.autorun

describe Vizkit::WidgetTaskConnector do
    before do
        if !@widget
            assert Vizkit.default_loader.widget? "TestVizkitWidget"
            @widget = Vizkit.default_loader.TestVizkitWidget
            @widget.extend Vizkit::QtTypelibExtension
            @task = Orocos::Async.proxy "test_task"
            @connector = Vizkit::WidgetTaskConnector.new(@widget,@task)
            @ruby_task = Orocos::RubyTaskContext.new("test_task")
            @ruby_task.create_property("prop1","/base/samples/RigidBodyState")
            @ruby_task.create_input_port("int_port","int")
            @ruby_task.create_input_port("frame","/base/samples/frame/Frame")
            #make sure the task and port is connected
            @task.wait
            @task.port("int_port").wait
            @task.port("frame").wait
        end
        @widget.disconnect
        @widget.close
        Vizkit.process_events
    end

    describe "method_name" do
        it "returns the name without the parameters" do 
            name = @connector.send :method_name,"test(int)"
            assert_equal "test",name
            name = @connector.send :method_name,"test"
            assert_equal "test",name
        end
    end

    describe "valid_slot?" do
        it "returns true if the slot is known" do 
            assert @connector.send :valid_slot?, "setFrame(base::samples::frame::Frame)"
            assert @connector.send :valid_slot?, "setFrame"
        end
        it "returns false if the slot is unknown" do 
            assert !@connector.send(:valid_slot?, "setFrame(base::samples::frame::FramePair)")
            assert !@connector.send(:valid_slot?, "setBla")
        end
    end

    describe "resolve" do
        describe "SIGNAL" do
            it "raises if signal is unknown" do 
                assert_raises ArgumentError do
                    @connector.send(:resolve,@connector.SIGNAL("intChanged2(int,int)"))
                end
            end

            it "returns :signal" do 
                assert_equal :signal,@connector.send(:resolve,@connector.SIGNAL("intChanged(int)")).first
            end

            it "returns :signal" do 
                assert_equal :signal,@connector.send(:resolve,@connector.SIGNAL("intChanged")).first
            end
        end

        describe "SLOT" do
            it "raises if slot has more than one parameter" do 
                assert_raises ArgumentError do
                    @connector.send(:resolve,@connector.SLOT("set2Int(int,int)"))
                end
            end

            it "raises if slot is unknown" do 
                assert_raises ArgumentError do
                    @connector.send(:resolve,@connector.SLOT("set(int,int)"))
                end
            end

            it "returns the :slot" do 
                assert_equal :slot,@connector.send(:resolve,@connector.SLOT("setFrame")).first
            end
        end
    end

    describe "connect_signal_to_port" do
        before do 
            @widget.disconnect
            @widget.close
            Vizkit.process_events
        end

        it "directly connects signals to ports" do 
            @connector.send(:connect_signal_to_port,"intChanged(int)","int_port",Hash.new)
            @widget.intChanged(2)
            Vizkit.process_events
            Orocos::Async.steps
            assert_equal 2,@ruby_task.int_port.read_new
        end

        it "uses a getter function" do 
            @connector.send(:connect_signal_to_port,"frameChanged()","frame",:getter => "const base::samples::frame::Frame getFrame()const")
            sample = Types::Base::Samples::Frame::Frame.new.zero!
            sample.time = Time.now
            @widget.setFrame sample
            Vizkit.process_events
            @widget.frameChanged
            Vizkit.process_events
            Orocos::Async.steps
            assert_equal sample.time.usec,@ruby_task.frame.read_new.time.usec
        end

        it "uses a getter function (signal signature is not fully defined)" do 
            @connector.send(:connect_signal_to_port,"frameChanged","frame",:getter => "getFrame")
            sample = Types::Base::Samples::Frame::Frame.new.zero!
            sample.time = Time.now
            @widget.setFrame sample
            Vizkit.process_events
            @widget.frameChanged
            Vizkit.process_events
            Orocos::Async.steps
            assert_equal sample.time.usec,@ruby_task.frame.read_new.time.usec
        end

        it "raises if there is no getter and the signal is not passing a parameter" do
            assert_raises ArgumentError do 
                @connector.send(:connect_signal_to_port,"frameChanged()","frame",:getter => nil)
            end
        end

        it "raises if types are not compatible" do 
        #    @connector.send(:connect_signal_to_port,"intChanged(int)","int_port",Hash.new)
        end

    end

end
