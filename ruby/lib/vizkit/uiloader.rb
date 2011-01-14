#!/usr/bin/env ruby

require 'Qt4'
require  File.join(File.dirname(__FILE__),'qt_bugfix')
require 'qtuitools'
require 'delegate'
require 'rexml/document'
require 'rexml/xpath'

module Vizkit
  #because of the shadowed method load we have to use DelegateClass
  class UiLoader < DelegateClass(Qt::UiLoader)
    class << self
      attr_accessor :widget_name_for_fct_hash
      attr_accessor :widget_names_for_fct_hash
      attr_accessor :current_loader_instance

      #interface for ruby extensions
      def register_widget_for(widget_name,value,call_back_fcn=:update)
        @current_loader_instance.register_widget_for(widget_name,value,call_back_fcn)
      end
      def register_ruby_widget(widget_name,widget_class)
        @current_loader_instance.register_ruby_widget(widget_name,widget_class)
      end
      def extend_cplusplus_widget_class(class_name,&block)
        @current_loader_instance.extend_cplusplus_widget_class(class_name,&block)
      end

      def add_widget_for_methods(name,klass,&map)
        @widget_name_for_fct_hash[klass] = "widget_name_for_#{name}".to_sym
        @widget_names_for_fct_hash[klass] = "widget_names_for_#{name}".to_sym
        self.send(:define_method,"widget_for_#{name}") do|value,*parent|
          raise "Wrong type!" if value.class != klass
          widget_for_value map.call(value)
        end
        self.send(:define_method,"widget_name_for_#{name}")do|value|
          raise "Wrong type!" if value.class != klass
          name = widget_name_for_value map.call(value)
        end
         self.send(:define_method,"widget_names_for_#{name}") do|value|
          raise "Wrong type!" if value.class != klass
          name = widget_names_for_value map.call(value)
        end
      end
    end

    UiLoader.widget_name_for_fct_hash = Hash.new
    UiLoader.widget_names_for_fct_hash = Hash.new

    def initialize(parent = nil)
      super(Qt::UiLoader.new(parent))
      @widget_for_hash = Hash.new
      @default_widget_for_hash = Hash.new
      @ruby_widget_hash = Hash.new
      @cplusplus_extension_hash = Hash.new
      @call_back_fcn_hash = Hash.new

      load_cplusplus_extensions(File.join(File.dirname(__FILE__),"cplusplus_extensions"))

      paths = plugin_paths()
      paths.each do|path|
        load_cplusplus_extensions(path)
      end
      add_widget_accessor
    end

    def add_widget_accessor
      list = available_widgets
      list.each do |widget_name|
        if !respond_to?(widget_name.to_sym)
          (class << self;self;end).send(:define_method,widget_name)do|*parent|
            create_widget(widget_name,parent.first)
          end
        end
    end
