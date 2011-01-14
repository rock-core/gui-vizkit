
class LogControl
  module Functions
      
    def control(replay)
      raise "Cannot control #{replay.class}" if !replay.instance_of?(Orocos::Log::Replay)
      @log_replay = replay
      @replay_on = false 

      dir = File.dirname(__FILE__)
      @pause_icon =  Qt::Icon.new(File.join(dir,'pause.png'))
      @play_icon = Qt::Icon.new(File.join(dir,'play.png'))
      setFixedSize(253,146)

      connect(bquit, SIGNAL('clicked()'), $qApp, SLOT('quit()'))
      connect(slider, SIGNAL('valueChanged(int)'), lcd_index, SLOT('display(int)'))
      slider.connect(SIGNAL('sliderReleased()'),self,:slider_released)
      bnext.connect(SIGNAL('clicked()'),self,:bnext_clicked)
      bback.connect(SIGNAL('clicked()'),self,:bback_clicked)
      bstop.connect(SIGNAL('clicked()'),self,:bstop_clicked)
      bplay.connect(SIGNAL('clicked()'),self,:bplay_clicked)
      doubleSpinBoxSpeed.connect(SIGNAL('valueChanged(double)')) do |value|
        speed=value
      end

      @log_replay.align unless @log_replay.aligned?
      return if !@log_replay.replay?
      @log_replay.process_qt_events = true
      slider.maximum = @log_replay.size-1
      display_info
    end

    def display_info
      slider.setSliderPosition(@log_replay.sample_index)
      timestamp.text = @log_replay.time.to_f.to_s
    end

    def speed=(double)
      @log_replay.speed = double
      @log_replay.reset_time_sync
      doubleSpinBoxSpeed.value = double if speed() != double 
    end

    def speed
      doubleSpinBoxSpeed.value
    end

    def auto_replay
      @replay_on = true
      @log_replay.reset_time_sync
      last_warn = Time.now 
      last_info = Time.now
      while @replay_on
       bplay_clicked if !@log_replay.step(true) #stop replay if end of file is reached
       if Time.now - last_info > 0.1
        last_info = Time.now
        if @log_replay.out_of_sync_delta < -0.05 &&  last_info - last_warn > 2
          last_warn = last_info
          puts 
          warn "Can not replay streams in desired speed of time. The replayed streams are #{-@log_replay.out_of_sync_delta} seconds behind the desired time."
        end
        $qApp.processEvents
        display_info      #we do not display the info every step to save cpu time
       end
      end
      display_info        #display info --> otherwise info is maybe not up to date
    end

    def slider_released
      return if !@log_replay.replay?
      @log_replay.seek(slider.value)
      display_info
    end

    def bnext_clicked
      return if !@log_replay.replay?
      bplay_clicked if @replay_on
      @log_replay.step(false)
      display_info
    end

    def bback_clicked 
      return if !@log_replay.replay?
      bplay_clicked if @replay_on
      @log_replay.step_back()
      display_info
    end
    
    def bstop_clicked 
       return if !@log_replay.replay?
       bplay_clicked if @replay_on
       @log_replay.rewind
       display_info
    end
    
    def bplay_clicked 
      return if !@log_replay.replay?
      if @replay_on
        bplay.icon = @play_icon
        @replay_on = false
      else
        bplay.icon = @pause_icon
        bstop_clicked if @log_replay.eof?
        @log_replay.reset_time_sync
        auto_replay
      end
    end
  end

  def self.create_widget(parent = nil)
    form = Vizkit.load(File.join(File.dirname(__FILE__),'LogControl.ui'),parent)
    form.extend Functions
    form
  end
end

Vizkit::UiLoader.register_ruby_widget('log_control',LogControl.method(:create_widget))
