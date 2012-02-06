
#!/usr/bin/env ruby

require 'vizkit'
require 'test/unit'
Orocos.initialize

Vizkit.logger.level = Logger::INFO

class TestWidget < Qt::Widget
    def upadte(data,port_name)

    end
end
    
class LoaderUiTest < Test::Unit::TestCase
    def setup
    end

    def test_OQConnection
        task = Vizkit::TaskProxy.new("port_proxy")

        #the reader and writer should automatically connect after the task was started
        writer = task.port("in_test").writer
        reader = task.port("out_test").reader

        connection = Vizkit::OQConnection.new("port_proxy","out_test") do |sample,port_name|
            @sample = sample
        end
        connection.connect

        Orocos.run "rock_port_proxy" do 
            task.start
            assert(task.createProxyConnection("test","/base/Time",0.01))
            assert(task.has_port? "in_test")
            assert(task.has_port? "out_test")

            while $qApp.hasPendingEvents
                $qApp.processEvents
            end

            writer.write Time.now 
            reader.read
            sleep(0.2)
            assert(reader.read)
            
            while $qApp.hasPendingEvents
                $qApp.processEvents
            end

            assert(@sample)
        end
    end
end
