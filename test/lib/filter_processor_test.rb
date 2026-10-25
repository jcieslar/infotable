require "test_helper"

class FilterProcessorTest < ActiveSupport::TestCase
  setup do
    create_users
    @table = build_table do
      column :name, filterable: true
      column :company, filterable: true
      column :status, filterable: true, filter_type: :select
      column :age, type: :integer, filterable: true
      column :created_at, type: :datetime, filterable: true
      column :secret, filterable: false
    end
  end

  def names(rel) = rel.order(:id).pluck(:name)

  test "no filters returns query unchanged" do
    assert_equal 3, filter(@table, {}).count
    assert_equal 3, filter(@table, nil).count
  end

  test "unknown or non filterable columns ignored" do
    assert_equal 3, filter(@table, { "nope" => { "value" => "x" }, "secret" => { "value" => "x" } }).count
  end

  test "a text filter on a number column compares its text form" do
    table = build_table do
      column :age, type: :integer, filterable: true, filter_type: :text
    end
    assert_equal [ "Alice Smith" ], names(filter(table, { "age" => { "op" => "contains", "value" => "30" } }))
    assert_equal [ "Bob_100%" ], names(filter(table, { "age" => { "op" => "exact", "value" => "45" } }))
    assert_equal 0, filter(table, { "age" => { "op" => "is_empty" } }).count
  end

  test "text contains is case insensitive" do
    assert_equal [ "Alice Smith" ], names(filter(@table, { "name" => { "op" => "contains", "value" => "alice" } }))
  end

  test "text default op is contains" do
    assert_equal [ "Alice Smith" ], names(filter(@table, { "name" => { "value" => "smith" } }))
  end

  test "text exact" do
    assert_equal [ "Alice Smith" ], names(filter(@table, { "name" => { "op" => "exact", "value" => "ALICE SMITH" } }))
    assert_empty names(filter(@table, { "name" => { "op" => "exact", "value" => "Alice" } }))
  end

  test "text not_contain" do
    assert_equal [ "Bob_100%", "Carol Jones" ], names(filter(@table, { "name" => { "op" => "not_contain", "value" => "alice" } }))
  end

  test "text starts_with and ends_with" do
    assert_equal [ "Carol Jones" ], names(filter(@table, { "name" => { "op" => "starts_with", "value" => "car" } }))
    assert_equal [ "Carol Jones" ], names(filter(@table, { "name" => { "op" => "ends_with", "value" => "JONES" } }))
  end

  test "text is_empty and is_not_empty" do
    assert_equal [ "Carol Jones" ], names(filter(@table, { "company" => { "op" => "is_empty" } }))
    assert_equal [ "Alice Smith", "Bob_100%" ], names(filter(@table, { "company" => { "op" => "is_not_empty" } }))
  end

  test "LIKE wildcards are escaped" do
    assert_equal [ "Bob_100%" ], names(filter(@table, { "name" => { "op" => "contains", "value" => "_100%" } }))
    assert_empty names(filter(@table, { "name" => { "op" => "contains", "value" => "%" } }).where(name: "Alice Smith"))
  end

  test "backslash in value does not raise" do
    assert_nothing_raised { filter(@table, { "name" => { "value" => "a\\" } }).to_a }
  end

  test "SQL injection in value is inert" do
    assert_nothing_raised { filter(@table, { "name" => { "value" => "'; DROP TABLE users;--" } }).to_a }
    assert_equal 3, User.count
  end

  test "blank value is a no-op" do
    assert_equal 3, filter(@table, { "name" => { "op" => "contains", "value" => "" } }).count
  end

  test "number range" do
    assert_equal [ "Alice Smith", "Bob_100%" ], names(filter(@table, { "age" => { "from" => "30" } }))
    assert_equal [ "Alice Smith", "Carol Jones" ], names(filter(@table, { "age" => { "to" => "30" } }))
    assert_equal [ "Alice Smith" ], names(filter(@table, { "age" => { "from" => "25", "to" => "40" } }))
  end

  test "date range includes whole to-day" do
    User.where(name: "Alice Smith").update_all(created_at: Time.zone.parse("2024-05-10 18:00"))
    User.where.not(name: "Alice Smith").update_all(created_at: Time.zone.parse("2020-01-01"))
    r = filter(@table, { "created_at" => { "from" => "2024-05-10", "to" => "2024-05-10" } })
    assert_equal [ "Alice Smith" ], names(r)
  end

  test "invalid date ignored" do
    assert_equal 3, filter(@table, { "created_at" => { "from" => "garbage" } }).count
  end

  test "select single" do
    assert_equal [ "Bob_100%" ], names(filter(@table, { "status" => { "value" => "inactive" } }))
  end

  test "select multi (array)" do
    assert_equal [ "Alice Smith", "Bob_100%" ], names(filter(@table, { "status" => %w[active inactive] }))
  end

  test "boolean filter" do
    t = build_table(Author) { column :verified, type: :boolean, filterable: true }
    Author.create!(name: "A", verified: true)
    Author.create!(name: "B", verified: false)
    Author.create!(name: "C", verified: nil)
    count = ->(v) { filter(t, { "verified" => { "value" => v } }).count }
    assert_equal 1, count.("true")
    assert_equal 1, count.("false")
    assert_equal 1, count.("is_empty")
    assert_equal 2, count.("is_not_empty")
  end

  test "multiple filters are ANDed" do
    r = filter(@table, { "status" => { "value" => "active" }, "age" => { "from" => "40" } })
    assert_empty r
  end

  test "virtual column uses HAVING with aggregate" do
    Author.create!(name: "A").tap { |a| 2.times { Post.create!(author: a, title: "p") } }
    Author.create!(name: "B")
    t = build_table(Author) do
      query { Author.left_joins(:posts).group("authors.id").select("authors.*, COUNT(posts.id) AS posts_n") }
      column :posts_n, type: :integer, filterable: true, virtual: true, virtual_sql: "COUNT(posts.id)"
    end
    assert_equal 1, filter(t, { "posts_n" => { "from" => "1" } }).to_a.size
  end
