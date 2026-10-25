require "test_helper"

# Smoke test: every dummy table renders, sorts by each sortable column and exports.
class DummyTablesTest < ActionDispatch::IntegrationTest
  setup do
    author = Author.create!(name: "Ann", verified: true)
    post = Post.create!(author: author, title: "Hello", status: "published", featured: true, views_count: 3)
    Comment.create!(post: post, author: author, body: "hi", status: "approved", likes_count: 1, flagged: false)
    User.create!(name: "U", email: "u@x.io")
    Product.create!(name: "P", sku: "S1", price: 1, active: true)
  end

  %w[users_table products_table authors_table posts_table comments_table cms_users_table cms_admins_users_table].each do |name|
    test "#{name} renders, sorts and exports" do
      klass = Infotable::TableResolver.resolve(name)
      get "/infotable/tables/#{name}"
      assert_response :success, "#{name} show"

      klass.sortable_columns.each do |col|
        get "/infotable/tables/#{name}", params: { sort_column: col[:name], sort_direction: "desc" }
        assert_response :success, "#{name} sort by #{col[:name]}"
      end

      get "/infotable/tables/#{name}/export"
      assert_response :success, "#{name} export"
    end
  end
end
