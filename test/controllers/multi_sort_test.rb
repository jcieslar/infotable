require "test_helper"

class MultiSortTest < ActionDispatch::IntegrationTest
  setup do
    User.create!(name: "B", email: "1@x.io", status: "active", age: 30)
    User.create!(name: "A", email: "2@x.io", status: "active", age: 40)
    User.create!(name: "C", email: "3@x.io", status: "inactive", age: 20)
  end

  def order_clause(params)
    sqls = []
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, p| sqls << p[:sql] if p[:sql] =~ /FROM "users"/ && p[:sql] =~ /ORDER BY/ }
    get "/infotable/tables/users_table", params: params
    assert_response :success
    sqls.first[/ORDER BY (.*?)( LIMIT|\z)/m, 1]
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  def names(params)
    get "/infotable/tables/users_table/export", params: params.merge(visible_columns: "name")
    CSV.parse(response.body).drop(1).flatten
  end

  test "sort param orders by several columns in sequence, then pk" do
    assert_equal "users.status asc, users.age desc, users.id ASC", order_clause(sort: "status:asc,age:desc").downcase.sub("users.id asc", "users.id ASC")
    assert_equal %w[A B C], names(sort: "status:asc,age:desc")
    assert_equal %w[B A C], names(sort: "status:asc,age:asc")
  end

  test "legacy sort_column still works and sort wins when both are given" do
    assert_equal %w[A B C], names(sort_column: "name")
    assert_equal %w[C B A], names(sort_column: "name", sort_direction: "desc")
    assert_equal %w[C B A], names(sort: "name:desc", sort_column: "name", sort_direction: "asc")
  end

  test "invalid entries are dropped, duplicates ignored, capped at three" do
    assert_equal %w[A B C], names(sort: "nope:asc,name:asc,name:desc,;;,age:bogus")
    clause = order_clause(sort: "name:asc,age:asc,status:asc,id:asc,email:asc")
    assert_equal 3, clause.scan(/users\.(name|age|status|id|email) /i).size - clause.scan(/users\.id ASC/).size.clamp(0, 1)
  end

  test "sort by pk does not add a duplicate tiebreaker" do
    assert_equal 1, order_clause(sort: "id:desc").scan(/users\.id/i).size
  end

  test "header shows order numbers for multiple sorts and links keep sort" do
    get "/infotable/tables/users_table", params: { sort: "status:asc,age:desc", per_page: 2 }
    doc = Nokogiri::HTML(response.body)
    assert_equal %w[1 2], doc.css("thead th a span.text-\\[10px\\]").map { _1.text.strip }
    assert_equal "ascending", doc.at_css('thead th a[data-sort-column="status"]')["aria-sort"]
    assert_equal "descending", doc.at_css('thead th a[data-sort-column="age"]')["aria-sort"]
    pager = doc.css("a[href*='/data?']").map { CGI.unescape(CGI.unescapeHTML(_1["href"])) }
    assert(pager.any? { _1.include?("page=2") && _1.include?("sort=status:asc,age:desc") })
  end

  test "plain header click link replaces the multi sort" do
    get "/infotable/tables/users_table", params: { sort: "status:asc,age:desc" }
    href = CGI.unescape(CGI.unescapeHTML(Nokogiri::HTML(response.body).at_css('thead th a[data-sort-column="name"]')["href"]))
    assert_includes href, "sort_column=name"
    assert_not_includes href, "sort=status"
  end

  test "malformed sort params never 500" do
    [ "sort[]=a", "sort[a]=b", "sort=", "sort=:", "sort=name", "sort=name:", "sort=%00" ].each do |qs|
      get "/infotable/tables/users_table?#{qs}"
      assert_response :success, qs
    end
  end
end
