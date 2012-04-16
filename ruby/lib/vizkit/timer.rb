module Vizkit
    class Timer
        def initialize(sec,single_shot=false,&block)
            @timer = Qt::Timer.new
            @timer.setSingleShot(single_shot)
            @timer.connect(SIGNAL('timeout()'),&block)
            @timer.start((sec*1000).to_i)
        end
    end
end



