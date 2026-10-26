require "test_helper"
require "infotable/mcp"

class McpTest < ActiveSupport::TestCase
  setup { @dir = Dir.mktmpdir }
  teardown { FileUtils.rm_rf(@dir) }

  def payload(response)
    JSON.parse(response.content.first[:text])
  end

  def call(tool, **args)
    tool.call(server_context: nil, **args)
  end

  test "list_models describes models with columns and enums" do
    user = payload(call(Infotable::Mcp::ListModels)).find { _1["name"] == "User" }

    assert_equal "string", user["columns"]["name"]
    assert_equal "users", user["table"]
  end

  test "list_tables describes existing tables" do
    posts = payload(call(Infotable::Mcp::ListTables)).find { _1["class"] == "PostsTable" }

    assert_equal "Post", posts["model"]
    assert posts["columns"].any? { _1["name"] == "title" }
    assert_includes posts.keys, "no_authorize_block"
  end

  test "describe_dsl lists column options from the code" do
    dsl = payload(call(Infotable::Mcp::DescribeDsl))

    assert_equal Infotable::VERSION, dsl["version"]
    assert_equal Infotable::Base::COLUMN_OPTIONS.map(&:to_s), dsl["column_options"]
    assert_includes dsl["generate_table_options"], "per_page"
  end

  test "table_options proposes defaults from the model" do
    options = payload(call(Infotable::Mcp::TableOptions, model: "Post"))
    questions = options["questions"].index_by { _1["param"] }

    assert_equal "created_at:desc", questions["sort"]["default"]
    assert_includes questions["only"]["choices"], "title"
    assert_includes questions.keys, "authorize"
  end

  test "table_options rejects things that are not models" do
    assert_match(/not an ActiveRecord model/, call(Infotable::Mcp::TableOptions, model: "String").content.first[:text])
  end

  test "generate_table only shows the code unless write is set" do
    result = payload(call(Infotable::Mcp::GenerateTable, model: "Post", per_page: 50, sort: "title:asc", toolbar: "rail",
                                                         checkbox: true, authorize: "controller.current_user.present?"))

    assert_equal false, result["written"]
    assert_equal "app/infotable/posts_table.rb", result["path"]
    assert_match(/per_page 50/, result["code"])
    assert_match(/default_sort :title, :asc/, result["code"])
    assert_match(/toolbar :rail/, result["code"])
    assert_match(/checkbox_column/, result["code"])
    assert_match(/authorize \{ \|controller\| controller\.current_user\.present\? \}/, result["code"])
  end

  test "generate_table passes the association, formatter and title options" do
    code = payload(call(Infotable::Mcp::GenerateTable, model: "Comment", title: "Replies"))["code"]
    plain = payload(call(Infotable::Mcp::GenerateTable, model: "Product", formatters: false, associations: false))["code"]

    assert_match(/left_joins\(:post, :author\)/, code)
    assert_match(/table_title "Replies"/, code)
    assert_no_match(/formatter/, plain)
  end

  test "generate_table honors only" do
    code = payload(call(Infotable::Mcp::GenerateTable, model: "Post", only: %w[title status]))["code"]

    assert_match(/column :title/, code)
    assert_match(/column :status/, code)
    assert_no_match(/column :body/, code)
  end

  test "generate_table rejects code that does not parse" do
    response = call(Infotable::Mcp::GenerateTable, model: "Post", authorize: "controller.(")

    assert response.error?
    assert_match(/does not parse/, response.content.first[:text])
  end

  test "generate_table rejects an unknown model" do
    assert call(Infotable::Mcp::GenerateTable, model: "Nope").error?
  end

  test "TableWriter writes into the app and refuses to replace a file without overwrite" do
    Rails.stub(:root, Pathname.new(@dir)) do
      writer = Infotable::Mcp::TableWriter.new("Post")
      writer.write

      assert File.exist?(File.join(@dir, "app/infotable/posts_table.rb"))
      assert_raises(Infotable::Mcp::TableWriter::Error) { writer.write }
      assert writer.write(overwrite: true)
    end
  end

  test "validate_table passes a table and previews rows" do
    create_users
    report = payload(call(Infotable::Mcp::ValidateTable, name: "users_table", preview: 2))

    assert report["ok"]
    assert_equal 2, report["preview"].size
  end

  test "validate_table reports columns the model lacks and a bad default sort" do
    source = <<~RUBY
      class X < Infotable::Base
        query { User.all }
        column :name, type: :string
        column :nonexistent, type: :string
        default_sort :ghost
      end
    RUBY
    report = payload(call(Infotable::Mcp::ValidateTable, source: source))

    assert_equal false, report["ok"]
    assert report["problems"].any? { _1.include?(":nonexistent is not an attribute of User") }
    assert report["problems"].any? { _1.include?("default_sort :ghost") }
  end

  test "validate_table reports a failing query" do
    source = "class X < Infotable::Base\n  query { raise 'boom' }\nend"

    assert_match(/boom/, payload(call(Infotable::Mcp::ValidateTable, source: source))["problems"].first)
  end

  test "validate_table warns about a missing authorize" do
    source = "class X < Infotable::Base\n  query { User.all }\n  column :name\nend"
    report = payload(call(Infotable::Mcp::ValidateTable, source: source))

    assert report["ok"]
    assert report["problems"].any? { _1.start_with?("no authorize") }
  end

  test "an unknown table is an error, not a crash" do
    assert call(Infotable::Mcp::ValidateTable, name: "nothing_table").error?
  end

  test "the server exposes tools, the prompt and the readme" do
    server = Infotable::Mcp::Server.build
    handle = ->(method, params = {}) { JSON.parse(server.handle_json({ jsonrpc: "2.0", id: 1, method: method, params: params }.to_json))["result"] }

    assert_equal %w[describe_dsl generate_table list_models list_tables table_options validate_table], handle.("tools/list")["tools"].map { _1["name"] }.sort
    assert_equal [ "new_table" ], handle.("prompts/list")["prompts"].map { _1["name"] }
    assert_match(/Post/, handle.("prompts/get", { name: "new_table", arguments: { model: "Post" } })["messages"].first["content"]["text"])
    assert_match(/InfoTable/, handle.("resources/read", { uri: "infotable://readme" })["contents"].first["text"])
  end
end
