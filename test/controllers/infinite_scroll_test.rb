require "test_helper"

class InfiniteScrollTest < ActionDispatch::IntegrationTest
  setup do
    author = Author.create!(name: "A")
    5.times { |i| Post.create!(author: author, title: "Post #{i}", status: "draft") }
  end

  test "the lazy next-page frame is rendered when the first page is requested explicitly" do
    get "/infotable/tables/posts_table", params: { per_page: 2, page: 1 }
    assert_response :success
    assert_select "turbo-frame#posts_table_pagination[src]"
  end

  test "a stream request past the last page appends nothing and ends the list" do
    get "/infotable/tables/posts_table/data", params: { per_page: 2, page: 99 }, as: :turbo_stream
    assert_response :success
    assert_no_match(/<tr/, response.body)
    assert_match(/posts_table_pagination/, response.body)
  end

  test "the lazy next-page frame survives a sort and a search" do
    get "/infotable/tables/posts_table", params: { per_page: 2, page: 1, sort_column: "title", sort_direction: "desc", search: "Post" }
    assert_select "turbo-frame#posts_table_pagination[src]"
  end
end
