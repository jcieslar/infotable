require "application_system_test_case"

class RowClickTest < ApplicationSystemTestCase
  setup do
    author = Author.create!(name: "A")
    post = Post.create!(author: author, title: "p")
    @comment = Comment.create!(post: post, author: author, body: "hello", flagged: false)
  end

  def click_row
    wait_for_table("comments_table")
    find("tr#comment_#{@comment.id} td", match: :first).click
  end

  test "a row click fires infotable:row-click with the row's data, then follows the link" do
    visit "/comments"
    wait_for_table("comments_table")
    page.execute_script(<<~JS)
      window.rowClicks = []
      document.addEventListener("infotable:row-click", e => window.rowClicks.push(e.detail))
    JS

    click_row

    clicks = page.evaluate_script("window.rowClicks")
    assert_equal 1, clicks.size
    assert_equal "comment_#{@comment.id}", clicks.first["id"]
    assert_equal "#comment-#{@comment.id}", clicks.first["url"]
    assert_equal @comment.id.to_s, clicks.first["data"]["commentId"]
    assert_equal "#comment-#{@comment.id}", page.evaluate_script("location.hash")
  end

  test "preventDefault() on the event stops the fallback to the link" do
    visit "/comments"
    wait_for_table("comments_table")
    page.execute_script('document.addEventListener("infotable:row-click", e => e.preventDefault())')

    click_row

    assert_equal "", page.evaluate_script("location.hash")
  end
end
