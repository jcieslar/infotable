require "test_helper"

class EngineTest < ActiveSupport::TestCase
  test "Pagy is not mixed into host controllers or views" do
    assert_not_includes ApplicationController.ancestors, Pagy::Method
    assert_not_includes ActionView::Base.ancestors, Pagy::Method
    assert_includes Infotable::TablesController.ancestors, Pagy::Method
  end

  test "engine JS path is registered once" do
    path = Infotable::Engine.root.join("app/assets/javascripts")
    assert_equal 1, Rails.application.config.assets.paths.count { _1.to_s == path.to_s }
  end

  test "host app/infotable tables are autoloadable" do
    assert_equal UsersTable, Object.const_get(:UsersTable)
  end

  test "engine helpers available in host views" do
    assert_includes ApplicationController._helpers.ancestors, Infotable::TablesHelper
  end
end
