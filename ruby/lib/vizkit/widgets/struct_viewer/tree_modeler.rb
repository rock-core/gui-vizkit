#!/usr/bin/env ruby

class TreeModeler
    MAX_ARRAY_FIELDS = 30

    def initialize
        @brush = Qt::Brush.new(Qt::Color.new(200,200,200))
    end
    
    # Generates empty tree model.
    def create_tree_model
        model = Qt::StandardItemModel.new
        model.set_horizontal_header_labels(["Property","Value"])
        model
    end
    
    # Generates a tree model with sample as root item of the first sub tree.
    # Default layout: 2 columns: (Property, Value)
    def generate_tree(sample, port_name, model=nil)
        if not model
            # Create new model
            model = create_tree_model
        end
        
        root_item = model.invisible_root_item
        
        # Try to find item in model
        item = find_item(model, port_name)
        unless item
            # Item not found. Create new item and add it to the model.
            item = Qt::StandardItem.new(port_name)
            item.set_background(@brush)
            item2 = Qt::StandardItem.new
            item2.set_background(@brush)
            item2.set_text(sample.class.to_s.match('/(.*)>$')[1])
            root_item.append_row(item)
            root_item.set_child(item.row,1,item2)
        end
        
        # Update model with new sample.
        add_object(sample, item)
        model
    end
    
private

    # Adds object to parent_item as a child. Object's children will be 
    # added in the original tree structure as well.
    def add_object(object, parent_item)
        if object.kind_of?(Typelib::CompoundType)
          row = 0;
          object.each_field do |name,value|
            item, item2 = child_items(parent_item,row)
            item.set_text name
            item2.set_text value.class.name
            add_object(value,item)
            # item.set_background(@brush)
            # item2.set_background(@brush)
            row += 1
          end
          #delete all other rows
          parent_item.remove_rows(row,parent_item.row_count-row) if row < parent_item.row_count

        elsif object.is_a?(Array) || (object.kind_of?(Typelib::Type) && object.respond_to?(:each))
          if object.size > MAX_ARRAY_FIELDS
            item2 = parent_item.parent.child(parent_item.row,parent_item.column+1)
            item2.set_text "#{object.size} fields ..."
          else
            row = 0
            object.each_with_index do |val,row|
              item,item2 = child_items(parent_item,row)
              item2.set_text val.class.name
              item.set_text "[#{row}]"
              add_object val,item
            end
            #delete all other rows
            row += 1
            parent_item.remove_rows(row,parent_item.row_count-row) if row < parent_item.row_count
          end
        else
          item2 = parent_item.parent.child(parent_item.row,parent_item.column+1)
          item2.set_text(object.to_s)
        end
    end
    
    # Check if the item is already in the model
    def find_item(model, item_name)
        found_items = model.find_items(item_name, Qt::MatchFixedString || Qt::MatchCaseSensitive)
        case found_items.size
            when 0
                return nil
            when 1
                return found_items.first
            else
                raise "Found more items than expected. Use unique names!"
        end
    end
    
    # Gets a pair of parent_item's direct children in the specified row. 
    # Constraint: There are only two children in each row (columns 0 and 1).
    def child_items(parent_item,row)
      item = parent_item.child(row)
      item2 = parent_item.child(row,1)
      unless item
        #item = Qt::StandardItem.new(name.to_s)
        item = Qt::StandardItem.new("*******TESTTEST*******") # TODO debug
        parent_item.append_row(item)
        item2 = Qt::StandardItem.new
        parent_item.set_child(item.row,1,item2)
      end
      [item,item2]
    end
    
end






