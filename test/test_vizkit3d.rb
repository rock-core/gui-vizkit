require './test_helper'
require 'vizkit'

MiniTest::Unit.autorun
Orocos.initialize

describe Vizkit do
    before do
        sleep 0.1
        Orocos::Async.clear
        Orocos::Async.step
        Orocos::Async.clear
        Vizkit.instance_variable_set :@default_loader,nil
    end

    describe "vizkit3d_widget" do 
        it "should create a vizkit3d widget" do
            assert(Vizkit.default_loader.widget?("vizkit3d::Vizkit3DWidget"))
            widget = Vizkit.vizkit3d_widget
            assert(widget)
        end
    end

    describe "pushTransformerConfiguration(data)" do 
        it "should push the given configuration to vizkit3d" do
            widget = Vizkit.vizkit3d_widget
            assert Orocos.load_typekit_for("/transformer/ConfigurationState")
            assert Orocos.load_typekit_for("/base/samples/RigidBodyState")
            state = Types::Transformer::ConfigurationState.new
            trans = Types::Base::Samples::RigidBodyState.new

            assert(state)
            assert(trans)

            trans.sourceFrame = "world"
            trans.targetFrame= "body"
            trans.position.x = 0
            trans.position.y = 2
            trans.position.z = 1
            trans.orientation = Eigen::Quaternion.new(0.7071,0,0.7071,0)
            state.static_transformations << trans

            trans = Types::Base::Samples::RigidBodyState.new
            trans.sourceFrame = "body"
            trans.targetFrame= "body2"
            trans.position.x = 0
            trans.position.y = 2
            trans.position.z = 1
            trans.orientation = Eigen::Quaternion.new(0.7071,0,0.7071,0)
            state.static_transformations << trans

            widget.pushTransformerConfiguration(state)
            widget.setVisualizationFrame("body")
            assert_equal "body",widget.getVisualizationFrame().to_s

            #widget.show
            #Vizkit.exec
        end
    end
end
