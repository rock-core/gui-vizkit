#!/usr/bin/env ruby

class StructViewer < Qt::Widget
  MAX_ARRAY_FIELDS = 30

  def self.child_items(parent_item,row)
      item = parent_item.child(row)
      item2 = parent_item.child(row,1)
      unless item
        item = Qt::StandardItem.new(name.to_s)
        parent_item.appendRow(item)
        item2 = Qt::StandardItem.new
        parent_item.setChild(item.row,1,item2)
      end
      [item,item2]
  end

  def initialize(parent=nil)
    super
    load File.join(File.dirname(__FILE__),'struct_viewer_window.ui.rb')
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
      add_object(data,item)
     else
      item = Qt::StandardItem.new(name)
      item.setBackground(@brush)
      item2 = Qt::StandardItem.new
      item2.setBackground(@brush)
      item2.setText(data.class.to_s.match('/(.*)>$')[1])
      @hash[name]=item
      @root_item.appendRow(item)
      @root_item.setChild(item.row,1,item2)
      add_object(data,item)
      @window.treeView.resizeColumnToContents(0)
     end
  end

  def add_object(object, parent_item)
    if object.kind_of?(Typelib::CompoundType)
      row = 0;
      object.each_field do |name,value|
        item, item2 = StructViewer.child_items(parent_item,row)
        item.setText name
        item2.setText value.class.name
        add_object(value,item)
        # item.setBackground(@brush)
        # item2.setBackground(@brush)
        row += 1
      end
      #delete all other rows
      parent_item.removeRows(row,parent_item.rowCount-row) if row < parent_item.rowCount

    elsif object.is_a?(Array) || (object.kind_of?(Typelib::Type) && object.respond_to?(:each))
      if object.size > MAX_ARRAY_FIELDS
        item2 = parent_item.parent.child(parent_item.row,parent_item.column+1)
        item2.setText "#{object.size} fields ..."
      else
        row = 0
        object.each_with_index do |val,row|
          item,item2 = StructViewer.child_items(parent_item,row)
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
end

Vizkit::UiLoader.register_ruby_widget("StructViewer",StructViewer.method(:new))
