
#!/usr/bin/env ruby

require 'vizkit'
require 'test/unit'
Orocos.initialize

Vizkit.logger.level = Logger::INFO
Orocos.logger.level = Logger::INFO
    
class LoaderUiTest < Test::Unit::TestCase
    def setup
        Vizkit::ReaderWriterProxy.default_policy = {:port_proxy => Vizkit::TaskProxy.new("port_proxy"),:init => true}
        Vizkit::OQConnection::max_reconnect_frequency = 1
    end

    def test_orogen_default_port_proxy_deployment
        task = Vizkit::ReaderWriterProxy.default_policy[:port_proxy]
        writer = task.port("in_test").writer(:port_proxy =>  nil)
        Orocos.run "port_proxy::Task" => "port_proxy" do 
            task.start
            assert(task.createProxyConnection("test","/base/Time",0.01))
            assert(task.has_port? "in_test")
            assert(task.has_port? "out_test")
            reader = task.out_test.reader
            writer.write Time.now 
            sleep(0.2)
            assert(reader.read)
        end
    end

    def test_orogen_port_proxy_deployment
        task = Vizkit::ReaderWriterProxy.default_policy[:port_proxy]
        writer = task.port("in_test").writer(:port_proxy =>  nil)
        Orocos.run "rock_port_proxy" do 
            task.start
            assert(task.createProxyConnection("test","/base/Time",0.01))
            assert(task.has_port? "in_test")
            assert(task.has_port? "out_test")
            reader = task.out_test.reader
            writer.write Time.now 
            sleep(0.2)
            assert(reader.read)
        end
    end

    def test_orogen_port_proxy
        task = Vizkit::ReaderWriterProxy.default_policy[:port_proxy]
        port = task.port("out_test")

        Orocos.run "rock_port_proxy" do 
            task.start
            assert(task.load_plugins_for_type("/base/Time"))
            assert(task.createProxyConnection("test","/base/Time",0.01))
            assert(task.has_port? "in_test")
            assert(task.has_port? "out_test")
            assert(!task.proxy_port?(port))
            proxy_port = task.proxy_port(port,{:port_proxy_periodicity => 0.2})
            assert(proxy_port)
            assert(task.has_port? "in_port_proxy_out_test")
            assert(task.has_port? "out_port_proxy_out_test")
            assert(task.proxy_port?(port))
                       
            reader = proxy_port.reader
            writer = task.in_test.writer
            writer.write Time.new
            sleep(0.2)
            assert(reader.read)
        end
    end

    def test_task_proxy
        task = Vizkit::ReaderWriterProxy.default_policy[:port_proxy]

        proxy_reader = task.port("out_test").reader() #use task port_proxy as proxy
        #this is activating the port_proxy because the reader/writer is deactivating
        #it if a proxy port shall be proxied
        proxy_reader.instance_variable_set(:@__orogen_port_proxy,task)
        proxy_reader.__reader_writer

        writer = task.port("in_test").writer(:port_proxy => nil)
        port = task.port("out_test")
        reader = port.reader(:port_proxy => nil)

        assert(writer)
        assert(reader)
        assert(proxy_reader)
        assert(!writer.type_name)
        assert(writer.port)
        assert(writer.port.task)
        assert(!writer.port.task.__task)
        assert(!task.ping)
        assert(!task.has_port?("bla"))
        assert(!port.type_name)

        Orocos.run "rock_port_proxy" do 
            assert (task.ping)
            assert (!task.has_port?("bla"))

            task.start

            assert(task.createProxyConnection("test","/base/Time",0.01))
            assert(task.has_port? "in_test")
            assert(task.has_port? "out_test")
            assert(port.type_name)

            reader.read
            sleep(2)
            #test without port_proxy
            writer.write Time.now 
            sleep(2)
            assert(reader.read)

            #test with port_proxy
            proxy_reader.read
            temp_reader = task.__task.out_port_proxy_out_test.reader
            writer.write Time.now 
            sleep 0.2
            assert(temp_reader.read)
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
            sleep 0.4
            assert(proxy_reader.read)
        end
    end

    def test_proxy_subfield_reading
        Orocos.run "rock_port_proxy" do 
            task = Vizkit::ReaderWriterProxy.default_policy[:port_proxy]
            task.start

            assert(task.createProxyConnection("test","/base/samples/frame/FramePair",0.01))
            assert(task.has_port? "in_test")
            assert(task.has_port? "out_test")

            writer = task.in_test.writer
            writer.instance_variable_set(:@__orogen_port_proxy,task)
            writer.__reader_writer
            reader = task.out_test.reader
            reader.instance_variable_set(:@__orogen_port_proxy,task)
            reader.__reader_writer
            assert(writer)
            assert(reader)

            sample = Types::Base::Samples::Frame::FramePair.new
            time_first = Time.now-1000
            sample.time = Time.now
            sample.first.time = time_first
            sample.first.data_depth = 1
            sample.first.received_time = Time.now
            sample.first.frame_mode = :MODE_UNDEFINED
            sample.first.frame_status = :STATUS_EMPTY
            sample.second.time = Time.now
            sample.second.received_time = Time.now
            sample.second.frame_mode = :MODE_UNDEFINED
            sample.second.frame_status = :STATUS_EMPTY
            sample.second.data_depth = 1
            writer.write sample 
            sleep(0.2)
            assert(reader.read)

            #create a subfield reader
            subfield_port = task.out_test(:subfield => "first",:type_name =>"/base/samples/frame/Frame")
            assert(subfield_port)
            assert(subfield_port.type_name == "/base/samples/frame/Frame")
            reader = subfield_port.reader
            
            subfield_port2 = task.out_test(:subfield => ["first","size"],:type_name =>"/base/samples/frame/frame_size_t")
            assert(subfield_port2)
            assert(subfield_port2.type_name == "/base/samples/frame/frame_size_t")
            reader2 = subfield_port2.reader

            writer.write sample 
            sleep(0.2)
            assert(reader.read.time == time_first) 
            assert(reader2.read) 
        end
    end
end
