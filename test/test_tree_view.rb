require File.join(File.dirname(__FILE__),"test_helper")
start_simple_cov("test_tree_view")

require 'vizkit'
require 'vizkit/tree_view.rb'
require 'minitest/spec'

Orocos.initialize
Orocos.load_typekit "base"
MiniTest::Unit.autorun

# TODO
# update to the QStandartItemModel

=begin
describe Vizkit::TypelibDataModel do
    describe "method initialize" do
        it "must raise if a wrong options is given" do 
            sample = Types::Base::Samples::Frame::Frame.new
            sample.zero!
            assert_raises ArgumentError do 
                Vizkit::TypelibDataModel.new sample,nil,:invalid => false
            end
        end
    end

    describe "method child" do
        it "must return its childs" do
            sample = Types::Base::Samples::Frame::Frame.new
            sample.zero!
            model = Vizkit::TypelibDataModel.new sample
            sample.class.fields.each_with_index do |field,index|
                assert model.child(index)
            end
        end
    end

    describe "method raw_data" do
        it "must return the raw data for a child" do
            sample = Types::Base::Samples::Frame::Frame.new
            sample.zero!
            model = Vizkit::TypelibDataModel.new sample
            sample.class.fields.each_with_index do |field,index|
                child = model.child(index)
                field = sample.raw_get_field(field.first)
                assert_equal field, model.raw_data(child)
            end
        end
    end

    describe "method update" do
        it "must update the underlying data" do
            sample = Types::Base::Samples::Frame::Frame.new
            sample2 = Types::Base::Samples::Frame::Frame.new
            sample.zero!
            sample2.zero!
            sample2.data_depth = 11
            model = Vizkit::TypelibDataModel.new sample
            model.update(sample2)
            assert 11,sample.data_depth
        end
    end

    describe "method on_change" do
        it "must call code block if update is called" do
            sample = Types::Base::Samples::Frame::Frame.new
            sample2 = Types::Base::Samples::Frame::Frame.new
            sample.zero!
            sample2.zero!
            model = Vizkit::TypelibDataModel.new sample
            result = nil
            model.on_changed do |item|
                result = item
            end
            model.update(sample2)
            assert result
        end
    end

    describe "method field_name,field_accessor,field_type" do
        it "must return information about the field" do
            sample = Types::Base::Samples::Frame::Frame.new
            sample.zero!
            model = Vizkit::TypelibDataModel.new sample
            sample.class.fields.each_with_index do |field,index|
                child = model.child(index)
                assert_equal field.first,model.field_name(child).toString
                assert_equal field.first,model.field_accessor(child)
                assert_equal field.last,model.field_type(child)
            end
        end
    end

    describe "method data" do
        it "must return the data for each field as Qt::Variant" do
            sample = Types::Base::Samples::Frame::Frame.new
            sample.zero!
            model = Vizkit::TypelibDataModel.new sample
            sample.class.fields.each_with_index do |field,index|
                child = model.child(index)
                data = model.data(child)
                data.must_be_kind_of Qt::Variant
                if field.first == "time"
                    data = model.data(child,Qt::EditRole)
                    data.value.must_be_kind_of Qt::DateTime
                end
            end
        end
    end

    describe "method set" do
        it "must set the underlying data to the given Qt::Variant value" do
            sample = Types::Base::Samples::Frame::Frame.new
            sample.zero!
            model = Vizkit::TypelibDataModel.new sample
            sample.class.fields.each_with_index do |field,index|
                if field.first == "data_depth"
                    child = model.child(index)
                    assert 11 != sample.data_depth
                    model.set(child,Qt::Variant.new(11))
                    assert_equal 11,sample.data_depth
                    assert model.modified_by_user?
                end
            end
        end
    end

    describe "method parent" do
        it "must return the parent of the item" do
            sample = Types::Base::Samples::Frame::Frame.new
            sample.zero!
            model = Vizkit::TypelibDataModel.new sample
            sample.class.fields.each_with_index do |field,index|
                child = model.child(index)
                assert_equal model, model.parent(child)
                if model.rows(child)
                    0.upto model.rows(child)-1 do |index|
                        child_child = model.child(index,child)
                        assert_equal child,model.parent(child_child)
                    end
                end
            end
        end
    end

    describe "method flags" do
        it "must return the flag of each item" do
            sample = Types::Base::Samples::Frame::Frame.new
            sample.zero!
            model = Vizkit::TypelibDataModel.new sample
            sample.class.fields.each_with_index do |field,index|
                child = model.child(index)
                assert_equal 37,model.flags(0,child)
                assert_equal 0,model.flags(1,child)
            end

            # must return editable for fields which can be edit
            model = Vizkit::TypelibDataModel.new sample,nil,:editable => true
            sample.class.fields.each_with_index do |field,index|
                child = model.child(index)
                assert_equal 37,model.flags(0,child)
                if field.first == "time"
                    assert_equal Qt::ItemIsEnabled | Qt::ItemIsEditable,model.flags(1,child)
                end
            end
        end
    end

    describe "method rows" do
        it "must return the number of childs for each field" do
            sample = Types::Base::Samples::Frame::Frame.new
            sample.zero!
            sample.image << 12
            model = Vizkit::TypelibDataModel.new sample
            assert_equal sample.class.fields.size,model.rows

            sample.class.fields.each_with_index do |field,index|
                child = model.child(index)
                rows = model.rows(child)
                case field.first
                when "size"
                    assert_equal 2,rows
                when "time"
                    assert_equal 0,rows
                when "image"
                    assert_equal 1,rows
                else
                end
            end
        end
    end
