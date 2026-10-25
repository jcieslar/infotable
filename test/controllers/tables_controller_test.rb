require "test_helper"

class TablesControllerTest < ActionDispatch::IntegrationTest
  include Infotable::Engine.routes.url_helpers

  setup do
    @routes = Infotable::Engine.routes
    create_users
    40.times { |i| User.create!(name: "User #{i}", email: "u#{i}@x.io", status: "active", age: 20 + i) }
  end

  def path(name = "users_table", action = "", **params)
    "/infotable/tables/#{name}#{action}?#{params.to_query}"
  end

  test "show renders table" do
    get path(per_page: 100)
    assert_response :success
    assert_includes response.body, "Alice Smith"
  end

  test "unknown table is 404" do
    get path("nope_table")
    assert_response :not_found
  end

  test "non table constant is 404 not 500" do
    get path("user_table")
    assert_response :not_found
  end

  test "class that is not an Infotable::Base is 404" do
    get path("not_a_table")
    assert_response :not_found
  end

  test "multi word table name is served" do
    get path("order_items_table")
    assert_response :success
  end

  test "authorize block denies show, data and export" do
    %w[ /infotable/tables/forbidden_table /infotable/tables/forbidden_table/data /infotable/tables/forbidden_table/export ].each do |url|
      get url
      assert_response :forbidden, url
    end
  end

  test "authorize block allows when passing" do
    get "/infotable/tables/forbidden_table?let_me_in=1"
    assert_response :success
  end

  test "pagination respects per_page" do
    get path(per_page: 5, sort_column: "id", sort_direction: "asc")
    assert_response :success
    assert_equal 5, response.body.scan(/user-\d+/).uniq.size.clamp(0, 5)
  end

  test "sorting asc and desc" do
    get path(sort_column: "name", sort_direction: "asc", per_page: 100)
    assert_operator response.body.index("Alice Smith"), :<, response.body.index("Carol Jones")
    get path(sort_column: "name", sort_direction: "desc", per_page: 100)
    assert_operator response.body.index("Carol Jones"), :<, response.body.index("Alice Smith")
  end

  test "sort by non sortable or injected column is ignored" do
    get path(sort_column: "id; DROP TABLE users", sort_direction: "asc")
    assert_response :success
    assert_equal 43, User.count
  end

  test "invalid sort direction falls back" do
    get path(sort_column: "name", sort_direction: "sideways")
    assert_response :success
  end

  test "filters apply" do
    get path("users_table", "", filters: { name: { op: "exact", value: "Alice Smith" } })
    assert_response :success
    assert_includes response.body, "Alice Smith"
    assert_not_includes response.body, "Carol Jones"
  end

  test "bad per_page does not 500" do
    %w[abc 0 -1].each do |v|
      get path(per_page: v)
      assert_response :success, "per_page=#{v}"
    end
  end

  test "huge per_page is capped" do
    get path(per_page: 10_000_000)
    assert_response :success
  end

  test "page past the end does not 500" do
    get path(page: 9999)
    assert_response :success
  end

  test "filters as string does not 500" do
    get "/infotable/tables/users_table?filters=oops"
    assert_response :success
  end

  test "filter value as array does not 500" do
    get "/infotable/tables/users_table?filters[name][op]=exact&filters[name][value][]=a&filters[name][value][]=b"
    assert_response :success
  end

  test "data turbo_stream appends rows" do
    get path("users_table", "/data", page: 2), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "export csv" do
    get path("users_table", "/export")
    assert_response :success
    assert_equal "text/csv; charset=utf-8", response.headers["Content-Type"]
    rows = CSV.parse(response.body)
    assert_equal 43 + 1, rows.size
    assert_includes rows.first, "Name"
  end

  test "export applies filters" do
    get path("users_table", "/export", filters: { status: { value: "inactive" } })
    rows = CSV.parse(response.body)
    assert_equal 2, rows.size
  end

  test "export applies sorting" do
    get path("users_table", "/export", sort_column: "name", sort_direction: "desc", visible_columns: "name")
    names = CSV.parse(response.body).drop(1).flatten
    assert_equal "User 9", names.first
    assert_equal "Alice Smith", names.last
  end

  test "export neutralizes formula injection" do
    User.create!(name: "=HYPERLINK(\"http://x\")", email: "f@x.io")
    get path("users_table", "/export", visible_columns: "name")
    cell = CSV.parse(response.body).flatten.find { |c| c.to_s.include?("HYPERLINK") }
    assert_no_match(/\A[=+\-@]/, cell)
  end

  test "export filename is quoted" do
    get path("users_table", "/export")
    assert_match(/filename="users_table_\d+_\d+\.csv"/, response.headers["Content-Disposition"])
  end
end

