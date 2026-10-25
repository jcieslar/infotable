require "test_helper"

class ConfigurationTest < ActiveSupport::TestCase
  teardown { Infotable.reset_configuration! }

  test "defaults" do
    c = Infotable.configuration
    assert_equal 25, c.default_per_page
    assert_equal [ 10, 25, 50, 100 ], c.per_page_options
    assert_equal "-", c.nil_value
    assert_equal "-", c.empty_value
    assert c.autofilter
  end

  test "configure yields and persists" do
    Infotable.configure { |c| c.default_per_page = 5 }
    assert_equal 5, Infotable.configuration.default_per_page
  end

  test "reset_configuration! restores defaults" do
    Infotable.configure { |c| c.default_per_page = 5 }
    Infotable.reset_configuration!
    assert_equal 25, Infotable.configuration.default_per_page
  end

  test "new table picks up configured per_page" do
    Infotable.configure { |c| c.default_per_page = 7 }
    assert_equal 7, build_table.pagination_settings[:per_page]
  end
end

class ParentControllerTest < ActiveSupport::TestCase
  test "default parent controller" do
    assert_equal "ActionController::Base", Infotable::Configuration.new.parent_controller
  end

  test "engine controller inherits configured parent" do
    assert_equal Infotable.configuration.parent_controller.constantize, Infotable::ApplicationController.superclass
  end
end
