require "test_helper"

class CountlessTest < ActionDispatch::IntegrationTest
  setup { 12.times { |i| User.create!(name: "U#{i.to_s.rjust(2, '0')}", email: "u#{i}@x.io") } }

  def sql_during
    sqls = []
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, p| sqls << p[:sql] }
    yield
    sqls
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end

  test "countless table never issues COUNT and renders prev/next only" do
    sqls = sql_during { get "/infotable/tables/countless_table", params: { sort_column: "name" } }
    assert_response :success
    assert_empty sqls.grep(/COUNT\(/i)
    assert_includes response.body, "U00"
    assert_not_includes response.body, "U05"
    assert_no_match(/\bresults\b/, Nokogiri::HTML(response.body).at_css("p.text-sm").text)
    assert_match(/page=2/, response.body)
  end

  test "last page has no next link; page past the end falls back" do
    get "/infotable/tables/countless_table", params: { sort_column: "name", page: 3 }
    assert_includes response.body, "U10"
    assert_no_match(/page=4/, response.body)
    get "/infotable/tables/countless_table", params: { page: 99 }
    assert_response :success
  end

  test "regular tables still count" do
    sqls = sql_during { get "/infotable/tables/users_table" }
    assert_not_empty sqls.grep(/COUNT\(/i)
  end

  test "dsl" do
    assert CountlessTable.countless?
    assert_not UsersTable.countless?
    assert Class.new(CountlessTable).countless?
  end
end