class TablesStateTest < ActionDispatch::IntegrationTest
  setup do
    create_users
    40.times { |i| User.create!(name: "User #{i}", email: "u#{i}@x.io", status: "active", age: 20 + i) }
  end

  test "sort and pagination links keep filters" do
    get "/infotable/tables/users_table", params: { filters: { status: { value: "active" } }, per_page: 5 }
    assert_response :success
    links = response.body.scan(/href="([^"]+)"/).flatten.map { |h| CGI.unescapeHTML(h) }
    state_links = links.select { |l| l.include?("/data?") }
    assert_operator state_links.size, :>, 0
    state_links.each { |l| assert_includes CGI.unescape(l), "filters[status][value]=active", l }
  end

  test "per page select carries filters" do
    get "/infotable/tables/users_table", params: { filters: { status: { value: "active" } } }
    query = CGI.unescapeHTML(response.body[/data-current-query="([^"]+)"/, 1])
    assert_includes CGI.unescape(query), "filters[status][value]=active"
  end
end

class PerPageSelectTest < ActionDispatch::IntegrationTest
  def options_for(url)
    get url
    response.body.scan(/<option value="(\d+)"/).flatten.map(&:to_i)
  end

  test "selector uses the table's per_page_options" do
    assert_equal [ 5, 10, 25, 50 ], options_for("/infotable/tables/users_table")
  end

  test "current per_page missing from options is still offered and selected" do
    assert_equal [ 10, 15, 25 ], options_for("/infotable/tables/odd_per_page_table")
    assert_match(/<option value="15" selected/, response.body)
  end
end

class RowLinkTest < ActionDispatch::IntegrationTest
  test "row link renders valid data attributes" do
    user = User.create!(name: "Row", email: "row@x.io")
    get "/infotable/tables/linked_rows_table"
    row = Nokogiri::HTML(response.body).at_css("tr[data-row-link]")
    assert row, "row has data-row-link"
    assert_equal "/users/#{user.id}?a=1&b='2'", row["data-row-link"]
    assert_equal "click->infotable--table#handleRowClick", row["data-action"]
  end
end

class PinnedColumnsTest < ActionDispatch::IntegrationTest
  test "headers expose default pinned side" do
    User.create!(name: "P", email: "p@x.io")
    get "/infotable/tables/pinned_table"
    doc = Nokogiri::HTML(response.body)
    assert_equal "left", doc.at_css('th[data-column-name="id"]')["data-default-pinned"]
    assert_equal "right", doc.at_css('th[data-column-name="email"]')["data-default-pinned"]
    assert_nil doc.at_css('th[data-column-name="name"]')["data-default-pinned"]
  end
end

class StablePaginationTest < ActionDispatch::IntegrationTest
  setup { 12.times { |i| User.create!(name: "Same", email: "s#{i}@x.io", status: "active") } }

  def order_sql(url)
    sqls = []
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, p| sqls << p[:sql] if p[:sql] =~ /FROM "users"/ && p[:sql] =~ /ORDER BY/ }
    get url
    sqls.first[/ORDER BY.*?(LIMIT|\z)/m, 0]
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  test "sorting by a non unique column adds primary key tiebreaker" do
    sql = order_sql("/infotable/tables/users_table?sort_column=status&sort_direction=desc")
    assert_match(/users\.status desc, users\.id ASC/i, sql)
  end

  test "sorting by the primary key does not duplicate it" do
    sql = order_sql("/infotable/tables/users_table?sort_column=id")
    assert_equal 1, sql.scan(/users\.id/i).size
  end

  test "every row appears exactly once across pages" do
    ids = (1..3).flat_map do |page|
      get "/infotable/tables/users_table", params: { sort_column: "status", per_page: 5, page: page }
      Nokogiri::HTML(response.body).css("tbody tr").map { |tr| tr.at_css('td[data-column-name="email"]')&.text&.strip }
    end
    assert_equal 12, ids.compact.uniq.size
  end

  test "export orders with tiebreaker too" do
    get "/infotable/tables/users_table/export", params: { sort_column: "status", visible_columns: "id" }
    ids = CSV.parse(response.body).drop(1).flatten.map(&:to_i)
    assert_equal ids.sort, ids
  end
end

class SqlColumnSortTest < ActionDispatch::IntegrationTest
  setup do
    a = Author.create!(name: "Zed"); b = Author.create!(name: "Amy")
    Post.create!(author: a, title: "one"); Post.create!(author: b, title: "two")
  end

  test "sorting by association column does not 500 and orders by joined name" do
    get "/infotable/tables/assoc_posts_table?sort_column=author&sort_direction=asc"
    assert_response :success
    assert_operator response.body.index("Amy"), :<, response.body.index("Zed")
  end

  test "export uses value proc" do
    get "/infotable/tables/assoc_posts_table/export?sort_column=author&visible_columns=author"
    assert_equal [ "Amy", "Zed" ], CSV.parse(response.body).drop(1).flatten
  end
