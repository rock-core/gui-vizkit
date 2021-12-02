#prepares the c++ qt widget for the use in ruby with widget_grid

Vizkit::UiLoader::extend_cplusplus_widget_class "Plot2d" do
    class Plot2dEventFilter < ::Qt::Object
        attr_accessor :preferences

        def initialize(preferences = nil)
            super(nil)
            @preferences = preferences
        end

        def eventFilter(obj,event)
            if event.is_a?(Qt::CloseEvent)
                if @preferences
                    @preferences.close
                end
            end
            return false
        end
    end

    attr_accessor :options

    def default_options()
        options = Hash.new
        options[:auto_scrolling] = true     # auto scrolling for a specific axis is true
        options[:auto_scrolling_y] = false  # if one of auto_scrolling or auto_scrolling_<axis>
        options[:auto_scrolling_x] = false  # is true
        options[:time_window] = 30              #window size during auto scrolling
        options[:cached_time_window] = 60        #total cached window size
        options[:pre_time_window] = 5
        options[:xaxis_window] = 5
        options[:pre_xaxis_window] = 5
        options[:yaxis_window] = 5
        options[:pre_yaxis_window] = 5
        options[:max_points] = 50000

        options[:colors] = [Qt::red, Qt::green, Qt::blue, Qt::cyan, Qt::magenta, Qt::yellow, Qt::gray]
        options[:reuse] = true
        options[:use_y_axis2] = false
        options[:plot_style] = :Line  #:Dot
        options[:multi_use_menu] = true
        options[:update_period] = 0.25   # repaint periode if new data are available
                                         # this prevents repainting for each new sample
        options[:plot_timestamps] = true
        options[:is_time_plot] = false
        options
    end

    def time 
        time = if @log_replay
                   @log_replay.time
               else
                   Time.now
               end
        @time ||= time 
        time
    end

    def setXTitle(value)
        getXAxis.setLabel(value.to_s)
    end

    def setYTitle(value)
        getYAxis.setLabel(value.to_s)
    end

    def update_zoom_range_flag(flag, use_2nd_axis)
        y_axis = Hash[true => 1, false => 0][use_2nd_axis]
        setZoomAble flag, y_axis
        setRangeAble flag, y_axis
    end

    def initialize_vizkit_extension
        @options = default_options
        @graphs = Hash.new
        @time = nil 
        @timer = Qt::Timer.new
        @needs_update = false
        @timer.connect(SIGNAL"timeout()") do 
            replot if @needs_update
            @needs_update = false
        end
        @timer.start(1000*@options[:update_period])
        @color_next_idx = 0
        
        getLegend.setVisible(true)
        getXAxis.setLabel("Time in sec")
        setTitle("Rock-Plot2d")
        
        @preferences = Vizkit::Plot2d::Preferences.new('vizkit', 'plot2d', default_opts: @options)
        @preferences.connect(SIGNAL('updated()')) do
            update_options
        end
        update_options
        
        self.connect(SIGNAL('mousePressOnPlotArea(QMouseEvent*)')) do |event|
            if event.button() == Qt::RightButton
                #show pop up menue
                menu = Qt::Menu.new(self)
                action_scrolling = Qt::Action.new("AutoScrolling", self)
                action_scrolling.checkable = true
                action_scrolling.checked = @options[:auto_scrolling]
                menu.add_action(action_scrolling)
                action_clear = Qt::Action.new("Clear", self)
                menu.add_action(action_clear)
                action_autosize = Qt::Action.new("Autosize", self)
                menu.add_action(action_autosize)
                if @options[:multi_use_menu]
                    action_reuse = Qt::Action.new("Reuse Widget", self)
                    action_reuse.checkable = true
                    action_reuse.checked = @options[:reuse]
                    menu.add_action(action_reuse)
                    action_use_y2 = Qt::Action.new("Use 2. Y-Axis", self)
                    action_use_y2.checkable = true
                    action_use_y2.checked = @options[:use_y_axis2]
                    menu.add_action(action_use_y2)
                    action_plotdot = Qt::Action.new("'dot' style", self)
                    action_plotdot.checkable = true
                    action_plotdot.checked = @options[:plot_style] == :Dot
                    menu.add_action(action_plotdot)
                    action_plotline = Qt::Action.new("'line' style", self)
                    action_plotline.checkable = true
                    action_plotline.checked = @options[:plot_style] == :Line
                    menu.add_action(action_plotline)
                end
                menu.addSeparator
                action_preferences = Qt::Action.new("Preferences", self)
                menu.add_action(action_preferences)
                action_saving = Qt::Action.new("Save to File", self)
                menu.add_action(action_saving)
                if @options[:is_time_plot]
                    menu.addSeparator
                    action_timestamp = Qt::Action.new("Show timestamps", self)
                    action_timestamp.checkable = true
                    action_timestamp.checked = @options[:plot_timestamps]
                    menu.add_action(action_timestamp)
                    action_sample_period = Qt::Action.new("Show sample period", self)
                    action_sample_period.checkable = true
                    action_sample_period.checked = !@options[:plot_timestamps]
                    menu.add_action(action_sample_period)
                end

                action = menu.exec(mapToGlobal(event.pos))
                if(action == action_scrolling)
                    update_auto_scrolling !@options[:auto_scrolling]
		        elsif(action == action_clear)
                    clearData()
                elsif(action == action_autosize)
                    autosize()
                elsif(action == action_reuse)
                    @options[:reuse] = !@options[:reuse]
                elsif(action == action_use_y2)
                    update_use_y2 !@options[:use_y_axis2]
                 elsif(action == action_plotdot)
                    plot_style(:Dot)
                elsif(action == action_plotline)
                    plot_style(:Line)
                elsif action == action_preferences
                    open_preferences
                elsif action == action_saving
                    file_path = Qt::FileDialog::getSaveFileName(nil,"Save Plot to Pdf",File.expand_path("."),"Pdf (*.pdf)")
                    savePdf(file_path,false,0,0) if file_path
                elsif ((action == action_timestamp) || (action == action_sample_period))
                    @options[:plot_timestamps] =! @options[:plot_timestamps]
                end
                @preferences.load_from_hash(@options)
                @preferences_widget.load if @preferences_widget
            end
        end


        self.connect(SIGNAL('mousePressOnLegendItem(QMouseEvent*, QVariant)')) do |event, itemIdx|
            if event.button() == Qt::RightButton
                #show pop up menue
                menu = Qt::Menu.new(self)
                action_remove = Qt::Action.new("remove graph", self)
                menu.add_action(action_remove)

                action = menu.exec(mapToGlobal(event.pos))

                if(action == action_remove)
                    # note: we assume all graphs have a corresponding
                    # legend item with the same index (true for this widget)
                    graph = getGraph(itemIdx.to_i())

                    unless graph == 0 || graph.nil?

                        while true
                            cur_port = connection_manager().find_port_by_name(graph.name)

                            if cur_port
                                connection_manager().disconnect(cur_port,  keep_port: false)
                            else
                                break
                            end
                        end

                        @graphs.delete graph.name
                        removeGraph(itemIdx.to_i())
                        @needs_update = true
                    end
                end
            end
        end

    end

    def update_auto_scrolling(value = @options[:auto_scrolling])
        @options[:auto_scrolling] = value
        update_zoom_range_flag(!@options[:auto_scrolling], @options[:use_y_axis2])
    end

    def update_use_y2(value = @options[:use_y_axis2])
        update_zoom_range_flag(false, !value)
        @options[:use_y_axis2] = value
        if @options[:use_y_axis2]
            getYAxis2.setVisible(true)
        end
        update_zoom_range_flag(!@options[:auto_scrolling], @options[:use_y_axis2])
    end

    def update_timer(time_seconds = @options[:update_period])
        @timer.stop
        @timer.start(1000 * time_seconds)
    end

    def update_options
        @options[:auto_scrolling]     = @preferences.autoscroll
        @options[:reuse]              = @preferences.reuse_widget
        @options[:use_y_axis2]        = @preferences.use_2yaxes
        @options[:time_window]        = @preferences.time_window
        @options[:cached_time_window] = @preferences.time_window_cache
        @options[:pre_time_window]    = @options[:time_window] / 6
        @options[:update_period]      = @preferences.update_period

        update_use_y2
        update_auto_scrolling
        update_timer
    end

    def open_preferences
        if !@preferences_widget
            @preferences_widget = Vizkit::Plot2d::PreferencesWidget.new(@preferences)
            if !@event_filter
                installEventFilter(@event_filter = Plot2dEventFilter.new(@preferences_widget))
            else
                @event_filter.preferences = @preferences_widget
            end
        end
        @preferences_widget.show()
    end

    def graph_style(graph,style)
        if style == :Dot
            graph.setLineStyle(Qt::CPGraph::LSNone)
            graph.setScatterStyle(Qt::CPGraph::SSDot)
        else
            graph.setLineStyle(Qt::CPGraph::LSLine)
            graph.setScatterStyle(Qt::CPGraph::SSNone)
        end
        @needs_update = true
    end

    def plot_style(style)
        if @options[:plot_style] != style
            @options[:plot_style] = style
            @graphs.each_value do |graph|
                graph_style(graph,style)
            end
        end
    end

    def config(value,options)
        @log_replay = if value.respond_to? :task
                          if value.task.respond_to? :log_replay
                              value.task.log_replay
                          end
                      end
        @options = options.merge(@options)
        if value.type_name == "/base/samples/SonarBeam"
            if !@graphs.empty?
                puts "Cannot plot SonarBeam because plot is already used!"
                return :do_not_connect
            else
                @options[:multi_use_menu] = false
                getXAxis.setLabel "Bin Number"
            end
        elsif value.type_name =~ /\/std\/vector</ || value.type_name == "/base/samples/LaserScan"
            if !@graphs.empty?
                puts "Cannot plot std::vector because plot is already used!"
                return :do_not_connect
            else
                @options[:multi_use_menu] = false
                getXAxis.setLabel "Index"
            end
        end
        subfield = Array(options[:subfield]).join(".")
        subfield = "." + subfield if !subfield.empty?
        graph2(value.full_name+subfield) if value.respond_to? :full_name
    end

    def graph2(name)
        if(!@graphs.has_key?(name))
            axis = if @options[:use_y_axis2] then getYAxis2
                   else getYAxis
                   end

            axis.setLabel(name.split(".").last)
            graph = addGraph(getXAxis(),axis)
            graph.setName(name)
            graph_style(graph,@options[:plot_style])
            graph.addToLegend

            if color = @options[:colors][@color_next_idx]
                graph.setPen(Qt::Pen.new(Qt::Brush.new(color),1))
            end

            @color_next_idx = (@color_next_idx + 1) % @options[:colors].count

            @graphs[name] = graph
        end

        @graphs[name]
    end

    def autosize
        rescaleAxes
    end

    def multi_value?
        @options[:reuse] && @options[:multi_use_menu]
    end

    def rename_graph(old_name,new_name)
        graph = @graphs[old_name]
        if graph
            graph.setName(new_name)
            @graphs[new_name] = @graphs[old_name]
            @graphs.delete old_name
        end
    end

    # Add a new sample to a given graph on the plot
    #
    # @param [#to_f] sample the value to be added to the graph
    # @param [String] name the name of the graph. It is created if needed
    # @param [Time] time the sample time
    def update(sample, name, time: self.time)
        graph = graph2(name)
        @time ||= time
        x = time-@time

        graph.removeDataBefore(x - @options[:cached_time_window])
        graph.addData(x, sample.to_f)
        if @options[:auto_scrolling] || @options[:auto_scrolling_x]
            getXAxis.setRange(x-@options[:time_window],x+@options[:pre_time_window])
            graph.rescaleValueAxis(true)
        end
        @needs_update = true
    end

    def update_orientation(sample,name)
        rename_graph(name,name+"_yaw")
        update((sample.yaw)   *(180.00/Math::PI),name+"_yaw")
        update((sample.pitch) *(180.00/Math::PI),name+"_pitch")
        update((sample.roll)   *(180.00/Math::PI),name+"_roll")
    end

    def update_vector3d(sample,name)
        rename_graph(name,name+"_x")
        update(sample[0],name+"_x")
        update(sample[1],name+"_y")
        update(sample[2],name+"_z")
    end

    def update_vectorXd(sample,name)
        if (sample.size() == 1)
            update(sample[0], name)
        else
            rename_graph(name,name+"[0]")
            for i in (0..sample.size()-1)
                update(sample[i], name+"["+i.to_s()+"]")
            end
        end
    end

    def update_time(sample, name)
        # So that the time related options of the right click menu are not shown for other types
        @options[:is_time_plot] = true
        if @options[:plot_timestamps]
            update(sample.to_f, name)
        else
            update_time_diff(sample, name)
        end
    end

    def update_time_diff(sample, name)
        # For each data source an entry in the dictionary is created
        if @previous_time == nil
            @previous_time = {}
        end
        if @previous_time[name] == nil
            @previous_time[name] = sample.to_f
        end
        difference = sample.to_f - @previous_time[name]
        @previous_time[name] = sample.to_f
        update(difference, name)
    end


    def set_x_axis_scale(start,stop)
        getXAxis.setRange(start,stop)
    end

    def set_y_axis_scale(start,stop)
        getYAxis.setRange(start,stop)
    end

    def update_custom(name,values_x,values_y)
        graph = graph2(name)
        graph.addData(values_x,values_y)
        if @options[:auto_scrolling] || @options[:auto_scrolling_x]
            getXAxis.setRange(values_x-@options[:xaxis_window],values_x+@options[:pre_xaxis_window])
            graph.rescaleValueAxis(true)
        end
        if @options[:auto_scrolling] || @options[:auto_scrolling_y]
            getYAxis.setRange(values_y-@options[:yaxis_window],values_y+@options[:pre_yaxis_window])
            graph.rescaleValueAxis(true)
        end
        @needs_update = true
    end

    def update_vector(sample,name)
        if sample.size() > @options[:max_points]
            Vizkit.logger.warn "Cannot plot #{name}. Vector is too big"
            return
        end
        graph = graph2(name)
        graph.clearData
        sample.to_a.each_with_index do |value,index|
            graph.addData(index,value)
        end
        if @options[:auto_scrolling] || @options[:auto_scrolling_x]
            graph.rescaleKeyAxis(false)
        end
        if @options[:auto_scrolling] || @options[:auto_scrolling_y]
            graph.rescaleValueAxis(false)
        end
        @needs_update = true
    end

    def update_sonar_beam(sample,name)
        update_vector sample.beam,name
    end
    def update_laser_scan(sample,name)
        update_vector sample.ranges,name
    end
    def update_angle(sample,name)
        update sample.rad,name
    end