end

class SqlColumnFilterTest < ActiveSupport::TestCase
  setup do
    a = Author.create!(name: "Zed")
    b = Author.create!(name: "Amy")
    Post.create!(author: a, title: "one")
    Post.create!(author: b, title: "two")
    @table = build_table(Post) do
      query { Post.joins(:author) }
      column :author, sql: "authors.name", sort_sql: "authors.name", filterable: true, value: ->(post) { post.author.name }
      column :author_id_col, sql: "posts.author_id", filterable: true, filter_type: :select
      column :shout, virtual: true, sql: "(SELECT COUNT(*) FROM posts p2 WHERE p2.author_id = posts.author_id)", type: :integer, filterable: true
    end
  end

  test "text filter on an association column uses its SQL expression" do
    assert_equal [ "one" ], filter(@table, { "author" => { "op" => "contains", "value" => "ze" } }).pluck(:title)
  end

  test "select filter by id through sql" do
    id = Author.find_by!(name: "Amy").id
    assert_equal [ "two" ], filter(@table, { "author_id_col" => { "value" => id.to_s } }).pluck(:title)
  end

  test "non aggregate virtual column with sql uses WHERE not HAVING" do
    assert_nothing_raised { filter(@table, { "shout" => { "from" => "1" } }).to_a }
    assert_equal 2, filter(@table, { "shout" => { "from" => "1" } }).count
  end

  test "cell_value uses value proc" do
    post = Post.joins(:author).find_by!(title: "one")
    assert_equal "Zed", @table.cell_value(post, @table.columns.first)
  end
end

