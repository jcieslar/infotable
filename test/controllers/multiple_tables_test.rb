require "test_helper"

# Several tables on one page (dummy home page); users and products both have name/created_at filters.
class MultipleTablesTest < ActionDispatch::IntegrationTest
  setup { get "/" }

  test "home renders several tables" do
    assert_response :success
    assert_operator Nokogiri::HTML(response.body).css("[data-controller~='infotable--table']").size, :>=, 3
  end

  test "all DOM ids are unique across tables" do
    ids = Nokogiri::HTML(response.body).xpath("//*[@id]").map { _1["id"] }
    duplicates = ids.tally.select { |_, n| n > 1 }.keys
    assert_empty duplicates
  end

  test "filter control ids carry the table name" do
    ids = Nokogiri::HTML(response.body).xpath("//*[starts-with(@id, 'filter_')]").map { _1["id"] }
    assert(ids.any? { _1.start_with?("filter_users_table_") })
    assert(ids.any? { _1.start_with?("filter_products_table_") })
  end

  test "no inline scripts (strict CSP friendly)" do
    assert_empty Nokogiri::HTML(response.body).css("body script")
  end

  test "text filter operator select is wired through the drawer controller" do
    select = Nokogiri::HTML(response.body).at_css("select[data-filter-op]")
    assert_equal "change->infotable--drawer#syncFilterOps", select["data-action"]
    assert select.ancestors("[data-filter-container]").any?
    assert select.ancestors("[data-filter-container]").first.at_css("[data-filter-value-wrapper]")
  end
end
