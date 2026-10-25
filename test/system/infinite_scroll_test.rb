require "application_system_test_case"

class InfiniteScrollSystemTest < ApplicationSystemTestCase
  setup do
    author = Author.create!(name: "Writer", email: "writer@example.com")
    60.times { |i| Post.create!(author: author, title: "Post #{format('%02d', i)}", body: "Body", status: "published", category: "tech") }
    visit "/posts"
    wait_for_table("posts_table")
  end

  # Scrolls until the next page is in: a scroll made while the frame is about to be replaced
  # (right after a search) is lost, so it is repeated
  def scroll_until_rows(count)
    20.times do
      page.execute_script("document.querySelector('#posts_table_content .overflow-y-auto').scrollTop = 1e6")
      break if table_rows("posts_table") == count

      sleep 0.25
    end
  end

  test "scrolling loads the next page" do
    assert_equal 50, table_rows("posts_table")
    scroll_until_rows(60)
    assert_selector "turbo-frame#posts_table_content tbody tr", count: 60
  end

  test "scrolling still loads the next page after a search" do
    fill_in "search", with: "Post"
    assert_selector "turbo-frame#posts_table_content tbody tr", count: 50
    scroll_until_rows(60)
    assert_selector "turbo-frame#posts_table_content tbody tr", count: 60
  end
end
