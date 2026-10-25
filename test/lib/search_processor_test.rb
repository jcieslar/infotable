require "test_helper"

class SearchProcessorTest < ActiveSupport::TestCase
  setup do
    create_users
    @table = build_table do
      column :name, searchable: true
      column :email, searchable: true
      column :age, type: :integer, searchable: true
      column :company
    end
  end

  def search(term, table = @table) = Infotable::SearchProcessor.new(table.base_query, table, term).apply.order(:id).pluck(:name)

  test "matches any searchable column case insensitively" do
    assert_equal [ "Alice Smith" ], search("ALICE")
    assert_equal [ "Carol Jones" ], search("other.org")
  end

  test "non text columns are matched as text" do
    assert_equal [ "Bob_100%" ], search("45")
  end

  test "non searchable columns are ignored" do
    assert_empty search("Globex")
  end

  test "every term must match" do
    assert_equal [ "Alice Smith" ], search("alice example")
    assert_empty search("alice other")
  end

  test "wildcards and backslashes are literal" do
    assert_equal [ "Bob_100%" ], search("_100%")
    assert_equal [ "Bob_100%" ], search("%")
    assert_empty search("_x")
    assert_nothing_raised { search("a\\") }
  end

  test "blank term and tables without searchable columns are no-ops" do
    assert_equal 3, search("   ").size
    assert_equal 3, search("zzz", build_table { column :name }).size
  end

  test "sql injection is inert" do
    assert_nothing_raised { search("'; DROP TABLE users;--") }
    assert_equal 3, User.count
  end

  test "sql: expression is searched (joined column)" do
    a = Author.create!(name: "Zed")
    Post.create!(author: a, title: "t1")
    t = build_table(Post) do
      query { Post.joins(:author) }
      column :title
      column :author, sql: "authors.name", searchable: true
    end
    assert_equal 1, Infotable::SearchProcessor.new(t.base_query, t, "zed").apply.count
  end

  test "aggregate virtual columns are skipped, not crashing" do
    t = build_table { column :name, searchable: true; column :n, virtual: true, virtual_sql: "COUNT(*)", searchable: true }
    assert_nothing_raised { Infotable::SearchProcessor.new(t.base_query, t, "alice").apply.to_a }
  end
end
