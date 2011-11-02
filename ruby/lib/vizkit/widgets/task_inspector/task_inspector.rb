#!/usr/bin/env ruby

require 'vizkit'

class TaskInspector < Qt::Widget

  slots 'refresh()','set_task_attributes()','cancel_set_task_attributes()','itemChangeRequest(const QModelIndex&)','contextMenuRequest(const QPoint&)','clickedAction(const QString&)'
  attr_reader :multi  #widget supports displaying of multi tasks
  PropertyConfig = Struct.new(:name, :attribute, :type)
  DataPair = Struct.new :name, :task
  
  LABEL_ATTRIBUTES = "Attributes"
  LABEL_INPUT_PORTS = "Input Ports"
  LABEL_OUTPUT_PORTS = "Output Ports"

  def initialize(parent=nil)
    super
    load File.join(File.dirname(__FILE__), 'task_inspector_window.ui.rb')
    load File.join(File.dirname(__FILE__), '../..', 'tree_modeler.rb')
    @window = Ui_Form.new
    @window.setupUi(self)
    @window.buttonFrame.hide
    @brush = Qt::Brush.new(Qt::Color.new(200,200,200))
    @modeler = Vizkit::TreeModeler.new
    @tree_model = @modeler.create_tree_model
    @root_item = @tree_model.invisibleRootItem
    @window.treeView.setModel(@tree_model)
    @window.treeView.setAlternatingRowColors(true)
    @window.treeView.setSortingEnabled(true)
    #@window.treeView.setContextMenuPolicy(Qt::CustomContextMenu)
    @window.treeView.setContextMenuPolicy(Qt::DefaultContextMenu)
    
    @signal_mapper = nil
    
    @hash = Hash.new
    @reader_hash = Hash.new
    @tasks = Hash.new

    @multi = true
    @read_obj = false
    connect(@window.treeView, SIGNAL('doubleClicked(const QModelIndex&)'), self, SLOT('itemChangeRequest(const QModelIndex&)'))
    connect(@window.setPropButton, SIGNAL('clicked()'),self,SLOT('set_task_attributes()'))
    connect(@window.cancelPropButton, SIGNAL('clicked()'),self,SLOT('cancel_set_task_attributes()'))
    #connect(@window.treeView, SIGNAL('customContextMenuRequested(const QPoint&)'), self, SLOT('contextMenuRequest(const QPoint&)'))
    @timer = Qt::Timer.new(self)
    connect(@timer,SIGNAL('timeout()'),self,SLOT('refresh()'))
  end

  def default_options()
    options = Hash.new
    options[:interval] = 1000   #update interval in msec
    return options
  end

  def config(task,options=Hash.new)
    data_pair = DataPair.new
    if task.is_a? Orocos::TaskContext
      data_pair.name = task.name
      data_pair.task = task
    else
      data_pair.name = task
    end
    @tasks[data_pair.name] = data_pair if !@tasks.has_key?(data_pair.name)
    options = default_options.merge(options)
    @timer.start(options[:interval])
  end

  def get_item(key,name,root_item)
    if @hash.has_key?(key)
      item =  @hash[key]
      item2 = root_item.child(item.row,1)
      [item,item2]
    else
      item, item2 = @modeler.child_items root_item, -1
      item.setText name.to_s
      @hash[key]=item
      [item,item2]
    end
  end

  def update_item(object, object_name, parent_item,read_obj=false,row=0,name_hint=nil)
      #puts "Updating #{object_name} of class type #{object.class}"
      @modeler.update_sub_tree(object, object_name, parent_item, read_obj)
  end

  def port_reader(task, port)
    readers = @reader_hash[task]
    if !readers
      readers = Hash.new 
      @reader_hash[task] = readers
    end
    #we have to use the name of the port
    #because task.port returns a new object
    #each time it is called
    reader = readers[port.name]
    if !reader
      reader = port.reader :pull => true
      readers[port.name] = reader
    end
    reader
  end

  def delete_port_reader(task)
    @reader_hash[task] = nil
  end


  def refresh()
    @tasks.each_value do |pair|
      #check if task is still available and try 
      #to reconnect if not
      if !pair.task || !pair.task.reachable?
        delete_port_reader pair.task if pair.task
        begin
          pair.task = Orocos::TaskContext.get pair.name
        rescue Orocos::NotFound 
          pair.task = nil
        end
      end

      item, item2 = get_item(pair.name, pair.name, @root_item)
      if !pair.task
        item2.setText("not reachable")
        item.removeRows(1,item.rowCount-1)
      else
        begin
          task = pair.task
          item2.setText(task.state.to_s) 
          
          #setting attributes unless user changes them right now (GUI)
          unless @read_obj
              key = task.name + "__ATTRIBUTES__"
              item3, item4 = get_item(key, LABEL_ATTRIBUTES, item)

              task.each_property do |attribute|
                key = task.name+"_"+ attribute.name
                
                unless attribute.read.kind_of?(Typelib::CompoundType)
                    item5, item6 = get_item(key,attribute.name, item3)
                end
                
                Vizkit.debug("Attribute '#{attribute.name}' is of class type '#{attribute.read.class}'")
                
                if attribute.read.is_a?(String)||attribute.read.is_a?(Float)||attribute.read.is_a?(Fixnum)
                  item6.setText(attribute.read.to_s.gsub(',', '.')) # use international decimal point 
                  @hash[item6]=pair if !@hash.has_key? item6
                elsif attribute.read.kind_of?(Typelib::CompoundType)
                    # Submit 'attributes' node as parent because a new node 
                    # will be generated as parent for the compound items.
                    update_item(attribute.read, attribute.name, item3)
                    
                else
                    update_item(attribute.read, attribute.name, item5)
                end
              end
              @modeler.set_all_children_editable(item3, true) # attributes
          end

          #setting ports
          key = task.name + "__IPORTS__"
          key2 = task.name + "__OPORTS__"
          item3, item4 = get_item(key, LABEL_INPUT_PORTS, item)
          item5, item6 = get_item(key2, LABEL_OUTPUT_PORTS, item)

          task.each_port do |port|
            key = task.name+"_"+ port.name
            if port.is_a?(Orocos::InputPort)
              item7, item8 = get_item(key,port.name, item3)
            else
              item7, item8 = get_item(key,port.name, item5)
              reader = port_reader(task,port)
              if reader.read.kind_of?(Typelib::CompoundType)
                # Submit 'output_ports' node as parent because a new node 
                # will be generated as parent for the compound items.
                update_item(reader.read, port.name, item5)
              else
                update_item(reader.read, port.name, item7)
              end
            end
            item8.setText(port.type_name.to_s)
          end
          @modeler.set_all_children_editable(item3, false) # input ports
          @modeler.set_all_children_editable(item5, false) # output ports
        rescue Orocos::CORBA::ComError
          pair.task = nil
        end
      end
    end
    @window.treeView.resizeColumnToContents(0)
  end

  def set_task_attributes
    Vizkit.debug("Property changes will be processed.")
    @tasks.each_value do |pair|
        next if !pair || !pair.task || !pair.task.reachable?
        
        item, item2 = get_item(pair.name, pair.name, @root_item)
        task = pair.task
        
        key = task.name + "__ATTRIBUTES__"
        item3, item4 = get_item(key, LABEL_ATTRIBUTES, item)
        task.each_property do |attribute|
            Vizkit.debug("Changing attribute '#{attribute.name}', old value: '#{attribute.read}'")
            sample = attribute.new_sample.zero!
            update_item(sample, attribute.name, item3, true)
            Vizkit.debug("Updated attribute value = #{sample}")
            attribute.write sample
        end
    end
    Vizkit.debug("Attributes updated.")
    @window.buttonFrame.hide
    @read_obj = false;
  end
  
    def itemChangeRequest(index)
        Vizkit.debug("Doubleclicked view")
        if @tree_model.item_from_index(index).is_editable
            Vizkit.debug("Item is editable. Setting button checked.")
            @read_obj = true;
            @window.buttonFrame.show
        end
    end
    
    def cancel_set_task_attributes
        @read_obj = false;
        @window.buttonFrame.hide
    end
    
    def contextMenuEvent(event)

        pos = event.pos
        model_index = @window.treeView.index_at(Qt::Point.new(pos.x,pos.y-31)) # TODO Hard coded offset! Only works for mouse click. Better: use correct coordinate system conversion.
        item = @tree_model.item_from_index(model_index)
        if item && item.parent && item.parent.text.eql?(LABEL_OUTPUT_PORTS)
            # Clicked on an item in the view. Display context menu.
            menu = Qt::Menu.new(self)
            
            loader = Vizkit.default_loader
            
            widgets = []
            widgets = loader.widget_names_for_value(item.text)
            
            # Always offer struct viewer if not yet present.
            if not widgets.include? "StructViewer"
                widgets << "StructViewer"
            end
            
            # TODO: get task and port for clicked item
            # like this:
            # task = item.parent.parent.text
            # port = ...
            
            @signal_mapper = Qt::SignalMapper.new(self)
            connect(@signal_mapper, SIGNAL('mapped(const QString&)'), self, SLOT('clickedAction(const QString&)'))
            
            widgets.each do |w|
                a = Qt::Action.new(w, self)
                menu.add_action(a)
                connect(a, SIGNAL('triggered()'), @signal_mapper, SLOT('map()'));
                @signal_mapper.set_mapping(a, w);
            end
         
            menu.exec(event.global_pos)
        end
    end
    
    def clickedAction(name)
        Vizkit.info "You triggerred action #{name}"
        widget = Vizkit.default_loader.create_widget(name)
        widget.show
    end
  
end


Vizkit::UiLoader.register_ruby_widget("task_inspector",TaskInspector.method(:new))
Vizkit::UiLoader.register_widget_for("task_inspector",Orocos::TaskContext)
#not supported so far
#Vizkit::UiLoader.register_widget_for("task_inspector",Orocos::Log::TaskContext)
