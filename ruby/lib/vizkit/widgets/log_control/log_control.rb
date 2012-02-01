require File.join(File.dirname(__FILE__), '../..', 'tree_modeler.rb')

class LogControl
  module Functions

    def config(replay,options=Hash.new)
      raise "Cannot control #{replay.class}" if !replay.instance_of?(Orocos::Log::Replay)
      
      @log_replay = replay
      @replay_on = false 
      @slider_pressed = false
      @user_speed = @log_replay.speed
      
      dir = File.dirname(__FILE__)
      @pause_icon =  Qt::Icon.new(File.join(dir,'pause.png'))
      @play_icon = Qt::Icon.new(File.join(dir,'play.png'))
      setAttribute(Qt::WA_QuitOnClose, true);

      connect(slider, SIGNAL('valueChanged(int)'), lcd_index, SLOT('display(int)'))
      slider.connect(SIGNAL('sliderReleased()'),self,:slider_released)
      bnext.connect(SIGNAL('clicked()'),self,:bnext_clicked)
      bback.connect(SIGNAL('clicked()'),self,:bback_clicked)
      bstop.connect(SIGNAL('clicked()'),self,:bstop_clicked)
      bplay.connect(SIGNAL('clicked()'),self,:bplay_clicked)
      slider.connect(SIGNAL(:sliderPressed)) {@slider_pressed = true;}
      
      @log_replay.align unless @log_replay.aligned?
      return if !@log_replay.replay?
      @log_replay.process_qt_events = true
      slider.maximum = @log_replay.size-1

      #add replayed streams to tree view 
      @tree_view = Vizkit::TreeModeler.new(treeView)
      @tree_view.model.setHorizontalHeaderLabels(["Replayed Tasks","Information"])
      @tree_view.update(@log_replay, nil)
      treeView.resizeColumnToContents(0)

      treeView.connect(SIGNAL('expanded(const QModelIndex)')) do 
        @tree_view.update(@log_replay, nil)
      end

      
      @brush = Qt::Brush.new(Qt::Color.new(200,200,200))
      @widget_hash = Hash.new

      display_info
    end

    def playing?
      @replay_on
    end

    def display_info
      slider.setSliderPosition(@log_replay.sample_index) unless @slider_pressed
      if @log_replay.time
        timestamp.text = @log_replay.time.strftime("%a %D %H:%M:%S." + "%06d" % @log_replay.time.usec)
        lcd_speed.display(@log_replay.actual_speed)
        last_port.text = @log_replay.current_port.full_name if @log_replay.current_port
      else
        timestamp.text = "0"
      end
      @tree_view.update(@log_replay, nil)
    end

    def speed=(double)
      @user_speed = double
      @log_replay.speed = double
      @log_replay.reset_time_sync
    end

    def speed
      @user_speed
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
        $qApp.processEvents
        display_info      #we do not display the info every step to save cpu time
       end
      end
      display_info        #display info --> otherwise info is maybe not up to date
    end

    def slider_released
      @slider_pressed = false
      return if !@log_replay.replay?
      @log_replay.reset_time_sync
      @log_replay.seek(slider.value)
      display_info
    end
    
    def bnext_clicked
      return if !@log_replay.replay?
      if @replay_on
        #we cannot use speed= here because this would overwrite the 
        #user_speed which is the default speed for replay
        @log_replay.speed = @log_replay.speed*2
        @log_replay.reset_time_sync
      else
        @log_replay.step(false)
      end
      display_info
    end

    def bback_clicked 
      return if !@log_replay.replay?
      if @replay_on
        @log_replay.speed = @log_replay.speed*0.5
        @log_replay.reset_time_sync
      else
        @log_replay.step_back
      end
      display_info
    end
    
    def bstop_clicked 
       return if !@log_replay.replay?
       bplay_clicked if @replay_on
       @log_replay.rewind
       @log_replay.reset_time_sync
       display_info
    end

    def refresh
        @log_replay.refresh
    end
    
    def bplay_clicked 
      return if !@log_replay.replay?
      if @replay_on
        bplay.icon = @play_icon
        @replay_on = false
      else
        bplay.icon = @pause_icon
        bstop_clicked if @log_replay.eof?
        self.speed = @user_speed
        auto_replay
      end
    end
  end # module Functions

  def self.create_widget(parent = nil)
    form = Vizkit.load(File.join(File.dirname(__FILE__),'LogControl.ui'),parent)
    form.extend Functions
    geo = form.size()
    geo.setHeight(260)
    form.resize(geo)

    #workaround 
    #it seems that widgets which are created by the UiLoader do not 
    #forward message calls to ruby
    short = Qt::Shortcut.new(Qt::KeySequence.new("Ctrl+R"),form)
    short.connect(SIGNAL('activated()'))do
        form.refresh
    end

    #workaround
    #it is not possible to define virtual functions for qwidgets which are loaded
    #via UiLoader (qtruby1.8)
    #stop replay if all windows are closed
    $qApp.connect(SIGNAL(:lastWindowClosed)) do 
      form.instance_variable_set(:@replay_on,false)
    end

    form
  end
  
end

Vizkit::UiLoader.register_ruby_widget('log_control',LogControl.method(:create_widget))
Vizkit::UiLoader.register_control_for('log_control',Orocos::Log::Replay, :config)
