require "test_helper"

class DrawerConfigTest < ActionDispatch::IntegrationTest
  teardown { Infotable.reset_configuration! }

  def drawer
    get "/users"
    Nokogiri::HTML(response.body).at_css("[data-drawer-side]")
  end

  test "defaults to right side, 26rem" do
    d = drawer
    assert_equal "right", d["data-drawer-side"]
    assert_includes d["style"], "right: 0; width: 26rem"
    assert_includes d["style"], "translateX(100%)"
  end

  test "left side and custom width" do
    Infotable.configure { |c| c.drawer_position = :left; c.drawer_width = "500px" }
    d = drawer
    assert_equal "left", d["data-drawer-side"]
    assert_includes d["style"], "left: 0; width: 500px"
    assert_includes d["style"], "translateX(-100%)"
  end

  test "invalid width falls back instead of injecting CSS" do
    Infotable.configure { |c| c.drawer_width = "1px; background:url(x)" }
    assert_includes drawer["style"], "width: 26rem"
  end

  test "closed drawer is an inert, labelled dialog" do
    d = drawer
    assert_equal "dialog", d["role"]
    assert d.key?("inert")
    assert_equal "true", d["aria-hidden"]
    assert_equal "Filters and columns", d["aria-label"]
  end
end
