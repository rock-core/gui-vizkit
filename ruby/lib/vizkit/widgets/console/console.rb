require "stringio"

module Vizkit 
    class ConsoleContext
        HELP = { nil => "Type 'methods' to see all available methods.\nType 'help('method_name')' for help.",
                "clear" => "clears the console output."}

        def initialize(console)
            @console = console
        end
        def clear
            @console.clear
        end
        def help(name=nil)
            ConsoleContext::HELP[name]
        end

        def close
            @console.close
        end

        def text(val)
            @console.insert_text(val)
        end

        def info
            "The following objects are defined:\n "+singleton_methods.join("; ")
        end

        def methods
            super-Class.instance_methods
        end

        alias :reset :clear
        alias :exit :close
        alias :quit :close
    end

    class Console < Qt::TextEdit
        #used to flag QTextBlocks
        COMMAND_TYPE = 1
        ERROR_TYPE = 2
        STDOUT_TYPE = 3
        STDERR_TYPE = 4
        RESULT_TYPE = 5
        TEXT_TYPE = 6

        def self.colors 
            if !@colors
                @colors = Hash.new 
                @colors[:black] = Qt::Color.new(0,0,0)
                @colors[:gray] = Qt::Color.new(120,120,120)
                @colors[:red] = Qt::Color.new(255,0,0)
                @colors[:blue] = Qt::Color.new(0,0,255)
                @colors[31] = Qt::Color.new(255,0,0)
                @colors[35] = Qt::Color.new(0,255,0)
            end
            @colors
        end

        def initialize(parent=nil)
            super
            resize(600,350)
            @history = [""] 
            @history_index = 0
            @console_context = ConsoleContext.new(self)
            @console_binding = @console_context.instance_eval("binding")
            @colors = Console.colors
            @cursor = "> "
            @font = Qt::Font.new("Monospace",10)
            setCursorWidth(10)
            setAcceptRichText(false)
            setContextMenuPolicy Qt::NoContextMenu
            append @console_context.help,:gray,Console::RESULT_TYPE
            new_command
            deselect
        end

        def multi_value?
            true
        end

        def clear
            document().clear
            deselect
        end

        def command
            textCursor.block.text[@cursor.size..-1]
        end

        def new_command(new_command="")
            append @cursor+new_command,:black,Console::COMMAND_TYPE
        end

        def add_obj(obj,options)
            name = obj.name.downcase
            if @console_context.respond_to? name
                insert_text "Cannot Add #{name}(#{obj.class.name}). #{name} is already defined."
            else
                insert_text "Added #{name}(#{obj.class.name}). You can access it via #{name}.",:blue
                @console_context.instance_eval("class << self;self;end").send(:define_method,name) do 
                    instance_variable_get("@#{name}")
                end
                @console_context.instance_variable_set("@#{name}",obj)
                if command.empty?
                    replace_current_command(name)
                end
            end
        end

        def add_dynamic_obj(obj,options)
            name = obj.name.downcase
            if !@console_context.respond_to? name
                insert_text "Added #{name}(#{obj.class.name}). You can access it via #{name}.\n"+
                            "The object will be updated automatically.",:blue
                @console_context.instance_eval("class << self;self;end").send(:define_method,name) do 
                    instance_variable_get("@#{name}")
                end
                if command.empty?
                    replace_current_command(name)
                end
            end
            @console_context.instance_variable_set("@#{name}",obj)
        end

        def insert_text(text,color=:blue)
            deselect
            cursor = textCursor
            cursor.select(Qt::TextCursor::LineUnderCursor)
            old_text = cursor.selectedText
            cursor.removeSelectedText
            append text,color,Console::TEXT_TYPE
            new_command(old_text[@cursor.size..-1])
            nil
        end

        def append(val,color=nil,type=Console::RESULT_TYPE)
            values = val.to_s.split("\n")
            values.each do |val|
                val =~ /\e\[(\d*)m(.*)/
                    val = $2 if $2
                if $1
                    append(val,$1.to_i,type)
                else
                    color = if color.is_a?(Qt::Color)
                                color
                            elsif color && @colors.has_key?(color)
                                @colors[color]
                            else
                                @colors[:black]
                            end
                    setTextColor(color)
                    setCurrentFont(@font)
                    if type == COMMAND_TYPE
                        super val
                    else
                        super(" "*@cursor.size+val) 
                    end
                    textCursor.block.setUserState(type)
                end
            end
        end

        def interprete_command(cmd)
            return unless cmd
            @history << cmd
            @history_index = @history.size
            result = nil
            error = nil
            out = capture_all_output do 
                begin
                    result = eval(cmd,@console_binding,__FILE__,__LINE__).to_s
                rescue Exception => e
                    error = e.message
                end
            end
            if out
                append out.first,:gray, Console::STDOUT_TYPE if !out.first.empty? 
                append out[1],:red,Console::STDERR_TYPE if !out[1].empty? 
            end
            append error,:red,Console::ERROR_TYPE if error && !error.empty?
            append result,:gray,Console::RESULT_TYPE if result && !result.empty?
            new_command
        end

        def capture_all_output(&block)
            real_stdout, $stdout = $stdout, StringIO.new 
            real_stderr, $stderr = $stderr, StringIO.new
            logdev = Vizkit.logger.instance_variable_get(:@logdev)
            real_dev = logdev.instance_variable_get(:@dev)
            logdev.instance_variable_set(:@dev,$stdout)
            yield
            [$stdout.string,$stderr.string]
        ensure
            $stdout = real_stdout
            $stderr = real_stderr
            logdev.instance_variable_set(:@dev,real_dev)
        end

        def deselect
            #we have to set the cursor otherwise there will be no effect
            cursor = textCursor
            cursor.movePosition(Qt::TextCursor::End,Qt::TextCursor::MoveAnchor)
            setTextCursor(cursor)
            ensureCursorVisible
        end

        def replace_current_command(val)
            cursor = textCursor
            cursor.select(Qt::TextCursor::LineUnderCursor)
            cursor.removeSelectedText
            cursor.insertText(@cursor+val)
            ensureCursorVisible
        end

        def prev_command(direction=-1)
            @history_index += direction
            @history_index = 0 if @history_index < 0 
            cmd = if @history_index >= @history.size
                          @history_index = @history.size
                          ""
                      else
                          @history[@history_index]
                      end
            replace_current_command(cmd)
        end

        def keyPressEvent(event)
            #block paste outside the last line
            if event.modifiers == Qt::ControlModifier
                case event.key
                when 86  # ctrl-v
                    deselect
                    return super
                when 67  #ctrl-c
                    return super
                end
            end

            case event.key
            when 16777234 #left
                if textCursor.positionInBlock > @cursor.size
                    super
                else
                    if textCursor.blockNumber > 0
                        cursor = textCursor
                        cursor.movePosition(Qt::TextCursor::Up,Qt::TextCursor::MoveAnchor)
                        cursor.movePosition(Qt::TextCursor::EndOfLine,Qt::TextCursor::MoveAnchor)
                        setTextCursor(cursor)
                    end
                end
            when 16777236 #right
                if textCursor.positionInBlock < textCursor.block.length-1
                    super
                else
                    if textCursor.blockNumber < document.blockCount-1
                        cursor = textCursor
                        cursor.movePosition(Qt::TextCursor::Down,Qt::TextCursor::MoveAnchor)
                        cursor.movePosition(Qt::TextCursor::StartOfLine,Qt::TextCursor::MoveAnchor)
                        cursor.movePosition(Qt::TextCursor::NextCharacter,Qt::TextCursor::MoveAnchor,@cursor.size)
                        setTextCursor(cursor)
                    else
                        super
                    end
                end
            when 16777235 #up
                if textCursor.blockNumber == document.blockCount-1
                    prev_command(-1) 
                else
                    super
                end
            when 16777237 #down
                if textCursor.blockNumber == document.blockCount-1
                    prev_command(1) 
                else
                    super
                end
            when 16777220 #return
                deselect
                interprete_command(command)
            when 16777219 #backspace
                if textCursor.hasSelection
                    deselect
                else
                    super if textCursor.positionInBlock > @cursor.size
                end
            when 16777232 
                cursor = textCursor
                cursor.movePosition(Qt::TextCursor::StartOfLine,Qt::TextCursor::MoveAnchor)
                cursor.movePosition(Qt::TextCursor::NextCharacter,Qt::TextCursor::MoveAnchor,@cursor.size)
                setTextCursor(cursor)
                ensureCursorVisible
            when 16777233
                super
            when 16777217 #tab
                #super # TODO auto completion
            else
                #puts event.key
                if textCursor.blockNumber != document.blockCount-1 && event.key < 1000
                    deselect
                else
                    deselect if textCursor.positionInBlock < @cursor.size
                    super
                end
            end
        end
    end
    UiLoader.register_ruby_widget("Console",Console.method(:new))
    UiLoader.register_widget_for("Console",Orocos::TaskContext,:add_obj)
    UiLoader.register_widget_for("Console",Vizkit::TaskProxy,:add_obj)
    UiLoader.register_widget_for("Console",Orocos::Log::TaskContext,:add_obj)
    UiLoader.register_widget_for("Console",Typelib::Type,:add_dynamic_obj)
    UiLoader.register_control_for("Console",Orocos::TaskContext,:add_obj)
    UiLoader.register_control_for("Console",Vizkit::TaskProxy,:add_obj)
end
