require "test_helper"

class UrlStateRenderTest < ActionDispatch::IntegrationTest
  def frame_src(path)
    get path
    Nokogiri::HTML(response.body).at_css("turbo-frame[id=users_table_content]")["src"]
  end

  def frame_params(path)
    Rack::Utils.parse_nested_query(URI.parse(frame_src(path)).query.to_s)
  end

  test "the frame starts from the state in the page URL" do
    params = frame_params("/users?users_table[search]=ann&users_table[page]=2&users_table[per_page]=10" \
                          "&users_table[sort_column]=name&users_table[sort_direction]=desc" \
                          "&users_table[filters][age][from]=30&users_table[filters][name][op]=contains&users_table[filters][name][value]=a")

    assert_equal "ann", params["search"]
    assert_equal "2", params["page"]
    assert_equal "10", params["per_page"]
    assert_equal "name", params["sort_column"]
    assert_equal "desc", params["sort_direction"]
    assert_equal({ "age" => { "from" => "30" }, "name" => { "op" => "contains", "value" => "a" } }, params["filters"])
  end

  test "the search box and the export link carry the state" do
    get "/users?users_table[search]=ann&users_table[filters][age][from]=30"
    doc = Nokogiri::HTML(response.body)

    assert_equal "ann", doc.at_css("input[name=search]")["value"]
    export = Rack::Utils.parse_nested_query(URI.parse(doc.at_css("a[download]")["href"]).query)
    assert_equal "ann", export["search"]
    assert_equal "30", export.dig("filters", "age", "from")
  end

  test "without state the frame src has no params" do
    assert_nil URI.parse(frame_src("/users")).query
  end

  test "other tables' state and unknown keys are ignored" do
    params = frame_params("/users?products_table[search]=zzz&users_table[evil]=1&users_table[table_name]=x&search=top")

    assert_empty params.except("table_name")
  end

  test "malformed state is dropped instead of breaking the page" do
    [ "users_table=oops", "users_table[search][]=a", "users_table[filters]=1", "users_table[page][a]=1" ].each do |query|
      get "/users?#{query}"
      assert_response :success, query
    end
  end

  test "values are stripped of NUL bytes and capped" do
    params = frame_params("/users?users_table[search]=#{'x' * 2000}%00y")

    assert_operator params["search"].size, :<=, 500
    assert_not_includes params["search"], "\u0000"
  end

  test "the state is escaped where it is rendered" do
    get "/users?users_table[search]=%22%3E%3Cscript%3Ealert(1)%3C/script%3E"

    assert_not_includes response.body, "<script>alert(1)</script>"
    assert_equal '"><script>alert(1)</script>', Nokogiri::HTML(response.body).at_css("input[name=search]")["value"]
  end

  test "tables render url_state? into the controller" do
    get "/users"
    assert_equal "true", Nokogiri::HTML(response.body).at_css("[data-controller~='infotable--table']")["data-infotable--table-url-state-value"]
  end
end

class UrlStateSettingTest < ActiveSupport::TestCase
  teardown { Infotable.reset_configuration! }

  test "on by default and configurable globally" do
    assert build_table.url_state?
    Infotable.configuration.url_state = false
    assert_not build_table.url_state?
  end

  test "a table overrides the global setting and subclasses inherit it" do
    table = build_table { url_state false }
    assert_not table.url_state?
    assert_not Class.new(table).url_state?

    Infotable.configuration.url_state = false
    assert build_table { url_state true }.url_state?
  end
end
