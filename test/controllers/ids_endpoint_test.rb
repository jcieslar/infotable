require "test_helper"

class IdsEndpointTest < ActionDispatch::IntegrationTest
  setup do
    author = Author.create!(name: "A")
    @posts = 5.times.map { |i| Post.create!(author: author, title: i == 1 ? "Zebra crossing" : "Post #{i}", status: i.even? ? "published" : "draft") }
  end

  teardown { Infotable.reset_configuration! }

  def ids(params = {})
    get "/infotable/tables/posts_table/ids", params: params
    assert_response :success
    JSON.parse(response.body)
  end

  test "returns every matching id as strings" do
    body = ids
    assert_equal @posts.map { _1.id.to_s }.sort, body["ids"].sort
    assert_equal false, body["truncated"]
  end

  test "applies the same filters and search as the table" do
    published = @posts.select { _1.status == "published" }.map { _1.id.to_s }.sort

    assert_equal published, ids(filters: { status: { value: "published" } })["ids"].sort
    assert_equal [ @posts[1].id.to_s ], ids(search: "Zebra")["ids"]
  end

  test "ignores paging, so it reaches past the visible page" do
    assert_equal 5, ids(per_page: 2, page: 2)["ids"].size
  end

  test "is capped by max_select_all and says so" do
    Infotable.configuration.max_select_all = 3
    body = ids
    assert_equal 3, body["ids"].size
    assert body["truncated"]
  end

  test "a capped selection is the first rows in the table's order" do
    Infotable.configuration.max_select_all = 2
    body = ids(sort_column: "title", sort_direction: "desc")
    assert_equal [ @posts[1].id.to_s, @posts[4].id.to_s ], body["ids"]
  end

  test "exactly at the cap is not truncated" do
    Infotable.configuration.max_select_all = 5
    body = ids
    assert_equal 5, body["ids"].size
    assert_equal false, body["truncated"]
  end

  test "no cap when max_select_all is nil" do
    Infotable.configuration.max_select_all = nil
    assert_equal 5, ids["ids"].size
  end

  test "tables without checkboxes have no ids endpoint" do
    get "/infotable/tables/users_table/ids"
    assert_response :not_found
  end

  test "respects authorize" do
    get "/infotable/tables/forbidden_table/ids"
    assert_response :forbidden
  end

  test "an id method that is not a column falls back to reading the records" do
    table = Class.new(Infotable::Base) do
      query { Post.all }
      column :title
      checkbox_column id_method: :to_param
    end

    assert_equal @posts.map { _1.id.to_s }.sort, table.checkbox_ids(Post.all).map(&:to_s).sort
  end

  test "the frame carries the total for the select-all-matching button" do
    get "/infotable/tables/posts_table", params: { per_page: 2 }
    assert_equal "5", Nokogiri::HTML(response.body).at_css("[data-total-count]")&.[]("data-total-count")
  end

  test "countless tables carry no total" do
    get "/infotable/tables/countless_table"
    assert_response :success
    assert_nil Nokogiri::HTML(response.body).at_css("[data-total-count]")&.[]("data-total-count")
  end
end
