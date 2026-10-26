require "application_system_test_case"

class ColumnPinningTest < ApplicationSystemTestCase
  setup do
    author = Author.create!(name: "Ann")
    Post.create!(author: author, title: "Hello")
  end

  def header_names
    page.evaluate_script("Array.from(document.querySelectorAll('thead th[data-column-name]')).map(th => th.dataset.columnName)")
  end

  def left_of(name)
    page.evaluate_script("document.querySelector('thead th[data-column-name=\"#{name}\"]').getBoundingClientRect().left")
  end

  test "columns pinned left move to the left edge in order, with no gap" do
    visit "/posts"
    wait_for_table("posts_table")
    page.execute_script(%(localStorage.setItem("infotable_column_pinned_posts_table", JSON.stringify({ id: "left", category: "left", title: "left" }))))
    visit "/posts"
    wait_for_table("posts_table")

    assert_selector "thead th.infotable-pinned-left", minimum: 3
    assert_equal %w[id title category], header_names.first(3)
    id_right = page.evaluate_script("document.querySelector('thead th[data-column-name=\"id\"]').getBoundingClientRect().right")
    assert_in_delta id_right, left_of("title"), 1
    assert_equal "left", page.evaluate_script("document.querySelector('tbody td[data-column-name=\"category\"]').classList.contains('infotable-pinned-left') ? 'left' : ''")
  end

  test "unpinning restores the original column order" do
    visit "/posts"
    wait_for_table("posts_table")
    original = header_names
    page.execute_script(%(localStorage.setItem("infotable_column_pinned_posts_table", JSON.stringify({ id: "left", category: "left" }))))
    visit "/posts"
    wait_for_table("posts_table")
    assert_selector "thead th.infotable-pinned-left", minimum: 2
    assert_not_equal original, header_names

    page.execute_script(%(localStorage.setItem("infotable_column_pinned_posts_table", JSON.stringify({ id: "left", category: "" }))))
    visit "/posts"
    wait_for_table("posts_table")
    assert_selector "thead th.infotable-pinned-left", count: 1
    assert_equal original, header_names
  end

  test "columns pinned right move to the right edge, side by side" do
    visit "/posts"
    wait_for_table("posts_table")
    page.execute_script(%(localStorage.setItem("infotable_column_pinned_posts_table", JSON.stringify({ category: "right", actions: "right" }))))
    visit "/posts"
    wait_for_table("posts_table")

    assert_selector "thead th.infotable-pinned-right", minimum: 2
    assert_equal %w[category actions], header_names.last(2)
    category_right = page.evaluate_script("document.querySelector('thead th[data-column-name=\"category\"]').getBoundingClientRect().right")
    assert_in_delta category_right, left_of("actions"), 1
  end

  # Moves `name` before `before` in the columns drawer list, like a drag would, and fires the reorder
  def drag_column(name, before:)
    page.execute_script(<<~JS)
      const el = document.querySelector('[data-controller~="infotable--drawer"]')
      const c = (window.Stimulus || window.application).getControllerForElementAndIdentifier(el, "infotable--drawer")
      const list = document.querySelector('[data-infotable--drawer-target="columnList"]')
      const item = list.querySelector('.column-item[data-column-name="#{name}"]')
      list.insertBefore(item, list.querySelector('.column-item[data-column-name="#{before}"]'))
      c.handleColumnReorder("posts_table", list, item)
    JS
  end

  def pinned
    JSON.parse(page.evaluate_script("localStorage.getItem('infotable_column_pinned_posts_table')"))
  end

  def pin_columns_left(*names)
    visit "/posts"
    wait_for_table("posts_table")
    page.execute_script(%(localStorage.setItem("infotable_column_pinned_posts_table", JSON.stringify(#{names.index_with { "left" }.to_json}))))
    visit "/posts"
    wait_for_table("posts_table")
    assert_selector "thead th.infotable-pinned-left", minimum: names.size
  end

  test "reordering pinned columns among themselves keeps them pinned" do
    pin_columns_left "id", "category"
    drag_column "category", before: "id"

    assert_equal %w[category id], header_names.first(2)
    assert_equal "left", pinned["category"]
    assert_equal "left", pinned["id"]
  end

  test "dragging a pinned column out of the pinned zone unpins it" do
    pin_columns_left "id", "category"
    drag_column "id", before: "status"

    assert_nil pinned["id"]
    assert_equal "left", pinned["category"]
    assert_selector "thead th.infotable-pinned-left", count: 1
  end

  test "dragging an unpinned column into the pinned zone pins it" do
    pin_columns_left "id", "category"
    drag_column "status", before: "category"

    assert_equal "left", pinned["status"]
    assert_equal %w[id status category], header_names.first(3)
  end
end
