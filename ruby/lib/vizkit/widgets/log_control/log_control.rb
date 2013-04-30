require "vizkit/tree_view"
require 'orocos/async/log/task_context'

class LogControl
  class StopAllTimer < Qt::Object
    def eventFilter(obj,event)
      if(obj.is_a? Qt::Timer)
          obj.stop
          $qApp.quit
      end
      return false
    end
  end

  class CloseAllFilter < Qt::Object
    def initialize(obj)
        @obj = obj
        super
    end
    
    def eventFilter(obj,event)
      if event.is_a?(Qt::CloseEvent)
         # close all is not compatible with ubuntu 10.04 
         # hole qt ruby will freeze 
         # $qApp.closeAllWindows
         
         #workaround to stop a running rock-replay 
         @obj.instance_variable_set(:@replay_on,false)
         @stop_all_timer = StopAllTimer.new
         $qApp.installEventFilter(@stop_all_timer)
         $qApp.quit
      end
      return false
    end
  end

  module Functions
    def config(replay,options=Hash.new)
      raise "Cannot control #{replay.class}" if !replay.instance_of?(Orocos::Log::Replay)
      raise "LogControl: config was called more than once!" if @log_replay

      #workaround because qt objects created via an ui File
      #cannot be overloaded
      setObjectName("LogControl")
      @event_filter = CloseAllFilter.new(self)
      installEventFilter(@event_filter)
      
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
      dtarget_speed.connect(SIGNAL('valueChanged(double)'),self,:update_target_speed)
    
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
      Vizkit.setup_tree_view treeView
      model = Vizkit::VizkitItemModel.new
      treeView.setModel model
      model.setHorizontalHeaderLabels ["Replayed Tasks","Information"]


      @global_meta_data = Vizkit::GlobalMetaItem.new @log_replay
      @global_meta_data2 = Vizkit::GlobalMetaItem.new @log_replay,:item_type => :value
      model.appendRow [@global_meta_data, @global_meta_data2]
      @log_replay.tasks.each do |task|
          next unless task.used?
          task = task.to_async
          @item1 = Vizkit::LogTaskItem.new(task)
          @item2 = Vizkit::LogTaskItem.new(task,:item_type => :value) 
          model.appendRow [@item1, @item2]
      end
      treeView.resizeColumnToContents(0)

      actionNone.connect(SIGNAL("triggered(bool)")) do |checked|
        if checked 
            actionCurrent_Port.setChecked(false)
        else 
            actionNone.setChecked(true)
        end
      end

      actionCurrent_Port.connect(SIGNAL("triggered(bool)")) do |checked|
        if checked 
            actionNone.setChecked(false)
        else 
            actionCurrent_Port.setChecked(true)
        end
      end

      actionExport.connect(SIGNAL("triggered()")) do 
        setDisabled(true)
        file = Qt::FileDialog::getSaveFileName(nil,"Export Log File",File.expand_path("."),"Log Files (*.log)")
        if file
          bstop_clicked
          progress = Qt::ProgressDialog.new
          progress.setLabelText "exporting streams"
          progress.show       
          @log_replay.export_to_file(file,timeline.getStartMarkerIndex, timeline.getEndMarkerIndex) do |index,max|
            progress.setMaximum(max)
            progress.setValue(index)
            Vizkit.process_events
            progress.wasCanceled
          end
          progress.close if progress.isVisible
        end
        setEnabled(true)
      end

      @last_info = Time.now
      @timer = Orocos::Async.event_loop.every 0.001,false do
	  # make sure we only process steps for around 10ms
	  # and dont block here
	  update_time = Time.now
	  while @log_replay.sync_step? && Time.now - update_time < 0.01
	      sample = @log_replay.step
	      if @log_replay.sample_index >= timeline.getEndMarkerIndex || !sample
		  bplay_clicked
		  break
	      end
	  end

	  #we do not display the info every step to save cpu time
	  if Time.now - @last_info > 0.1
	      @last_info = Time.now
	      display_info      
	      timeline.setSliderIndex(@log_replay.sample_index)
	  end
      end
      @timer.doc = "Log::Replay"
      display_info
    end

    def playing?
        @timer.running?
    end

    def display_info
      if @log_replay.time
        timestamp.text = @log_replay.time.strftime("%a %D %H:%M:%S." + "%06d" % @log_replay.time.usec)
        dcurrent_speed.text = ( '%.1f' % @log_replay.actual_speed )
        dtarget_speed.value = ( @log_replay.speed )
        index.setValue(@log_replay.sample_index)
        last_port.text = @log_replay.current_port.full_name if @log_replay.current_port
      else
        timestamp.text = "0"
      end
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
      @log_replay.reset_time_sync
      display_info              #display info --> otherwise info is maybe not up to date
      timeline.setSliderIndex(@log_replay.sample_index)
      @timer.start
    end

    def slider_released(index)
  #    return if !@log_replay.replay?
      @log_replay.reset_time_sync
      @log_replay.seek(timeline.getSliderIndex)
      display_info
    end

    def update_target_speed value
        @log_replay.speed = value.to_f
        @log_replay.reset_time_sync
    end
    
    def bnext_clicked
      return if !@log_replay.replay?
      if playing?
	update_target_speed @log_replay.speed*2
      else
        if actionNone.isChecked
            @log_replay.step(false)
        else
            @port ||= @log_replay.current_port
            @log_replay.step(false)
            timeline.setSliderIndex(@log_replay.sample_index)
            display_info
            if @port != @log_replay.current_port
                Orocos::Async.event_loop.once do 
                    bnext_clicked
                end
            else
                @port = nil
            end
        end
      end
      timeline.setSliderIndex(@log_replay.sample_index)
      display_info
    end

    def bback_clicked 
      return if !@log_replay.replay?
      if playing?
	update_target_speed @log_replay.speed*0.5
      else
        if actionNone.isChecked
            @log_replay.step_back
        else
            @port ||= @log_replay.current_port
            @log_replay.step_back
            timeline.setSliderIndex(@log_replay.sample_index)
            display_info
            if @port != @log_replay.current_port
                Orocos::Async.event_loop.once do 
                    bback_clicked
                end
            else
                @port = nil
            end
        end
      end
      timeline.setSliderIndex(@log_replay.sample_index)
      display_info
    end
    
    def bstop_clicked
       return if !@log_replay.replay?
       bplay_clicked if playing?
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
      if playing?
        bplay.icon = @play_icon
        @timer.cancel
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

    form
  end
  
end

Vizkit::UiLoader.register_ruby_widget('LogControl',LogControl.method(:create_widget))
Vizkit::UiLoader.register_control_for('LogControl',Orocos::Log::Replay, :config)
Vizkit::UiLoader.register_deprecate_plugin_clone("log_control","LogControl")