end

describe Vizkit::ProxyDataModel do
    before do 
        Orocos::Async.clear
        sample = Types::Base::Samples::Frame::Frame.new
        sample.zero!
        @model = Vizkit::TypelibDataModel.new sample
        @model2 = Vizkit::ProxyDataModel.new
    end

    describe "method add" do
        it "must add a model to the ProxyDataModel" do 
            @model2.add @model,"test","123",:bla
            assert_equal 1,@model2.rows
        end
    end

    describe "method rows" do
        it "must return the number of rows" do 
            @model2.add @model,"test","123",:bla
            assert_equal 1,@model2.rows
            child = @model2.child 0
            assert_equal @model.rows,@model2.rows(child)
        end
    end

    describe "method child" do
        it "must return the child" do 
            @model2.add @model,"test","123",:bla
            child = @model2.child 0
            assert_equal @model,child
            0.upto(@model.rows - 1) do |index|
                assert_equal @model.child(index),@model2.child(index,child)
            end
        end
    end

    describe "method parent" do
        it "must return the child" do 
            @model2.add @model,"test","123",:bla
            child = @model2.child(0)
            0.upto(@model2.rows(child) - 1) do |index|
                child_child = @model2.child(index,child)
                assert_equal child,@model2.parent(child_child)
            end
        end
    end
end

describe Vizkit::TaskContextDataModel do
    before do
        Orocos::Async.clear
        if !@model
            # we have to initialize read only pointer for now
            sample = Types::Base::Samples::Frame::Frame.new.zero!
            sample2 = Types::Base::Samples::Frame::FramePair.new.zero!
            @task = Orocos::RubyTaskContext.new("test_task2")
            @task.create_property("prop1","/base/samples/RigidBodyState")
            p = @task.create_property("prop2","/base/samples/frame/FramePair")
            p.write sample2
            p = @task.create_output_port("frame","base/samples/frame/Frame")
            p.write sample
            @task.create_output_port("data","/base/samples/RigidBodyState")
            @task.create_input_port("in_data","/base/samples/RigidBodyState")

            @task_proxy = Orocos::Async.proxy "test_task2",:period => 0.1
            Orocos::Async.wait_for do 
                @task_proxy.reachable?
            end
            @model = Vizkit::TaskContextDataModel.new @task_proxy
        end
    end

    describe "method data" do
        it "should report the properties, and ports" do 
            Orocos::Async.steps
            sleep 0.11
            Orocos::Async.steps
            sleep 0.11
            Orocos::Async.steps

            in_ports = @model.child 0
            assert_equal 1, @model.rows(in_ports)
            assert_equal "Input Ports",@model.field_name(in_ports).toString
            in1 = @model.child 0,in_ports
            assert_equal "in_data",@model.field_name(in1).toString
            assert_equal "/base/samples/RigidBodyState_m",@model.data(in1).toString

            out_ports = @model.child 1
            assert_equal "Output Ports",@model.field_name(out_ports).toString
            assert_equal 2, @model.rows(out_ports)
            out1 = @model.child 0,out_ports
            out2 = @model.child 1,out_ports
            assert_equal "frame",@model.field_name(out1).toString
            assert_equal "/base/samples/frame/Frame",@model.data(out1).toString
            assert_equal "data",@model.field_name(out2).toString
            assert_equal "/base/samples/RigidBodyState_m",@model.data(out2).toString

            properties = @model.child 2
            assert_equal 2, @model.rows(properties)
            assert_equal "Properties",@model.field_name(properties).toString
            prop1 = @model.child 0,properties
            prop2 = @model.child 1,properties
            assert_equal "prop1",@model.field_name(prop1).toString
            assert_equal "/base/samples/RigidBodyState_m",@model.data(prop1).toString
            assert_equal "prop2",@model.field_name(prop2).toString
            assert_equal "/base/samples/frame/FramePair",@model.data(prop2).toString
        end
    end
