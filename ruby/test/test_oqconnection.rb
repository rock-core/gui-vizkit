
#!/usr/bin/env ruby

require 'vizkit'
require 'test/unit'
Orocos.initialize

Vizkit.logger.level = Logger::INFO

class TestWidget < Qt::Object
    attr_accessor :sample

    def update(data,port_name)
        @sample = data        
    end
end
    
class LoaderUiTest < Test::Unit::TestCase
    def setup
        Vizkit::OQConnection::max_reconnect_frequency = 1
        Vizkit::ReaderWriterProxy.default_policy = {:port_proxy => Vizkit::TaskProxy.new("port_proxy"),:init => true}
    end

    def test_OQConnection
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
        Vizkit::TaskProxy.new("port_proxy").port("out_test").connect_to widget 

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
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end

            assert(@sample)
            assert(@sample2)
            #test if sample was received
            assert(widget.sample)
        end
    end
end
