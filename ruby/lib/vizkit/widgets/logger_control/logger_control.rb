# Main Window setting up the ui
class LoggerControlWidget < Qt::Widget 

  def initialize(parent = nil)
    super
    @logger = nil
    @layout = Qt::GridLayout.new
    @widget = Vizkit.load File.join(File.dirname(__FILE__),'logger_control.ui'), self
    @layout.addWidget(@widget,0,0)
    @current_index = -1;
    self.setLayout @layout
  end

  def config(task,options=Hash.new)
    @logger = task
    @timer = Qt::Timer.new
    @timer.connect(SIGNAL('timeout()')) do
        if(@logger.reachable? && @logger.running?)
            @widget.button_send.setEnabled(true)
        else
            @widget.button_send.setEnabled(false)
        end
    end
    @timer.start(1000)

    @widget.button_send.connect(SIGNAL('clicked()')) do 
        used_index = -1
        combobox_text = @widget.combobox.currentText
        comment = @widget.text_comment.text
        error = false

        if(@logger.reachable? && @logger.running?)
            case combobox_text
                when "Start Marker"
                    @current_index += 1
                    used_index = @current_index
                    @logger.marker_start(@current_index,comment)
                    if @widget.auto.isChecked
                        index = @widget.combobox.findText("Stop Marker")
                        @widget.combobox.setCurrentIndex index
                    end
                when "Stop Marker"
                    if @current_index >= 0
                        @logger.marker_stop(@current_index,comment)
                        used_index = @current_index
                        @current_index -= 1
                        if @widget.auto.isChecked
                            index = @widget.combobox.findText("Start Marker")
                            @widget.combobox.setCurrentIndex index
                        end
                    else
                        puts "There is no start marker!"
                        error = true
                    end
                when "Abort Marker"
                    if @current_index >= 0
                        @logger.marker_abort(@current_index,comment)
                        used_index = @current_index
                        @current_index -= 1
                    else
                        puts "There is no start marker!"
                        error = true
                    end
                when "Event Marker"
                    @logger.marker_event(comment)
                when "Abort All Marker"
                    @logger.marker_abort_all(comment)
                    @current_index = -1
                when "Stop All Marker"
                    @logger.marker_stop_all(comment)
                    @current_index = -1
            end 
            if !error
                text = if used_index == -1
                           "++ #{combobox_text}: #{comment} ++"
                       else
                           "#{" "*3*used_index}#{combobox_text}(#{used_index}): #{comment}"
                       end
                @widget.text_comment.text = ""
                @widget.list_history.addItem(text)
                @widget.list_history.scrollToBottom 
            end
        end
    end
  end
end

Vizkit::UiLoader.register_ruby_widget "logger_control", LoggerControlWidget.method(:new)
Vizkit::UiLoader.register_control_for "logger_control", "logger::Logger", :config
