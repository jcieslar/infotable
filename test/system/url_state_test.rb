require "application_system_test_case"

class UrlStateTest < ApplicationSystemTestCase
  setup do
    create_users
    30.times { |i| User.create!(name: "Extra #{format('%02d', i)}", email: "extra#{i}@example.com", status: "active", age: 20 + i, salary: 1000) }
  end

  def query
    Rack::Utils.parse_nested_query(URI.parse(current_url).query.to_s)
  end

  # The address bar is updated after the frame loads, so wait for it
  def assert_state(*path, expected)
    deadline = Time.now + 6
    sleep 0.05 until query.dig(*path) == expected || Time.now > deadline
    message = "users_table state #{path.inspect} in #{current_url}"
    expected.nil? ? assert_nil(query.dig(*path), message) : assert_equal(expected, query.dig(*path), message)
  end

  # The table controller moves cells around right after a frame load (column order, pinning),
  # so read the names in a retry loop instead of trusting a single snapshot
  def names(expected_count)
    page.document.synchronize do
      list = all("turbo-frame#users_table_content tbody tr td strong").map(&:text)
      raise Capybara::ExpectationNotMet, "expected #{expected_count} names, got #{list.inspect}" unless list.size == expected_count

      list
    end
  end

  def open_filters
    find("button[data-action*='infotable--drawer#open']").click
  end

  def row_count
    all("turbo-frame#users_table_content tbody tr").size
  end

  test "search, sort and page are written to the address bar under the table's name" do
    visit "/users"
    wait_for_table("users_table")
    assert_empty query

    fill_in "search", with: "extra"
    assert_selector "turbo-frame#users_table_content tbody tr", minimum: 1
    assert_state("users_table", "search", "extra")

    find("turbo-frame#users_table_content th a", text: "Name", exact_text: true).click
    assert_selector "th a[aria-sort='ascending']"
    assert_state("users_table", "sort_column", "name")
    assert_state("users_table", "sort_direction", "asc")
  end

  test "opening a shared link restores search, filters, sort and the drawer form" do
    visit "/users?users_table[search]=extra&users_table[sort_column]=name&users_table[sort_direction]=desc&users_table[filters][age][from]=45"
    wait_for_table("users_table")

    assert_equal [ "Extra 29", "Extra 28", "Extra 27", "Extra 26", "Extra 25" ], names(5)
    assert_equal "extra", find("input[name='search']").value
    assert_selector "th a[aria-sort='descending']"

    open_filters
    assert_equal "45", find("input[name='filters[age][from]']", visible: :all).value
  end

  test "changing a filter after opening a shared link keeps the other filters" do
    visit "/users?users_table[filters][age][from]=45"
    wait_for_table("users_table")
    open_filters

    find("input[name='filters[name][value]']").fill_in with: "Extra 3"
    assert_state("users_table", "filters", "name", "value", "Extra 3")
    assert_equal "45", query.dig("users_table", "filters", "age", "from")
  end

  test "reloading the page keeps the table state" do
    visit "/users"
    wait_for_table("users_table")
    select "10", from: "per_page_users_table"
    assert_selector "turbo-frame#users_table_content tbody tr", count: 10
    click_link "Next", match: :first
    assert_state("users_table", "page", "2")
    assert_state("users_table", "per_page", "10")

    page.refresh
    wait_for_table("users_table")
    assert_equal 10, row_count
    assert_selector "[aria-current='page']", text: "2"
  end

  test "Back returns to the previous table state" do
    visit "/users"
    wait_for_table("users_table")
    fill_in "search", with: "carol"
    assert_selector "turbo-frame#users_table_content tbody tr", count: 1
    assert_state("users_table", "search", "carol")

    page.go_back
    wait_for_table("users_table")
    assert_selector "turbo-frame#users_table_content tbody tr", minimum: 10
    assert_state("users_table", "search", nil)
    assert_equal "", find("input[name='search']").value
  end

  test "garbage in the URL does not break the page" do
    [ "users_table=oops", "users_table[page]=abc&users_table[filters]=1&users_table[sort_column][]=x",
      "users_table[filters][age][from]=NaN&users_table[per_page]=99999999999" ].each do |garbage|
      visit "/users?#{garbage}"
      wait_for_table("users_table")
      assert_selector "turbo-frame#users_table_content tbody tr", minimum: 1
    end
  end
end
