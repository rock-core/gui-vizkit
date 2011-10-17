#!/usr/bin/env ruby

require 'vizkit'

class TaskInspector < Qt::Widget
  MAX_ARRAY_FIELDS = 32

  slots 'refresh()','set_task_attributes(bool)','itemChangeRequest(QStandardItem*)'
  attr_reader :multi  #widget supports displaying of multi tasks
  PropertyConfig = Struct.new(:name, :attribute, :type)
  DataPair = Struct.new :name, :task

  def initialize(parent=nil)
    super
    load File.join(File.dirname(__FILE__), 'task_inspector_window.ui.rb')
    load File.join(File.dirname(__FILE__), '../..', 'tree_modeler.rb')
    @window = Ui_Form.new
    @window.setupUi(self)
    @brush = Qt::Brush.new(Qt::Color.new(200,200,200))
    @modeler = Vizkit::TreeModeler.new
    @tree_model = @modeler.create_tree_model
    @root_item = @tree_model.invisibleRootItem
    @window.treeView.setModel(@tree_model)
    @window.treeView.setAlternatingRowColors(true)
    @window.treeView.setSortingEnabled(true)
    
    @hash = Hash.new
    @reader_hash = Hash.new
    @tasks = Hash.new

    @multi = true
    @read_obj = false
    #connect(@tree_model, SIGNAL('itemChanged(QStandardItem*)'),self,SLOT('itemChangeRequest(QStandardItem*)'))
    connect(@window.setPropButton, SIGNAL('toggled(bool)'),self,SLOT('set_task_attributes(bool)'))
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
          #setting attributes
          key = task.name + "__ATTRIBUTES__"
          item3, item4 = get_item(key,"Attributes", item)

          task.each_property do |attribute|
            key = task.name+"_"+ attribute.name
            item5, item6 = get_item(key,attribute.name, item3)
            if attribute.read.is_a?(String)||attribute.read.is_a?(Float)||attribute.read.is_a?(Fixnum)
              item6.setEditable true
              item6.setText(attribute.read.to_s) 
              @hash[item6]=pair if !@hash.has_key? item6
            else
              update_item(attribute.read, attribute.name, item5)
            end
          end

          #setting ports
          key = task.name + "__IPORTS__"
          key2 = task.name + "__OPORTS__"
          item3, item4 = get_item(key,"Input Ports", item)
          item5, item6 = get_item(key2,"Output Ports", item)

          task.each_port do |port|
            key = task.name+"_"+ port.name
            if port.is_a?(Orocos::InputPort)
              item7, item8 = get_item(key,port.name, item3)
            else
              item7, item8 = get_item(key,port.name, item5)
              reader = port_reader(task,port)
              if reader.read.kind_of?(Typelib::CompoundType)
                # Submit output_ports node as parent because a new node 
                # will be generated as parent for the compound items.
                update_item(reader.read, port.name, item5)
              else
                update_item(reader.read, port.name, item7)
              end
            end
            item8.setText(port.type_name.to_s)
          end
        rescue Orocos::CORBA::ComError
          pair.task = nil
        end
      end
    end
    @window.treeView.resizeColumnToContents(0)
  end

  def set_task_attributes(checked)
    # TODO change name of flag 'checked'
    
    @read_obj = checked
    
    Vizkit.info("Attribute change request received.")
    
    if @read_obj
        puts "Please enter your attribute changes."
    else
        Vizkit.info("Property changes will be processed.")
        # TODO
        @tasks.each_value do |pair|
            next if !pair || !pair.task || !pair.task.reachable?
            
            item, item2 = get_item(pair.name, pair.name, @root_item)
            task = pair.task
            
            key = task.name + "__ATTRIBUTES__"
            item3, item4 = get_item(key,"Attributes", item)
            task.each_property do |attribute|
                sample = attribute.new_sample
                update_item(sample, attribute.name, item3, true)
                Vizkit.debug("updated attribute value = #{sample}")
                attribute.write sample
            end
        end
        
    end
  
  #   return if !item2.parent
  #   item = item2.parent.child(item2.row,0) 
  #   pair = @hash[item2]
  #   return if !pair || !pair.task || !pair.task.reachable?

  #   property = pair.task.property item.text
  #   sample = property.new_sample
  #   update_item(sample,item.parent,true,item.row)
  #   property.write sample
  end
  
end


Vizkit::UiLoader.register_ruby_widget("task_inspector",TaskInspector.method(:new))
Vizkit::UiLoader.register_widget_for("task_inspector",Orocos::TaskContext)
#not supported so far
#Vizkit::UiLoader.register_widget_for("task_inspector",Orocos::Log::TaskContext)
