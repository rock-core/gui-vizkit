require 'vizkit/test'

describe Vizkit::WidgetTaskConnector do
    class SandBoxWidgetTaskConnector < MiniTest::Spec
        def self.prepare
            @@widget = Vizkit.default_loader.create_plugin("vizkit3d::Vizkit3DWidget")
            @@widget.extend Vizkit::QtTypelibExtension
            @@widget.setTransformation("world","bla",Qt::Vector3D.new,Qt::Quaternion.new)
            @@widget.setTransformation("world","world2",Qt::Vector3D.new,Qt::Quaternion.new)
            @@widget.setTransformation("world","world3",Qt::Vector3D.new,Qt::Quaternion.new)

            @@task = Orocos::Async.proxy "test_task"
            @@connector = Vizkit::WidgetTaskConnector.new(@@widget,@@task)
            @@ruby_task = Orocos::RubyTaskContext.new("test_task")
            @@ruby_task.create_property("prop1","/std/string")
            @@ruby_task.create_input_port("string_port","/std/string")
            @@ruby_task.create_output_port("string_oport","/std/string")

            #make sure the task and port is connected
            @@task.port("string_port").wait
            @@task.port("string_oport").wait
            @@task.property("prop1").wait
            def @@widget.ruby_method(value)
                @ruby_value = value
            end
        end

        prepare
        before do
            @@widget.disconnect
            @@widget.close
            @@ruby_task.string_oport.disconnect_all
            @@ruby_task.string_port.disconnect_all
            Vizkit.process_events
        end

        describe "resolve" do
            describe "SIGNAL" do
                it "raises if signal is unknown" do 
                    assert_raises ArgumentError do
                        @@connector.send(:resolve,@@connector.SIGNAL("intChanged2(int,int)"))
                    end
                end

                it "returns ConnectorSlot" do 
                    @@connector.send(:resolve,@@connector.SIGNAL("propertyChanged(QString)")).must_be_kind_of ConnectorSignal
                end

                it "returns :signal" do 
                    @@connector.send(:resolve,@@connector.SIGNAL("propertyChanged")).must_be_kind_of ConnectorSignal
                end
            end

            describe "SLOT" do
                it "raises if slot is unknown" do 
                    assert_raises ArgumentError do
                        @@connector.send(:resolve,@@connector.SLOT("set(int,int)"))
                    end
                end

                it "returns the :slot" do 
                    @@connector.send(:resolve,@@connector.SLOT("setTransformer")).must_be_kind_of ConnectorSlot
                end
            end
        end

        describe "connect" do
            before do
                @@widget.disconnect
                @@widget.close
                @@ruby_task.string_oport.disconnect_all
                @@ruby_task.string_port.disconnect_all
                Orocos::Async.steps
                @@task.port("string_port").unreachable!
                @@task.port("string_oport").unreachable!
                Vizkit.process_events
                Orocos::Async.steps
                Vizkit.process_events
            end

            it "directly connect signal to port" do
                @@connector.connect @@connector.SIGNAL("propertyChanged(QString)"),@@connector.PORT("string_port")
                Orocos::Async.steps
                @@widget.setVisualizationFrame("world")
                Vizkit.process_events
                Orocos::Async.steps
                assert_equal "frame",@@ruby_task.string_port.read_new
            end

            it "uses a getter function" do
                @@connector.connect @@connector.SIGNAL("propertyChanged"),@@connector.PORT("string_port"),:getter => @@connector.SLOT("QString getVisualizationFrame()")
                Orocos::Async.steps
                @@widget.setVisualizationFrame "world2"
                Vizkit.process_events
                Orocos::Async.steps
                assert_equal "world2",@@ruby_task.string_port.read_new
            end

            it "uses a getter function and buffered connection" do
                @@connector.connect(@@connector.SIGNAL("propertyChanged"),@@connector.PORT("string_port"),
                                    :getter => @@connector.SLOT("QString getVisualizationFrame()"),:type =>:buffer,:size => 10)
                Orocos::Async.steps
                @@widget.setVisualizationFrame "world"
                Vizkit.process_events
                @@widget.setVisualizationFrame "world2"
                Vizkit.process_events
                @@widget.setVisualizationFrame "world3"
                Vizkit.process_events

                Orocos::Async.steps
                assert_equal "world",@@ruby_task.string_port.read_new
                assert_equal "world2",@@ruby_task.string_port.read_new
                assert_equal "world3",@@ruby_task.string_port.read_new
            end

            it "uses a getter function (signal signature is not fully defined)" do 
                @@connector.connect @@connector.SIGNAL("propertyChanged"),@@connector.PORT("string_port"),:getter => @@connector.SLOT("getVisualizationFrame")
                Orocos::Async.steps
                @@widget.setVisualizationFrame "world3"
                Vizkit.process_events
                Orocos::Async.steps
                assert_equal "world3",@@ruby_task.string_port.read_new
            end

            it "connect a property to slot" do 
                @@widget.setVisualizationFrame("world")
                @@connector.connect @@connector.PROPERTY(:prop1),@@connector.SLOT("setVisualizationFrame(QString)")
                Orocos::Async.steps

                @@ruby_task.prop1 = "bla"
                Orocos::Async.steps
                sleep 0.2
                Orocos::Async.steps
                Vizkit.process_events
                assert_equal "bla" ,@@widget.getVisualizationFrame
            end

            it "connect a port to slot" do 
                @@widget.setVisualizationFrame("bla")
                Vizkit.process_events
                @@connector.connect @@connector.PORT("string_oport"),@@connector.SLOT("setVisualizationFrame(QString)")
                Orocos::Async.steps

                @@ruby_task.string_oport.write "world"
                sleep 0.11
                Orocos::Async.steps
                Vizkit.process_events
                assert_equal "world",@@widget.getVisualizationFrame
            end

            it "connect a port to a proc using bufferd connection" do
                values = Array.new
                # clear buffer

                @@connector.connect @@connector.PORT("string_oport"),:type => :buffer,:size => 10 do |data|
                    values << data
                end
                Orocos::Async.steps

                @@ruby_task.string_oport.write "world"
                @@ruby_task.string_oport.write "world2"
                @@ruby_task.string_oport.write "world3"

                sleep 0.2
                Orocos::Async.steps
                sleep 0.2
                Orocos::Async.steps
                sleep 0.2
                Orocos::Async.steps
                assert_equal ["world","world2","world3"],values
            end

            it "connect a signal to a property" do
                @@connector.connect @@connector.SIGNAL("propertyChanged(QString)"),@@connector.PROPERTY("prop1"),:getter => SLOT("getVisualizationFrame")
                Orocos::Async.steps

                @@widget.setVisualizationFrame("bla")
                Vizkit.process_events
                sleep 0.11
                Orocos::Async.steps
                assert_equal "bla",@@ruby_task.prop1
            end


            it "raises if types are not compatible" do 
            #    @@connector.send(:connect_signal_to_port,"intChanged(int)","int_port",Hash.new)
            end
        end
    end
end
