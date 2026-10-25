require "test_helper"

class QuerySqlTest < ActionDispatch::IntegrationTest
  setup do
    create_users # Alice 30 active, Bob 45 inactive, Carol 22 pending (excluded by the SQL)
    User.create!(name: "Dave", email: "d@x.io", status: "active", age: 10)
  end

  def names(params, endpoint = "/export")
    get "/infotable/tables/sql_source_table#{endpoint}", params: params.merge(visible_columns: "name")
    CSV.parse(response.body).drop(1).flatten
  end

  test "base_query is a relation over the SQL" do
    assert_equal %w[Alice\ Smith Bob_100% Dave].sort, SqlSourceTable.base_query.pluck(:name).sort
  end

  test "renders and paginates" do
    get "/infotable/tables/sql_source_table", params: { sort_column: "name" }
    assert_response :success
    assert_includes response.body, "Alice Smith"
    assert_not_includes response.body, "Dave"
    assert_not_includes response.body, "Carol"
  end

  test "filters, search, sort and export all work" do
    assert_equal [ "Dave" ], names(filters: { name: { value: "dav" } })
    assert_equal [ "Bob_100%" ], names(search: "bob")
    assert_equal [ "Bob_100%", "Alice Smith", "Dave" ], names(sort_column: "double_age", sort_direction: "desc")
    assert_equal [ "Bob_100%" ], names(filters: { double_age: { from: "70" } })
  end

  test "model: is required" do
    assert_raises(ArgumentError) { Class.new(Infotable::Base) { query_sql "SELECT 1" } }
    assert_raises(ArgumentError) { Class.new(Infotable::Base) { query_sql "SELECT 1", model: "users" } }
  end
end
