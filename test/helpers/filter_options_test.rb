require "test_helper"

class FilterOptionsTest < ActionView::TestCase
  include Infotable::TablesHelper

  setup do
    @calls = 0
    @table = build_table
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Infotable.reset_configuration!
  end

  teardown do
    Rails.cache = @original_cache
    Infotable.reset_configuration!
  end

  def column(**options)
    { name: :status, filter_options: options.delete(:source) }.merge(options)
  end

  test "arrays, pairs and procs are returned as given with their total" do
    assert_equal [ [ "a", "b" ], 2 ], infotable_filter_options(@table, column(source: %w[a b]))
    assert_equal [ [ [ "A", 1 ] ], 1 ], infotable_filter_options(@table, column(source: [ [ "A", 1 ] ]))
    assert_equal [ [ "x" ], 1 ], infotable_filter_options(@table, column(source: -> { %w[x] }))
    assert_equal [ [], 0 ], infotable_filter_options(@table, column(source: nil))
  end

  test "options are capped by the configured maximum and the total is reported" do
    Infotable.configuration.max_filter_options = 3
    options, total = infotable_filter_options(@table, column(source: (1..10).to_a))

    assert_equal [ 1, 2, 3 ], options
    assert_equal 10, total
  end

  test "a column can set its own limit and nil removes the cap" do
    options, = infotable_filter_options(@table, column(source: (1..10).to_a, filter_options_limit: 4))
    assert_equal 4, options.size

    Infotable.configuration.max_filter_options = nil
    options, = infotable_filter_options(@table, column(source: (1..1000).to_a))
    assert_equal 1000, options.size
  end

  test "a Proc runs on every call unless the column opts into caching" do
    source = -> { @calls += 1; %w[a] }
    2.times { infotable_filter_options(@table, column(source: source)) }
    assert_equal 2, @calls
  end

  test "filter_options_cache caches the Proc result per table and column" do
    source = -> { @calls += 1; %w[a b] }
    col = column(source: source, filter_options_cache: 5.minutes)

    3.times { assert_equal [ %w[a b], 2 ], infotable_filter_options(@table, col) }
    assert_equal 1, @calls

    other = build_table
    infotable_filter_options(other, col)
    assert_equal 2, @calls, "another table must not share the cache entry"
  end

  test "the cached list is still capped" do
    col = column(source: -> { (1..10).to_a }, filter_options_cache: 1.minute, filter_options_limit: 2)
    assert_equal [ [ 1, 2 ], 10 ], infotable_filter_options(@table, col)
    assert_equal [ [ 1, 2 ], 10 ], infotable_filter_options(@table, col)
  end

  test "the DSL keeps the new column options" do
    table = build_table { column :status, filter_options: -> { [] }, filter_options_cache: 1.hour, filter_options_limit: 50 }
    col = table.columns.first
    assert_equal 1.hour, col[:filter_options_cache]
    assert_equal 50, col[:filter_options_limit]
  end
end