end

class SearchRequestTest < ActionDispatch::IntegrationTest
  setup { create_users }

  test "search filters rows" do
    get "/infotable/tables/users_table", params: { search: "alice", per_page: 50 }
    assert_includes response.body, "Alice Smith"
    assert_not_includes response.body, "Carol Jones"
  end

  test "search combines with filters" do
    get "/infotable/tables/users_table", params: { search: "o", filters: { status: { value: "pending" } }, per_page: 50 }
    assert_includes response.body, "Carol Jones"
    assert_not_includes response.body, "Bob_100"
  end

  test "pagination and sort links keep search" do
    40.times { |i| User.create!(name: "Findme #{i}", email: "f#{i}@x.io") }
    get "/infotable/tables/users_table", params: { search: "findme", per_page: 5 }
    links = response.body.scan(/href="([^"]+\/data\?[^"]+)"/).flatten.map { CGI.unescape(CGI.unescapeHTML(_1)) }
    assert_operator links.size, :>, 0
    links.each { assert_includes _1, "search=findme" }
  end

  test "export honours search" do
    get "/infotable/tables/users_table/export", params: { search: "alice", visible_columns: "name" }
    assert_equal [ [ "Alice Smith" ] ], CSV.parse(response.body).drop(1)
  end

  test "search input shown only when table has searchable columns" do
    get "/users"
    assert_select "input[type=search][name=search]"
  end

  test "array or hash search param does not 500" do
    get "/infotable/tables/users_table?search[]=a&search[]=b"
    assert_response :success
    get "/infotable/tables/users_table?search[a]=b"
    assert_response :success
  end
end

class PagyV43Test < ActionDispatch::IntegrationTest
  setup { 25.times { |i| User.create!(name: "N#{i.to_s.rjust(2, '0')}", email: "n#{i}@x.io") } }

  test "page past the end falls back to the first page's rows" do
    get "/infotable/tables/users_table", params: { page: 9999, per_page: 5, sort_column: "name" }
    assert_response :success
    assert_includes response.body, "N00"
  end

  test "pagination footer shows range, total and prev/next on a middle page" do
    get "/infotable/tables/users_table", params: { page: 2, per_page: 5, sort_column: "name" }
    text = Nokogiri::HTML(response.body).at_css("p.text-sm").text.squish
    assert_equal "Showing 6 to 10 of 25 results", text
    hrefs = Nokogiri::HTML(response.body).css("a[href*='/data?']").map { CGI.unescape(CGI.unescapeHTML(_1["href"])) }
    assert(hrefs.any? { _1.include?("page=1") })
    assert(hrefs.any? { _1.include?("page=3") })
  end

  test "empty table reports zero rows without error" do
    User.delete_all
    get "/infotable/tables/users_table"
    assert_response :success
  end

  test "per_page above the cap is limited to 500 rows" do
    get "/infotable/tables/users_table", params: { per_page: 100_000 }
    assert_response :success
  end
end

class RowAttributesTest < ActionDispatch::IntegrationTest
  setup do
    author = Author.create!(name: "A")
    post = Post.create!(author: author, title: "p")
    @flagged = Comment.create!(post: post, author: author, body: "x", flagged: true)
    @plain = Comment.create!(post: post, author: author, body: "y", flagged: false)
  end

  def row(record)
    get "/infotable/tables/comments_table"
    Nokogiri::HTML(response.body).at_css("tr##{ActionView::RecordIdentifier.dom_id(record)}")
  end

  test "rows get a dom_id" do
    assert row(@flagged), "tr#comment_#{@flagged.id}"
  end

  test "row_class and row_data decorate the row" do
    assert_includes row(@flagged)["class"], "bg-amber-50/60"
    assert_not_includes row(@plain)["class"], "bg-amber-50/60"
    assert_equal @flagged.id.to_s, row(@flagged)["data-comment-id"]
    assert_equal @flagged.author_id.to_s, row(@flagged)["data-author-id"]
  end

  test "clickable rows keep the link and the click action" do
    r = row(@flagged)
    assert_equal "#comment-#{@flagged.id}", r["data-row-link"]
    assert_equal "click->infotable--table#handleRowClick", r["data-action"]
    assert_includes r["class"], "cursor-pointer"
  end

  test "rows of other tables have an id but no click action" do
    User.create!(name: "u", email: "u@x.io")
    get "/infotable/tables/users_table"
    r = Nokogiri::HTML(response.body).at_css("tbody tr")
    assert r["id"].start_with?("user_")
    assert_nil r["data-action"]
    assert_not_includes r["class"], "cursor-pointer"
  end
end
