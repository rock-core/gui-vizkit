require_relative 'helpers'

module Vizkit
    describe 'Plot2d' do
        include TestHelpers

        before do
            register_widget(@plot2d = Vizkit.default_loader.Plot2d)
            @plot2d.show
        end

        it "clears when the 'Clear' context entry is chosen" do
            last_value = 0
            timer 100 do
                @plot2d.update(last_value += rand - 0.5, 'test')
            end
            confirm 'A curve should appear, click the "Clear" '\
              'button and make sure it disappears before reappearing again'
        end

        it "automatically changes the y-axis limits when the 'Autosize' context entry is chosen" do
            last_value = 1
            scale = 0.001
            timer 100 do
                @plot2d.update(last_value += scale*(rand - 0.5), 'test')
            end
            confirm 'A curve that looks like a constant value should appear, click the "Autosize" '\
              'button to automatically detect its limits '
        end

        it "starts a new plotting widget if 'Reuse Widget' is unchecked" do
            last_value = 0
            timer 100 do
                @plot2d.update(last_value += rand - 0.5, 'test')
            end
            step 'disable "Reuse Widget" and click Yes to continue'
            register_widget(@plot2d = Vizkit.default_loader.Plot2d)
            @plot2d.show
            confirm 'a new plot should have appeared, and the data is now updated in the new plot'
        end

        it "uses the other Y axis if 'Use 2. Y-Axis' is enabled" do
            last_value = 0
            timer 100 do
                @plot2d.update(last_value += rand - 0.5, 'test')
            end
            step 'enable "Use 2. Y-Axis" and click Yes to continue'

            value2 = 0
            timer 100 do
                @plot2d.update(value2 += (rand - 0.5) * 100, 'test*100')
            end
            confirm 'the new plot, that has a widely different scale than the first one, '\
                'should be using the second axis'
            step 'now disable "Use 2. Y-Axis" and click Yes to continue'

            value3 = 0
            timer 100 do
                @plot2d.update(value3 += (rand - 0.5), 'test3')
            end
            confirm 'this third plot, should be using the first axis again. '\
                'It has the same scale than the first plot'
        end
    end
end

