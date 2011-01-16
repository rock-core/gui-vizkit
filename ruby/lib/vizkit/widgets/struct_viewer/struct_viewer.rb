#!/usr/bin/env ruby

require File.join(File.dirname(__FILE__),'struct_viewer_window.ui')

class DefaultDecoder
  #decoder for /base/samples/frame/Frame image
  def _base_samples_frame_Frame_image(data)
    return "Image data size = " + data.image.size.to_s
  end

  #decoder for /base/samples/frame/Frame field attribute
  def _base_samples_frame_Frame_attributes(data)
    text = String.new
    data.attributes.to_a.each do |element| 
      text += "#{element.name_}=#{element.data_}; "
    end
    return text
  end

  #decoder for /can/Messages field data
  def _can_Message_data(data)
    text = String.new("hex: ")
    data.data.to_a[0..data.size-1].each do |c|
      text << c.to_s(16)
      text << " " 
    end
    return text
  end
end

class StructViewer < Qt::Widget
  attr_accessor :decoder
  def initialize(parent=nil)
    super
    @decoder = DefaultDecoder.new
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
    @act_data = nil
  end

  def update(data, port_name)
     @act_data_type = data.class.name
     @act_data = data
     name = port_name
     if @hash.has_key?(name)
      item = @hash[name]
      add_compound_type(data,item,name)
     else
      item = Qt::StandardItem.new(name)
      item.setBackground(@brush)
      item2 = Qt::StandardItem.new
      item2.setBackground(@brush)
      item2.setText(data.class.to_s.match('/(.*)>$')[1])
      @hash[name]=item
      @root_item.appendRow(item)
      @root_item.setChild(item.row,1,item2)
      add_compound_type(data,item,name)
      @window.treeView.resizeColumnToContents(0)
     end
  end

  def add_compound_type(object, parent_item,id)
    if !object.kind_of?(Typelib::CompoundType)
      puts "Can not visualize #{object.name}. It is not a Typelib::CompoundType"
      return
    end
    struct = object.public_methods(false).sort
    struct.each do |method_name|
      next if method_name.to_s.match('=$')
      result = object.method(method_name).call
      _id = id +"_"+ method_name.to_s
      if @hash.has_key?(_id)
        item = @hash[_id]
        item2 = parent_item.child(item.row,1)
      else
        item = Qt::StandardItem.new(method_name.to_s)
        @hash[_id]=item
        parent_item.appendRow(item)
        item2 = Qt::StandardItem.new
        parent_item.setChild(item.row,1,item2)
      end
      if result.kind_of?(Typelib::CompoundType)
        item.setBackground(@brush)
        item2.setBackground(@brush)
        add_compound_type(result,item,_id)
      else
        _method = (@act_data_type.gsub("/","_")+"_"+method_name.to_s).to_sym
        if decoder.respond_to?(_method)
          item2.setText(decoder.method(_method).call(@act_data))
        else
          item2.setText(result.to_s)
        end
      end
    end
  end
end

Vizkit::UiLoader.register_ruby_widget("struct_viewer",StructViewer.method(:new))
