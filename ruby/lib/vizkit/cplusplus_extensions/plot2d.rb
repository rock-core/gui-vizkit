#prepares the c++ qt widget for the use in ruby with widget_grid

Vizkit::UiLoader::extend_cplusplus_widget_class "Plot2d" do
    attr_accessor :options

    def default_options()
        options = Hash.new
        options[:auto_scrolling] = true
        options[:time_window] = 60
        options[:pre_time_window] = 5
        options[:colors] = [Qt::red, Qt::green, Qt::blue, Qt::cyan, Qt::magenta, Qt::yellow, Qt::gray]
        options[:reuse] = true
        options[:use_y_axis2] = false
        return options 
    end

    def time 
        if @log_replay
            @log_replay.time
        else
            Time.now
        end
    end

    def init()
        @init ||= false 
        if !@init
            @init = true
            @options = default_options
            @graphs = Hash.new
            @time = time.to_f
            
            getLegend.setVisible(true)
            getXAxis.setLabel("Time in sec")
            setTitle("Rock-Plot2d")
            self.connect(SIGNAL('mousePress(QMouseEvent*)')) do |event|
                if event.button() == Qt::RightButton
                    #show pop up menue 
                    menu = Qt::Menu.new(self)
                    action_scrolling = Qt::Action.new("AutoScrolling", self)
                    action_scrolling.checkable = true
                    action_scrolling.checked = @options[:auto_scrolling]
                    menu.add_action(action_scrolling)
                    action_reuse = Qt::Action.new("Reuse Widget", self)
                    action_reuse.checkable = true
                    action_reuse.checked = @options[:reuse]
                    menu.add_action(action_reuse)
                    action_use_y2 = Qt::Action.new("Use 2. Y-Axis", self)
                    action_use_y2.checkable = true
                    action_use_y2.checked = @options[:use_y_axis2]
                    menu.add_action(action_use_y2)
                    menu.addSeparator

                    action_saving = Qt::Action.new("Save to File", self)
                    #  menu.add_action(action_saving)

                    action = menu.exec(mapToGlobal(event.pos))
                    if(action == action_scrolling)
                        @options[:auto_scrolling] = !@options[:auto_scrolling]
                        setZoomAble !@options[:auto_scrolling]
                        setRangeAble !@options[:auto_scrolling]
                    elsif(action == action_reuse)
                        @options[:reuse] = !@options[:reuse]
                    elsif(action == action_use_y2)
                        @options[:use_y_axis2] = !@options[:use_y_axis2]
                    elsif action == action_saving

                    end
                end
            end
        end

    end

    def config(value,options)
        @log_replay = if value.respond_to? :task
                          if value.task.respond_to? :log_replay
                              value.task.log_replay
                          end
                      end
        init
        @options = options.merge(@options)
        graph2(value.full_name) if value.respond_to? :full_name
    end

    def graph2(name)
        init
        graph = if(@graphs.has_key?(name))
                    @graphs[name]
                else
                    graph = if @options[:use_y_axis2] == true
                                getYAxis2.setVisible(true)
                                getYAxis2.setLabel(name.split(".").last)
                                addGraph(getXAxis(),getYAxis2())
                            else
                                getYAxis.setLabel(name.split(".").last)
                                addGraph(getXAxis(),getYAxis())
                            end
                    graph.setName(name)
                    graph.addToLegend
                    if(@graphs.size < @options[:colors].size)
                        graph.setPen(Qt::Pen.new(Qt::Brush.new(@options[:colors][@graphs.size]),1))
                    end
                    @graphs[name] = graph
                end
    end

    def multi_value?
        @options[:reuse]
    end

    def rename_graph(old_name,new_name)
        graph = @graphs[old_name]
        if graph
            graph.setName(new_name)
            @graphs[new_name] = @graphs[old_name]
            @graphs.delete old_name
        end
    end

    #diplay is called each time new data are available on the orocos output port
    #this functions translates the orocos data struct to the widget specific format
    def update(sample,name)
        graph = graph2(name)
        x = time.to_f-@time
        graph.addData(x,sample.to_f)
        if @options[:auto_scrolling]
            getXAxis.setRange(x-@options[:time_window],x+@options[:pre_time_window])
            graph.rescaleValueAxis(true)
        else
        end
        replot
    end

    def update_orientation(sample,name)
        new_sample = sample.to_euler(2,1,0)
        rename_graph(name,name+"_yaw")
        update(new_sample[0],name+"_yaw")
        update(new_sample[1],name+"_pitch")
        update(new_sample[2],name+"_roll")
    end

end

Vizkit::UiLoader.register_widget_for("Plot2d",Fixnum,:update)
Vizkit::UiLoader.register_widget_for("Plot2d",Float,:update)
Vizkit::UiLoader.register_widget_for("Plot2d",Eigen::Quaternion,:update_orientation)
