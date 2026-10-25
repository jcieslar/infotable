require "test_helper"

class BaseTest < ActiveSupport::TestCase
  test "column defaults" do
    t = build_table { column :name }
    col = t.columns.first
    assert_equal :name, col[:name]
    assert_equal "name", col[:label]
    assert_equal :string, col[:type]
    assert_equal "200px", col[:width]
    assert_equal true, col[:visible]
    assert_equal false, col[:sortable]
    assert_equal false, col[:filterable]
    assert_equal false, col[:searchable]
  end

  test "column label from underscore name and custom width" do
    t = build_table { column :first_name, width: "50px", type: :boolean }
    assert_equal "first name", t.columns.first[:label]
    assert_equal "50px", t.columns.first[:width]
  end

  test "default widths by type" do
    t = build_table do
      column :a, type: :boolean
      column :b, type: :date
      column :c, type: :datetime
      column :d, type: :integer
      column :e, type: :text
    end
    assert_equal %w[80px 120px 180px 100px 300px], t.columns.map { |c| c[:width] }
  end

  test "column collections" do
    t = build_table do
      column :a, sortable: true
      column :b, filterable: true, visible: false
      column :c, searchable: true
      column :d, virtual: true, virtual_sql: "COUNT(*)"
    end
    assert_equal [ :a ], t.sortable_columns.map { |c| c[:name] }
    assert_equal [ :b ], t.filterable_columns.map { |c| c[:name] }
    assert_equal [ :c ], t.searchable_columns.map { |c| c[:name] }
    assert_equal [ :d ], t.virtual_columns.map { |c| c[:name] }
    assert_equal [ :a, :c, :d ], t.visible_columns.map { |c| c[:name] }
    assert_equal [ :a, :b, :c ], t.regular_columns.map { |c| c[:name] }
  end

  test "pagination, sort, heights" do
    t = build_table do
      per_page 5
      per_page_options [ 5, 10 ]
      default_sort :name, :desc
      table_min_height "100px"
      table_max_height "200px"
    end
    assert_equal 5, t.pagination_settings[:per_page]
    assert_equal [ 5, 10 ], t.pagination_settings[:per_page_options]
    assert_equal({ column: :name, direction: :desc }, t.sort_settings)
    assert_equal "100px", t.min_height
    assert_equal "200px", t.max_height
  end

  test "heights fall back to global config" do
    t = build_table
    assert_equal Infotable.configuration.table_min_height, t.min_height
    assert_equal Infotable.configuration.table_max_height, t.max_height
  end

  test "infinite scroll, filters button, titles" do
    t = build_table do
      infinite_scroll true
      show_filters_button false
      table_title "T"
      table_subtitle "S"
    end
    assert t.infinite_scroll_enabled?
    assert_not t.filters_button_visible?
    assert_equal "T", t.title
    assert_equal "S", t.subtitle
  end

  test "toolbar defaults to the header and accepts :rail" do
    assert_equal :header, build_table.toolbar_mode
    assert_not build_table.rail_toolbar?
    assert build_table { toolbar :rail }.rail_toolbar?
  end

  test "toolbar rejects unknown modes" do
    assert_raises(ArgumentError) { build_table { toolbar :sidebar } }
  end

  test "row_link with proc and string" do
    user = User.new(id: 3)
    t = build_table { row_link ->(r) { "/u/#{r.id}" } }
    assert t.row_link_enabled?
    assert_equal "/u/3", t.row_link_url(user)
    assert_not build_table.row_link_enabled?
  end

  test "row_size" do
    assert_equal :default, build_table.row_size_value
    assert_equal :slim, build_table { row_size :slim }.row_size_value
    assert_raises(ArgumentError) { build_table { row_size :huge } }
  end

  test "nil and empty placeholders" do
    assert_equal "-", build_table.nil_value_placeholder
    t = build_table do
      nil_value "n/a"
      empty_value "empty"
    end
    assert_equal "n/a", t.nil_value_placeholder
    assert_equal "empty", t.empty_value_placeholder
  end

  test "base_query uses query block" do
    create_users
    assert_equal 3, build_table.base_query.count
  end

  test "base_query without query raises" do
    klass = Class.new(Infotable::Base)
    assert_raises(StandardError) { klass.base_query }
  end

  test "subclass settings are isolated" do
    a = build_table { per_page 3 }
    b = build_table
    assert_equal 3, a.pagination_settings[:per_page]
    assert_not_equal 3, b.pagination_settings[:per_page]
  end

  test "subclass of a table inherits parent columns" do
    parent = build_table { column :name }
    child = Class.new(parent)
    assert_equal [ :name ], child.columns.map { |c| c[:name] }
  end

  test "multi select option is stored" do
    t = build_table { column :status, filter_type: :select, filter_multi_select: true }
    assert t.columns.first[:filter_multi_select]
  end
end

class BaseAuthorizationTest < ActiveSupport::TestCase
  test "query block receives context" do
    ctx = Struct.new(:scope).new(:ctx)
    seen = nil
    t = build_table { query { |c| seen = c; User.all } }
    t.base_query(ctx)
    assert_same ctx, seen
  end

  test "zero-arity query block still works" do
    assert_nothing_raised { build_table.base_query(Object.new) }
  end

  test "authorized by default" do
    assert build_table.authorized?
  end

  test "authorize block decides" do
    t = build_table { authorize { |c| c == :ok } }
    assert t.authorized?(:ok)
    assert_not t.authorized?(:nope)
  end

  test "authorize is per table" do
    build_table { authorize { false } }
    assert build_table.authorized?
  end
end

class BaseAuthorizationInheritanceTest < ActiveSupport::TestCase
  test "subclass inherits authorize" do
    parent = build_table { authorize { false } }
    assert_not Class.new(parent).authorized?
  end
end
