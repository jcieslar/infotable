require "application_system_test_case"

class TableInteractionsTest < ApplicationSystemTestCase
  setup do
    create_users
    visit "/users"
    wait_for_table("users_table")
  end

  # Cells are moved around right after a frame load, so retry if a node goes stale
  def names
    page.document.synchronize { all("turbo-frame#users_table_content table tbody tr td strong").map(&:text) }
  end

  def open_filters
    find("button[data-action*='infotable--drawer#open']").click
  end

  # Filters apply after a debounce, so retry until the rows settle
  def assert_names(expected)
    page.document.synchronize do
      actual = names.sort
      raise Capybara::ExpectationNotMet, "expected #{expected.inspect}, got #{actual.inspect}" unless actual == expected.sort
    end
  end

  def header(label)
    find("turbo-frame#users_table_content th a", text: label, exact_text: true)
  end

  test "global search narrows the rows and clearing it restores them" do
    fill_in "search", with: "carol"
    assert_selector "turbo-frame#users_table_content tbody tr", count: 1
    assert_text "Carol Jones"
    assert_no_text "Alice Smith"

    fill_in "search", with: ""
    assert_selector "turbo-frame#users_table_content tbody tr", count: 3
  end

  test "clicking a header sorts ascending then descending" do
    header("Name").click
    assert_selector "th[aria-sort], th a[aria-sort='ascending']"
    assert_equal [ "Alice Smith", "Bob_100%", "Carol Jones" ], names

    header("Name").click
    assert_selector "th a[aria-sort='descending']"
    assert_equal [ "Carol Jones", "Bob_100%", "Alice Smith" ], names
  end

  test "shift-click adds a second sort column" do
    header("Name").click
    assert_selector "th a[aria-sort='ascending']"

    header("Age").click(:shift)
    assert_selector "th a[aria-sort]", count: 2
    assert_includes page.find("turbo-frame#users_table_content")[:src].to_s + current_url, "sort"
  end

  test "filter drawer opens, filters the rows and clears" do
    drawer = find("[role=dialog]", visible: :all)
    assert_equal "true", drawer["aria-hidden"]

    open_filters
    assert_selector "[role=dialog]:not([aria-hidden='true'])"

    within("[role=dialog]") do
      find("input[name='filters[name][value]']").fill_in with: "Bob"
    end
    assert_selector "turbo-frame#users_table_content tbody tr", count: 1
    assert_text "Bob_100%"

    within("[role=dialog]") { click_button "Clear All" }
    assert_selector "turbo-frame#users_table_content tbody tr", count: 3
  end

  test "text operator hides the value input for is_empty" do
    open_filters
    within("[role=dialog]") do
      select "Is empty", from: "filters[company][op]" if has_select?("filters[company][op]")
      op = find("select[name='filters[name][op]']")
      op.select "Is empty"
      assert_selector "[data-filter-value-wrapper].hidden, [data-filter-value-wrapper][hidden], [data-filter-value-wrapper][style*='none']", visible: :all
    end
  end

  test "escape closes the drawer" do
    open_filters
    assert_selector "[role=dialog]:not([aria-hidden='true'])"

    find("body").send_keys(:escape)
    assert_selector "[role=dialog][aria-hidden='true']", visible: :all
  end

  test "per-page selector changes the page size" do
    30.times { |i| User.create!(name: "Extra #{i}", email: "extra#{i}@example.com", status: "active", age: 20, salary: 1000) }
    visit "/users"
    wait_for_table("users_table")

    select "10", from: "per_page_users_table"
    assert_selector "turbo-frame#users_table_content tbody tr", count: 10
    click_link "Next", match: :first
    assert_selector "turbo-frame#users_table_content tbody tr", count: 10
  end

  test "number operator swaps the range inputs for one value input" do
    open_filters
    within("[role=dialog]") do
      assert_selector "input[name='filters[age][from]']"
      assert_no_selector "input[name='filters[age][value]']"

      find("select[name='filters[age][op]']").select "Greater than or equal"
      assert_no_selector "input[name='filters[age][from]']"
      find("input[name='filters[age][value]']").fill_in with: "30"
    end

    assert_names [ "Alice Smith", "Bob_100%" ]
  end

  test "is_empty on a number column hides every input and matches nulls" do
    open_filters
    within("[role=dialog]") do
      find("select[name='filters[score][op]']").select "Is empty"
      assert_no_selector "input[name='filters[score][from]']"
      assert_no_selector "input[name='filters[score][value]']"
    end

    assert_names [ "Carol Jones" ]
  end

  test "date operator offers a single date and clearing goes back to the range" do
    open_filters
    within("[role=dialog]") do
      find("select[name='filters[created_at][op]']").select "Before"
      assert_selector "input[name='filters[created_at][value]'][type=date]"
      find("input[name='filters[created_at][value]']").fill_in with: "2000-01-01"
    end
    assert_names []

    within("[role=dialog]") { click_button "Clear All" }
    assert_names [ "Alice Smith", "Bob_100%", "Carol Jones" ]
    within("[role=dialog]") { assert_selector "input[name='filters[created_at][from]']" }
  end

  test "the export link carries the columns in the user's on-screen order and without hidden ones" do
    order = %w[email name id]
    headers = all("turbo-frame#users_table_content th[data-column-name]", visible: :all).map { _1["data-column-name"] }
    page.execute_script("localStorage.setItem('infotable_column_order_users_table', JSON.stringify(#{(order + (headers - order)).to_json}))")
    page.execute_script("localStorage.setItem('infotable_columns_users_table', JSON.stringify({ id: false }))")
    visit "/users"
    wait_for_table("users_table")

    href = nil
    page.document.synchronize do
      href = find("a[href*='/export']")[:href]
      raise Capybara::ExpectationNotMet, href unless href.include?("visible_columns=email")
    end
    columns = Rack::Utils.parse_query(URI.parse(href).query)["visible_columns"].split(",")
    assert_equal %w[email name], columns.first(2)
    assert_not_includes columns, "id"
  end
end
