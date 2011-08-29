
class LogControl
  module Functions
    def control(replay,options=Hash.new)
      raise "Cannot control #{replay.class}" if !replay.instance_of?(Orocos::Log::Replay)
      @log_replay = replay
      @replay_on = false 
      @slider_pressed = false
      @user_speed = @log_replay.speed


      dir = File.dirname(__FILE__)
      @pause_icon =  Qt::Icon.new(File.join(dir,'pause.png'))
      @play_icon = Qt::Icon.new(File.join(dir,'play.png'))
     # setFixedSize(253,146)
      #
      setAttribute(Qt::WA_QuitOnClose, true);

      connect(slider, SIGNAL('valueChanged(int)'), lcd_index, SLOT('display(int)'))
      slider.connect(SIGNAL('sliderReleased()'),self,:slider_released)
      bnext.connect(SIGNAL('clicked()'),self,:bnext_clicked)
      #bnext.connect(SIGNAL('clicked()'),self,:bnextmarker_clicked)
      bback.connect(SIGNAL('clicked()'),self,:bback_clicked)
      #bback.connect(SIGNAL('clicked()'),self,:bprevmarker_clicked)
      bstop.connect(SIGNAL('clicked()'),self,:bstop_clicked)
      bplay.connect(SIGNAL('clicked()'),self,:bplay_clicked)
      treeView.connect(SIGNAL('doubleClicked(const QModelIndex&)'),self,:tree_double_clicked)
      slider.connect(SIGNAL(:sliderPressed)) {@slider_pressed = true;}
     
      if(options.has_key?(:show_marker))
             if options[:show_marker] == true
          	marker_view.show
                @marker_mapping = Hash.new
                @marker_model = Qt::StandardItemModel.new
                @marker_model.setColumnCount(1)
                @marker_model.setHorizontalHeaderLabels(["Information"])
                @marker_root = @marker_model.invisibleRootItem
                marker_view.setModel(@marker_model)
                marker_view.setAlternatingRowColors(true)
                marker_view.setSortingEnabled(true)
                marker_view.connect(SIGNAL('doubleClicked(const QModelIndex&)'),self,:marker_tree_double_clicked)
              end
      end

      if(options.has_key?(:marker_type))
          add_marker_stream_by_type(options[:marker_type])
      end
      if(options.has_key?(:marker_stream))
          add_marker_stream_by_name(options[:marker_stream])
      end

      @log_replay.align unless @log_replay.aligned?
      return if !@log_replay.replay?
      @log_replay.process_qt_events = true
      slider.maximum = @log_replay.size-1

      #add replayed streams to tree view 
      @tree_model = Qt::StandardItemModel.new
      @tree_model.setHorizontalHeaderLabels(["Replayed Tasks","Information"])
      @root_item = @tree_model.invisibleRootItem
      treeView.setModel(@tree_model)
      treeView.setAlternatingRowColors(true)
      treeView.setSortingEnabled(true)
      @brush = Qt::Brush.new(Qt::Color.new(200,200,200))
      @widget_hash = Hash.new
      @mapping = Hash.new
     
		 	#if not @log_replay.tasks
			#	STDERR.puts "Cannot handle empty Task"
			#else
        @log_replay.tasks.each do |task|
        next if !task.used?
        item, item2 = get_item(task.name,task.name, @root_item)
        item2.setText(task.file_path)
        #setting ports
        task.each_port do |port|
          key = task.name+"_"+ port.name
          item2, item3 = get_item(key,port.name, item)
          @mapping[item2] = port
          @mapping[item3] = port
          item3.setText(port.type_name.to_s)

          item4, item5 = get_item(key,"Samples", item2)
          item5.setText(port.number_of_samples.to_s)

          item4, item5 = get_item(key,"Filter", item2)
          if port.filter
            item5.setText("yes")
          else
            item5.setText("no")
          end
        end
      end
			#end
      treeView.resizeColumnToContents(0)
      display_info
    end

    def add_marker_stream_by_id(id)
        throw "Cannot add marker, unless it's not initializaed in options (:show_marker=>true)" if not @marker_root

	#need to align first, sorry
        @log_replay.align unless @log_replay.aligned?
        @log_replay.rewind
        before = Time.new
        

        #don't use step, alining takes to much time we need only the header
        #if later on more informations are requierd please re-read only current sample
        while t = @log_replay.advance
          if(t[0] == id)
            sample = @log_replay.single_data(id)
            time = sample.time
            @log_replay.markers << time
            target_sample_pos = @log_replay.get_sample_index_for_time(time)
            slider.addMarker(target_sample_pos)

	    #Only getting first line, to prevent too log messages
            string = sample.comment.split("\n")[0] 
	    string = "<nil>" if not string

            item = get_marker_item(sample.id,string, @marker_root)
            get_marker_item("id_#{sample.id}","ID: #{sample.id}",item)
            get_marker_item("comment_#{sample.id}",sample.comment,item)
            get_marker_item("time_#{sample.id}",sample.time,item) 
          end
        end
        
        #rewind to beginning
        @log_replay.rewind
    end

    def add_marker_stream_by_type(type)
	#need to align first, sorry
        @log_replay.align unless @log_replay.aligned?
        id = @log_replay.get_stream_index_for_type(type)
	pp "Found stream id: #{id} #{type}"
	add_marker_stream_by_id(id)        
    end

    def add_marker_stream_by_name(name)
	#need to align first, sorry
        @log_replay.align unless @log_replay.aligned?
        #getting the ID for later header compareision
        id = @log_replay.get_stream_index_for_name(name)
	add_marker_stream_by_id(id)        
    end
    
    def marker_tree_double_clicked(model_index)
      item = @marker_model.itemFromIndex(model_index)
      return unless @marker_mapping.has_key? item.text
      @log_replay.seek(@marker_mapping[item.text]) if @marker_mapping[item.text].is_a? Time
      display_info
    end

    def tree_double_clicked(model_index)
      item = @tree_model.itemFromIndex(model_index)
      return unless @mapping.has_key? item
      port = @mapping[item]
      widget = @widget_hash[port]
      if widget
        Vizkit.connect(widget)
        widget.show
      else
        widget = Vizkit.display port
        widget.setAttribute(Qt::WA_QuitOnClose, false) if widget
        @widget_hash[port]=widget
      end
    end
    
    def playing?
      @replay_on
    end

    def get_marker_item(key,name,root_item)
      item = Qt::StandardItem.new(name.to_s)
      item.setEditable(false)
      root_item.appendRow(item)
      @marker_mapping[name.to_s] = name
      return item
    end

    def get_item(key,name,root_item)
      item = Qt::StandardItem.new(name)
      item.setEditable(false)
      root_item.appendRow(item)
      item2 = Qt::StandardItem.new
      item2.setEditable(false)
      root_item.setChild(item.row,1,item2)
      return [item,item2]
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
    
    def bnextmarker_clicked
      return if !@log_replay.replay?
      @log_replay.next_marker()
      display_info
    end
    
    def bprevmarker_clicked
      return if !@log_replay.replay?
      @log_replay.prev_marker()
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
  end

  def self.create_widget(parent = nil)
    form = Vizkit.load(File.join(File.dirname(__FILE__),'LogControl.ui'),parent)
    form.extend Functions
    form.marker_view.hide

    #workaround
    #it is not possible to define virtual functions for qidgets which are loaded
    #via UiLoader (qtruby1.8)
    #stop replay if all windows are closed
    $qApp.connect(SIGNAL(:lastWindowClosed)) do 
      form.instance_variable_set(:@replay_on,false)
    end

    form
  end
end

Vizkit::UiLoader.register_ruby_widget('log_control',LogControl.method(:create_widget))
