require "test_helper"

# Hostile / random query params must never produce a 5xx, and must never touch the data.
class FuzzTest < ActionDispatch::IntegrationTest
  TABLES = %w[users_table products_table authors_table posts_table comments_table author_stats_table countless_table].freeze
  ENDPOINTS = [ "", "/data", "/export" ].freeze

  NASTY = [
    "", " ", "0", "-1", "1e309", "NaN", "9" * 40, "abc", "a'b", "'; DROP TABLE users;--", "\" OR 1=1 --",
    "%", "_", "\\", "%00", "\u0000", "\u{1F600}", "<script>alert(1)</script>", "../../etc/passwd",
    "1; SELECT pg_sleep(5)", "name; DROP TABLE users", "users.name", "(SELECT 1)", "true", "null", "{}", "[]"
  ].freeze

  setup do
    create_users
    a = Author.create!(name: "A", verified: true)
    p = Post.create!(author: a, title: "t")
    Comment.create!(post: p, author: a, body: "b")
    Product.create!(name: "P", sku: "S", price: 1)
    @rng = Random.new(ENV.fetch("FUZZ_SEED", 20_260_101).to_i)
  end

  def nasty = NASTY[@rng.rand(NASTY.size)]

  def random_params(klass)
    cols = klass.columns.map { _1[:name].to_s } + [ "nope", nasty ]
    params = {}
    params[:page] = nasty if @rng.rand < 0.5
    params[:per_page] = nasty if @rng.rand < 0.5
    params[:search] = nasty if @rng.rand < 0.4
    params[:sort_column] = cols.sample(random: @rng) if @rng.rand < 0.7
    params[:sort_direction] = [ "asc", "desc", nasty ].sample(random: @rng) if @rng.rand < 0.5
    params[:visible_columns] = [ cols.sample(random: @rng), nasty ].join(",") if @rng.rand < 0.3
    if @rng.rand < 0.8
      params[:filters] = Array.new(@rng.rand(1..3)) do
        shape = @rng.rand(4)
        value = case shape
        when 0 then { op: nasty, value: nasty }
        when 1 then { from: nasty, to: nasty }
        when 2 then { value: [ nasty, nasty ] }
        else nasty
        end
        [ cols.sample(random: @rng), value ]
      end.to_h
    end
    params
  end

  test "random hostile params never 500 and never change the data" do
    counts = [ User, Author, Post, Comment, Product ].map(&:count)

    ENV.fetch("FUZZ_RUNS", 400).to_i.times do |i|
      table = TABLES.sample(random: @rng)
      endpoint = ENDPOINTS.sample(random: @rng)
      klass = Infotable::TableResolver.resolve(table)
      params = random_params(klass)

      begin
        get "/infotable/tables/#{table}#{endpoint}", params: params
      rescue StandardError => e
        raise "##{i} GET /infotable/tables/#{table}#{endpoint} #{params.inspect} raised #{e.class}: #{e.message.lines.first}"
      end
      assert_operator response.status, :<, 500, "##{i} GET /infotable/tables/#{table}#{endpoint} #{params.inspect}"
    end

    assert_equal counts, [ User, Author, Post, Comment, Product ].map(&:count)
    assert ActiveRecord::Base.connection.table_exists?(:users)
  end

  test "malformed nested param shapes" do
    [
      "filters=1", "filters[]=1", "filters[name]=1", "filters[name][]=1", "filters[name][value][a]=1",
      "filters[name][op][]=x", "filters[][]=1", "sort_column[]=name", "sort_direction[a]=1",
      "search[a][b]=1", "page[]=1", "per_page[a]=1", "visible_columns[]=name"
    ].each do |qs|
      TABLES.each do |table|
        get "/infotable/tables/#{table}?#{qs}"
        assert_operator response.status, :<, 500, "#{table}?#{qs}"
      end
    end
  end

  test "table_name values are rejected cleanly" do
    [ "..%2F..%2Fetc", "users_table%00", "Object", "kernel", "file", "active_record_base_table", "%20", "users__table" ].each do |name|
      get "/infotable/tables/#{name}"
      assert_includes [ 404, 400 ], response.status, name
    end
  end
end
