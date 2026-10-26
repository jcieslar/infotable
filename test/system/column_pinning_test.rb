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
end
