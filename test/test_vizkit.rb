require './test_helper'
require 'vizkit'

MiniTest::Unit.autorun
Orocos.initialize

class TestWidget < Qt::Object
    attr_accessor :sample
    def update(data,port_name)
        @sample = data
    end
end

describe Vizkit do
    before do
        Orocos::Async.clear
        Orocos::Async.name_service << Orocos::Async::CORBA::NameService.new
        Orocos::Async.steps

        Vizkit.instance_variable_set :@default_loader,nil
        Vizkit.default_loader.register_plugin("TestWidget",:ruby_plugin,TestWidget.method(:new))
        Vizkit.default_loader.register_plugin_for("TestWidget", "/base/samples/RigidBodyState",:display,nil,:update)
    end

    describe "remote task is not reachable" do 
        before do 
            sleep 0.1
            Orocos::Async.clear
            Orocos::Async.step
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
            con.must_be_kind_of Orocos::Async::EventListener
        end


        it "should setup a connection between a port and a method" do
            def result(a,b)
            end
            t = Vizkit.proxy "test"
            con = t.port("bla").connect_to method(:result)
            con.must_be_kind_of Orocos::Async::EventListener
        end

        it "should setup a connection between a port and a widget" do
            w = Vizkit.default_loader.ImageView
            t = Vizkit.proxy "test"
            con = t.port("bla",:type => Types::Base::Samples::Frame::Frame).connect_to w
            con.must_be_kind_of Orocos::Async::EventListener
        end
    end

    describe "when remote task is reachable" do
        before do
            #start virtual task
            if !@task
                Orocos.load_typekit "base"
                @task = Orocos::RubyTaskContext.new("task")
                @task.configure
                @task.start
                @port_time = @task.create_output_port("time","/base/Time")
                @port = @task.create_output_port("position","/base/samples/RigidBodyState")
                @sample = @port.new_sample
                @sample.time = Time.now
            end
        end

        it "should connect a port to a code block" do 
            t = Vizkit.proxy("task",:retry_period => 0.08,:period => 0.1,:wait=>true)
            data = nil
            t.port("position").connect_to do |sample,_|
                data = sample
            end
            Orocos::Async.steps
            @port.write @sample
            sleep 0.2
            Orocos::Async.steps
            sleep 0.2
            Orocos::Async.steps
            assert data
            (data.time-@sample.time).must_be_within_delta 1e-6
        end

        it "should connect a port to a widget" do 
            widget = Vizkit.default_loader.TestWidget
            t = Vizkit.proxy("task",:retry_period => 0.08,:period => 0.1,:wait=>true)
            data = nil
            l = t.port("position",:wait => true,:period => 0.05).connect_to widget
            Orocos::Async.steps
            @port.write @sample
            sleep 0.1
            Orocos::Async.steps
            assert widget.sample
            (widget.sample.time-@sample.time).must_be_within_delta 1e-6
        end

        it "should automatically find the right widget and connect it" do 
            t1 = Vizkit.proxy("task",:retry_period => 0.08,:period => 0.1)
            p = t1.port("position")
            p.wait
            w = Vizkit.display p
            w.must_be_instance_of Qt::Widget
        end

        it "should automatically find the right slot of a given widget" do 
            widget = Vizkit.default_loader.TestWidget

            t1 = Vizkit.proxy("task",:retry_period => 0.08,:period => 0.1)
            t1.unreachable!
            p = t1.port("position")
            assert !p.type?

            p.connect_to widget
            p.wait
            assert p.type?
            @port.write @port.new_sample
            sleep 0.1
            Orocos::Async.steps
            sleep 0.1
            Orocos::Async.steps
            Vizkit.process_events
            assert widget.sample
        end

        it "should raise if the right slot of a given widget cannot be found after the type is known" do 
            widget = Vizkit.default_loader.TestWidget
            t1 = Vizkit.proxy("task",:retry_period => 0.08,:period => 0.1)
            t1.unreachable!
            p = t1.port("time")
            assert !p.type?
            p.connect_to widget
            p.wait
            assert p.type?
            @port_time.write Time.now
            sleep 0.1
            assert_raises Orocos::NotFound do
                Orocos::Async.steps
            end
            assert_raises Orocos::NotFound do
                p.connect_to widget
            end
        end

        it "should emulate sub fields as sub ports" do 
            t1 = Vizkit.proxy("task",:retry_period => 0.08,:period => 0.1,:wait=>true)
            p = t1.port("position",:wait => true)
            sub = p.sub_port(:position)
            data = nil
            sub.on_data do |sample|
                data = sample
            end
            Orocos::Async.steps
            @port.write @port.new_sample
            sleep 0.1
            Orocos::Async.steps
            assert data

            w = Vizkit.display sub
            w.must_be_instance_of Qt::Widget
        end

        it "should connect to ports when reachable" do 
            data = nil
            Vizkit.connect_port_to "task","position" do |sample,_|
                data = sample
            end
            #wait that the underlying port proxy got connected
            Orocos::Async.proxy("task").port("position").wait
            Orocos::Async.steps

            # wait because we use pulled connections
            @port.write @port.new_sample
            sleep 0.3
            Orocos::Async.steps

            assert data
        end
    end
end