end

describe Vizkit::PropertiesDataModel do
    before do
        Orocos::Async.clear

        if !@model
            @task = Orocos::RubyTaskContext.new("test_task")
            @task.create_property("prop1","/base/samples/RigidBodyState")

            @task_proxy = Orocos::Async.proxy "test_task",:period => 0.1
            Orocos::Async.wait_for do
                @task_proxy.reachable?
            end
            @model = Vizkit::PropertiesDataModel.new
            @model.add @task_proxy.property "prop1"
        end
    end

    describe "method data" do
        it "should report the propertie" do 
            sleep 0.11
            Orocos::Async.steps
            sleep 0.11
            Orocos::Async.steps
            prop1 = @model.child(0)
            data = @model.field_name(prop1)
            assert_equal "prop1",data.toString
        end
    end
end

describe Vizkit::TaskContextsDataModel do
    before do
        Orocos::Async.clear
        if !@model
            @task = Orocos::RubyTaskContext.new("test_task")
            @task_proxy = Orocos::Async.proxy "test_task",:period => 0.1
            Orocos::Async.wait_for do 
                @task_proxy.reachable?
            end
            @model = Vizkit::TaskContextsDataModel.new
            @model.add @task_proxy
        end
    end

    describe "method data" do
        it "should report the right state of the added tasks" do 
            @task.start unless @task.running?
            sleep 0.11
            Orocos::Async.steps
            sleep 0.11
            Orocos::Async.steps
            item = @model.child(0)
            data = @model.data(item)
            assert_equal "RUNNING",data.toString
            @task.stop
            sleep 0.11
            Orocos::Async.steps
            sleep 0.11
            Orocos::Async.steps
            data = @model.data(item)
            assert_equal "STOPPED",data.toString
        end
    end
end

describe Vizkit::NameServiceDataModel do
    before do
        Orocos::Async.clear
        Orocos::Async.step
        Orocos::Async.clear

        if !@model
            @task1 = Orocos::RubyTaskContext.new("test_task1")
            @task2 = Orocos::RubyTaskContext.new("test_task2")
            ns = Orocos::Async::CORBA::NameService.new :period => 0.1
            @model = Vizkit::NameServiceDataModel.new nil,ns
        end
    end

    describe "method data" do
        it "should report all running tasks" do 
            sleep 0.11
            Orocos::Async.steps
            sleep 0.11
            Orocos::Async.steps
            sleep 0.11
            Orocos::Async.steps
            assert 2 <= @model.rows

            names = []
            @model.rows.times do |i|
                item = @model.child(i)
                names << @model.field_name(item).toString
            end

            assert names.include? "test_task1"
            assert names.include? "test_task2"
        end
    end
end

describe Vizkit::NameServicesDataModel do
    before do
        Orocos::Async.clear
        if !@model
            @task1 = Orocos::RubyTaskContext.new("test_task1")
            @task2 = Orocos::RubyTaskContext.new("test_task2")
            ns1 = Orocos::Async::CORBA::NameService.new :period => 0.1
            ns1.ip = "127.0.0.1"

            ns2 = Orocos::Async::CORBA::NameService.new :period => 0.1
            @model = Vizkit::NameServicesDataModel.new

            @model.add ns1
            @model.add ns2
        end
    end

    describe "method data" do
        it "should report added name service" do 
            sleep 0.11
            Orocos::Async.steps
            assert_equal 2,@model.rows

            item = @model.child(0)
            name = @model.field_name(item)
            assert_equal "CORBA:127.0.0.1",name.toString

            item = @model.child(1)
            name = @model.field_name(item)
            assert_equal "CORBA:",name.toString
        end
    end
end
=end
