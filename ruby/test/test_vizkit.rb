require File.join(File.dirname(__FILE__),"test_helper")
start_simple_cov("test_vizkit")

require 'vizkit'
require 'test/unit'
Orocos.initialize
Orocos.load_typekit "base"

Vizkit.logger.level = Logger::INFO

    
class VizkitTest < Test::Unit::TestCase
    class TestWidget < Qt::Object
        attr_accessor :sample

        def update(data,port_name)
            @sample = data        
        end
    end
    def setup
        Vizkit.instance_variable_set :@default_loader,nil
        #generate log file 
        @log_path = File.join(File.dirname(__FILE__),"test_log")
        if !File.exist?(@log_path+".0.log")
            output = Pocolog::Logfiles.create(@log_path,Orocos.registry)
            Orocos.load_typekit_for("/base/Time")
            stream_output = output.stream("test_task.time","/base/Time",true)

            time = Time.now
            0.upto 100 do |i|
                stream_output.write(time+i,time+i,time+i)
            end
            output.close
        end
    end

    #test integration between Vizkit, TaskProxy and Replay
    def test_1_vizkit_log_replay
        #open log file
        log = Orocos::Log::Replay.open(@log_path+".0.log")
        assert(log)

        Vizkit.connect_port_to "test_task","time" do |sample,_|
            @sample = sample
        end

        #create TaskProxy
        task = Vizkit::TaskProxy.new("test_task")
        assert(task)
        port = task.port("time")
        assert(port)
        reader = port.reader
        #check disconnect for log reader which is not initialized
        reader.disconnect
        assert(reader)

        assert(!reader.read)
        assert(!reader.connected?)
        assert(!task.reachable?)
        log.track(true)
        log.align

        #test type of the underlying objects
        assert(task.__task.is_a?(Orocos::Log::TaskContext))
        assert(port.task.__task.is_a?(Orocos::Log::TaskContext))
        assert(port.__port.is_a?(Orocos::Log::OutputPort))
        #test if task is reachable now

        assert(task.reachable?)
        assert(port.task.reachable?)
        assert(reader.__reader_writer)
        assert(reader.connected?)

        assert(Vizkit.display task)
        assert(Vizkit.control task)

        #start replay 
        sleep(0.2)
        while $qApp.hasPendingEvents
            $qApp.processEvents
        end
        log.step
        assert(reader.read)
        sleep(0.2)
        while $qApp.hasPendingEvents
            $qApp.processEvents
        end
        assert(@sample)
    end

    def test_vizkit_display
        log = Orocos::Log::Replay.open(@log_path+".0.log")
        assert(log)
    task = Vizkit::ReaderWriterProxy.default_policy[:port_proxy]

        Orocos.run "rock_port_proxy" do 
            task.start

            connection = Types::PortProxy::ProxyConnection.new
            connection.task_name = "task"
            connection.port_name = "port"
            connection.type_name = "/base/Time"
            connection.periodicity = 0.1
            connection.check_periodicity = 0.2
            assert(task.createProxyConnection(connection))
            assert(task.has_port?("out_task_port"))

            pp Vizkit.default_loader.find_all_plugin_specs(:argument => task.out_task_port,:default => false)

            widget = Vizkit.display task.out_task_port
            assert(widget)
            widget.close

            widget = Vizkit.display log.test_task.time
            assert(widget)
            widget.close

            task2 = Vizkit::TaskProxy.new("test_task")
            #task does not exist 
            assert_raise RuntimeError do 
                widget = Vizkit.display task2.port("time22")
            end
            widget = Vizkit.display task2.time
            assert(widget)
            widget.close

            assert(Vizkit.display task)
            assert(Vizkit.control task)
        end
    end

    def test_vizkit_control
        task = Vizkit::ReaderWriterProxy.default_policy[:port_proxy]

        Orocos.run "rock_port_proxy" do 
            task.start
            task.closeAllProxyConnections
            sleep(1)
            assert(!task.has_port?("out_task_port2"))
            connection = Types::PortProxy::ProxyConnection.new
            connection.task_name = "task"
            connection.port_name = "port2"
            connection.type_name = "/base/Angle"
            connection.periodicity = 0.1
            connection.check_periodicity = 0.2
            assert_equal("/base/Angle",connection.type_name)
            assert(task.createProxyConnection(connection))
            assert(task.has_port?("out_task_port2"))
            assert_equal("/base/Angle",task.out_task_port2.type_name)

            widget = Vizkit.control task.out_task_port2.type_name
            assert(widget)
            widget.close

            widget = Vizkit.control task.out_task_port2
            assert(widget)
            widget.close

            widget = Vizkit.control task.out_task_port2.new_sample
            assert(widget)
            widget.close
        end
        #process events otherwise qt is crashing
        sleep(0.2)
        while $qApp.hasPendingEvents
            $qApp.processEvents
        end
    end

    def test_vizkit_connect_port_to
        log = Orocos::Log::Replay.open(@log_path+".0.log")
        log.track(true)
        log.align
        assert(log)
        time = nil
        Vizkit.connect_port_to("test_task","time") do |sample, _|
            time = sample
            123
        end
        log.step
        sleep(0.5)
        while $qApp.hasPendingEvents
            $qApp.processEvents
        end
        assert(time)
        #test connect_port_to with an orocos task
    end

    def test_vizkit_disconnect

    end
end
