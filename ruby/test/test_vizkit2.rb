require 'minitest/spec'
require 'vizkit'

MiniTest::Unit.autorun
Orocos.initialize

class TestWidget < Qt::Object
    attr_accessor :sample
    def update(data,port_name)
        @sample = data
    end
end

Vizkit.default_loader.register_plugin("TestWidget",:ruby_plugin,TestWidget.method(:new))
Vizkit.default_loader.register_plugin_for("TestWidget", "/base/samples/RigidBodyState",:display,nil,:update)

describe Vizkit do
    before do 
        Orocos::Async.clear
    end

    describe "remote task is not reachable" do 
        before do 
            Orocos::Async.clear
        end

        it "should create a proxy for a remote tasks" do
            t = Vizkit.proxy "test"
            t.must_be_kind_of Orocos::Async::TaskContextProxy
        end

        it "should raise Orocos::NotFound if a task context is requested" do
            assert_raises(Orocos::NotFound) do
                t = Vizkit.get "test"
            end
        end

        it "should setup a connection between a port and code block" do
            t = Vizkit.proxy "test"
            con = t.port("bla").connect_to{|data,name|}
            con.must_be_kind_of Orocos::Async::PortProxy
        end


        it "should setup a connection between a port and a method" do
            def result(a,b)
            end
            t = Vizkit.proxy "test"
            con = t.port("bla").connect_to method(:result)
            con.must_be_kind_of Orocos::Async::PortProxy
        end

        it "should raise if a connection is setup to widget but the type name is unknown" do
            w = Vizkit.default_loader.StructViewer
            t = Vizkit.proxy "test"
            assert_raises ArgumentError do 
                con = t.port("bla").connect_to w
            end
        end

        it "should setup a connection between a port and a widget" do
            w = Vizkit.default_loader.ImageView
            t = Vizkit.proxy "test"
            con = t.port("bla",:type_name => "/base/samples/frame/Frame").connect_to w
            con.must_be_kind_of Orocos::Async::PortProxy
        end
    end

    describe "when remote task is reachable" do
        #start virtual task
        Orocos.load_typekit "base"
        task = Orocos::RubyTaskContext.new("task")
        task.configure
        task.start
        port = task.create_output_port("position","/base/samples/RigidBodyState")
        sample = port.new_sample
        sample.time = Time.now

        it "should connect a port to a code block" do 
            t = Vizkit.proxy "task"
            data = nil
            t.port("position").connect_to do |sample,_|
                data = sample
            end
            5.times do
                Vizkit.step
                sleep 0.05
            end
            port.write sample
            5.times do
                Vizkit.step
                sleep 0.05
            end
            assert data
            (data.time-sample.time).must_be_within_delta 1e-6
        end

        it "should connect a port to a widget" do 
            widget = Vizkit.default_loader.TestWidget
            t = Vizkit.proxy "task"
            data = nil
            t.port("position",:wait => true).connect_to widget
            port.write sample
            5.times do
                Vizkit.step
                sleep 0.05
            end
            assert widget.sample
            (widget.sample.time-sample.time).must_be_within_delta 1e-6
        end
    end
end
