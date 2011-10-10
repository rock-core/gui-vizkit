#!/usr/bin/env ruby

require 'utilrb/logger'

module Vizkit

    extend Logger::Root('tree_modeler.rb', Logger::INFO)

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
        def update_sub_tree(sample, item_name, parent_item)
            Vizkit.debug("Ubdating subtree for #{item_name}, sample.class = #{sample.class}")
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
            add_object(sample, item)
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

              if object
                item2.set_text(object.to_s)
              else
                item2.setText "no samples received"
              end
            end
        end
        
        # Checks if there is a direct child of parent_item corresponding to item_name.
        # If yes, the child will be returned; nil otherwise. 
        # 'Direct' refers to a difference in (tree) depth of 1 between parent and child.
        def direct_child(parent_item, item_name)
            rc = 0
            child = nil
            while rc < parent_item.row_count
                child = parent_item.child(rc)
                if child.text.eql?(item_name)
                    return child
                end
                rc+=1
            end
            nil
        end

    end
end




