class TestWidget123 < Qt::Widget
    def initialize(parent=nil)
        super
    end
    def test
        123
    end
end

Vizkit::UiLoader.register_ruby_widget("TestWidget123",TestWidget123.method(:new))
