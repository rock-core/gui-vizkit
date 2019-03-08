require_relative 'helpers'

module Vizkit
    describe 'Plot2d' do
        include TestHelpers

        before do
            register_widget(@plot2d = Vizkit.default_loader.Plot2d)
            @plot2d.show
        end

        it "changes the update period" do
            last_value = 0
            timer 20 do
                @plot2d.update(last_value += rand - 0.5, 'test')
            end
            step 'Set the update period to 1 second and click "Apply", you should clearly '\
                'see the curve updating every second'
            confirm 'Now change the update period to 0.02 seconds and "Apply", the curve'\
                'should update smoothly now'
        end

        it "changes the time window" do
            confirm 'Verify that you can\'t set the "time window" bigger than the "time window cache"'
            
            freq = 2 * Math::PI / 2
            t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            timer 40 do |time|
                time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
                @plot2d.update(2 * Math::sin(freq * time), 'test')
            end
            confirm 'Set the "time window" to 30 seconds and click "Apply", you should see several '\
                "periods of the sine wave"
            confirm 'Now change the "time window" to 4 seconds, you should see two whole periods '\
                'of the sine wave'
            confirm "Change the \"time window cache\" to 10 seconds and click \"Apply\", you should be "\
                "able to remove\n\"auto-scroll\" and zoom out to see that only the last 10 seconds of data "\
                "is recorder"
        end

        it "change settings locally and permanently" do
            freq = [2 * Math::PI / 2 , 2 * Math::PI * 1.5 , 2 * Math::PI * 3]
            t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            timer 40 do |time|
                time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
                value = 0
                freq.each do |f|
                    value += Math.sin(f * time)
                end
                @plot2d.update(value, 'test')
                @plot2d_other.update(value, 'test') if @plot2d_other
            end
            confirm 'Play around with the settings and verify that the "Apply", "Ok" and "Cancel" '\
                'buttons work as expected.'
            step 'Choose some settings of your liking, disable "Reuse widget" and click "Save" '\
                'to continue.'
            register_widget(@plot2d_other = Vizkit.default_loader.Plot2d)
            @plot2d_other.show
            confirm 'A new plot should have appeared with settings matching the ones you saved. '\
                'You can open "Preferences" for this new plot and check this out.'
            confirm 'Play around with the settings on both plots and verify that they are '\
                'independent of each other as long as you don\'t save them'
        end

        it "closes preferences when plot closes" do
            step 'Open the "Preferences" window to continue'
            confirm 'Close the plot, the "Preferences" window should have closed as well'
        end
    end
end

