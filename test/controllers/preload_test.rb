require "test_helper"

class PreloadTest < ActionDispatch::IntegrationTest
  setup do
    5.times do |i|
      a = Author.create!(name: "Au#{i}")
      p = Post.create!(author: a, title: "T#{i}")
      Comment.create!(post: p, author: a, body: "b")
    end
  end

  def selects_from(table, url)
    sqls = []
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, p| sqls << p[:sql] if p[:sql] =~ /FROM "#{table}"/ }
    get url, params: { per_page: 50 }
    assert_response :success
    sqls.size
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  test "includes: preloads the association once instead of per row" do
    # authors: once for post.author, once for comments.author - not once per row
    assert_equal 2, selects_from("authors", "/infotable/tables/preloaded_posts_table")
    assert_equal 1, selects_from("comments", "/infotable/tables/preloaded_posts_table")
  end

  test "without includes: the table does one query per row (guards the test itself)" do
    assert_operator selects_from("authors", "/infotable/tables/n_plus_one_posts_table"), :>=, 5
  end

  test "export preloads too" do
    sqls = []
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, p| sqls << p[:sql] if p[:sql] =~ /FROM "authors"/ }
    get "/infotable/tables/preloaded_posts_table/export"
    assert_equal 2, sqls.size
    assert_equal 6, CSV.parse(response.body).size
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  test "preloads are deduplicated and inherited" do
    t = build_table(Post) { column :a, includes: :author; column :b, includes: [ :author, :comments ] }
    assert_equal [ :author, :comments ], t.preloads
    assert_equal [ :author, :comments ], Class.new(t).preloads
  end
end
