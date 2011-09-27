#!/usr/bin/env ruby

require 'Qt4'

class TreeModeler
    MAX_ARRAY_FIELDS = 30

    def initialize
        @brush = Qt::Brush.new(Qt::Color.new(200,200,200))
    end
    
    def createTreeModel
        model = Qt::StandardItemModel.new
        model.setHorizontalHeaderLabels(["Property","Value"])
        model
    end
    
    # Generates a tree model with sample as root item of the first sub tree.
    # Default layout: 2 columns: (Property, Value)
    def generateTree(sample, port_name, model=nil)
        if not model
            # Create new model
            model = createTreeModel
        end
        
        root_item = model.invisibleRootItem
        
        # Try to find item in model
        item = findItem(model, port_name)
        unless item
            # Item not found. Create new item and add it to the model.
            item = Qt::StandardItem.new(port_name)
            item.setBackground(@brush)
            item2 = Qt::StandardItem.new
            item2.setBackground(@brush)
            item2.setText(sample.class.to_s.match('/(.*)>$')[1])
            root_item.appendRow(item)
            root_item.setChild(item.row,1,item2)
        end
        
        # Update model with new sample.
        add_object(sample, item)
        model
    end
    
private

    def add_object(object, parent_item)
        if object.kind_of?(Typelib::CompoundType)
          row = 0;
          object.each_field do |name,value|
            item, item2 = child_items(parent_item,row)
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
              item,item2 = child_items(parent_item,row)
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
    
    # Check if the item is already in the model
    def findItem(model, itemName)
        foundItems = model.findItems(itemName, Qt::MatchFixedString || Qt::MatchCaseSensitive)
        case foundItems.size
            when 0
                return nil
            when 1
                return foundItems.first
            else
                raise "Found more items than expected. Use unique names!"
        end
    end
    
    def child_items(parent_item,row)
      item = parent_item.child(row)
      item2 = parent_item.child(row,1)
      unless item
        #item = Qt::StandardItem.new(name.to_s)
        item = Qt::StandardItem.new("*******TESTTEST*******") # TODO debug
        parent_item.appendRow(item)
        item2 = Qt::StandardItem.new
        parent_item.setChild(item.row,1,item2)
      end
      [item,item2]
    end
    
end

#====== Testing =============

#tree_model = Qt::StandardItemModel.new
#tree_model.setHorizontalHeaderLabels(["Property","Value"])
#root_item = tree_model.invisibleRootItem

tm = TreeModeler.new






