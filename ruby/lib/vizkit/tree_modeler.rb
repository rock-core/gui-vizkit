#!/usr/bin/env ruby

require 'utilrb/logger'

module Vizkit

    extend Logger::Root('tree_modeler.rb', Logger::INFO)
    
    # The TreeModeler class' purpose is to provide useful functionality for
    # working with Qt's StandardItemModel (handled as TreeModel). The main focus
    # is the generation of (sub) trees out of (compound) data structures such as sensor samples
    # with possibly multiple layers of data. 
    # Multilayer recognition only works with Typelib::CompoundType.
    class TreeModeler

        MAX_ARRAY_FIELDS = 30

        def initialize
        end
        
        # Generates empty tree model.
        # Default layout: 2 columns: (Property, Value)
        def create_tree_model
            model = Qt::StandardItemModel.new
            model.set_horizontal_header_labels(["Property","Value"])
            model
        end
        
        # Updates a sub tree for an existing parent item. Non-existent 
        # children will be added to parent_item. See generate_tree.
        def update_sub_tree(sample, item_name, parent_item, read_obj=false)
            Vizkit.debug("Updating subtree for #{item_name}, sample.class = #{sample.class}")
            # Try to find item in model. Is there already a matching 
            # child item for sample in parent_item?
            item = direct_child(parent_item, item_name)
            
            unless item
                Vizkit.debug("No item for item_name '#{item_name}'found. Generating one and appending it to parent_item.")
                # Item not found. Create new item and add it to the model.
                item = Qt::StandardItem.new(item_name)
                item2 = Qt::StandardItem.new
                text = nil
                Vizkit.debug "sample.class = #{sample.class}"
                
                match = sample.class.to_s.match('/(.*)>$')
                if sample
                    unless match
                        text = sample.class.to_s
                    else
                        text = match[1]
                    end
                end
                item2.set_text(text)
                parent_item.append_row(item)
                parent_item.set_child(item.row,1,item2)
            end
            
            # Update sub tree with new sample.
            add_object(sample, item, read_obj)
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
        
        # Checks if there is a direct child of parent_item corresponding to item_name.
        # If yes, the child will be returned; nil otherwise. 
        # 'Direct' refers to a difference in (tree) depth of 1 between parent and child.
        def direct_child(parent_item, item_name)
            rc = 0
            children = get_direct_children(parent_item).each do |child,_|
                if child.text.eql?(item_name)
                    return child
                end
            end
            nil
        end
        
        # Returns pairs of all direct children (pair: row 0, row 1) as an array.
        def get_direct_children(parent_item)
            children = []
            rc = 0;
            while rc < parent_item.row_count
                item = parent_item.child(rc,0)
                item2 = parent_item.child(rc,1)
                children << [item,item2]
                rc+=1
            end
            children
        end
        
        # Sets all child items' editable status to the value of <i>editable</i> 
        # except items acting as parent. 'Child item' refers to the value of 
        # the (property,value) pair.
        def set_all_children_editable(parent_item, editable)
            row = 0;
            while row < parent_item.row_count
                item, item2 = child_items(parent_item, row)
                if item.has_children
                    item2.set_editable(false)
                    set_all_children_editable(item, editable)
                else
                    item2.set_editable(editable)
                end
                row += 1
            end
        end

    private

        # Adds object to parent_item as a child. Object's children will be 
        # added as well. The original tree structure will be preserved.
        def add_object(object, parent_item, read_obj=false, row=0, name_hint=nil)
            if object.kind_of?(Typelib::CompoundType)
              Vizkit.debug("add_object->CompoundType")
              row = 0;
              object.each_field do |name,value|
                item, item2 = child_items(parent_item,row)
                item.set_text name
                #item2.set_text value.class.name
                if read_obj
                  object.set_field(name,add_object(value,item,read_obj,row,name))
                else
                  add_object(value,item,read_obj,row,name)
                end
                row += 1
              end
              #delete all other rows
              parent_item.remove_rows(row,parent_item.row_count-row) if row < parent_item.row_count

            elsif object.is_a?(Array) || (object.kind_of?(Typelib::Type) && object.respond_to?(:each))
              Vizkit.debug("add_object->Array||Typelib+each")
              if object.size > MAX_ARRAY_FIELDS
                item2 = parent_item.parent.child(parent_item.row,parent_item.column+1)
                item2.set_text "#{object.size} fields ..."
              elsif object.size > 0
                row = 0
                object.each_with_index do |val,row|
                  item,item2 = child_items(parent_item,row)
                  item2.set_text val.class.name
                  item.set_text "[#{row}]"
                  if read_obj
                    object[row] = update_item(val,item,read_obj,row)
                  else
                    add_object(val,item,read_obj,row)
                  end
                end
                #delete all other rows
                row += 1
                parent_item.remove_rows(row,parent_item.row_count-row) if row < parent_item.row_count
              elsif read_obj
                a = (add_object(object.to_ruby,parent_item,read_obj,0))
                if a.kind_of? String
                  # Append char by char because Typelib::ContainerType.<<(value) does not support argument strings longer than 1.
                  a.each_char do |c|
                    object << c
                  end
                end
              end
            else
              Vizkit.debug("add_object->else")
              item = parent_item.parent.child(parent_item.row,parent_item.column)
              item2 = parent_item.parent.child(parent_item.row,parent_item.column+1)

              if object
                if read_obj
                  Vizkit.debug("Mode: Reading user input")
                  raise "name differs" if(object.respond_to?(:name) && item.text != object.name)
                  #convert type
                  type = object
                  if object.is_a? Typelib::Type
                    Vizkit.debug("We have a Typelib::Type.")
                    type = object.to_ruby 
                  end
                  
                  Vizkit.debug("Changing property '#{item.text}' to value '#{item2.text}'")
                  Vizkit.debug("object of class type #{object.class}, object.to_ruby (if applicable) is of class type #{type.class}")
                  
                  data = item2.text if type.is_a? String
                  data = item2.text.gsub(',', '.').to_f if type.is_a? Float # use international decimal point
                  data = item2.text.to_i if type.is_a? Fixnum
                  data = item2.text.to_i if type.is_a? File
                  data = item2.text.to_i == 0 if type.is_a? FalseClass
                  data = item2.text.to_i == 1 if type.is_a? TrueClass
                  data = item2.text.to_sym if type.is_a? Symbol
                  data = Time.new(item2.text) if type.is_a? Time
                  Vizkit.debug("Converted object data: '#{data}'")
                  
                  if object.is_a? Typelib::Type
                    Typelib.copy(object,Typelib.from_ruby(data, object.class))
                  else
                    object = data
                  end
                else
                  Vizkit.debug("Mode: Displaying data")
                  if object.is_a? Float
                    item2.set_text(object.to_s.gsub(',', '.')) # use international decimal point
                  else
                    item2.set_text(object.to_s)
                  end
                end
                
              else
                item2.setText "no samples received"
              end
            end
        object
        end

    end
end




