require "test_helper"
require "infotable/mcp"

class TableEditorTest < ActiveSupport::TestCase
  SOURCE = <<~RUBY
    class EditDemoTable < Infotable::Base
      query { User.all }

      column :name,
        type: :string,
        sortable: true

      column :email, type: :string # keep me

      per_page 25
    end
  RUBY

  Error = Infotable::Mcp::TableEditor::Error

  setup do
    @dir = Dir.mktmpdir
    @file = File.join(@dir, "app/infotable/edit_demo_table.rb")
    FileUtils.mkdir_p(File.dirname(@file))
    File.write(@file, SOURCE)
    load @file
  end

  teardown do
    Object.send(:remove_const, :EditDemoTable) if Object.const_defined?(:EditDemoTable)
    FileUtils.rm_rf(@dir)
  end

  # The editor looks for the table under Rails.root/app/infotable
  def editor(write: true)
    Rails.stub(:root, Pathname.new(@dir)) { yield Infotable::Mcp::TableEditor.new("edit_demo_table", write: write) }
  end

  def source
    File.read(@file)
  end

  def column_names(src = source)
    mod = Module.new
    mod.module_eval(src.sub("EditDemoTable", "Reloaded"), "reloaded.rb")
    mod.const_get(:Reloaded).columns.map { _1[:name] }
  end

  test "add_column appends after the last column and leaves the rest alone" do
    result = editor { |e| e.add_column("age", { type: "integer", sortable: true, filterable: true, filter_type: "number" }) }

    assert result.written
    assert_includes source, "column :email, type: :string # keep me\n\n  column :age"
    assert_match(/column :age,\n    type: :integer,\n    sortable: true,\n    filterable: true,\n    filter_type: :number\n/, source)
    assert_match(/per_page 25/, source)
    assert_equal %i[name email age], column_names
    assert_match(/^\+\s+column :age,/, result.diff)
  end

  test "add_column renders strings, symbols, booleans and Ruby source" do
    editor do |e|
      e.add_column("score", { type: "decimal", label: "Score", visible: false, pinned: "left", formatter: "percent",
                              formatter_options: "{ precision: 1 }", value: "->(record) { record.age.to_f }" }, after: "name")
    end

    assert_match(/label: "Score"/, source)
    assert_match(/visible: false/, source)
    assert_match(/pinned: :left/, source)
    assert_match(/formatter: :percent/, source)
    assert_match(/value: ->\(record\) \{ record\.age\.to_f \}/, source)
    assert_equal %i[name score email], column_names
  end

  test "add_column accepts a lambda as the formatter" do
    editor { |e| e.add_column("age", { type: "integer", formatter: "->(value, record) { value.to_s }" }) }

    assert_match(/formatter: ->\(value, record\) \{ value\.to_s \}/, source)
  end

  test "nothing is written without write" do
    result = editor(write: false) { |e| e.add_column("age", { type: "integer" }) }

    assert_equal false, result.written
    assert_equal SOURCE, source
    assert_match(/\+  column :age/, result.diff)
  end

  test "add_column refuses duplicates, bad names and unknown options" do
    editor do |e|
      assert_match(/already exists/, assert_raises(Error) { e.add_column("name") }.message)
      assert_match(/not a valid column name/, assert_raises(Error) { e.add_column("Bad Name") }.message)
      assert_match(/unknown column option\(s\) sortible/, assert_raises(Error) { e.add_column("age", { sortible: true }) }.message)
      assert_match(/no column :ghost/, assert_raises(Error) { e.add_column("age", {}, after: "ghost") }.message)
    end
  end

  test "an edit that leaves the file unparsable or the table broken is refused" do
    editor do |e|
      assert_match(/unparsable/, assert_raises(Error) { e.add_column("age", { value: "->(r) {" }) }.message)
      assert_match(/column :ghost is not an attribute of User/, assert_raises(Error) { e.add_column("ghost") }.message)
    end
    assert_equal SOURCE, source
  end

  test "update_column changes existing options and adds missing ones in a multi-line column" do
    editor { |e| e.update_column("name", { sortable: false, filterable: true, filter_type: "text" }) }

    assert_match(/column :name,\n    type: :string,\n    sortable: false,\n    filterable: true,\n    filter_type: :text\n/, source)
  end

  test "update_column adds options to a one-line column and keeps its comment" do
    editor { |e| e.update_column("email", { searchable: true, label: "E-mail" }) }

    assert_includes source, %(column :email, type: :string, searchable: true, label: "E-mail" # keep me)
  end

  test "update_column adds options to a column without any" do
    File.write(@file, SOURCE.sub("column :email, type: :string # keep me", "column :email"))
    load @file
    editor { |e| e.update_column("email", { type: "string" }) }

    assert_includes source, "column :email, type: :string"
  end

  test "update_column needs a column and options" do
    editor do |e|
      assert_match(/no column :ghost; the table has name, email/, assert_raises(Error) { e.update_column("ghost", { sortable: true }) }.message)
      assert_match(/no options/, assert_raises(Error) { e.update_column("name", {}) }.message)
    end
  end

  test "remove_column deletes the statement and one blank line" do
    editor { |e| e.remove_column("name") }

    assert_equal %i[email], column_names
    assert_no_match(/\n\n\n/, source)
    assert_match(/query \{ User\.all \}\n\n  column :email/, source)
  end

  test "add_batch_action creates the block and then extends it" do
    editor { |e| e.add_batch_action("archive", url: "/users/archive", label: "Archive", method: "patch") }
    assert_match(/batch_actions do\n    action :archive, url: "\/users\/archive", label: "Archive", method: :patch\n  end\nend\n\z/, source)

    load @file
    editor { |e| e.add_batch_action("delete", url: "/users/delete", method: "delete", confirm: "Delete %{count}?", color: "danger") }
    assert_match(/action :archive, .*\n    action :delete, url: "\/users\/delete", method: :delete, confirm: "Delete %\{count\}\?", color: :danger\n  end/, source)

    load @file
    assert_equal %i[archive delete], EditDemoTable.batch_action_list.map { _1[:name] }
  end

  test "add_batch_action applies the DSL's own checks" do
    editor do |e|
      assert_match(/color must be one of/, assert_raises(Error) { e.add_batch_action("x", url: "/x", color: "pink") }.message)
      assert_match(/missing keyword: :url/, assert_raises(Error) { e.add_batch_action("x") }.message)
    end
  end

  test "set_option replaces an existing setting and adds a missing one" do
    editor { |e| e.set_option("per_page", "50") }
    editor { |e| e.set_option("toolbar", ":rail") }
    editor { |e| e.set_option("authorize", "controller.current_user.present?") }

    assert_match(/per_page 50\n/, source)
    assert_no_match(/per_page 25/, source)
    assert_match(/  toolbar :rail\n/, source)
    assert_match(/authorize \{ \|controller\| controller\.current_user\.present\? \}/, source)
  end

  test "set_option takes only known settings" do
    editor do |e|
      assert_match(/unknown setting query/, assert_raises(Error) { e.set_option("query", "{ User.destroy_all }") }.message)
    end
  end

  test "a table outside app/infotable is not edited" do
    Rails.stub(:root, Pathname.new(Dir.mktmpdir)) do
      assert_match(/outside app\/infotable/, assert_raises(Error) { Infotable::Mcp::TableEditor.new("edit_demo_table") }.message)
    end
  end

  test "the edit tools work through the server" do
    server = Infotable::Mcp::Server.build
    call = lambda do |name, arguments|
      Rails.stub(:root, Pathname.new(@dir)) do
        request = { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: name, arguments: arguments } }
        JSON.parse(server.handle_json(request.to_json))["result"]
      end
    end

    added = call.("add_column", { table: "edit_demo_table", name: "age", options: { type: "integer" }, write: true })
    assert_equal false, added["isError"]
    assert_equal %i[name email age], column_names

    load @file
    assert_equal true, call.("remove_column", { table: "edit_demo_table", name: "ghost" })["isError"]
    assert_equal false, call.("set_option", { table: "edit_demo_table", setting: "per_page", args: "10" })["isError"]
    assert_equal true, call.("add_column", { table: "nothing_table", name: "x" })["isError"]
  end
end
