require "test_helper"

class ResizableColumnsTest < ActionDispatch::IntegrationTest
  test "tables are resizable by default and the setting reaches the page" do
    get "/users"
    assert_select "[data-infotable--table-resizable-value=true]"
    assert_select "[data-resize-label]"
  end

  test "resizable_columns false is inherited and rendered" do
    parent = Class.new(Infotable::Base) { resizable_columns false }
    child = Class.new(parent)

    assert_not parent.resizable_columns?
    assert_not child.resizable_columns?
    assert Class.new(Infotable::Base).resizable_columns?
    assert Class.new(parent) { resizable_columns true }.resizable_columns?
  end

  test "the label exists in en and pl" do
    %i[en pl].each { assert I18n.exists?("infotable.table.resize_column", _1), _1.to_s }
  end
end
