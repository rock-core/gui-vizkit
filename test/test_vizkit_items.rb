require File.join(File.dirname(__FILE__),"test_helper")
start_simple_cov("test_vizkit_items")
require 'vizkit'
require 'vizkit/vizkit_items'
require 'minitest/spec'
require 'minitest/autorun'

Orocos.initialize
Orocos.load_typekit "base"

describe Vizkit::VizkitItem do
    include FlexMock::MockContainer

    describe "collapse" do
        it "must call collapse on all children" do
            item = Vizkit::VizkitItem.new
            childs = []
            0.upto 10 do
                child = flexmock(Vizkit::VizkitItem.new)
                child.should_receive(:collapse).with(true)
                childs << child
                item.appendRow child
            end
            childs.each do |child|
                assert(!child.flexmock_received?(:collapse,[true]))
            end
            item.collapse
            childs.each do |child|
                assert(child.flexmock_received?(:collapse,[true]))
            end
        end
    end

    describe "modified!" do
        it "must call modified! on the parent if set to true" do
            item = flexmock(Vizkit::VizkitItem.new)
            child = Vizkit::VizkitItem.new
            item.appendRow child
            item.should_receive(:modified!)
            child.modified!
            assert(item.flexmock_received?(:modified!,[true,[child],true]))
        end

        it "must call modified! on all childs if set to false" do
            item = Vizkit::VizkitItem.new
            child = flexmock(Vizkit::VizkitItem.new)
            item.appendRow child
            child.should_receive(:modified!)
            item.modified!(false)
            assert(child.flexmock_received?(:modified!,[false,[item],false]))
        end
    end

    describe "child?" do
        it "must return false if no direct child in column 0 has the given text" do
            item = Vizkit::VizkitItem.new
            child = flexmock(Vizkit::VizkitItem.new)
            item.appendRow child
            assert_equal false,item.child?("12")
        end
        it "must return true if a direct child in column 0 has the given text" do
            item = Vizkit::VizkitItem.new
            child = flexmock(Vizkit::VizkitItem.new("test"))
            item.appendRow child
            assert_equal true,item.child?("test")
        end
    end
end

describe Vizkit::TypelibItem do
    describe "collapse" do
        it "must call collapse on all children" do
        end
    end
end

describe Vizkit::PortItem do
    describe "collapse" do
        it "must call collapse on all children" do
        end
    end
end

describe Vizkit::PortsItem do
    describe "collapse" do
        it "must call collapse on all children" do
        end
    end
end

describe Vizkit::OutputPortItem do
    describe "collapse" do
        it "must call collapse on all children" do
        end
    end
end

describe Vizkit::OutputPortsItem do
    describe "collapse" do
        it "must call collapse on all children" do
        end
    end
end

describe Vizkit::InputPortItem do
    describe "collapse" do
        it "must call collapse on all children" do
        end
    end
end

describe Vizkit::InputPortsItem do
    describe "collapse" do
        it "must call collapse on all children" do
        end
    end
end

describe Vizkit::PropertyItem do
    describe "collapse" do
        it "must call collapse on all children" do
        end
    end
end


describe Vizkit::PropertiesItem do
    describe "collapse" do
        it "must call collapse on all children" do
        end
    end
end

describe Vizkit::TaskContextItem do
    describe "collapse" do
        it "must call collapse on all children" do
        end
    end
end

describe Vizkit::NameServiceItem do
    describe "collapse" do
        it "must call collapse on all children" do
        end
    end
end
