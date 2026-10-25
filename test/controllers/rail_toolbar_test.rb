require "test_helper"

class RailToolbarTest < ActionDispatch::IntegrationTest
  test "rail tables hide the header bar and render the rail" do
    get "/authors"
    doc = Nokogiri::HTML(response.body)

    assert_nil doc.at_css("h2.text-xl"), "header title should be gone"
    assert doc.at_css("aside button[data-action*='infotable--drawer#toggleFilters']")
    assert doc.at_css("aside button[data-action*='infotable--drawer#toggleColumns']")
    assert doc.at_css("aside a[data-infotable--table-target=exportButton][href*='/export']")
    assert doc.at_css("aside button[data-action*='infotable--table#refresh']")
  end

  test "rail tables move the search box into the drawer" do
    get "/authors"
    doc = Nokogiri::HTML(response.body)

    assert_equal 1, doc.css("input[type=search][name=search]").size
    assert doc.at_css("[role=dialog] input[type=search][name=search]")
  end

  test "the filter badge shows the active filter columns from the URL" do
    get "/authors", params: { authors_table: { filters: { name: { op: "contains", value: "a" } } } }
    doc = Nokogiri::HTML(response.body)

    badge = doc.at_css("[data-infotable--table-target=filterCount]")
    assert_equal "1", badge.text.strip
    assert_no_match(/\bhidden\b/, badge["class"])
  end

  test "the filter badge is hidden without filters" do
    get "/authors"

    assert_match(/\bhidden\b/, Nokogiri::HTML(response.body).at_css("[data-infotable--table-target=filterCount]")["class"])
  end

  test "header tables are unchanged" do
    get "/users"
    doc = Nokogiri::HTML(response.body)

    assert doc.at_css("h2.text-xl")
    assert_nil doc.at_css("aside[aria-label]")
  end
end
