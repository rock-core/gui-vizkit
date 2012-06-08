require File.join(File.dirname(__FILE__),"test_helper")
start_simple_cov("test_task_proxy")

require 'test/unit'
require 'vizkit'

Orocos.initialize
Vizkit.logger.level = Logger::INFO
Orocos.logger.level = Logger::INFO

class TaskProxyTest < Test::Unit::TestCase
    def setup
        Vizkit::OQConnection::max_reconnect_frequency = 1
    end

    def test_TaskProxyNotConnected
        task = Vizkit::TaskProxy.new("test_task")

        proxy_reader = task.port("out_dummy_port").reader()
        writer = task.port("in_dummy_port").writer
        port = task.port("out_dummy_port")

        assert(proxy_reader)
        assert(!proxy_reader.__reader_writer)
        assert(writer)
        assert_raise RuntimeError do 
            writer.type_name
        end
        assert_equal(:NotReachable,task.state)
        assert(writer.port)
        assert(writer.port.task)
        assert(!writer.port.task.__task)
        assert(!task.ping)
        assert(!task.has_port?("bla"))
        assert_raise RuntimeError do 
            assert(!port.type_name)
        end
    end

    def test_TaskProxyConnectedToPortProxy
        test_task = Vizkit::TaskProxy.new("test_task")
        assert(!test_task.reachable?)
        Orocos.run "port_proxy::Task" => "port_proxy",:output => "%m.log" do 
            task = Orocos::TaskContext.get "port_proxy"
            task.start
            assert_equal(:NotReachable,test_task.state)
        end
    end

    #a proxy connection should automatically connect to the given task and port
    #as soon the given task and port is reachable 
    def test_TaskProxyWithoutOrogenPortProxy
        #setup TaskProxy
        test_task = Vizkit::TaskProxy.new("test_task")
        reader = test_task.port("out_dummy_port").reader(:port_proxy => nil)
        writer = test_task.port("in_dummy_port").writer(:port_proxy => nil)

        connection = Types::PortProxy::ProxyConnection.new
        connection.task_name = "dummy"
        connection.port_name = "port"
        connection.type_name = "/base/Time"
        connection.periodicity = 0.1
        connection.check_periodicity = 1
        Orocos.run "port_proxy::Task" => "test_task",:output => "%m2.log" do 
            #setup source
            task2 = Orocos::TaskContext.get "test_task"
            task2.start
            assert(task2.createProxyConnection(connection))
            assert(task2.has_port? "out_dummy_port")
            assert(task2.has_port? "in_dummy_port")

            #check connection
            sleep(0.5)
            assert test_task.reachable?
            assert_equal :RUNNING,test_task.state
            assert !reader.connected?
            assert reader.__reader_writer
            assert reader.connected?
            assert reader.port.task.reachable?
            assert !reader.instance_variable_get(:@__orogen_port_proxy)

            #InputPorts are not using a port_proxy at all
            assert !writer.instance_variable_get(:@__orogen_port_proxy)
            assert writer.__reader_writer
            assert writer.connected?

            writer.write Time.now 
            sleep(0.3)
            assert(reader.read)
        end
        #now the source is killed 
        assert(!reader.connected?)
        assert(!writer.connected?)

        #check if the taskproxy can recover after the task is reachable again
        Orocos.run "port_proxy::Task" => "test_task",:output => "%m3.log" do 
            task2 = Orocos::TaskContext.get "test_task"
            task2.start
            assert(task2.createProxyConnection(connection))
            assert(task2.has_port? "out_dummy_port")
            assert(task2.has_port? "in_dummy_port")

            #check connection
            sleep(0.5)

            assert !reader.connected?
            assert reader.__reader_writer
            assert !writer.connected?
            assert writer.__reader_writer
            assert(reader.connected?)
            assert(writer.connected?)

            time = Time.now
            writer.write time
            sleep(0.3)
            assert_equal(time,reader.read)
        end
        assert(!reader.connected?)
        assert(!writer.connected?)
    end


    #a proxy connection should automatically connect to the given task and port
    #as soon the given task and port is reachable 
    def test_TaskProxyWithOrogenPortProxy
        #setup TaskProxy
        test_task = Vizkit::TaskProxy.new("test_task")

        proxy_reader = test_task.port("out_dummy_port").reader()
        writer = test_task.port("in_dummy_port").writer
        Orocos.run "port_proxy::Task" => "port_proxy",:output => "%m.log" do 
            #setup port porxy 
            task = Orocos::TaskContext.get "port_proxy"
            connection = Types::PortProxy::ProxyConnection.new
            connection.task_name = "test_task"
            connection.port_name = "out_dummy_port"
            connection.type_name = "/base/Time"
            connection.periodicity = 0.1
            connection.check_periodicity = 0.2
            task.start
            assert(task.createProxyConnection(connection))
            assert(task.has_port? "in_test_task_out_dummy_port")
            assert(task.has_port? "out_test_task_out_dummy_port")

            task2 = nil
            Orocos.run "port_proxy::Task" => "test_task",:output => "%m2.log" do 
                #setup source
                connection.task_name = "dummy"
                connection.port_name = "port"
                connection.type_name = "/base/Time"
                connection.periodicity = 0.1
                connection.check_periodicity = 1
                task2 = Orocos::TaskContext.get "test_task"
                task2.start
                assert(task2.createProxyConnection(connection))
                assert(task2.has_port? "out_dummy_port")
                assert(task2.has_port? "in_dummy_port")

                #check connection
                sleep(0.5)
                assert test_task.reachable?
                assert_equal :RUNNING,test_task.state
                assert_equal :RUNNING,test_task.state
                assert proxy_reader.__reader_writer
                assert proxy_reader.connected?
                assert proxy_reader.port.task.reachable?
                assert proxy_reader.instance_variable_get(:@__orogen_port_proxy)

                assert writer.instance_variable_get(:@__orogen_port_proxy)
                assert writer.__reader_writer
                assert writer.connected?

                writer.write Time.now 
                sleep(0.3)
                assert(proxy_reader.read)
                assert(!proxy_reader.read_new)
            end
            sleep(2)
            #now the source is killed
            assert(!task2.reachable?)
            assert(!proxy_reader.connected?)
            assert(!writer.connected?)

            #check if the taskproxy can recover after the task is reachable again
            Orocos.run "port_proxy::Task" => "test_task",:output => "%m3.log" do 
                task2 = Orocos::TaskContext.get "test_task"
                task2.start
                assert(task2.createProxyConnection(connection))
                assert(task2.has_port? "out_dummy_port")
                assert(task2.has_port? "in_dummy_port")

                #check connection
                sleep(0.5)
                assert proxy_reader.__reader_writer
                assert writer.__reader_writer
                assert(proxy_reader.connected?)
                assert(writer.connected?)

                #check that the task object is restored
                test_task.stop
                assert_equal :STOPPED,test_task.state
                test_task.start
                assert_equal :RUNNING,test_task.state
                time = Time.now
                writer.write time
                sleep(0.3)
                assert_equal(time,proxy_reader.read)
            end
            sleep(1.0)
            assert(!writer.connected?)
        end
        sleep(1.0)
        assert(!proxy_reader.connected?)
    end

    def test_proxy_subfield_reading
        Orocos.run "rock_port_proxy" do 
            task = Vizkit::ReaderWriterProxy.default_policy[:port_proxy]
            task.start

            connection = Types::PortProxy::ProxyConnection.new
            connection.task_name = "task"
            connection.port_name = "port"
            connection.type_name = "/base/samples/frame/FramePair"
            connection.periodicity = 0.1
            connection.check_periodicity = 0.2

            assert(task.reachable?)
            assert(task.createProxyConnection(connection))
            assert(task.has_port? "in_task_port")
            assert(task.has_port? "out_task_port")

            writer = task.in_task_port.writer
            writer.__reader_writer
            reader = task.out_task_port.reader
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
            sample.first.size.width = 100
            element = sample.first.raw_get_field("attributes").element_t.new
            element.data_ = "payload"
            element.name_ = "first"
            sample.first.attributes <<  element.dup
            element.name_ = "second"
            sample.first.attributes <<  element
            pp sample.first.attributes

            sample.second.time = Time.now
            sample.second.received_time = Time.now
            sample.second.frame_mode = :MODE_UNDEFINED
            sample.second.frame_status = :STATUS_EMPTY
            sample.second.data_depth = 1

            assert task.reachable?
            #task proxy has no connection on the input side therefore 
            #reader is not valid 
            assert !reader.connected? 
            reader.instance_variable_set :@__proxy_connected,true
            assert writer.connected?
            assert reader.connected?
            writer.write sample 
            sleep(1.0)
            assert(reader.read)

            #create a subfield reader
            subfield_port = task.out_task_port(:subfield => "first")
            assert(subfield_port)
            assert(subfield_port.type_name == "/base/samples/frame/Frame")
            reader = subfield_port.reader

            subfield_port2 = task.out_task_port(:subfield => ["first","size"],:typelib_type => Orocos.registry.get("/base/samples/frame/frame_size_t"))
            assert(subfield_port2)
            assert(subfield_port2.type_name == "/base/samples/frame/frame_size_t")
            reader2 = subfield_port2.reader

            subfield_port3 = task.out_task_port(:subfield => ["first","size","width"])
            assert(subfield_port3)
            assert_equal("/uint16_t",subfield_port3.type_name)
            reader3 = subfield_port3.reader

            subfield_port4 = task.out_task_port(:subfield => ["first","attributes",1,"name_"])
            assert(subfield_port4)
            assert_equal("/std/string",subfield_port4.type_name)
            reader4 = subfield_port4.reader

            subfield_port5 = task.out_task_port(:subfield => ["first","attributes",10,"name_"])
            assert(subfield_port5)
            assert_equal("/std/string",subfield_port5.type_name)
            reader5 = subfield_port5.reader

            subfield_port6 = task.out_task_port(:subfield => ["first","attributess"])
            assert(subfield_port6)
            assert_raise ArgumentError do
                subfield_port6.type_name
            end
            reader6 = subfield_port6.reader

            writer.write sample 
            sleep(2.0)
            assert_equal(reader.read.time.to_s, time_first.to_s) 
            assert(reader2.read) 
            assert_equal reader3.read,100
            assert_equal reader4.read,"second"

            #subfield does not exist
            #out of index
            assert_equal reader5.read,nil 
            #wrong spelling
            assert_raise ArgumentError do
                reader6.read
            end
        end
    end
end