class FilterOperatorsTest < ActiveSupport::TestCase
  setup do
    create_users # ages 30, 45, 22
    @table = build_table do
      column :age, type: :integer, filterable: true
      column :company, type: :integer, filterable: true, filter_type: :number # nullable: Carol has nil
      column :created_at, type: :datetime, filterable: true
    end
    User.where(name: "Alice Smith").update_all(created_at: Time.zone.parse("2024-05-10 08:00"))
    User.where(name: "Bob_100%").update_all(created_at: Time.zone.parse("2024-05-10 23:30"))
    User.where(name: "Carol Jones").update_all(created_at: Time.zone.parse("2024-05-12 12:00"))
  end

  def ages(f) = filter(@table, f).order(:id).pluck(:age)
  def names(f) = filter(@table, f).order(:id).pluck(:name)

  test "number operators" do
    assert_equal [ 30 ], ages("age" => { "op" => "eq", "value" => "30" })
    assert_equal [ 45, 22 ], ages("age" => { "op" => "neq", "value" => "30" })
    assert_equal [ 45 ], ages("age" => { "op" => "gt", "value" => "30" })
    assert_equal [ 30, 45 ], ages("age" => { "op" => "gte", "value" => "30" })
    assert_equal [ 22 ], ages("age" => { "op" => "lt", "value" => "30" })
    assert_equal [ 30, 22 ], ages("age" => { "op" => "lte", "value" => "30" })
    assert_equal [ 30 ], ages("age" => { "op" => "between", "from" => "25", "to" => "40" })
  end

  test "number decimals, blank and invalid values" do
    assert_equal [ 45 ], ages("age" => { "op" => "gt", "value" => "44.5" })
    assert_equal 3, ages("age" => { "op" => "gt", "value" => "" }).size
    assert_equal 3, ages("age" => { "op" => "gt", "value" => "abc" }).size
    assert_equal 3, ages("age" => { "op" => "nonsense" }).size
  end

  test "number is_empty / is_not_empty" do
    User.where(name: "Carol Jones").update_all(age: nil)
    assert_equal [ nil ], ages("age" => { "op" => "is_empty" })
    assert_equal [ 30, 45 ], ages("age" => { "op" => "is_not_empty" })
  end

  test "date on matches the whole day" do
    assert_equal [ "Alice Smith", "Bob_100%" ], names("created_at" => { "op" => "on", "value" => "2024-05-10" })
  end

  test "date before and after are exclusive of the day" do
    assert_equal [], names("created_at" => { "op" => "before", "value" => "2024-05-10" })
    assert_equal [ "Alice Smith", "Bob_100%" ], names("created_at" => { "op" => "before", "value" => "2024-05-11" })
    assert_equal [ "Carol Jones" ], names("created_at" => { "op" => "after", "value" => "2024-05-10" })
  end

  test "date between and invalid date" do
    assert_equal [ "Carol Jones" ], names("created_at" => { "op" => "between", "from" => "2024-05-11", "to" => "2024-05-12" })
    assert_equal 3, names("created_at" => { "op" => "on", "value" => "garbage" }).size
  end

  test "date is_empty / is_not_empty on a nullable column" do
    author = Author.create!(name: "A")
    Post.create!(author: author, title: "dated", published_at: Time.zone.now)
    Post.create!(author: author, title: "draft", published_at: nil)
    t = build_table(Post) { column :published_at, type: :datetime, filterable: true }
    assert_equal [ "draft" ], filter(t, "published_at" => { "op" => "is_empty" }).pluck(:title)
    assert_equal [ "dated" ], filter(t, "published_at" => { "op" => "is_not_empty" }).pluck(:title)
  end

  test "legacy from/to without op still works" do
    assert_equal [ 45 ], ages("age" => { "from" => "40" })
  end
end

class SelectFilterTypingTest < ActiveSupport::TestCase
  setup do
    Author.create!(name: "V", verified: true)
    Author.create!(name: "U", verified: false)
    @t = build_table(Author) do
      column :verified, type: :boolean, filterable: true, filter_type: :select
      column :id, type: :integer, filterable: true, filter_type: :select
      column :name, filterable: true, filter_type: :select
    end
  end

  def names(f) = filter(@t, f).order(:id).pluck(:name)

  test "boolean select casts true/false and ignores garbage" do
    assert_equal [ "V" ], names("verified" => { "value" => "true" })
    assert_equal [ "U" ], names("verified" => { "value" => "false" })
    assert_empty names("verified" => { "value" => "[]" })
    assert_empty names("verified" => { "value" => "banana" })
  end

  test "integer select with garbage or out of range value matches nothing instead of raising" do
    id = Author.find_by!(name: "U").id
    assert_equal [ "U" ], names("id" => { "value" => id.to_s })
    assert_empty names("id" => { "value" => "abc" })
    assert_empty names("id" => { "value" => "9" * 40 })
  end

  test "multi select drops invalid values and keeps valid ones" do
    id = Author.find_by!(name: "V").id
    assert_equal [ "V" ], names("id" => [ id.to_s, "abc" ])
    assert_equal [ "V" ], names("id" => { "value" => [ id.to_s, "zzz" ] })
  end

  test "string select supports single, array and nested array" do
    assert_equal [ "V", "U" ], names("name" => [ "V", "U" ])
    assert_equal [ "V" ], names("name" => { "value" => "V" })
    assert_equal 2, names("name" => { "value" => [ "", nil ] }).size
  end
end

class SelectFilterOnSqlColumnTest < ActiveSupport::TestCase
  test "sql column declared as string but backed by an integer is compared as text" do
    a = Author.create!(name: "A")
    Post.create!(author: a, title: "mine")
    t = build_table(Post) { column :author, sql: "posts.author_id", filterable: true, filter_type: :select }
    assert_equal [ "mine" ], filter(t, "author" => { "value" => a.id.to_s }).pluck(:title)
    assert_empty filter(t, "author" => "NaN")
  end
end
