require 'vizkit/test'

Vizkit.default_loader.add_plugin_path File.join(File.dirname(__FILE__),"..","..","build","test","test_vizkit_widget")

describe Vizkit::TypelibQtAdapter do
    before do
        if !@widget
            assert Vizkit.default_loader.widget? "TestVizkitWidget"
            @widget = Vizkit.default_loader.TestVizkitWidget
            @widget.extend Vizkit::QtTypelibExtension
        end
        assert @widget
    end

    describe "call methods with qt types as argument and return value" do
        it "must be possible to set the window title" do 
            @widget.setWindowTitle("Test Widget - 123")
            assert_equal "Test Widget - 123", @widget.windowTitle
        end
    end

    describe "call methods with typelib type as argument and return value" do
        it "it must be possible to call setFrame and getFrame" do 
            sample = Types::Base::Samples::Frame::Frame.new
            sample.zero!
            sample.time = Time.now
            @widget.setFrame(sample)
            frame = @widget.getFrame()
            assert_equal(sample.time.usec,frame.time.usec)
        end
    end
end