end

    def create_widget(class_name,parent=nil)
      klass = @ruby_widget_hash[class_name]
      if klass
        widget = klass.new(parent) if klass
      else
        widget = super
        redefine_widget_class_name(widget,class_name)
      end
      extend_widget widget if widget
      widget
    end

    def load(ui_file,parent=nil)
      file = Qt::File.new(ui_file)
      file.open(Qt::File::ReadOnly)
      form = __getobj__.load(file,parent)
      mapping = map_objectName_className(ui_file)
      extend_all_widgets form,mapping if form
      form
    end

    #work around
    #metaObject.className is always QWidget for qt4-ruby1.8 4.4.5
    #therefore we have to pass the ui file to get the mapping
    #this error disappears on newer versions
    def map_objectName_className(ui_file)
      doc = REXML::Document.new File.new ui_file
      mapping = Hash.new
      REXML::XPath.each( doc, "//widget")do |ele|
        mapping[ele.attributes["name"]] = ele.attributes["class"]
      end
      mapping
    end

    def redefine_widget_class_name(widget,class_name)
      if class_name && widget.class_name == "Qt::Widget"
        widget.instance_variable_set(:@real_class_name,class_name)
        def widget.class_name;@real_class_name;end
        def widget.className;@real_class_name;end
      end
    end

    def extend_widget(widget,mapping = nil)
      redefine_widget_class_name(widget,mapping[widget.objectName]) if mapping
      class_name = widget.class_name
      if !ruby_widget? class_name
        extension_module = @cplusplus_extension_hash[class_name]
        widget.send(:extend,extension_module) if extension_module
      end
      raise "Cannot extend widget #{class_name} because method loader is alread defined" if widget.respond_to?(:loader)
      widget.instance_variable_set(:@__loader__,self)
      def widget.loader
        @__loader__
      end
      widget
    end

    def extend_all_widgets(widget,mapping = nil)
      extend_widget(widget,mapping)

      #extend childs and add accessor for QObject
      #find will find children recursive 
      #objectNames are unique for widgets therefore we can put them to the toplevel
      #warning: ruby objects have the wrong parent
      children = widget.findChildren(Qt::Object)
      children.each do |child|
          if child.objectName
            extend_widget child, mapping
            (class << widget; self;end).send(:define_method,child.objectName){child}
          end
      end
      widget
    end

    def widget_name_for(value)
      fct = UiLoader.widget_name_for_fct_hash[value.class]
      if fct
        method(fct).call(value)
      else
        widget_name_for_value(value)
      end
    end

    def widget_names_for(value)
      fct = UiLoader.widget_names_for_fct_hash[value.class]
      if fct
        method(fct).call(value)
      else
        widget_names_for_value(value)
      end
    end  
    
    def widget_name_for_value(value)
      return @default_widget_for_hash[value] if @default_widget_for_hash.has_key?(value)
      names = widget_names_for_value(value)
      if names.size > 1
        raise "There are more than one widget available for #{value.to_s}. "+ 
              "Call register_default_widget_for to define a default widget." 
      end
      names.first if names.size == 1
    end

    def widget_names_for_value(value)
      array = @widget_for_hash[value]
      array || Array.new
    end

    def widget_for(value,parent=nil)
      name = widget_name_for value
      create_widget(name, parent) if name
    end

    def widget_for_value(value,parent=nil)
      name = widget_name_for_value value
      create_widget(name, parent) if name
    end

    def add_plugin_path(path)
      super
      load_cplusplus_extensions(path)
      add_widget_accessor
    end

    def load_cplusplus_extensions(*paths)
      paths.flatten!
      paths.each do |path|
        if ::File.file?(path) 
            UiLoader.current_loader_instance = self
            Kernel.load path if !path.match(/.ui.rb$/) && ::File.extname(path) ==".rb"
        else
          if ::File.exist?(path)
            load_cplusplus_extensions ::Dir.glob(::File.join(path,"**","*.rb"))
          else
            raise "File does not exist: #{path.inspect}!"
          end
        end
      end
    end

    def available_widgets
      super + @ruby_widget_hash.keys
    end

    def widget?(class_name)
      available_widgets.include?(class_name)
    end

    def ruby_widget?(class_name)
      @ruby_widget_hash.has_key? class_name
    end

    def cplusplus_widget?(class_name)
      available_widgets.include? class_name && !ruby_widget?(class_name)
    end

    def call_back_fct(class_name,value)
      @call_back_fcn_hash[class_name][value ]if @call_back_fcn_hash.has_key?(class_name)
    end

    def register_default_widget_for(class_name,value,call_back_fcn=:update)
      register_widget_for(class_name,value,call_back_fcn)
      @default_widget_for_hash[value] = class_name
      self
    end

    def register_widget_for(class_name,value,call_back_fcn=:update)
      #check if widget is available
      if !widget? class_name
        puts "Widget #{class_name} is unknown to the loader. Cannot extend it!" 
        return nil
      end
      @call_back_fcn_hash[class_name] ||= Hash.new
      @call_back_fcn_hash[class_name][value] = call_back_fcn

      @widget_for_hash[value] ||= Array.new
      @widget_for_hash[value] << class_name if !@widget_for_hash[value].include?(class_name)
      self
    end

    def register_ruby_widget(class_name,widget_class)
      @ruby_widget_hash[class_name] = widget_class
      self
    end

    def extend_cplusplus_widget_class(class_name,&block)
      @cplusplus_extension_hash[class_name] = Module.new(&block)
      self
    end

    alias :createWidget :create_widget
    alias :availableWidgets :available_widgets
    alias :addPluginPath :add_plugin_path
  end
end

