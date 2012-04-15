require File.join(File.dirname(__FILE__), '../..', 'tree_modeler.rb')

class LogControl

  class CloseAllFilter < Qt::Object
    def initialize(obj)
      super(nil)
      @obj = obj
    end
    def eventFilter(obj,event)
      if event.is_a?(Qt::CloseEvent) && obj.objectName == @obj.objectName
          $qApp.closeAllWindows
          return true
      end
      return false
    end
  end

  module Functions
    def config(replay,options=Hash.new)
      raise "Cannot control #{replay.class}" if !replay.instance_of?(Orocos::Log::Replay)

      #workaround because qt objects created via an ui File
      #cannot be overloaded
      setObjectName("LogControl")
      @event_filter = CloseAllFilter.new(self)
      $qApp.installEventFilter(@event_filter)
      
      @log_replay = replay
      @replay_on = false 
      @user_speed = @log_replay.speed
      
      dir = File.dirname(__FILE__)
      @pause_icon =  Qt::Icon.new(File.join(dir,'pause.png'))
      @play_icon = Qt::Icon.new(File.join(dir,'play.png'))
      setAttribute(Qt::WA_QuitOnClose, true);

      connect(timeline, SIGNAL('indexSliderMoved(int)'), index, SLOT('setValue(int)'))
      connect(timeline, SIGNAL('endMarkerMoved(int)'), index, SLOT('setValue(int)'))
      connect(timeline, SIGNAL('startMarkerMoved(int)'), index, SLOT('setValue(int)'))
      timeline.connect(SIGNAL('indexSliderReleased(int)'),self,:slider_released)
      bnext.connect(SIGNAL('clicked()'),self,:bnext_clicked)
      bback.connect(SIGNAL('clicked()'),self,:bback_clicked)
      bstop.connect(SIGNAL('clicked()'),self,:bstop_clicked)
      bplay.connect(SIGNAL('clicked()'),self,:bplay_clicked)
    
      timeline.connect(SIGNAL("endMarkerReleased(int)")) do |value| 
        index.setValue(@log_replay.sample_index)
      end
      timeline.connect(SIGNAL("startMarkerReleased(int)")) do |value| 
        index.setValue(@log_replay.sample_index)
      end
      timeline.connect SIGNAL('indexSliderClicked()') do 
          bplay_clicked if playing?
      end

      index.connect SIGNAL('editingFinished()') do
        if @log_replay.sample_index != index.value && !playing?
          #prevents the bottom play from starting replay
          #because of enter
          @replay_on = true
          seek_to(index.value)
        end
      end

      @log_replay.align unless @log_replay.aligned?
      return if !@log_replay.replay?
      @log_replay.process_qt_events = true
      timeline.setSteps(@log_replay.size-1)
      timeline.setStepSize 1
      timeline.setSliderIndex(@log_replay.sample_index)
      index.setMaximum(@log_replay.size-1)

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
      if @log_replay.time
        timestamp.text = @log_replay.time.strftime("%a %D %H:%M:%S." + "%06d" % @log_replay.time.usec)
        lcd_speed.display(@log_replay.actual_speed)
        index.setValue(@log_replay.sample_index)
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
       bplay_clicked if @log_replay.sample_index >= timeline.getEndMarkerIndex || !@log_replay.step(true)
       if Time.now - last_info > 0.1
        last_info = Time.now
        $qApp.processEvents
        display_info      #we do not display the info every step to save cpu time
        timeline.setSliderIndex(@log_replay.sample_index)
       end
      end
      display_info        #display info --> otherwise info is maybe not up to date
      timeline.setSliderIndex(@log_replay.sample_index)
    end

    def slider_released(index)
  #    return if !@log_replay.replay?
      @log_replay.reset_time_sync
      @log_replay.seek(timeline.getSliderIndex)
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
      timeline.setSliderIndex(@log_replay.sample_index)
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
      timeline.setSliderIndex(@log_replay.sample_index)
      display_info
    end
    
    def bstop_clicked 
       return if !@log_replay.replay?
       bplay_clicked if @replay_on
       if timeline.getStartMarkerIndex == 0
         @log_replay.rewind
       else
         seek_to(timeline.getStartMarkerIndex)
       end
       @log_replay.reset_time_sync
       timeline.setSliderIndex(@log_replay.sample_index)
       display_info
    end

    def refresh
        @log_replay.refresh
    end

    def seek_to(index)
        timeline.setSliderIndex index
        slider_released(index)
    end
    
    def bplay_clicked 
      return if !@log_replay.replay?
      if @replay_on
        bplay.icon = @play_icon
        @replay_on = false
      else
        bplay.icon = @pause_icon
        if(timeline.getSliderIndex < timeline.getStartMarkerIndex || timeline.getSliderIndex >= timeline.getEndMarkerIndex)
            seek_to(timeline.getStartMarkerIndex)
        end
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
