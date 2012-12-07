require '../vizkit'

module Vizkit::TreeModel
    class EnumEditor < Qt::ComboBox
        def initialize(parent,data)
            super(parent)
            data.to_a.each do |val|
                addItem(val.to_s)
            end
        end
        # we cannot use user properties here 
        # there is no way to define some on the ruby side
        def getData
            currentText
        end
    end

    class ItemDelegate < Qt::StyledItemDelegate
        def createEditor (parent, option,index)
            data = index.data(Qt::EditRole)
            if data.type == Qt::Variant::StringList
                Vizkit::TreeModel::EnumEditor.new(parent,data)
            else
                super
            end
        end
        def setModelData(editor,model,index)
            # we cannot use user properties here 
            # there is no way to define some on the ruby side
            if editor.respond_to? :getData
                model.setData(index,Qt::Variant.new(editor.getData),Qt::EditRole)
            else
                super
            end
        end
    end

    class TreeView < Qt::TreeView
        def initialize(parent= nil)
            super
            @delegator = ItemDelegate.new
            setItemDelegate(@delegator)
        end
    end

    class TypeLib < Qt::AbstractItemModel
        class ItemData < Struct.new(:parent,:row,:field,:model_index)
            def val
                parent[field_name]
            end
            def field_type
                field.last
            end
            def field_name
                field.first
            end
        end

        def initialize(data,parent = nil)
            super(parent)
            @root = data
            @data_for_item = Hash.new
        end

        def update(data)
            puts @root.time
            @root = Typelib.copy(@root,data)
            emit dataChanged(index(0,1),index(rowCount,1))
        end

        def index(row,column,parent = Qt::ModelIndex.new)
            item = itemFromIndex(parent)
            child,field = if !item.is_a? Typelib::Type
                              [nil,nil]
                          elsif item.class.respond_to? :fields
                              field = item.class.fields.sort[row]
                              if field
                                  [item.raw_get(field.first),field]
                              else
                                  [nil,nil]
                              end
                          elsif item.respond_to?(:raw_get) && item.size > row
                              [item.raw_get(row),[row,item.element_t]]
                          else
                              [nil,nil]
                          end
            if child
                #encode child as symbol if we got a non persistent ruby object
                child = if child.is_a? Typelib::Type
                            child
                        else
                            "#{item.object_id}_#{row}".to_sym
                        end
                #save parent for the child otherwise we would have a hard time
                #to recover
                #we also have to store the model index as qt is using the pointer
                #to check if two parents are equal
                model = create_index(row, column, child)
                @data_for_item[child] = ItemData.new(item,row,field,model) unless @data_for_item.has_key?(child)
                model
            else
                Qt::ModelIndex.new
            end
        end

        def to_variant(sample,role,data)
            val = if sample.is_a? Typelib::Type
                      sample.class.name
                  else
                      if sample.is_a?(Float) || sample.is_a?(Fixnum) ||
                          sample.is_a?(TrueClass) || sample.is_a?(FalseClass)
                          sample
                      elsif sample.is_a? Time
                          if role == Qt::EditRole
                              Qt::DateTime.new(sample)
                          else
                              "#{sample.strftime("%-d %b %Y %H:%M:%S")}.#{sample.nsec.to_s}"
                          end
                      elsif sample.is_a? Symbol
                          if role == Qt::EditRole
                              #add current value at the front
                              arr = data.field_type.keys.keys
                              arr.delete(sample.to_s)
                              arr.insert(0,sample.to_s)
                              arr
                          else
                              sample.to_s
                          end
                      else
                          sample.to_s
                      end
                  end
            Qt::Variant.new(val)
        end

        def data(index,role)
            if !index.valid? || role != Qt::DisplayRole && role != Qt::EditRole
                return Qt::Variant.new 
            end
            item = itemFromIndex(index)
            data = @data_for_item[item]
            if index.column == 0
                name = if data.field_name.is_a? Fixnum
                           "[#{data.field_name}]"
                        else
                           data.field_name
                        end
                to_variant(name,role,data)
            else
                to_variant(data.val,role,data)
            end
        end

        def itemFromIndex(index)
            return @root unless index.valid?
            index.internalPointer
        end

        def setData(index,value,role)
            if role != Qt::EditRole || !index.valid?
                return false
            end
            item = itemFromIndex(index)
            data = @data_for_item[item]
            return false if !data.parent
            item_val = data.val

            val = if item_val.is_a? Integer
                      value.to_i
                  elsif item_val.is_a? Float
                      value.to_f
                  elsif item_val.is_a? String
                      value.toString.to_s
                  elsif item_val.is_a? Time
                      Time.at(value.toDateTime.toTime_t)
                  elsif item_val.is_a? Symbol
                      value.toString.to_sym
                  end
            return false unless val

            data.parent[data.field.first] = val
            emit dataChanged(index,index)
            true
        end

        def flags(index)
            if index.valid?
                item = itemFromIndex(index)
                data = @data_for_item[item]
                item_val = if data
                               data.val
                           else
                               data
                           end
                if !item_val.is_a?(Typelib::Type) && rowCount(index) == 0 && index.column > 0
                    Qt::ItemIsEnabled | Qt::ItemIsEditable
                else
                    Qt::ItemIsEnabled
                end
            else
                0
            end
        end

        def headerData(section,orientation,role)
            return Qt::Variant.new if role != Qt::DisplayRole
            if section == 0
                Qt::Variant.new("Field")
            else
                Qt::Variant.new("Value")
            end
        end

        def parent(index)
            return Qt::ModelIndex.new unless index.valid? || index.column > 0
            item = itemFromIndex(index)
            data = @data_for_item[item]
            return Qt::ModelIndex.new if !data || data.parent.object_id == @root.object_id
            data2 = @data_for_item[data.parent]
            return Qt::ModelIndex.new unless data2
            data2.model_index
        end

        def rowCount(index = Qt::ModelIndex.new)
            item = itemFromIndex(index)
            #special case for Time as bignum cannot be but into a Variant :-(
            if !item.is_a?(Typelib::Type) || item.class.name == "/base/Time"
                0
            elsif item.class.respond_to? :fields
                item.class.fields.size
            elsif item.respond_to? :raw_get
                item.size
            else
                0
            end
        end

        def columnCount(index)
            2
        end
    end
end


Orocos.initialize
Orocos.load_typekit "base"
t = Types::Base::Samples::RigidBodyState.new
t = Types::Base::Samples::Frame::FramePair.new
t = Types::Base::Actuators::Command.new
t.mode << t.mode.element_t.keys.keys[0].to_sym
t.mode << t.mode.element_t.keys.keys[2].to_sym
t.mode << t.mode.element_t.keys.keys[0].to_sym
model = Vizkit::TreeModel::TypeLib.new(t)

w = Vizkit::TreeModel::TreeView.new
timer = Qt::Timer.new

timer.connect SIGNAL("timeout()") do 
    #t.time = Time.now
    #t.apply_changes_from_converted_types
    #model.update(t)
end
timer.start 100

w.resize(640,480)
w.setModel model
w.show
Vizkit.exec
