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
end
