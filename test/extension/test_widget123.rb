class TestWidget123 < Qt5::Widget
    def initialize(parent=nil)
        super
    end
    def test
        123
    end
end

Vizkit::UiLoader.register_ruby_widget("TestWidget123",TestWidget123.method(:new))
