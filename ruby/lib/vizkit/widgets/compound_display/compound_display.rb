require 'vizkit'

# Compound widget for displaying up to six visualization widgets in a 3x2 grid.
# Grid 'layouts', i.e. specific position configurations, can be saved to and
# restored from YAML files.
#
# @author Allan Conquest <allan.conquest@dfki.de>
class CompoundDisplay < Qt::Widget

    slots 'save()', 'setWidget(int, QString, QWidget)'
        
    def initialize(parent=nil)
        super
        @gui = Vizkit.load(File.join(File.dirname(__FILE__),'compound_display.ui'),self)
        self
    end
    
    def save
        puts "DEBUG: Saving configuration"
    end
    
    # position layout:
    #   0 1 2
    #   3 4 5
    def set_widget(src, pos, widget=nil)
        puts "DEBUG: Displaying src: #{src} at position #{pos} in widget #{widget}"
    end

end

Vizkit::UiLoader.register_ruby_widget("CompoundDisplay",CompoundDisplay.method(:new))
