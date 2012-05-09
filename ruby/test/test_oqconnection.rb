require File.join(File.dirname(__FILE__),"test_helper")
start_simple_cov("test_oqconnection")

require 'test/unit'
require 'vizkit'
Orocos.initialize
Vizkit.logger.level = Logger::INFO

class TestWidget < Qt::Widget
    attr_accessor :sample
    def update(data,port_name)
        @sample = data        
    end
end

class TestWidget2
    attr_accessor :sample
    def update(data,port_name)
        @sample = data        
    end
end
    
class OQConnectionTest < Test::Unit::TestCase
    def setup
        Vizkit::OQConnection::max_reconnect_frequency = 1
        Vizkit::ReaderWriterProxy.default_policy = {:port_proxy => Vizkit::TaskProxy.new("port_proxy"),:init => true}
    end

    def test_OQConnection
        Vizkit::ReaderWriterProxy.default_policy = {:port_proxy => Vizkit::TaskProxy.new("port_proxy"),:init => true}
        task = Vizkit::TaskProxy.new("port_proxy")

        #the reader and writer should automatically connect after the task was started
        writer = task.port("in_test").writer
        reader = task.port("out_test").reader

        #use directly OQConnection
        connection = Vizkit::OQConnection.new("port_proxy","out_test") do |sample,port_name|
            @sample = sample
        end
        connection.connect

        #Use OQConnection via PortProxy.connect_to
        widget = TestWidget.new
        widget.show
        Vizkit::TaskProxy.new("port_proxy").port("out_test").connect_to widget.method(:update)

        #Use OQConnection via Vizkit.connect_port_to
        Vizkit.connect_port_to "port_proxy","out_test" do |sample,_|
            @sample2 = sample
        end

        #testing phase where no task is present 
        0.upto(10) do
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end
            sleep(0.1)
        end

        #start task
        Orocos.run "rock_port_proxy" do 
            task.start
            assert(task.createProxyConnection("test","/base/Time",0.01,true))
            assert(task.has_port? "in_test")
            assert(task.has_port? "out_test")

            reader.read
            sleep(2)
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end
            writer.write Time.now 
            sleep 2
            assert(reader.read)
            sleep 2
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end
            assert(@sample)
            assert(@sample2)
            #test if sample was received
            assert(widget.sample)
        end

        #shutdown task 
        #and delete all samples
        @sample = nil
        @sample2 = nil
        widget.sample = nil
        assert(!reader.__valid?)

        #restart and test again
        Orocos.run "rock_port_proxy" do 
            task.start
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end

            assert(task.createProxyConnection("test","/base/Time",0.01,true))
            assert(task.has_port? "in_test")
            assert(task.has_port? "out_test")

            sleep(2.0)
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end

            reader.read
            writer.write Time.now 
            sleep(1.0)
            assert(reader.read)
            sleep(1.0)
            widget.hide 
            sleep(0.2)
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end

            assert(@sample)
            assert(@sample2)
            #test if sample was not received because it is hidden
            assert(!widget.sample)
            Vizkit.disconnect_all
            task.out_test.disconnect_from widget
        end
    end

    def test_connect_to_widget
        task = Vizkit::TaskProxy.new("port_proxy")

        #widget is not registered and connect_to is called 
        assert_raise RuntimeError do 
            widget = TestWidget.new
            task.port("out_test").connect_to widget
        end

        #the reader and writer should automatically connect after the task was started
        writer = task.port("in_test").writer
        reader = task.port("out_test").reader

        loader = Vizkit::UiLoader.new

        spec1 = Vizkit::UiLoader::register_ruby_widget("TestWidget",:new)
        spec2 = Vizkit::UiLoader::register_ruby_widget("TestWidget2",:new)
        Vizkit::UiLoader::register_widget_for("TestWidget","/base/Time",:update)
        Vizkit::UiLoader::register_widget_for("TestWidget2","/base/Time",:update)

        widget = TestWidget.new
        widget.show
        widget2 = TestWidget2.new
        spec1.extend_plugin(widget)
        widget2 = spec2.create_plugin

        task.port("out_test").connect_to widget
        task.port("out_test").connect_to widget2

        #testing phase where no task is present 
        0.upto(10) do
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end
            sleep(0.1)
        end

        #start task
        Orocos.run "rock_port_proxy" do 
            task.start
            assert(task.createProxyConnection("test","/base/Time",0.01,true))
            assert(task.has_port? "in_test")
            assert(task.has_port? "out_test")

            reader.read
            sleep(2)
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end
            writer.write Time.now 
            sleep 2
            assert(reader.read)
            sleep 2
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end
            assert(widget.sample)
            assert(widget2.sample)
        end
    end
end
