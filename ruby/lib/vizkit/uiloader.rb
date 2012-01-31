#!/usr/bin/env ruby

require 'Qt4'
require  File.join(File.dirname(__FILE__),'qt_bugfix')
require 'qtuitools'
require 'delegate'
require 'rexml/document'
require 'rexml/xpath'

class Module
  # Shortcut to define the necessary methods so that a module can be used to
  # "subclass" a Qt widget
  #
  # This is done with
  #
  #   require 'vizkit'
  #   module MapView
  #     vizkit_subclass_of 'ImageView'
  #   end
  #   Vizkit::UILoader.register_ruby_widget 'MapView', MapView.method(:new)
  #
  # If some initial configuration is needed, one should define the 'setup'
  # singleton method:
  #
  #   module MapView
  #     vizkit_subclass_of 'ImageView'
  #     def self.setup(obj)
  #       obj.setAspectRatio(true)
  #     end
  #   end
  #
  def vizkit_subclass_of(class_name)
    class_eval do
      def self.new
        widget = Vizkit.default_loader.send(class_name)
        widget.extend self
        widget
      end
      def self.extended(obj)
        if respond_to?(:setup)
          setup(obj)
        end
      end
    end
  end
end


module Vizkit
  #because of the shadowed method load we have to use DelegateClass
  class UiLoader < DelegateClass(Qt::UiLoader)
    class << self
      attr_accessor :widget_name_for_fct_hash
      attr_accessor :widget_names_for_fct_hash
      attr_accessor :control_name_for_fct_hash
      attr_accessor :control_names_for_fct_hash
      attr_accessor :current_loader_instance

      #interface for ruby extensions
      def register_widget_for(widget_name,value,callback_fct=:update)
        @current_loader_instance.register_widget_for(widget_name,value,callback_fct)
      end
      def register_default_widget_for(widget_name,value,callback_fct=:update)
        @current_loader_instance.register_default_widget_for(widget_name,value,callback_fct)
      end
      def register_control_for(widget_name,value,callback_fct=:control)
        @current_loader_instance.register_control_for(widget_name,value,callback_fct)
      end
      def register_default_control_for(widget_name,value,callback_fct=:control)
        @current_loader_instance.register_default_control_for(widget_name,value,callback_fct)
      end
      def register_ruby_widget(widget_name,widget_class)
        @current_loader_instance.register_ruby_widget(widget_name,widget_class)
      end
      def extend_cplusplus_widget_class(class_name,&block)
        @current_loader_instance.extend_cplusplus_widget_class(class_name,&block)
      end
      def register_3d_plugin(widget_name,lib_name,plugin_name)
        # This is used to share the plugin instance between the creation method
        # and the display method
        creation_method = lambda do |parent|
          if !Orocos.initialized?
            Orocos.initialize
          end
          widget = Vizkit.vizkit3d_widget
          widget.plugins[widget_name] = widget.createPlugin(lib_name, plugin_name)
          widget
        end
        register_ruby_widget(widget_name,creation_method)
      end
      def register_3d_plugin_for(widget_name,type_name,display_method = nil,&filter)
        @current_loader_instance.register_callback_fct('vizkit::Vizkit3DWidget',type_name,:update)
        VizkitPluginLoaderExtension.type_to_widget_name[type_name] = [widget_name,display_method,filter]
        register_widget_for(widget_name,type_name,"not_used")
      end
      def register_default_3d_plugin_for(widget_name,type_name,display_method = nil,&filter)
        @current_loader_instance.register_callback_fct('vizkit::Vizkit3DWidget',type_name,:update)
        VizkitPluginLoaderExtension.type_to_widget_name[type_name] = [widget_name,display_method,filter]
        register_default_widget_for(widget_name,type_name,"not_used")
      end

      def define_control_for_methods(name,*klasses,&map)
        if klasses.last != :no_auto     #control widget can not be reached via control_for value if no_auto is set
          klasses.each do |klass|
            @control_name_for_fct_hash[klass] = "control_name_for_#{name}".to_sym
            @control_names_for_fct_hash[klass] = "control_names_for_#{name}".to_sym
          end
        end
        self.send(:define_method,"control_for_#{name}") do|value,*parent|
          control_for_value map.call(value)
        end
        self.send(:define_method,"control_name_for_#{name}")do|value|
          raise "Wrong type!" if !klasses.include? value.class
          name = control_name_for_value map.call(value)
        end
         self.send(:define_method,"control_names_for_#{name}") do|value|
          raise "Wrong type!" if !klasses.include? value.class
          name = control_names_for_value map.call(value)
        end
      end

      def define_widget_for_methods(name,*klasses,&map)
        if klasses.last != :no_auto     #widget can not be reached via widget_for value if no_auto is set
          klasses.each do |klass|
            @widget_name_for_fct_hash[klass] = "widget_name_for_#{name}".to_sym
            @widget_names_for_fct_hash[klass] = "widget_names_for_#{name}".to_sym
          end
        end
        self.send(:define_method,"widget_for_#{name}") do|value,*parent|
          raise "Wrong type!" if !klasses.include? value.class
          widget_for_value map.call(value)
        end
        self.send(:define_method,"widget_name_for_#{name}")do|value|
          raise "Wrong type!" if !klasses.include? value.class
          name = widget_name_for_value map.call(value)
        end
         self.send(:define_method,"widget_names_for_#{name}") do|value|
          raise "Wrong type!" if !klasses.include? value.class
          name = widget_names_for_value map.call(value)
        end
      end
    end

    UiLoader.widget_name_for_fct_hash = Hash.new
    UiLoader.widget_names_for_fct_hash = Hash.new

    UiLoader.control_name_for_fct_hash = Hash.new
    UiLoader.control_names_for_fct_hash = Hash.new

    attr_reader :widget_for_hash
    attr_reader :cplusplus_extension_hash
    attr_reader :ruby_widget_hash
    # The file in which each widget has been registered, as a map from the
    # widget name to the file path
    attr_reader :registration_files

    def initialize(parent = nil)
      super(Qt::UiLoader.new(parent))
      @widget_for_hash = Hash.new
      @default_widget_for_hash = Hash.new
      @control_for_hash = Hash.new
      @default_control_for_hash = Hash.new
      @ruby_widget_hash = Hash.new
      @cplusplus_extension_hash = Hash.new
      @callback_fct_hash = Hash.new
      @control_callback_fct_hash = Hash.new
      @registration_files = Hash.new

      Orocos.load

      load_extensions(File.join(File.dirname(__FILE__),"cplusplus_extensions"))
      load_extensions(File.join(File.dirname(__FILE__),"widgets"))

      paths = plugin_paths()
      paths.each do|path|
        load_extensions(path)
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
      #if ruby widget
      if klass
        widget = klass.call(parent)
        if widget.respond_to?(:loader) && !widget.loader.is_a?(UiLoader)
          raise "Cannot extend ruby widget #{class_name} because method :loader is alread defined"
        end
        widget.instance_variable_set(:@__loader__,self)
        def widget.loader
          @__loader__
        end
      else 
        #look for c++ widget
        widget = super
        redefine_widget_class_name(widget,class_name)
        extend_widget widget if widget
      end
      widget
    end

    def load(ui_file,parent=nil)
      file = Qt::File.new(ui_file)
      file.open(Qt::File::ReadOnly)

      #for getting relative images 
      form = nil
      Dir.chdir File.dirname(ui_file) do 
        form = __getobj__.load(file,parent)
      end
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
      if class_name && (widget.class_name == "Qt::Widget" || "Qt::MainWindow")
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

      def widget.pretty_print(pp)
        loader.pretty_print_widget(pp,class_name)
      end
      widget
    end

    def pretty_print_widget(pp,widget_name)
      extension = cplusplus_extension_hash[widget_name]
      ruby_widget_new = ruby_widget_hash[widget_name]
      pp.text "=========================================================="
      pp.breakable
      pp.text "Widget name: #{widget_name}"
      pp.breakable
      if !ruby_widget_new
        pp.text "C++ Widget"
      else
        pp.text "Ruby Widget"
      end
      pp.breakable
      registered_for(widget_name).each do |val|
        pp.text "registerd for: #{val}"
        pp.breakable
      end
      pp.text "----------------------------------------------------------"
      pp.breakable

      if extension 
        pp.breakable
        extension.instance_methods.each do |method|
          pp.text "added ruby method: #{method.to_s}"
          pp.text "(#{extension.instance_method(method).arity} parameter)"
          pp.breakable
        end
      else
        if !ruby_widget_new
          pp.text "no ruby extension"
          pp.breakable
        else
          methods = Qt::Widget.instance_methods
          klass = ruby_widget_new.call.class
          klass.instance_methods.each do |method|
            if !methods.include? method
              pp.text "ruby method: #{method.to_s}"
              pp.text "(#{klass.instance_method(method).arity} parameter)"
              pp.breakable
            end
          end
        end
      end
    end

    def registered_for(widget)
      widget = widget.class_name if widget.is_a? Qt::Widget
      val = Array.new
      @widget_for_hash.each_pair do |key,value|
        val << key if value == widget  || (value.is_a?(Array) && value.include?(widget))
      end
      val
    end

    def extend_all_widgets(widget,mapping = nil)
      extend_widget(widget,mapping)

      #extend childs and add accessor for QObject
      #find will find children recursive 
      #objectNames are unique for widgets if the ui file was 
      #generated with the qt designer therefore we can put them to the toplevel
      #warning: ruby objects have the wrong parent
      children = widget.findChildren(Qt::Object)
      children.each do |child|
          if child.objectName && child.objectName.size > 0
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
      array ||= Array.new
    end

    def widget_for(value,parent=nil)
      name = widget_name_for value
      create_widget(name, parent) if name
    end

    def widget_for_value(value,parent=nil)
      name = widget_name_for_value value
      create_widget(name, parent) if name
    end

    def control_name_for(value)
      fct = UiLoader.control_name_for_fct_hash[value.class]
      if fct
        method(fct).call(value)
      else
        control_name_for_value(value)
      end
    end

    def control_names_for(value)
      fct = UiLoader.control_names_for_fct_hash[value.class]
      if fct
        method(fct).call(value)
      else
        control_names_for_value(value)
      end
    end  
    
    def control_name_for_value(value)
      return @default_control_for_hash[value] if @default_widget_for_hash.has_key?(value)
      names = control_names_for_value(value)
      if names.size > 1
        raise "There are more than one control available for #{value.to_s}. "+ 
              "Call register_default_control_for to define a default widget." 
      end
      names.first if names.size == 1
    end

    def control_names_for_value(value)
      array = @control_for_hash[value]
      array ||= Array.new
    end

    def control_for(value,parent=nil)
      name = control_name_for value
      create_widget(name, parent) if name
    end

    def control_for_value(value,parent=nil)
      name = control_name_for_value value
      create_widget(name, parent) if name
    end

    def add_plugin_path(path)
      super
      load_extensions(path)
      add_widget_accessor
    end

    def load_extensions(*paths)
      paths.flatten!
      paths.each do |path|
        if ::File.file?(path) 
            UiLoader.current_loader_instance = self
            Kernel.load path if !path.match(/.ui.rb$/) && ::File.extname(path) ==".rb"
        else
          if ::File.exist?(path)
            load_extensions ::Dir.glob(::File.join(path,"**","*.rb"))
          else
            warn "Qt designer plugin file or directory does not exist: #{path.inspect}!"
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

    def callback_fct(class_name,value)
      @callback_fct_hash[class_name][value ]if @callback_fct_hash.has_key?(class_name)
    end
    def control_callback_fct(class_name,value)
      @control_callback_fct_hash[class_name][value ]if @control_callback_fct_hash.has_key?(class_name)
    end

    def register_default_control_for(class_name,value,callback_fct=:control)
      register_control_for(class_name,value,callback_fct)
      @default_control_for_hash[value] = class_name
      self
    end

    def find_registration_file
        backtrace = caller
        line = backtrace.find do |line|
            line !~ /register/
        end
        if line
            line.gsub(/:\d+.*/, '')
        end
    end

    def register_control_for(class_name,value,callback_fct=:control)
      #check if widget is available
      if !widget? class_name
        return nil
      end

      @registration_files[class_name] = find_registration_file
      register_control_callback_fct(class_name,value,callback_fct)
      @control_for_hash[value] ||= Array.new
      @control_for_hash[value] << class_name if !@control_for_hash[value].include?(class_name)
      self
    end

    def register_default_widget_for(class_name,value,callback_fct=:update)
      register_widget_for(class_name,value,callback_fct)
      @default_widget_for_hash[value] = class_name
      self
    end

    def register_callback_fct(class_name,value,callback_fct=:update)
      @callback_fct_hash[class_name] ||= Hash.new
      @callback_fct_hash[class_name][value] = callback_fct
    end

    def register_control_callback_fct(class_name,value,callback_fct=:update)
      @control_callback_fct_hash[class_name] ||= Hash.new
      @control_callback_fct_hash[class_name][value] = callback_fct
    end

    def register_widget_for(class_name,value,callback_fct=:update)
      #check if widget is available
      if !widget? class_name
 #       puts "Widget #{class_name} is unknown to the loader. Cannot extend it!" 
        return nil
      end

      if value.respond_to?(:to_str)
          begin
              typekit = Orocos.load_typekit_for(value, false)
              type = Orocos.registry.get(value)
              intermediate = typekit.intermediate_type_for(value)
              if value != intermediate.name
                  register_widget_for(class_name, intermediate.name, callback_fct)
              end

          rescue ArgumentError
              # It's not a typelib type after all
          end
      end

      register_callback_fct(class_name,value,callback_fct)
      @registration_files[class_name] = find_registration_file
      @widget_for_hash[value] ||= Array.new
      @widget_for_hash[value] << class_name if !@widget_for_hash[value].include?(class_name)
      self
    end

    def register_ruby_widget(class_name,widget_class)
      @ruby_widget_hash[class_name] = widget_class
      add_widget_accessor
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

