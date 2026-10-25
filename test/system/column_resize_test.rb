require "application_system_test_case"

class ColumnResizeTest < ApplicationSystemTestCase
  setup do
    create_users
    visit "/users"
    wait_for_table("users_table")
  end

  def header(name) = find("turbo-frame#users_table_content th[data-column-name='#{name}']")

  def width(name)
    page.evaluate_script("document.querySelector(\"turbo-frame#users_table_content th[data-column-name='#{name}']\").getBoundingClientRect().width").round
  end

  def cell_width(name)
    page.evaluate_script("document.querySelector(\"turbo-frame#users_table_content tbody td[data-column-name='#{name}']\").getBoundingClientRect().width").round
  end

  def stored
    JSON.parse(page.evaluate_script("localStorage.getItem('infotable_column_widths_users_table')") || "{}")
  end

  def handle(name) = find("turbo-frame#users_table_content th[data-column-name='#{name}'] [data-resize-handle]", visible: :all)

  def center(name)
    handle(name) # handles are added right after the frame loads: wait for it
    page.evaluate_script("(() => { const r = document.querySelector(\"th[data-column-name='#{name}'] [data-resize-handle]\").getBoundingClientRect(); return [r.x + r.width / 2, r.y + r.height / 2] })()")
  end

  def drag(name, by:)
    box = center(name)
    page.driver.browser.mouse.move(x: box[0], y: box[1])
    page.driver.browser.mouse.down
    page.driver.browser.mouse.move(x: box[0] + by, y: box[1], steps: 5)
    page.driver.browser.mouse.up
  end

  test "every column header has a separator handle" do
    assert_selector "turbo-frame#users_table_content th[data-column-name] [data-resize-handle]", minimum: 1, visible: :all
    handles = all("turbo-frame#users_table_content th[data-column-name] [data-resize-handle]", visible: :all)
    assert_equal all("turbo-frame#users_table_content th[data-column-name]").size, handles.size
    assert_equal "separator", handles.first[:role]
    assert_equal "0", handles.first[:tabindex]
  end

  test "dragging the handle widens the column and its cells and remembers it" do
    before = width("name")
    drag("name", by: 80)

    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "width #{width('name')}" unless width("name") == before + 80
    end
    assert_equal width("name"), cell_width("name")
    assert_equal before + 80, stored["name"]
  end

  test "the width survives a reload" do
    drag("email", by: 60)
    wide = nil
    page.document.synchronize { wide = stored["email"] || raise(Capybara::ExpectationNotMet, "not stored yet") }

    visit "/users"
    wait_for_table("users_table")
    page.document.synchronize { raise Capybara::ExpectationNotMet, "got #{width('email')}" unless width("email") == wide }
    assert_equal wide, cell_width("email")
  end

  test "a column cannot be dragged below the minimum" do
    drag("age", by: -2000)
    page.document.synchronize { raise Capybara::ExpectationNotMet, width("age").to_s unless width("age") == 60 }
  end

  test "arrow keys resize the focused handle and double-click resets" do
    before = width("company")
    handle("company")
    page.execute_script("document.querySelector(\"th[data-column-name='company'] [data-resize-handle]\").focus()")
    page.driver.browser.keyboard.type(:Right)
    page.document.synchronize { raise Capybara::ExpectationNotMet, width("company").to_s unless width("company") == before + 10 }
    assert_equal before + 10, stored["company"]

    box = center("company")
    page.driver.browser.mouse.click(x: box[0], y: box[1], count: 2)
    page.document.synchronize { raise Capybara::ExpectationNotMet, width("company").to_s unless width("company") == before }
    assert_nil stored["company"]
  end

  test "using the handle does not sort the column" do
    drag("name", by: 30)
    sleep 0.3
    assert_no_selector "th[data-column-name='name'] a[aria-sort]"
    assert_no_selector "th a[aria-sort='ascending'], th a[aria-sort='descending']"
  end

  test "widths are kept after the rows reload" do
    drag("name", by: 50)
    wide = nil
    page.document.synchronize { wide = stored["name"] || raise(Capybara::ExpectationNotMet, "not stored") }

    fill_in "search", with: "a"
    page.document.synchronize do
      raise Capybara::ExpectationNotMet, "got #{width('name')}" unless width("name") == wide
    end
    assert_selector "[data-resize-handle]", count: all("th[data-column-name]").size, visible: :all
  end
end