end
vector_types = ["/std/vector</uint8_t>","/std/vector</uint16_t>","/std/vector</uint32_t>",
                "/std/vector</uint64_t>","/std/vector</int8_t>","/std/vector</int16_t>",
                "/std/vector</int32_t>","/std/vector</int64_t>","/std/vector</float>",
                "/std/vector</double>"]
Vizkit::UiLoader.register_widget_for("Plot2d","Typelib::NumericType",:update)
Vizkit::UiLoader.register_widget_for("Plot2d","/base/Quaterniond",:update_orientation)
Vizkit::UiLoader.register_widget_for("Plot2d","/base/samples/SonarBeam",:update_sonar_beam)
Vizkit::UiLoader.register_widget_for("Plot2d","/base/samples/LaserScan",:update_laser_scan)
Vizkit::UiLoader.register_widget_for("Plot2d",vector_types,:update_vector)
Vizkit::UiLoader.register_widget_for("Plot2d","/base/Angle",:update_angle)
Vizkit::UiLoader.register_widget_for("Plot2d","/base/Vector3d",:update_vector3d)
Vizkit::UiLoader.register_widget_for("Plot2d","/base/VectorXd",:update_vectorXd)
Vizkit::UiLoader.register_widget_for("Plot2d","/base/Time",:update_time)

