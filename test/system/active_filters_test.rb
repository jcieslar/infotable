require "application_system_test_case"

class ActiveFiltersTest < ApplicationSystemTestCase
  setup do
    create_users
    visit "/users"
    wait_for_table("users_table")
  end

  def names(count)
    page.document.synchronize do
      list = all("turbo-frame#users_table_content tbody tr td strong").map(&:text)
      raise Capybara::ExpectationNotMet, "expected #{count} rows, got #{list.inspect}" unless list.size == count

      list
    end
  end

  def open_filters
    find("button[data-action*='infotable--drawer#open']").click
  end

  def chip(name)
    "[data-active-filter='#{name}']"
  end

  test "filtering in the drawer shows a chip and removing it restores the rows and the drawer" do
    open_filters
    find("select[name='filters[age][op]']").select "Greater than or equal"
    find("input[name='filters[age][value]']").fill_in with: "30"

    assert_selector chip("age"), text: "≥ 30"
    assert_equal [ "Alice Smith", "Bob_100%" ], names(2).sort

    find("#{chip('age')} button").click
    assert_no_selector chip("age")
    names(3)
    assert_equal "", find("input[name='filters[age][value]']", visible: :all).value
    assert_equal "", find("select[name='filters[age][op]']", visible: :all).value
  end

  test "the search has a chip too" do
    fill_in "search", with: "alice"
    assert_selector chip("search"), text: "alice"
    names(1)

    find("#{chip('search')} button").click
    assert_no_selector chip("search")
    names(3)
    assert_equal "", find("input[name='search']").value
  end

  test "clear all drops the search and every filter but keeps the sort" do
    find("turbo-frame#users_table_content th a", text: "Name", exact_text: true).click
    fill_in "search", with: "a"
    open_filters
    find("input[name='filters[age][from]']").fill_in with: "25"
    assert_selector chip("age")
    assert_selector chip("search")

    find("[data-clear-all-filters]").click
    assert_no_selector "[data-active-filters]"
    names(3)
    assert_equal "", find("input[name='search']").value
    assert_equal "", find("input[name='filters[age][from]']", visible: :all).value
    assert_selector "th a[aria-sort]"
  end

  test "an empty result offers a clear filters button" do
    fill_in "search", with: "zzzz-nothing"
    assert_text "No rows match your filters"

    find("[data-empty-clear-filters]").click
    assert_no_text "No rows match your filters"
    names(3)
    assert_equal "", find("input[name='search']").value
  end

  test "a shared link shows the chips" do
    visit "/users?users_table[filters][age][from]=45&users_table[search]=bob"
    wait_for_table("users_table")

    assert_selector chip("age"), text: "≥ 45"
    assert_selector chip("search"), text: "bob"
  end
end
