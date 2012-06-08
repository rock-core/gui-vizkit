require File.join(File.dirname(__FILE__),"test_helper")
start_simple_cov("test_oqconnection")

require 'test/unit'
require 'vizkit'
Orocos.initialize
#Vizkit.logger.level = Logger::INFO

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
    end

    def test_OQConnection
        task = Vizkit::TaskProxy.new("port_proxy")

        #the reader and writer should automatically connect after the task was started
        writer = task.port("in_task_port").writer
        reader = task.port("out_task_port").reader

        #use directly OQConnection
        connection = Vizkit::OQConnection.new("port_proxy","out_task_port",:port_proxy => nil) do |sample,port_name|
            @sample = sample
        end
        connection.connect
        Vizkit.connections << connection

        #Use OQConnection via PortProxy.connect_to
        widget = TestWidget.new
        widget.show
        Vizkit::TaskProxy.new("port_proxy").port("out_task_port").connect_to widget.method(:update),:port_proxy => nil

        #Use OQConnection via Vizkit.connect_port_to
        Vizkit.connect_port_to "port_proxy","out_task_port",:port_proxy => nil do |sample,_|
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
            connection = Types::PortProxy::ProxyConnection.new
            connection.task_name = "task"
            connection.port_name = "port"
            connection.type_name = "/base/Time"
            connection.periodicity = 0.1
            connection.check_periodicity = 0.2

            task.start
            assert(task.createProxyConnection(connection))
            assert(task.has_port?("out_task_port"))

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

        sleep(1.0)
        #shutdown task 
        #and delete all samples
        @sample = nil
        @sample2 = nil
        widget.sample = nil
        assert(!reader.connected?)

        #restart and test again
        Orocos.run "rock_port_proxy" do 
            connection = Types::PortProxy::ProxyConnection.new
            connection.task_name = "task"
            connection.port_name = "port"
            connection.type_name = "/base/Time"
            connection.periodicity = 0.1
            connection.check_periodicity = 0.2
            task.start
            assert_equal :RUNNING, task.state
            assert(task.createProxyConnection(connection))
            assert(task.has_port?("out_task_port"))

            sleep(1.0)
            widget.hide 
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end
            sleep(1.0)
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end

            reader.read 
            assert reader.connected?
            writer.write Time.now 
            sleep(1.0)
            assert(reader.read)
            sleep(1.0)
            sleep(1.0)
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end
            sleep(1.0)
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end

            assert(@sample)
            assert(@sample2)
            #test if sample was not received because it is hidden
            assert(!widget.sample)
            Vizkit.disconnect_all
            task.out_task_port.disconnect_from widget
        end
    end

    def test_connect_to_widget
        task = Vizkit::TaskProxy.new("port_proxy")

        #widget is not registered and connect_to is called 
        assert_raise RuntimeError do 
            widget = TestWidget.new
            task.port("out_task_port").connect_to widget
        end

        #the reader and writer should automatically connect after the task was started
        writer = task.port("in_task_port").writer
        reader = task.port("out_task_port").reader

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

        task.port("out_task_port").connect_to widget
        task.port("out_task_port").connect_to widget2

        #testing phase where no task is present 
        0.upto(10) do
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end
            sleep(0.1)
        end

        #start task
        Orocos.run "rock_port_proxy" do 
            connection = Types::PortProxy::ProxyConnection.new
            connection.task_name = "task"
            connection.port_name = "port"
            connection.type_name = "/base/Time"
            connection.periodicity = 0.1
            connection.check_periodicity = 0.2
            task.start
            assert(task.createProxyConnection(connection))
            assert(task.has_port?("out_task_port"))

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
