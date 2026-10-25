require "test_helper"

class ActiveFiltersTest < ActionView::TestCase
  include Infotable::TablesHelper

  def chips(filters, search = nil, table: UsersTable)
    infotable_active_filters(table, filters, search)
  end

  def texts(filters, search = nil)
    chips(filters, search).map { _1[:text] }
  end

  test "no filters, no chips" do
    assert_empty chips({})
    assert_empty chips(nil)
    assert_empty chips("garbage")
  end

  test "blank inputs are not active" do
    assert_empty chips({ "name" => { "op" => "contains", "value" => "" }, "age" => { "op" => "", "from" => "", "to" => "" }, "status" => { "value" => "" } })
  end

  test "text filters show the operator and the value" do
    assert_equal [ "Contains “bob”" ], texts({ "name" => { "op" => "contains", "value" => "bob" } })
    assert_equal [ "Starts with “A”" ], texts({ "name" => { "op" => "starts_with", "value" => "A" } })
    assert_equal [ "Contains “x”" ], texts({ "name" => { "value" => "x" } })
  end

  test "is_empty is active without a value" do
    assert_equal [ "Is empty" ], texts({ "name" => { "op" => "is_empty" } })
  end

  test "number ranges and comparisons" do
    assert_equal [ "30 – 45" ], texts({ "age" => { "from" => "30", "to" => "45" } })
    assert_equal [ "≥ 30" ], texts({ "age" => { "from" => "30" } })
    assert_equal [ "≤ 45" ], texts({ "age" => { "to" => "45" } })
    assert_equal [ "≥ 45" ], texts({ "age" => { "op" => "gte", "value" => "45" } })
    assert_equal [ "≠ 7" ], texts({ "age" => { "op" => "neq", "value" => "7" } })
    assert_equal [ "30 – 45" ], texts({ "age" => { "op" => "between", "from" => "30", "to" => "45" } })
    assert_equal [ "Is empty" ], texts({ "score" => { "op" => "is_empty" } })
  end

  test "date comparisons use the operator labels" do
    assert_equal [ "Before 2024-01-01" ], texts({ "created_at" => { "op" => "before", "value" => "2024-01-01" } })
    assert_equal [ "2024-01-01 – 2024-02-01" ], texts({ "created_at" => { "from" => "2024-01-01", "to" => "2024-02-01" } })
  end

  test "select values are listed, several joined" do
    assert_equal [ "active" ], texts({ "status" => { "value" => "active" } })
    assert_equal [ "active, pending" ], texts({ "status" => { "value" => [ "active", "", "pending" ] } })
  end

  test "chips carry the column name, type and label for removal" do
    chip = chips({ "age" => { "from" => "30" } }).first
    assert_equal({ name: "age", type: "number", label: "Age" }, chip.slice(:name, :type, :label))
  end

  test "the search is a chip of its own, first" do
    list = chips({ "age" => { "from" => "30" } }, "bob")
    assert list.first[:search]
    assert_equal "Search: “bob”", list.first[:text]
    assert_equal 2, list.size
  end

  test "columns that are not filterable and tampered values are ignored" do
    assert_empty chips({ "id" => { "value" => "1" }, "nope" => { "value" => "x" }, "age" => "oops", "name" => { "value" => [ "a" ] } })
  end

  test "labels exist in en and pl" do
    %i[en pl].each do |locale|
      %w[active.search active.remove active.clear_all].each { assert I18n.exists?("infotable.filters.#{_1}", locale), "#{locale} #{_1}" }
      %w[filtered_title filtered_description].each { assert I18n.exists?("infotable.table.empty_state.#{_1}", locale), "#{locale} #{_1}" }
    end
  end
end
