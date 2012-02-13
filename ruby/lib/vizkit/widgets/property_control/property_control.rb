#!/usr/bin/env ruby

class PropertyControl < Qt::Widget
  slots 'val_changed(QString)','editing_finished(QString)','refresh_values()'

  def initialize(parent=nil)
    super

    @PropertyConfig = Struct.new(:name, :attribute, :type, :gui_object)
    @gridLayout = Qt::GridLayout.new(self)
    @gridLayout.objectName = "gridLayout"
    @hash = Hash.new
    @number_of_gui_objects = 0
    @timer_id = nil
    @timer = Qt::Timer.new(self)

    @signal_mapper_slider = Qt::SignalMapper.new(self)
    @signal_mapper_line_edit = Qt::SignalMapper.new(self)

    @signal_mapper_slider.connect(SIGNAL('mapped(const QString&)'),self,:val_changed)
    @timer.connect(SIGNAL('timeout()'),self,:refresh_values)
    @signal_mapper_line_edit.connect(SIGNAL('mapped(const QString&)'),self,:editing_finished)
    setWindowTitle("Property Control")
    resize(500,200)
  end

  def set_attributes(gui_object,options)
    gui_object.setMaximum(options[:max]) if options.has_key?(:max)
    gui_object.setMinimum(options[:min]) if options.has_key?(:min)
    gui_object.setSingleStep(options[:step]) if options.has_key?(:step)
  end

  def refresh_values()
    @hash.each_value do |pair|
      if pair.type == Float || pair.type == Fixnum
        pair.gui_object.value = pair.attribute.read
      elsif pair.type == String
        pair.gui_object.text = pair.attribute.read if !pair.gui_object.hasFocus
      end
    end
  end
  
  def control(task,options = Hash.new)
    raise 'PropertyControl:Config: Paramter task was not given!' if task == nil
    options = default_options.merge(options)
    
    #add all properties if no one is specified
    if !options.has_key?(:property)
      puts task
      task.each_property do |property|
        add_property(task,property,options)
      end
    else
      name = options[:property]
      raise "Task #{task.name} has no property called #{name}" if !task.has_property?(name)
      add_property(task,task.property(name),options)
    end

    refresh_values()
    @timer_id = @timer.start(options[:interval]) if !@timer_id
  end

  def add_property(task,attribute,options)
    name = task.name + '.' + attribute.name
    type = attribute.read.class
    
    @number_of_gui_objects += 1

    label = Qt::Label.new(self)
    label.Text = attribute.name
    @gridLayout.addWidget(label, @number_of_gui_objects,1, 1, 1)

    if attribute.read.is_a?(Fixnum)||attribute.read.is_a?(Float)
      gui_object = Qt::Slider.new(self)
      gui_object.orientation = Qt::Horizontal
      @gridLayout.addWidget(gui_object, @number_of_gui_objects,2, 1, 1)
      @signal_mapper_slider.setMapping(gui_object,name)
      connect(gui_object,SIGNAL('valueChanged(int)'),@signal_mapper_slider,SLOT('map()'))
    
      spin_box = attribute.read.is_a?(Fixnum) ? Qt::SpinBox.new(self) : Qt::DoubleSpinBox.new(self)
      @gridLayout.addWidget(spin_box, @number_of_gui_objects,3, 1, 1)
      connect(spin_box,SIGNAL('valueChanged(int)'),gui_object,SLOT('setValue(int)'))
      connect(gui_object,SIGNAL('valueChanged(int)'),spin_box,SLOT('setValue(int)'))

      set_attributes(gui_object,options)
      set_attributes(spin_box,options)

      gui_object.value = attribute.read
      @hash[name] = @PropertyConfig.new(name,attribute,type,gui_object)
    elsif attribute.read.is_a?(String)
      gui_object = Qt::LineEdit.new(self)
      gui_object.text = attribute.read
      @gridLayout.addWidget(gui_object, @number_of_gui_objects,2, 1, 1)
      @signal_mapper_line_edit.setMapping(gui_object,name)
      connect(gui_object,SIGNAL('editingFinished()'),@signal_mapper_line_edit,SLOT('map()'))
      @hash[name] = @PropertyConfig.new(name,attribute,type,gui_object)
    end
  end

  def default_options
    options = Hash.new
    options[:interval] = 1000
    return options
  end

  def val_changed(name)
    return if !@hash.has_key?(name)
    obj = @hash[name]
    obj.attribute.write(obj.gui_object.value)
  end
  
  def editing_finished(name)
    return if !@hash.has_key?(name)
    obj = @hash[name]
    obj.attribute.write(obj.gui_object.text)
  end
  
end

Vizkit::UiLoader.register_ruby_widget("property_control",PropertyControl.method(:new))
