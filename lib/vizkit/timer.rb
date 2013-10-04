module Vizkit
    class Timer
        class << self
            attr_reader :timer
        end
        @timer = Array.new

        def self.stop_all
            @timer.each do |t|
                t.stop
            end
        end
        
        def initialize(sec,single_shot=false,&block)
            @timer = Qt::Timer.new
            @timer.setSingleShot(single_shot)
            @timer.connect(SIGNAL('timeout()'),&block)
            start(sec)
            Timer.timer << self
        end

        def start(sec)
            @timer.start((sec*1000).to_i)
        end

        def stop
            @timer.stop
        end
    end
end



