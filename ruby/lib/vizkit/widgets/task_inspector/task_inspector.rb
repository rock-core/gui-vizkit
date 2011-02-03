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

  def add_object(object, parent_item)
    if object.is_a?(Orocos::Property)
	object = object.read
    end
    if object.is_a?(Orocos::OutputPort)
	object = nil #object.read # not now crashed sometimes
    end

    if object.kind_of?(Typelib::CompoundType)
      row = 0;
      object.each_field do |name,value|
        item, item2 = StructViewer.child_items(parent_item,row)
	item.setEditable(false)
        item.setText name
        item2.setText value.class.name
        add_object(value,item)
        # item.setBackground(@brush)
        # item2.setBackground(@brush)
        row += 1
      end
      #delete all other rows
      parent_item.removeRows(row,parent_item.rowCount-row) if row < parent_item.rowCount

    elsif object.is_a?(Array) || (object.kind_of?(Typelib::Type) && object.respond_to?(:each) )
      if object.size > MAX_ARRAY_FIELDS
        item2 = parent_item.parent.child(parent_item.row,parent_item.column+1)
        item2.setText "#{object.size} fields ..."
      else
        row = 0
        object.each_with_index do |val,row|
          item,item2 = StructViewer.child_items(parent_item,row)
	  item.setEditable(false)
          item2.setText val.class.name
          item.setText "[#{row}]"
          add_object val,item
        end
        #delete all other rows
        row += 1
        parent_item.removeRows(row,parent_item.rowCount-row) if row < parent_item.rowCount
      end
    else
      item2 = parent_item.parent.child(parent_item.row,parent_item.column+1)
      item2.setText(object.to_s)
      end
  end


  def refresh()
    @tasks.each_value do |task|
      item, item2 = get_item(task.name,task.name, @root_item)
      item2.setText(task.state.to_s) 
      #setting attributes
      key = task.name + "__ATTRIBUTES__"
      item3, item4 = get_item(key,"Attributes", item)
      
      #setChild(item.row,1,item2)
      task.each_property do |attribute|
      name = attribute.name
      if !@hash.has_key?(name)
	      itemm = Qt::StandardItem.new(name)
	      itemm.setEditable(false)
	      itemm2 = Qt::StandardItem.new
	      #itemm2.setText(attribute.class.to_s.match('/(.*)>$')[1])
	      itemm2.setText(attribute.name)
	      itemm2.setEditable(true)
	      @hash[name]=itemm
	      @mapping[itemm] = PropertyConfig.new(name,attribute,attribute.read.class)
	      item3.appendRow(itemm)
	      item3.setChild(itemm.row,1,itemm2)
	      add_object(attribute,itemm)
      end
      end
#        key = task.name+"_"+ attribute.name
#        item5, item6 = get_item(key,attribute.name, item3)
#        item6.setText(attribute.read.to_s)
#        if attribute.read.is_a?(String)||attribute.read.is_a?(Float)||attribute.read.is_a?(Fixnum)
#          if !@mapping.has_key?(item6)
#            @mapping[item6] = PropertyConfig.new(key,attribute,attribute.read.class)
#            item6.setEditable(true)
#          end
#        end

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
	  name = port.name.to_s
          if !@hash.has_key?(name)
	    itemm = Qt::StandardItem.new(name)
            itemm2 = Qt::StandardItem.new
            #itemm2.setText(attribute.class.to_s.match('/(.*)>$')[1])
            itemm2.setText(name)
            @hash[name]=itemm
            item5.appendRow(itemm)
            item5.setChild(itemm.row,1,itemm2)
            add_object(port,itemm)
            #item7, item8 = get_item(key,port.name, item5)
          else
            itemm = @hash[name]
            add_object(port,itemm)
          end
        end
        #item8.setText(port.type_name.to_s)
      end
    end

    @window.treeView.resizeColumnToContents(0)
  end
  
  def set_task_attribute(pos)
    #pp "somethig changed at pos #{pos}"
    item = @tree_model.itemFromIndex(pos)
    value = item.text
    #pp @mapping
    #pp "somethig changed at pos #{pos} on item #{item}"
    #pp item.name
    #pp pos
    
    obj = nil
    original_item = item
    #pp "Position #{pos.row} #{pos.column}"
    parent = item.parent
    left_object = nil
    if !parent.nil?
      left_object = parent.child(item.row,0)
    end
    name = ''
    first=true
    if !left_object.nil? 
      #name = left_object.text
      item = left_object
      first=false
    end

    while obj.nil? && !item.nil? do
	if @mapping.has_key?(item)
	  obj = @mapping[item]
        else 
          if !first
            name = "#{item.text}.#{name}"
            first=false
          else
	    name = item.text
	  end
	  item = item.parent
        end
    end
    if name.to_s.end_with?('.')
      name = name.to_s.chop
    end
    
      
    if name == "StructViewer"
    	return
    end

    if obj.nil?
#      STDERR.puts ""
#      STDERR.puts "Cannot find correct object for mapping:"
#      pp @mapping
#      STDERR.puts "------------original item is:-------"
#      pp original_item
#      STDERR.puts "------------------end--------------"

      #pp "We should set #{name} to #{value}"
      return 
    end
    #pp "We have Object: "
    #pp "We should set #{name} to #{value} "

    #name.to_sym
    data = obj.attribute.read
    #pp "Weve got data: #{data}"

    begin
    #  pp "hall"

    type = nil
    if(name.empty?)
      type = data.class
    else
      f = data
      name.split(".").each do |s|
        f = f.send(s)
      end
      type = f.class
    end


    if type == String
      if name.empty?
      	data = value
      else
      	eval "data.#{name} = value"
      end
      obj.attribute.write(data)
    elsif type == Fixnum
      if name.empty?
        data = value.to_i
      else
      	eval "data.#{name} = value.to_i"
      end
      pp "writing fixednum"
      obj.attribute.write(data)
    elsif type == Float
      if name.empty?
        data = value.to_i
      else
        eval "data.#{name} = value.to_i"
      end
      obj.attribute.write(data)
    elsif type == TrueClass || type == FalseClass 
      if value == "true" || value == "1"
        if name.empty?
	  data = true
	else
          eval "data.#{name} = true"
	end
	obj.attribute.write(data)
      elsif value == "false" || value == "0"
        if name.empty?
	  data = false
	else
          eval "data.#{name} = false"
	end
	obj.attribute.write(data)
      else
        STDERR.puts "Unknown Value #{value} for Boolean skipping"
      end
    else
      #pp "----name ----"
      #pp name
      #pp "---object----"
      #pp obj
      #pp "---obj.attribue---"
      #pp obj.attribute
      #pp "---end---"
      puts "task_inspector::set_task_attribute() not implemented for " + type.name
      #pp data.send(name)
    end

    rescue Exception => e
      STDERR.puts "Error #{e}"
      #pp e.backtrace
    end
  end
  
end

Vizkit::UiLoader.register_ruby_widget("task_inspector",TaskInspector.method(:new))
