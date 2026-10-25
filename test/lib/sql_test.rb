require "test_helper"

class SqlTest < ActiveSupport::TestCase
  Connection = Struct.new(:adapter_name)

  test "PostgreSQL gets ILIKE" do
    assert_equal "name ILIKE ?", Infotable::Sql.like(Connection.new("PostgreSQL"), "name")
    assert_equal "NOT name ILIKE ?", Infotable::Sql.like(Connection.new("PostgreSQL"), "name", negate: true)
  end

  test "SQLite gets LIKE with an explicit escape character" do
    assert_equal "name LIKE ? ESCAPE '\\'", Infotable::Sql.like(Connection.new("SQLite"), "name")
  end
end
