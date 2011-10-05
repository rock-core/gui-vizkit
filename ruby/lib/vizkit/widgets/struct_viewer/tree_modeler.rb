#!/usr/bin/env ruby

class TreeModeler
    MAX_ARRAY_FIELDS = 30

    def initialize

    end
    
    # Generates empty tree model.
    def create_tree_model
        model = Qt::StandardItemModel.new
        model.set_horizontal_header_labels(["Property","Value"])
        model
    end
    
    # Generates a tree model with sample as root item of the first sub tree.
    # Default layout: 2 columns: (Property, Value)
    def generate_tree(sample, item_name, model=nil)
        if not model
            # Create new model
            model = create_tree_model
        end
        
        root_item = model.invisible_root_item
        
        # Try to find item in model
        item = find_item(model, item_name)
        unless item
            # Item not found. Create new item and add it to the model.
            item = Qt::StandardItem.new(item_name)
            item2 = Qt::StandardItem.new
            item2.set_text(sample.class.to_s.match('/(.*)>$')[1])
            root_item.append_row(item)
            root_item.set_child(item.row,1,item2)
        end
        
        # Update model with new sample.
        add_object(sample, item)
        model
    end
    
    # Generates a sub tree for an existing parent item. Non-existent 
    # children will be added to parent_item. See generate_tree. Returns 
    # the updated parent_item.
    def generate_sub_tree(sample, item_name, parent_item)
        puts "Generating sub tree for #{item_name}, sample.class = #{sample.class}"
        # Try to find item in model. Is there already a matching 
        # descendant item for sample in parent_item?
        
        # item = find_descendant(parent_item, item_name)
        item = direct_child(parent_item, item_name)
        
        unless item
            #puts "*** No item for item_name '#{item_name}'found. Generating one and appending it to parent_item."
            # Item not found. Create new item and add it to the model.
            item = Qt::StandardItem.new(item_name)
            item2 = Qt::StandardItem.new
            text = nil
            unless sample.class == NilClass
                text = sample.class.to_s.match('/(.*)>$')[1]
            end
            item2.set_text(text)
            parent_item.append_row(item)
            #puts "*** item.row = #{item.row} "
            parent_item.set_child(item.row,1,item2)
        end
        
        # Update sub tree with new sample.
        add_object(sample, item)
        #parent_item
    end

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
    
    # Search for item in the model. Returns nil if the item is not found.
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
    
    # Checks if there is a direct child of parent_item corresponding to item_name.
    # If yes, the child will be returned; nil otherwise. 
    # 'Direct' refers to a difference in (tree) depth of 1 between parent and child.
    def direct_child(parent_item, item_name)
        #puts "*** direct_child? begin"
        rc = 0
        child = nil
        #puts "*** direct_child? parent_item.row_count = #{parent_item.row_count}"
        while rc < parent_item.row_count
            #puts "*** direct_child loop"
            child = parent_item.child(rc)
            #puts "*** checking #{child.text}"
            if child.text.eql?(item_name)
                #puts "*** direct_child: #{child.text} == #{item_name}"
                return child
            end
            rc+=1
        end
        nil
    end
    
    # Gets a pair of parent_item's direct children in the specified row. 
    # Constraint: There are only two children in each row (columns 0 and 1).
    def child_items(parent_item,row)
      item = parent_item.child(row)
      item2 = parent_item.child(row,1)
      unless item
        #item = Qt::StandardItem.new(name.to_s)
        item = Qt::StandardItem.new
        parent_item.append_row(item)
        item2 = Qt::StandardItem.new
        parent_item.set_child(item.row,1,item2)
        item.setEditable(false)
        item2.setEditable(false)
      end
      
      [item,item2]
    end
    
    
end






