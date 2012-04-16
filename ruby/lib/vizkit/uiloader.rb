#!/usr/bin/env ruby

require 'Qt4'
require  File.join(File.dirname(__FILE__),'qt_bugfix')
require 'qtuitools'
require 'delegate'
require 'rexml/document'
require 'rexml/xpath'


#TODO
#Clean up the hole class
#       * create a widget info object for each widget
#       * attach the info object to all created widgets
#       * all informations like callback_fct, value class name, file etc
#       * are stored in the info object
#####

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
      attr_accessor :widget_value_map
      attr_accessor :control_value_map

      def current_loader_instance
          raise "No Uiloader. Call Vizkit.default_loader to create one!" if !@current_loader_instance
          @current_loader_instance
      end

      #interface for ruby extensions
      def register_widget_for(widget_name,value,callback_fct=nil,&block)
        current_loader_instance.register_widget_for(widget_name,value,callback_fct,&block)
      end
      def register_default_widget_for(widget_name,value,callback_fct=nil,&block)
        current_loader_instance.register_default_widget_for(widget_name,value,callback_fct,&block)
      end
      def register_control_for(widget_name,value,callback_fct=nil,&block)
        current_loader_instance.register_control_for(widget_name,value,callback_fct,&block)
      end
      def register_default_control_for(widget_name,value,callback_fct=nil,&block)
        current_loader_instance.register_default_control_for(widget_name,value,callback_fct,&block)
      end
      def register_ruby_widget(widget_name,widget_class)
        current_loader_instance.register_ruby_widget(widget_name,widget_class)
      end
      def extend_cplusplus_widget_class(class_name,&block)
        current_loader_instance.extend_cplusplus_widget_class(class_name,&block)
      end
      def register_3d_plugin(widget_name,lib_name,plugin_name)
        current_loader_instance.register_3d_plugin(widget_name,lib_name,plugin_name)
      end
      def register_3d_plugin_for(widget_name,type_name,display_method = nil,&filter)
        current_loader_instance.register_3d_plugin_for(widget_name,type_name,display_method,&filter)
      end
      def register_default_3d_plugin_for(widget_name,type_name,display_method = nil,&filter)
        current_loader_instance.register_default_3d_plugin_for(widget_name,type_name,display_method,&filter)
      end

      def define_control_for_methods(name,*klasses,&map)
        if klasses.last != :no_auto     #control widget can not be reached via control_for value if no_auto is set
          klasses.each do |klass|
            @control_name_for_fct_hash[klass] = "control_name_for_#{name}".to_sym
            @control_names_for_fct_hash[klass] = "control_names_for_#{name}".to_sym
            @control_value_map[klass] = map
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
            @widget_value_map[klass] = map
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
    UiLoader.widget_value_map = Hash.new

    UiLoader.control_name_for_fct_hash = Hash.new
    UiLoader.control_names_for_fct_hash = Hash.new
    UiLoader.control_value_map = Hash.new

    attr_reader :widget_for_hash
    attr_reader :cplusplus_extension_hash
    attr_reader :ruby_widget_hash
    # The set of widgets that are actually registered Vizkit3D plugins, as a set
    # of names
    attr_reader :vizkit3d_widgets
    # The file in which each widget has been registered, as a map from the
    # widget name to the file path
    attr_reader :registration_files
    attr_reader :created_widgets

    def initialize(parent = nil)
      super(Qt::UiLoader.new(parent))
      @widget_for_hash = Hash.new
      @default_widget_for_hash = Hash.new
      @control_for_hash = Hash.new
      @default_control_for_hash = Hash.new
      @ruby_widget_hash = Hash.new
      @cplusplus_extension_hash = Hash.new
      @callback_fct_hash = Hash.new
      @callback_fct_symbols_hash = Hash.new
      @callback_fct_filter_hash = Hash.new
      @control_callback_fct_hash = Hash.new
      @vizkit3d_widgets = Set.new
      @registration_files = Hash.new

      Orocos.load
      @created_widgets = Array.new

      load_extensions(File.join(File.dirname(__FILE__),"cplusplus_extensions"))
      load_extensions(File.join(File.dirname(__FILE__),"widgets"))

      paths = plugin_paths()
      paths.each do|path|
        if File.directory?(path)
          Vizkit.info "Load extension from #{path}"
          load_extensions(path)
        else
          Vizkit.info "No Directory! Cannot load extensions from #{path}."
        end
      end
      add_widget_accessor
    end

    def add_widget_accessor
      list = available_widgets
      list.each do |widget_name|
        if !respond_to?(widget_name.to_sym)
          (class << self;self;end).send(:define_method,widget_name)do|*parent|
            reuse = if parent.size >= 2
                      parent[1]
                    else
                      false
                    end
            create_widget(widget_name,parent.first,reuse)
          end
        end
      end
    end

    def create_widget(class_name,parent=nil,reuse=false)
      #check if there is already a widget of the same type
      #which can handle multiple values 
      if reuse
        widgets = @created_widgets.find_all do |widget| 
          if(widget.respond_to?(:ruby_widget?) && widget.ruby_widget?)
            widget.ruby_class_name == class_name
          else
            widget.class_name == class_name
          end
        end
        widgets.each do |widget|
            return widget if(widget.respond_to?(:multi_value?) && widget.multi_value?)
        end
      end

      klass = @ruby_widget_hash[class_name]
      #if ruby widget
      if klass
        widget = klass.call(parent)
        if widget.respond_to?(:loader) && !widget.loader.is_a?(UiLoader)
          raise "Cannot extend ruby widget #{class_name} because method :loader is alread defined"
        end
        widget.instance_variable_set(:@__loader__,self)
        widget.instance_variable_set(:@__ruby_class_name__,class_name)
        def widget.loader
          @__loader__
        end
        def widget.ruby_widget?
          true
        end
        #store ruby class name because all qt ruby objects or of
        #the same class 
        #we cannot overwirte the class name because 
        #qtruby does not like this 
        def widget.ruby_class_name
          @__ruby_class_name__
        end
      else 
        #look for c++ widget
        widget = super(class_name,parent)
        redefine_widget_class_name(widget,class_name)
        extend_widget widget if widget
      end
      @created_widgets << widget
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
      #check that all widgets are available 
      mapping.each_key do |k|
        if !form.respond_to?(k.to_s) && form.objectName != k
            Vizkit.warn "Widgte #{k} of class #{mapping[k]} could not be loaded! Is this Qt Designer Widget installed?"
        end
      end
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
      if class_name && (widget.class_name == "Qt::Widget" || widget.class_name == "Qt::MainWindow")
        widget.instance_variable_set(:@real_class_name,class_name)
        def widget.class_name;@real_class_name;end
        def widget.className;@real_class_name;end
      end
    end

    # This module is included in all Qt widgets to make sure that the basic
    # Vizkit API is available on them
    module VizkitCXXExtension
      # Called when a C++ widget is created to do some additional
      # ruby-side initialization
      def initialize_vizkit_extension
        super if defined? super
      end

      attr_accessor :loader
      def pretty_print(pp)
        loader.pretty_print_widget(pp, class_name)
      end
    end

    def extend_widget(widget,mapping = nil)
      redefine_widget_class_name(widget,mapping[widget.objectName]) if mapping
      class_name = widget.class_name
      raise "Cannot extend widget #{class_name} because method loader is alread defined" if widget.respond_to?(:loader)

      widget.extend VizkitCXXExtension
      if !ruby_widget? class_name
        if extension_module = @cplusplus_extension_hash[class_name]
          widget.extend extension_module
        end
      end

      widget.loader = self
      widget.initialize_vizkit_extension
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

    def created_widgets_for(value)
        names = widget_names_for value
        widgets = Array.new
        @created_widgets.each do |widget|
          if widget.respond_to? :ruby_class_name
            widgets << widget if names.include? widget.ruby_class_name
          else
            widgets << widget if names.include? widget.class_name
          end
        end
        widgets
    end

    def created_controls_for(value)
        names = control_names_for value
        controls = Array.new

        #TODO 
        #clean this up
        #at the moment controls and widgets are stored in the same array
        @created_widgets.each do |control|
          if control.respond_to? :ruby_class_name
            controls << control if names.include? control.ruby_class_name
          else
            controls << control if names.include? control.class_name
          end
        end
        controls
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

    def default_widget_name_for_value(value)
      return @default_widget_for_hash[value] if @default_widget_for_hash.has_key?(value)
      name = if(value.respond_to?(:superclass))
                default_widget_name_for_value(value.superclass)
             end
      return name if name
      if value.respond_to?(:to_str) && Orocos.registry.include?(value)
        default_widget_name_for_value(Orocos.registry.get(value))
      end
    end

    def widget_name_for_value(value)
      name = default_widget_name_for_value(value)
      return name if name

      names = widget_names_for_value(value)
      if names.size > 1
        raise "There are more than one widget available for #{value.to_s}: #{names.sort.join(", ")} "+ 
              "Call register_default_widget_for to define a default widget." 
      end
      names.first
    end

    def widget_names_for_value(value)
      array = @widget_for_hash[value]
      array ||= Array.new
      return array if !value

      if value.respond_to? :superclass
        array.concat(widget_names_for_value(value.superclass))
      end
      if value.respond_to?(:to_str) && Orocos.registry.include?(value)
        array.concat(widget_names_for_value(Orocos.registry.get(value)))
      end
      array
    end

    def widget_from_options(value,options = Hash.new)
      if options[:widget].is_a? String
        options[:widget] = create_widget(options[:widget],options[:parent],options[:reuse]) 
      end
      widget = if options[:widget]
                 options[:widget]
               else
                 if options[:widget_type] == :control
                   control_for(value,options[:parent],options[:reuse])
                 else
                   widget_for(value,options[:parent],options[:reuse])
                 end
               end
    end

    def widget_for(value,parent=nil,reuse=false)
      name = widget_name_for value
      create_widget(name, parent,reuse) if name
    end

    def widget_for_value(value,parent=nil,reuse=false)
      name = widget_name_for_value value
      create_widget(name, parent,reuse) if name
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

    def default_control_name_for_value(value)
      return @default_control_for_hash[value] if @default_control_for_hash.has_key?(value)
      name = if(value.respond_to?(:superclass))
                default_control_name_for_value(value.superclass)
             end
      return name if name
      if value.respond_to?(:to_str) && Orocos.registry.include?(value)
        default_control_name_for_value(Orocos.registry.get(value))
      end
    end

    def control_name_for_value(value)
      name = default_control_name_for_value(value)
      return name if name

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

      if value.respond_to? :superclass
        array.concat control_names_for_value(value.superclass)
      end
      if value.respond_to?(:to_str) && Orocos.registry.include?(value)
        array.concat(control_names_for_value(Orocos.registry.get(value)))
      end
      array
    end

    def control_for(value,parent=nil,reuse=false)
      name = control_name_for value
      create_widget(name, parent,reuse) if name
    end

    def control_for_value(value,parent=nil,reuse=false)
      name = control_name_for_value value
      create_widget(name, parent,reuse) if name
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
            begin 
                Kernel.load path if !path.match(/.ui.rb$/) && ::File.extname(path) ==".rb"
            rescue Exception => e
                Vizkit.warn "Cannot load vizkit extension #{path}"
                Vizkit.warn "Backtrace:\n############\n #{e.backtrace.join("\n")}\n############"
            end
        elsif ::File.directory?(path)
            load_extensions ::Dir.glob(::File.join(path,"**","*.rb"))
        else
            # Check if we can find the file in $LOAD_PATH and by adding .rb
            paths.each do |file|
                $LOAD_PATH.each do |path|
                    if File.file?(full_path = File.join(path, file))
                        load_extensions(full_path)
                        return
                    elsif File.file?(full_path = "#{full_path}.rb")
                        load_extensions(full_path)
                        return
                    end
                end
            end
            warn "Qt designer plugin file or directory does not exist: #{path.inspect}!"
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
    
    def available_callback_fcts(class_name)
        @callback_fct_symbols_hash[class_name]
    end
    
    def filter_for_callback_fct(callback_fct)
        @callback_fct_filter_hash[callback_fct]
    end

    def callback_fct(class_name,value)
        class_name = if class_name.is_a? Qt::Widget
                         class_name.class_name
                     else
                         class_name
                     end
        if @callback_fct_hash.has_key?(class_name)
            if @callback_fct_hash[class_name].has_key? value
                @callback_fct_hash[class_name][value]
            else
                if UiLoader.widget_value_map.has_key? value.class
                    result = UiLoader.widget_value_map[value.class].call value
                    @callback_fct_hash[class_name][result]
                end
            end
        end
    end

    def control_callback_fct(class_name,value)
        class_name = if class_name.is_a? Qt::Widget
                         class_name.class_name
                     else
                         class_name
                     end
        if @control_callback_fct_hash.has_key?(class_name)
            if @control_callback_fct_hash[class_name].has_key? value
                @control_callback_fct_hash[class_name][value]
            else
                if UiLoader.control_value_map.has_key? value.class
                    result = UiLoader.control_value_map[value.class].call value
                    @control_callback_fct_hash[class_name][result]
                end
            end
        end
    end

    def register_default_control_for(class_name,value,callback_fct=nil,&block)
      register_control_for(class_name,value,callback_fct,&block)
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

    def register_control_for(class_name,value,callback_fct=nil,&block)
      callback_fct = UiLoader.adapt_callback_block(callback_fct || block || :control)
      #check if widget is available
      if !widget? class_name
        raise ArgumentError, "#{class_name} is not the name of a known widget. Known widgets are #{available_widgets.sort.join(", ")}"
      end

      @registration_files[class_name] = find_registration_file
      register_control_callback_fct(class_name,value,callback_fct)
      @control_for_hash[value] ||= Array.new
      @control_for_hash[value] << class_name if !@control_for_hash[value].include?(class_name)
      self
    end

    def register_default_widget_for(class_name,value,callback_fct=nil,&block)
      register_widget_for(class_name,value,callback_fct,&block)
      @default_widget_for_hash[value] = class_name
      self
    end

    def register_callback_fct(class_name,value,callback_fct)
      @callback_fct_hash[class_name] ||= Hash.new
      @callback_fct_hash[class_name][value] = callback_fct
    end

    def register_control_callback_fct(class_name,value,callback_fct)
      @control_callback_fct_hash[class_name] ||= Hash.new
      @control_callback_fct_hash[class_name][value] = callback_fct
    end

    # If +typename+ is an opaque, returns the type that should be used to
    # manipulate it in typelib. In all other cases, returns nil.
    def find_typelib_type_for_opaque(typename)
      begin
          typekit = Orocos.load_typekit_for(typename, false)
          type = Orocos.registry.get(typename)
          intermediate = typekit.intermediate_type_for(typename)
          if typename != intermediate.name
              return intermediate
          end

      rescue ArgumentError
          # It's not a typelib type after all
      end
      nil
    end

    module Callbacks
        class MethodNameAdapter
            def initialize(sym)
                @sym = sym
            end

            def bind(object)
                object.method(@sym)
            end

            def call(*args, &block)
                obj = args.shift
                obj.send(@sym, *args, &block)
            end
        end

        class UnboundBlockAdapter
            def initialize(block)
                @block = block
            end
            def bind(object)
                BlockAdapter.new(@block, object)
            end
            def call(*args, &block)
                if block
                    args << block
                end
                @block.call(*args)
            end
        end

        class BlockAdapter
            def initialize(block, object)
                @block, @object = block, object
            end
            def call(*args, &block)
                if block
                    args << block
                end
                @block.call(@object, *args)
            end
        end
    end

    def self.adapt_callback_block(block)
        if block.respond_to?(:to_sym)
            block = Callbacks::MethodNameAdapter.new(block)
        elsif !block.kind_of?(Method)
            block = Callbacks::UnboundBlockAdapter.new(block)
        else
            block
        end
    end

    def register_widget_for(class_name,value,callback_fct=nil,&block)
      #check if widget is available
      if !widget? class_name
        raise ArgumentError, "#{class_name} is not the name of a known widget. Known widgets are #{available_widgets.sort.join(", ")}"
      end
      
      if value.respond_to?(:to_str)
          if typelib_type = find_typelib_type_for_opaque(value)
              register_widget_for(class_name, typelib_type.name, callback_fct, &block)
          end
      end
        
      if callback_fct && callback_fct.respond_to?(:to_sym)
        @callback_fct_symbols_hash[class_name] ||= Array.new
        @callback_fct_symbols_hash[class_name] << callback_fct if !@callback_fct_symbols_hash[class_name].include?(callback_fct)
        @callback_fct_filter_hash[callback_fct] = block if block
      end
        
      callback_fct = Vizkit::UiLoader.adapt_callback_block(callback_fct || block || :update)

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

    def register_3d_plugin(widget_name,lib_name,plugin_name)
      # This is used to share the plugin instance between the creation method
      # and the display method
      creation_method = lambda do |parent|
        Vizkit.ensure_orocos_initialized
        widget = Vizkit.vizkit3d_widget
        widget.show if widget.hidden?
        widget.createPlugin(lib_name, plugin_name)
      end
      register_ruby_widget(widget_name,creation_method)
      vizkit3d_widgets << widget_name
    end

    def extend_cplusplus_widget_class(class_name,&block)
      @cplusplus_extension_hash[class_name] = Module.new(&block)
      self
    end

    alias :register_3d_plugin_for :register_widget_for
    alias :register_default_3d_plugin_for :register_default_widget_for
    alias :createWidget :create_widget
    alias :availableWidgets :available_widgets
    alias :addPluginPath :add_plugin_path

    # Ruby 1.9.3's Delegate has a different behaviour than 1.8 and 1.9.2. This
    # is breaking the class definition, as some method calls gets undefined.
    #
    # Backward compatibility fix.
    def method_missing(*args, &block)
      __getobj__.send(*args, &block)
    end
  end
end

