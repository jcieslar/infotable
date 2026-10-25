require "test_helper"

class ActiveFiltersRenderTest < ActionDispatch::IntegrationTest
  setup { create_users }

  def doc(params = {})
    get "/infotable/tables/users_table", params: params
    Nokogiri::HTML(response.body)
  end

  test "no chips bar without filters" do
    assert_nil doc.at_css("[data-active-filters]")
  end

  test "an active filter renders a removable chip" do
    chip = doc(filters: { age: { from: "30" } }).at_css("[data-active-filter='age']")

    assert chip
    assert_includes chip.text, "≥ 30"
    button = chip.at_css("button")
    assert_equal "click->infotable--drawer#clearSingleFilter", button["data-action"]
    assert_equal "age", button["data-filter-name"]
    assert_equal "number", button["data-filter-type"]
    assert_match(/Remove filter Age/, button["aria-label"])
  end

  test "search gets a chip wired to clearSearch" do
    button = doc(search: "alice").at_css("[data-active-filter='search'] button")
    assert_equal "click->infotable--table#clearSearch", button["data-action"]
  end

  test "clear all appears from two chips on" do
    assert_nil doc(search: "alice").at_css("[data-clear-all-filters]")
    assert doc(search: "alice", filters: { age: { from: "1" } }).at_css("[data-clear-all-filters]")
  end

  test "chip values are escaped" do
    html = doc(filters: { name: { op: "contains", value: "<script>alert(1)</script>" } }).at_css("[data-active-filters]").to_html
    assert_not_includes html, "<script>"
  end

  test "an empty result with filters offers to clear them" do
    page = doc(search: "zzzz-nothing")

    assert page.at_css("[data-empty-clear-filters]")
    assert_includes page.text, "No rows match your filters"
  end

  test "an empty table without filters keeps the plain empty state" do
    User.delete_all
    page = doc

    assert_nil page.at_css("[data-empty-clear-filters]")
    assert_includes page.text, "No data found"
  end

  test "filters on columns that are not filterable do not make chips or change the empty state" do
    User.delete_all
    page = doc(filters: { id: { value: "1" } })

    assert_nil page.at_css("[data-active-filters]")
    assert_includes page.text, "No data found"
  end
end
