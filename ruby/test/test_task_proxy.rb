
#!/usr/bin/env ruby

require 'vizkit'
require 'test/unit'
Orocos.initialize

Vizkit.logger.level = Logger::INFO
    
class LoaderUiTest < Test::Unit::TestCase
    def setup
    end

    def test_proxy
        task = Vizkit::TaskProxy.new("port_proxy")
        proxy_reader = nil
        writer = nil 
        reader = nil

        assert (!task.ping)
        assert (!task.has_port?("bla"))

        Orocos.run "rock_port_proxy" do 
            assert (task.ping)
            assert (!task.has_port?("bla"))

            task.start

            assert(task.createProxyConnection("test","/base/Time",0.01))
            assert(task.has_port? "in_test")
            assert(task.has_port? "out_test")

            #test without port_proxyxy
            writer = task.in_test.writer
            reader = task.out_test.reader
            assert(writer)
            assert(reader)

            writer.write Time.now 
            reader.read
            sleep(0.2)
            assert(reader.read)

            #test with port_proxy
            #we are connecting the proxy with itsself to test setting up the port_proxy
            proxy_reader = task.port("out_test")
            assert(proxy_reader)
            proxy_reader = proxy_reader.reader(:port_proxy => "port_proxy") #use task port_proxy as proxy
            assert(proxy_reader)
            writer.write Time.now 
            sleep 0.2
            assert(proxy_reader.read)
            puts "#### NOW I AM KILLING THE PROXY TO TEST RECONNECT #####"
        end

        #testing reconnecting
        assert(!task.ping)
        Orocos.run "rock_port_proxy" do 
            puts "#### RESTART PROXY #####"
            assert (task.ping)
            assert (!task.has_port?("bla"))
            task.start

            #create ports again
            assert(task.createProxyConnection("test","/base/Time",0.01))
            assert(task.has_port? "in_test")
            assert(task.has_port? "out_test")

            proxy_reader.read # this should reconnect the proxy
            writer.write Time.now 
            sleep 0.2
            assert(proxy_reader.read)
        end
    end
end
