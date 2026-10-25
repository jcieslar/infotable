require "test_helper"

# User-controlled text must never reach the page unescaped, in any dummy table.
class XssTest < ActionDispatch::IntegrationTest
  EVIL = "<img src=x onerror=alert(1)>".freeze

  setup do
    author = Author.create!(name: EVIL, bio: EVIL, country: EVIL, email: EVIL, website: "javascript:alert(1)", verified: true)
    post = Post.create!(author: author, title: EVIL, category: EVIL, status: EVIL, body: EVIL)
    Comment.create!(post: post, author: author, body: EVIL, status: EVIL)
    User.create!(name: EVIL, email: "#{SecureRandom.hex(3)}@x.io", company: EVIL, status: EVIL)
    Product.create!(name: EVIL, sku: EVIL, description: EVIL, category: EVIL, manufacturer: EVIL, rating: 3, price: 1, stock_quantity: 1)
  end

  %w[users_table products_table authors_table posts_table comments_table].each do |name|
    test "#{name} escapes user data" do
      get "/infotable/tables/#{name}", params: { per_page: 50 }
      assert_response :success
      assert_not_includes response.body, EVIL, "#{name} rendered raw HTML"
      assert_includes response.body, "&lt;img", "#{name} should still show the (escaped) value"
    end
  end

  test "author website with javascript: scheme is not linked" do
    get "/infotable/tables/authors_table", params: { per_page: 50 }
    assert_no_match(/href=["']javascript:/i, response.body)
  end
end
