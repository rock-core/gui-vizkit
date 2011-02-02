#!/usr/bin/env ruby
#

require '../lib/vizkit/uiloader.rb'
require 'test/unit'
    
Qt::Application.new(ARGV)

class LoaderUiTest < Test::Unit::TestCase

  def setup
    @loader = Vizkit::UiLoader.new
    Vizkit::UiLoader.current_loader_instance = @loader
  end

  def test_qt
    assert defined? Qt
    assert defined? Qt::Application
  end

  def test_loader_exists
    assert(@loader)
  end

  def test_loader_register_widget_for
    Vizkit::UiLoader.register_widget_for("QWidget",123)
    Vizkit::UiLoader.register_widget_for("QPushButton","123")
    assert @loader.widget_for(123).is_a? Qt::Widget
    assert @loader.widget_for_value(123).is_a? Qt::Widget
    assert @loader.widget_for("123").is_a? Qt::PushButton
    
    Vizkit::UiLoader.register_widget_for("QPushButton","test",:update2)
    assert_equal :update2, @loader.callback_fct("QPushButton","test")
  end
  
  def test_loader_widget_name_for
    Vizkit::UiLoader.register_widget_for("QPushButton","test")
    assert_equal 1, @loader.widget_names_for("test").size
    assert @loader.widget_name_for("test")
    Vizkit::UiLoader.register_widget_for("QWidget","test")
    assert_equal 2, @loader.widget_names_for("test").size
    assert_raise(RuntimeError){@loader.widget_name_for "test"}
    @loader.register_default_widget_for("QWidget","test")
    assert @loader.widget_name_for "test"
  end

  def test_loader_register_ruby_widget
    Vizkit::UiLoader.register_ruby_widget("object",Qt::Object.method(:new))
    assert @loader.create_widget("object")
    assert @loader.available_widgets.find{|p| p == "object"}
    assert @loader.widget? "object"
    assert @loader.ruby_widget? "object"
    assert !(@loader.cplusplus_widget? "object")
  end

  def test_loader_create_widget
    assert @loader.create_widget("QWidget")
    widget = @loader.QWidget
    assert widget
    assert widget.loader
  end

  def test_loader_available_widgets 
    assert @loader.available_widgets.find{|p| p == "QWidget"}
  end
 
  def test_loader_extend_cplusplus_widget_class
    Vizkit::UiLoader.extend_cplusplus_widget_class("QWidget") do 
      def test123
        123
      end
    end
    widget = @loader.create_widget("QWidget")
    assert widget.respond_to?(:test123)
    assert_equal 123,widget.test123
  end

  def test_loader_load
    @loader.extend_cplusplus_widget_class("Qt::PushButton") do 
      def test123
        123
      end
    end

    form = @loader.load("test.ui")
    assert form
    assert form.pushButton
    assert_equal 123, form.pushButton.test123
    assert form.textEdit
  end
end
