#!/usr/bin/env ruby

class TaskInspector < Qt::Widget
  slots 'refresh()','set_task_attribute(const QModelIndex&)'
  attr_reader :multi  #widget supports displaying of multi tasks
  PropertyConfig = Struct.new(:name, :attribute, :type)

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
    @mapping = Hash.new
    @tasks = Hash.new
    @multi = true

    connect(@tree_model, SIGNAL('dataChanged(const QModelIndex&,const QModelIndex&)'),self,SLOT('set_task_attribute(const QModelIndex&)'))
    
    @timer = Qt::Timer.new(self)
    connect(@timer,SIGNAL('timeout()'),self,SLOT('refresh()'))
  end

  def default_options()
    options = Hash.new
    options[:interval] = 1000   #update interval in msec
    return options
  end

  def config(task,options=Hash.new)
    @tasks[task.name] = task if !@tasks.has_key?(task.name)
    options = default_options.merge(options)
    @timer.start(options[:interval])
  end

  def get_item(key,name,root_item)
    if @hash.has_key?(key)
       item =  @hash[key]
       item2 = root_item.child(item.row,1)
    else
      item = Qt::StandardItem.new(name)
      item.setEditable(false)
      @hash[key]=item
      root_item.appendRow(item)
      item2 = Qt::StandardItem.new
      item2.setEditable(false)
      root_item.setChild(item.row,1,item2)
    end
    return [item,item2]
  end

  def refresh()
    @tasks.each_value do |task|
      item, item2 = get_item(task.name,task.name, @root_item)
      item2.setText(task.state.to_s) 
      #setting attributes
      key = task.name + "__ATTRIBUTES__"
      item3, item4 = get_item(key,"Attributes", item)
      task.each_attribute do |attribute|
        key = task.name+"_"+ attribute.name
        item5, item6 = get_item(key,attribute.name, item3)
        item6.setText(attribute.read.to_s)
        if attribute.read.is_a?(String)||attribute.read.is_a?(Float)||attribute.read.is_a?(Fixnum)
          if !@mapping.has_key?(item6)
            @mapping[item6] = PropertyConfig.new(key,attribute,attribute.read.class)
            item6.setEditable(true)
          end
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
        end
        item8.setText(port.type_name.to_s)
      end
    end

    @window.treeView.resizeColumnToContents(0)
  end
  
  def set_task_attribute(pos)
    item = @tree_model.itemFromIndex(pos)
    return if !@mapping.has_key?(item)
    obj = @mapping[item]
    if obj.type == String
      obj.attribute.write(item.text)
    elsif obj.type == Fixnum
      obj.attribute.write(item.text.to_i)
    elsif obj.type == Float
      obj.attribute.write(item.text.to_i)
    else
      puts "task_inspector::set_task_attribute() not implemented for " + obj.type.to_s
    end
  end
  
end

Vizkit::UiLoader.register_ruby_widget("task_inspector",TaskInspector.method(:new))
