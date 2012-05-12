require File.join(File.dirname(__FILE__),"test_helper")
start_simple_cov("test_uiloader")

require 'test/unit'
require 'vizkit'

Orocos.initialize
Orocos.load_typekit "base"

class LoaderUiTest < Test::Unit::TestCase

    def setup
        @loader = Vizkit.default_loader
        Vizkit::UiLoader.current_loader_instance = @loader
        Vizkit::UiLoader.current_loader_instance.plugin_specs.delete("QWidget")
    end

    def test_qt
        assert defined? Qt
        assert defined? Qt::Application
    end

    def test_loader_exists
        assert(@loader)
    end

    def test_to_typelib_name
        assert_equal("/base/samples/frame/Frame",Vizkit::PluginHelper.to_typelib_name("Types::Base::Samples::Frame::Frame"))
        assert_equal("/base/Angle",Vizkit::PluginHelper.to_typelib_name("Types::Base::Angle"))
    end

    def test_class_from_string
        assert_equal String, Vizkit::PluginHelper.class_from_string("String")
        assert_equal String, Vizkit::PluginHelper.class_from_string(String)
        assert_equal Array, Vizkit::PluginHelper.class_from_string("Array")
        assert_equal nil, Vizkit::PluginHelper.class_from_string("Array2")
        assert_equal Qt::Widget, Vizkit::PluginHelper.class_from_string("Qt::Widget")
        assert_equal Types::Base::Samples::RigidBodyState, Vizkit::PluginHelper.class_from_string("Types::Base::Samples::RigidBodyState")
        assert_equal Types::Base::Samples::RigidBodyState, Vizkit::PluginHelper.class_from_string("/base/samples/RigidBodyState")
        assert_equal Types::Base::Samples::RigidBodyState, Vizkit::PluginHelper.class_from_string("/base/samples/RigidBodyState_m")
        assert_equal Types::Base::Angle, Vizkit::PluginHelper.class_from_string("Types::Base::Angle")
        assert_equal Types::Base::Angle, Vizkit::PluginHelper.class_from_string("/base/Angle")
    end

    def test_map_obj
        Vizkit::PluginHelper.register_map_obj("Array") do |object|
            if object == Numeric
                "my_name2"
            else
                ["my_name"]
            end
        end
        assert_equal "my_name",Vizkit::PluginHelper.map_obj("Array",Array).first
        assert_equal "my_name2",Vizkit::PluginHelper.map_obj("Array",Numeric).first
        assert_equal "my_name",Vizkit::PluginHelper.map_obj("Array").first
        assert_equal "my_name",Vizkit::PluginHelper.map_obj(Array).first
    end

    def test_classes
        _,v2,_ = RUBY_VERSION.split('.')
        if v2 == "8"
            assert_equal ["Float","Numeric","Object"],Vizkit::PluginHelper.classes(Float)
        else
            assert_equal ["Float","Numeric","Object","BasicObject"],Vizkit::PluginHelper.classes(Float)
        end
    end

    def test_normalize
        #test abstract name
        names = Vizkit::PluginHelper.normalize_obj("MyLabel")
        assert_equal(names.first,"MyLabel")
        assert_equal(1,names.size)

        #test typelib class 
        klass = Types::Base::Samples::RigidBodyState
        names = Vizkit::PluginHelper.normalize_obj(klass)
        assert_equal "/base/samples/RigidBodyState_m",names.first

        names = Vizkit::PluginHelper.normalize_obj("Types::Base::Samples::RigidBodyState")
        assert_equal "/base/samples/RigidBodyState_m",names.first

        #test typelib value
        argument = klass.new
        names = Vizkit::PluginHelper.normalize_obj(argument)
        assert_equal "/base/samples/RigidBodyState_m",names.first

        names = Vizkit::PluginHelper.normalize_obj("/base/samples/RigidBodyState")
        assert_equal "/base/samples/RigidBodyState_m",names.first

        #test normale qt widgets
        widget = Qt::Widget.new
        names = Vizkit::PluginHelper.normalize_obj(widget)
        assert_equal "Qt::Widget",names.first

        names = Vizkit::PluginHelper.normalize_obj("Qt::Widget")
        assert_equal "Qt::Widget",names.first

        #test vizkit plugins
        spec = Vizkit::PluginSpec.new("my_widget")
        widget.instance_variable_set :@__plugin_spec__,spec
        def widget.plugin_spec
            @__plugin_spec__
        end
        names = Vizkit::PluginHelper.normalize_obj(widget)
        assert_equal "my_widget",names.first

        names = Vizkit::PluginHelper.normalize_obj("my_widget")
        assert_equal "my_widget",names.first
    end

    def test_callback_create
        spec = Vizkit::CallbackSpec.new("String",:display,true,:test)
        assert_equal Vizkit::CallbackSpec::MethodNameAdapter, spec.callback.class
        assert_equal :test,spec.callback.to_sym
        assert_equal "String",spec.argument
        assert_equal :display,spec.callback_type
        spec.callback_type(:my)
        assert_equal :my,spec.callback_type
        assert_equal true,spec.default
        spec.default(false)
        assert_equal false,spec.default
        spec.doc("Doc")
        assert_equal "Doc",spec.doc

        spec = Vizkit::CallbackSpec.new("String",:display,false)
        assert_equal Vizkit::CallbackSpec::NoCallbackAdapter, spec.callback.class
        assert_equal "String",spec.argument
        assert_equal :display,spec.callback_type
        assert_equal false,spec.default

        spec = Vizkit::CallbackSpec.new("String")
        assert_equal Vizkit::CallbackSpec::NoCallbackAdapter, spec.callback.class
        assert_equal "String",spec.argument
        assert_equal nil,display,spec.callback_type
        assert_equal false,spec.default

        spec = Vizkit::CallbackSpec.new("String",:display,false) do |sample,port|
            123
        end
        assert_equal Vizkit::CallbackSpec::BlockAdapter, spec.callback.class
        assert_equal 123,spec.callback.call("la","la")
        assert_equal "String",spec.argument
        assert_equal :display,spec.callback_type
        assert_equal false,spec.default

        spec = Vizkit::CallbackSpec.new("String",:display,false) do |sample,port|
            123
        end
        assert_equal Vizkit::CallbackSpec::BlockAdapter, spec.callback.class
        assert_equal 123,spec.callback.call("la","la")
        assert_equal "String",spec.argument
        assert_equal :display,spec.callback_type
        assert_equal false,spec.default

        spec = Vizkit::CallbackSpec.new("String") do |sample,port|
            123
        end
        assert_equal Vizkit::CallbackSpec::BlockAdapter, spec.callback.class
        assert_equal 123,spec.callback.call("la","la")
        assert_equal "String",spec.argument
        assert_equal nil,spec.callback_type
        assert_equal false,spec.default
    end

    def test_callback_match
        spec = Vizkit::CallbackSpec.new("String",:display,true,:test)
        assert spec.match?(:argument => "String")
        assert !spec.match?(:argument => "Numeric")
        assert spec.match?(:argument => "String",:callback_type => :display)
        assert !spec.match?(:argument => "String",:callback_type => :display2)
        assert spec.match?(:argument => "String",:callback_type => :display,:default => true)
        assert !spec.match?(:argument => "String",:callback_type => :display,:default => false)

        assert spec.match?(:callback_type => :display)
        assert !spec.match?(:callback_type => :display2)
        assert spec.match?(:callback_type => :display,:default => true)
        assert !spec.match?(:callback_type => :display,:default => false)

        assert spec.match?(:default => true)
        assert !spec.match?(:default => false)

        #test superclass (Numeric is superclass of Float) 
        spec = Vizkit::CallbackSpec.new("Numeric",:display,true,:test)
        assert spec.match?(:argument => "Float")
        assert !spec.match?(:argument => "Float",:exact => true)
        assert !spec.match?(:argument => "String")
        assert !spec.match?(:argument => "Float",:callback_type => :display2)
        assert spec.match?(:argument => "Float",:callback_type => :display,:default => true)
        assert !spec.match?(:argument => "Float",:callback_type => :display,:default => false)

        #test mapping
        Vizkit::PluginHelper.register_map_obj("Float") do |object|
            ["test_name1","test_name2"]
        end
        spec = Vizkit::CallbackSpec.new("test_name1",:display,false,:test2)
        assert spec.match?(:argument => 123.2,:callback_type => :display)
    end

    def test_plugin_creation
        spec = Vizkit::PluginSpec.new("MyPlugin")
        spec.creation_method do |parent|
            String.new
        end
        assert spec.creation_method
        assert_equal String.name, spec.create_plugin.class.name
        assert_equal String.name, spec.created_plugins[0].class.name

        def spec.test(parent)
            Array.new
        end
        spec.creation_method(spec.method(:test))
        assert_equal Array.name, spec.create_plugin.class.name
        assert_equal Array.name, spec.created_plugins[1].class.name
        assert_equal spec, spec.created_plugins.first.plugin_spec 
        
    end

    def test_callbacks
        block = Proc.new do |*args|
            args
        end
        adapter = Vizkit::CallbackSpec::UnboundBlockAdapter.new(block)
        obj = String.new
        adapter2 = adapter.bind(obj)
        assert_equal obj,adapter2.call.first
    end

    def test_plugin_callback_spec
        spec = Vizkit::PluginSpec.new("MyPlugin")
        callback = Vizkit::CallbackSpec.new("String",nil,nil,:test).callback_type(:display).default(false)
        spec.callback_spec(callback)
        callback = Vizkit::CallbackSpec.new("Numeric",:display,false) do |sample,options|
            123
        end
        spec.callback_spec(callback)
        assert_equal 2,spec.find_all_callback_specs(:callback_type => :display).size
        assert_equal 0,spec.find_all_callback_specs(:callback_type => :display2).size
        assert_equal :test, spec.find_callback!(:argument => "String",:callback_type => :display,:default => false).to_sym

        spec = Vizkit::PluginSpec.new("MyPlugin")
        spec.callback_spec("String",:display,false,:test)
        spec.callback_spec("Numeric",:display,false) do |sample,options|
            123
        end
        assert_equal 2,spec.find_all_callback_specs(:callback_type => :display).size
        assert_equal 0,spec.find_all_callback_specs(:callback_type => :display2).size
        assert_equal :test, spec.find_callback!(:argument => "String",:callback_type => :display,:default => false).to_sym

        #test superclass: superclass of Float is Numeric
        assert_equal 123, spec.find_callback!(:argument => 1.2,:callback_type => :display,:default => false).call(123,Hash.new)

        #test mapping
        Vizkit::PluginHelper.register_map_obj("Float") do |object|
            ["test_name1","test_name2"]
        end
        spec.callback_spec(Vizkit::CallbackSpec.new("test_name1",:display,true,:test2))
        assert_equal :test2, spec.find_callback!(:argument => 123.2,:callback_type => :display).to_sym
        assert_equal 123, spec.find_callback!(:argument => 12,:callback_type => :display,:default=>nil).call(123,Hash.new)

        #test that double registration is not allowed
        spec.callback_spec("/base/samples/RigidBodyState_m",:display,true,:test2)
        assert_equal spec.callback_specs.last, spec.find_callback_spec!(:argument => "/base/samples/RigidBodyState_m",:callback_type => :display)
        size = spec.callback_specs.size
        spec.callback_spec("/base/samples/RigidBodyState_m",:display,false,:test2)
        assert_equal size,spec.callback_specs.size

    end

    module Test 
        def test
            111 
        end
    end
    module Test2 
        def test2
            222
        end
    end
    def test_plugin_extension
        spec = Vizkit::PluginSpec.new("MyPlugin")
        spec.extensions(Test,Test2)
        spec.creation_method do |caller,parent|
            String.new
        end
        assert_equal 111,spec.create_plugin.test
        assert_equal 222,spec.create_plugin.test2

        spec = Vizkit::PluginSpec.new("MyPlugin")
        spec.extensions([Test,Test2])
        spec.creation_method do |caller,parent|
            String.new
        end
        assert_equal 111,spec.create_plugin.test
        assert_equal 222,spec.create_plugin.test2

        spec = Vizkit::PluginSpec.new("MyPlugin")
        spec.extension(Test).extension(Test2)
        spec.creation_method do |caller,parent|
            String.new
        end
        spec.extension do 
            def test3
                333
            end
        end
        assert_equal 111,spec.create_plugin.test
        assert_equal 222,spec.create_plugin.test2
        assert_equal 333,spec.create_plugin.test3
    end

    def test_plugin_match
        spec = Vizkit::PluginSpec.new("MyPlugin")
        spec.cplusplus_name("CWidget")
        spec.callback_spec("String",:display,false,:test)
        spec.callback_spec("Float",:display,true) do |sample,options|
            123
        end
        assert spec.match?(:plugin_name => "MyPlugin")
        assert spec.match?(:plugin_name => "MyPlugin",:cplusplus_name => "CWidget")
        assert !spec.match?(:plugin_name => "MyPlugin2",:cplusplus_name => "CWidget")
        assert !spec.match?(:plugin_name => "MyPlugin",:cplusplus_name => "CWidget2")
        assert !spec.match?(:plugin_name => "MyPlugin2")
        assert spec.match?(:plugin_name => "MyPlugin",:argument => String,:callback_type => :display)
        assert spec.match?(:argument => String,:callback_type => :display)
        assert spec.match?(:plugin_name => "MyPlugin",:argument => Float,:callback_type => :display)
        assert !spec.match?(:plugin_name => "MyPlugin2",:argument => String,:callback_type => :display)
        assert !spec.match?(:plugin_name => "MyPlugin",:argument => Array,:callback_type => :display)
        assert !spec.match?(:plugin_name => "MyPlugin",:argument => Float,:callback_type => :display1)
        assert spec.match?(:plugin_name => "MyPlugin",:argument => Float,:callback_type => :display,:default => true)
        assert spec.match?(:argument => Float,:callback_type => :display,:default => true)
        assert !spec.match?(:plugin_name => "MyPlugin",:argument => Float,:callback_type => :display,:default => false)
        assert spec.match?(:plugin_name => "MyPlugin",:argument => String,:callback_type => :display,:default => false)
        assert !spec.match?(:plugin_name => "MyPlugin",:argument => String,:callback_type => :display,:default => true)

        #test additional flags
        spec.flags :depricated => true
        assert spec.match?(:plugin_name => "MyPlugin",:flags =>{:depricated => true})
        assert !spec.match?(:plugin_name => "MyPlugin",:flags =>{:depricated => false})
        assert !spec.match?(:plugin_name => "MyPlugin",:flags =>{:depricated1 => true})
        spec.flags :depricated1 => true
        assert spec.match?(:plugin_name => "MyPlugin",:flags =>{:depricated1 => true})
        assert !spec.match?(:plugin_name => "MyPlugin",:flags =>{:depricated1 => true,:depricated => true})
        spec.flags :depricated => true, :depricated1 => true
        assert spec.match?(:plugin_name => "MyPlugin",:flags =>{:depricated1 => true,:depricated => true})
    end

    def test_plugin_pretty_print
        spec = Vizkit::PluginSpec.new("MyPlugin")
        spec.cplusplus_name("CWidget")
        spec.callback_spec("String",:display,false,:test)
        spec.doc("This is a test doc")
        spec.callback_spec("Float",:display,true) do |sample,options|
            123
        end
        mod = Module.new do
            def test_method
            end
        end
        spec.extension(mod)
        pp2 = PrettyPrint.new
        spec.flags :test => 123
        spec.pretty_print(pp2)
    end

    def test_loader_register_ruby_widget
        spec = Vizkit::UiLoader.register_ruby_widget("object",Qt::Object.method(:new))
        assert(spec)
        assert_equal(spec.plugin_type,:ruby_plugin)
        assert @loader.create_plugin("object")
        assert @loader.available_plugins.find{|p| p == "object"}
        assert @loader.plugin?("object")
        assert !@loader.widget?("object")

        #test name spaces
        spec = Vizkit::UiLoader.register_ruby_widget("vizkit::object1",Qt::Object.method(:new))
        spec = Vizkit::UiLoader.register_ruby_widget("envire.object2",Qt::Object.method(:new))
        assert(spec)
        assert @loader.vizkit.object1
        assert @loader.envire.object2
        assert @loader.object
    end

    def test_loader_register_3d_plugin 
        spec = Vizkit::UiLoader.register_3d_plugin("RigidBodyStateVis","vizkit-base","RigidBodyStateVisualization")
        assert(spec)
        assert_equal(spec.plugin_type,:vizkit3d_plugin)
        assert @loader.create_plugin("RigidBodyStateVis")
        assert @loader.available_plugins.find{|p| p == "RigidBodyStateVis"}
        assert @loader.plugin?("RigidBodyStateVis")
        assert !@loader.widget?("RigidBodyStateVis")

        assert @loader.create_plugin("RigidBodyStateVisualization")

        #test loading plugin without calling the ui loader
        widget = Vizkit.vizkit3d_widget.createPlugin("vizkit-base","RigidBodyStateVisualization")
        assert widget 
    end

    def test_loader_extend_cplusplus_widget_class
        Vizkit::UiLoader.extend_cplusplus_widget_class("QWidget") do 
            def test123
                123
            end
            def initialize_vizkit_extension
                @val = 1234
            end
        end
        widget = @loader.create_plugin("QWidget")
        assert widget.respond_to?(:test123)
        assert widget.respond_to?(:initialize_vizkit_extension)
        assert_equal 1234, widget.instance_variable_get(:@val)
        assert @loader.plugin? "QWidget"
        assert @loader.create_plugin "QWidget"
        assert @loader.create_plugin "QPushButton"
        assert_equal 123,widget.test123
    end

    def test_loader_register_plugin_for
        #delete all loaded specs
        @loader.instance_variable_set(:@plugin_specs,Hash.new)

        Vizkit::UiLoader.register_plugin_for("QWidget",123,:display) do 
        end
        spec = Vizkit::UiLoader.register_plugin_for("QPushButton","String",:display) do 
        end
        assert spec.default

        plugin = @loader.create_plugin_for(Fixnum,:display)
        assert plugin
        assert plugin.is_a? Qt::Widget
        assert @loader.create_plugin_for(123,:display).is_a? Qt::Widget

        plugin = @loader.create_plugin_for(String,:display)
        assert plugin
        assert plugin.is_a? Qt::Widget

        #test multi value registration 
        specs = Vizkit::UiLoader.register_plugin_for("QLabel",["String","Array","Hash"],:display) do 
            888
        end
        assert_equal specs.size,3
        plugin = @loader.create_plugin_for(Hash,:display)
        assert plugin
        assert plugin.is_a? Qt::Label
        callback = plugin.plugin_spec.find_callback!(:argument => "Hash",:callback_type => :display)
        assert callback
        assert_equal 888,callback.call
    end

    def test_loader_register_widget_for
        #delete all loaded specs
        @loader.instance_variable_set(:@plugin_specs,Hash.new)

        Vizkit::UiLoader.register_widget_for("QWidget",123) do 
        end
        Vizkit::UiLoader.register_widget_for("QPushButton","String") do 
        end

        widget = @loader.create_plugin_for(Fixnum,:display)
        assert widget
        assert widget.is_a? Qt::Widget
        assert @loader.create_plugin_for(123,:display).is_a? Qt::Widget

        widget = @loader.create_plugin_for(String,:display)
        assert widget
        assert widget.is_a? Qt::Widget
    end

    def test_loader_load_ui
        widget = @loader.load File.join(File.dirname(__FILE__),"test.ui")
        assert widget
        assert widget.textEdit
        assert_equal widget.textEdit.class_name, "Qt::TextEdit"

        assert widget.plot2d
        assert_equal widget.plot2d.class_name, "Plot2d"

        #test that the spec was attaced
        assert widget.plot2d.plugin_spec

        #test that initialize_vizkit_extension was called
        assert_equal widget.plot2d.instance_variable_get(:@graphs).class,Hash

        #test that the spec was set corretly for plugins created via ui loader
        plugin = @loader.StructViewer
        assert_equal "StructViewer",plugin.plugin_spec.plugin_name
    end

    def test_loader_available_plugins
        assert @loader.available_plugins.include? "Plot2d"
    end

    def test_loader_plugin?
        assert @loader.plugin? "ImageView"
    end

    def test_loader_add_plugin_path
        assert !@loader.plugin?("TestWidget123")
        assert !@loader.widget?("TestWidget123")
        @loader.add_plugin_path(File.join(File.dirname(__FILE__),"extension"))
        assert @loader.plugin?("TestWidget123")
        plugin = @loader.create_plugin("TestWidget123")
        assert plugin
        assert_equal 123,plugin.test

        @loader.add_plugin_path(File.join(File.dirname(__FILE__),"does_not_exist"))
    end

    def test_loader_find_all_plugin_names
        names = @loader.find_all_plugin_names(:argument => "/base/Time")
        assert !names.empty?
    end

    def test_loader_create_plugin
        widget = @loader.create_plugin("QWidget")
        assert_equal widget.class_name, "QWidget"

        widget = @loader.QWidget
        assert_equal widget.class_name, "QWidget"

        #compatibility check
        widget = @loader.create_widget("QWidget",nil,true,true)
        assert_equal widget.class_name, "Qt::Widget"

        widget = @loader.create_widget("QWidget")
        assert_equal widget.class_name, "QWidget"

        widget = @loader.QLabel
        assert_equal widget.class_name, "Qt::Label"

        #throw error message
        assert_raise NoMethodError do 
            @loader.ImageView123
        end
    end

    def test_loader_create_plugin_for
       widget = @loader.create_plugin_for("/base/samples/frame/Frame",:display) 
       assert_equal widget.plugin_spec.plugin_name,"ImageView"
    end

    def test_loader_available_widgets 
        assert @loader.available_widgets.find{|p| p == "QWidget"}
    end

    def test_loader_widget?
        assert @loader.widget? "QWidget"
        assert @loader.widget? "QPushButton"
    end
end
