require "test_helper"

class GroupedQueryTest < ActionDispatch::IntegrationTest
  setup do
    5.times do |i|
      a = Author.create!(name: "Author #{i}")
      i.times { Post.create!(author: a, title: "p") }
    end
  end

  test "grouped query paginates" do
    get "/infotable/tables/author_stats_table", params: { sort_column: "name" }
    assert_response :success
    assert_includes response.body, "Author 0"
    assert_not_includes response.body, "Author 4"
    get "/infotable/tables/author_stats_table", params: { sort_column: "name", page: 3 }
    assert_includes response.body, "Author 4"
  end

  test "HAVING filter on aggregate with pagination" do
    get "/infotable/tables/author_stats_table", params: { filters: { posts_n: { from: "3" } }, sort_column: "name" }
    assert_response :success
    assert_includes response.body, "Author 3"
    assert_not_includes response.body, "Author 2"
  end

  test "sort by aggregate" do
    get "/infotable/tables/author_stats_table", params: { sort_column: "posts_n", sort_direction: "desc" }
    assert_response :success
    assert_includes response.body, "Author 4"
  end

  test "export" do
    get "/infotable/tables/author_stats_table/export", params: { visible_columns: "name" }
    assert_equal 6, CSV.parse(response.body).size
  end
end
