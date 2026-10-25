require "test_helper"

class ExportColumnsTest < ActionDispatch::IntegrationTest
  setup { create_users }

  def header(url, params = {})
    get url, params: params
    assert_response :success
    CSV.parse(response.body).first
  end

  test "export follows the order of visible_columns, not the table's" do
    assert_equal %w[Email Name], header("/infotable/tables/users_table/export", visible_columns: "email,name")
    assert_equal %w[Name Email], header("/infotable/tables/users_table/export", visible_columns: "name,email")
  end

  test "cells follow the header order" do
    get "/infotable/tables/users_table/export", params: { visible_columns: "email,name", sort_column: "name", sort_direction: "asc" }
    assert_equal [ "alice@example.com", "Alice Smith" ], CSV.parse(response.body)[1]
  end

  test "unknown and repeated names are dropped" do
    assert_equal %w[Name], header("/infotable/tables/users_table/export", visible_columns: "name,nope,name,password")
  end

  test "without a usable list the visible columns are exported in table order" do
    default = header("/infotable/tables/users_table/export")
    assert_equal default, header("/infotable/tables/users_table/export", visible_columns: "nope")
    assert_includes default, "Name"
  end

  test "action columns are never exported, even when requested" do
    columns = header("/infotable/tables/users_export_table/export", visible_columns: "name,actions")
    assert_equal %w[Name], columns
  end

  test "export_columns sets the default list and its order" do
    assert_equal %w[Email Name Company], header("/infotable/tables/users_export_table/export")
  end

  test "export_columns is also the pool: other columns cannot be requested" do
    assert_equal %w[Name], header("/infotable/tables/users_export_table/export", visible_columns: "name,age,id")
  end

  test "a user can narrow and reorder inside the export_columns pool" do
    assert_equal %w[Company Email], header("/infotable/tables/users_export_table/export", visible_columns: "company,email")
  end

  test "exportable false keeps a column out" do
    assert_not_includes header("/infotable/tables/users_export_table/export"), "Age"
  end

  test "export_columns with an unknown column raises a helpful error" do
    table = Class.new(Infotable::Base) do
      query { User.all }
      column :name
      export_columns :name, :typo
    end

    error = assert_raises(ArgumentError) { table.columns_for_export }
    assert_match(/unknown or non-exportable column :typo/, error.message)
  end

  test "values are still neutralized against formula injection" do
    User.create!(name: "=1+1", email: "x@example.com")
    get "/infotable/tables/users_table/export", params: { visible_columns: "name" }
    assert_includes response.body, "'=1+1"
  end
end
