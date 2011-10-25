#!/usr/bin/env ruby

class TaskInspector < Qt::Widget
  MAX_ARRAY_FIELDS = 32

  slots 'refresh()','set_task_attribute(QStandardItem*)'
  attr_reader :multi  #widget supports displaying of multi tasks
  PropertyConfig = Struct.new(:name, :attribute, :type)
  DataPair = Struct.new :name, :task


  def initialize(parent=nil)
    super
    load File.join(File.dirname(__FILE__),'task_inspector_window.ui.rb')
    @window = Ui_Form.new
    @window.setupUi(self)
    @tree_model = Qt::StandardItemModel.new
    @tree_model.setHorizontalHeaderLabels(["Property","Value"])
    @root_item = @tree_model.invisibleRootItem
    @window.treeView.setModel(@tree_model)
    @window.treeView.setAlternatingRowColors(true)
    @window.treeView.setSortingEnabled(true)
    @brush = Qt::Brush.new(Qt::Color.new(200,200,200))

    @hash = Hash.new
    @reader_hash = Hash.new
    @tasks = Hash.new

    @multi = true
    connect(@tree_model, SIGNAL('itemChanged(QStandardItem*)'),self,SLOT('set_task_attribute(QStandardItem*)'))

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

  def child_items(parent_item,row)
    item = parent_item.child(row,0)
    item2 = parent_item.child(row,1)
    unless item
      item = Qt::StandardItem.new
      parent_item.appendRow(item)
      item2 = Qt::StandardItem.new
      parent_item.setChild(item.row,1,item2)
      item.setEditable(false)
      item2.setEditable(false)
    end
    [item,item2]
  end

  def get_item(key,name,root_item)
    if @hash.has_key?(key)
      item =  @hash[key]
      item2 = root_item.child(item.row,1)
      [item,item2]
    else
      item, item2 = child_items root_item, -1
      item.setText name.to_s
      @hash[key]=item
      [item,item2]
    end
  end

  def update_item(object, parent_item,read_obj=false,row=0,name_hint=nil)
    if object.kind_of?(Typelib::CompoundType)
      row = 0;
      object.each_field do |name,value|
        if read_obj
          object.set_field(name,update_item(value,parent_item,read_obj,row,name))
        else
          update_item(value,parent_item,read_obj,row,name)
        end
        row += 1
      end
      #delete all other rows
      parent_item.removeRows(row,parent_item.rowCount-row) if row < parent_item.rowCount
    elsif object.is_a?(Array) || (object.kind_of?(Typelib::Type) && object.respond_to?(:each) )
      if object.size > MAX_ARRAY_FIELDS
        item, item2 = child_items(parent_item,0)
        item2.setText "#{object.size} fields ..."
      elsif object.size > 0
        row = 0
        object.each_with_index do |val,row|
          if read_obj
            object[row]=  update_item(val,parent_item,read_obj,row)
          else
            update_item(val,parent_item,read_obj,row)
          end
          row += 1
        end
        #delete all other rows
        parent_item.removeRows(row,parent_item.rowCount-row) if row < parent_item.rowCount
      elsif read_obj
        a = (update_item(object.to_ruby,parent_item,read_obj,0))
        object << a
      end
    else
      item, item2 = child_items(parent_item,row)
      if object 
        if read_obj
          raise "name differs" if(object.respond_to?(:name) && item.text != object.name)
          #confert type
          type = object
          if object.is_a? Typelib::Type
            type = object.to_ruby 
          end
          data = item2.text if type.is_a? String
          data = item2.text.to_f if type.is_a? Float
          data = item2.text.to_i if type.is_a? File
          data = item2.text.to_i == 0 if type.is_a? FalseClass
          data = item2.text.to_i == 1 if type.is_a? TrueClass
          data = item2.text.to_sym if type.is_a? Symbol
          data = Time.new(item2.text) if type.is_a? Time
          if object.is_a? Typelib::Type
            Typelib.copy(object,Typelib.from_ruby(data, object.class))
          else
            object = data
          end
        else
          if object.respond_to? :name
            item.setText object.name 
          elsif name_hint
            item.setText name_hint
          else
            item.setText "[#{row}]"
          end
          item2.setText object.to_s 
        end
      else
        raise 'No data available' if read_obj
        item2.setText "no samples received" 
      end
    end
    object
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

      item, item2 = get_item(pair.name,pair.name, @root_item)
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
              update_item(attribute.read,item5)
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
              update_item(reader.read,item7)
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

  def set_task_attribute(item2)
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
