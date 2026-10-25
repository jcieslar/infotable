require "test_helper"

class TablesHelperTest < ActionView::TestCase
  include Infotable::TablesHelper

  def col(**o) = { name: :name, type: :string, formatter: nil, formatter_options: nil }.merge(o)

  test "plain values render as-is, nil and empty use table placeholders" do
    t = build_table { nil_value "n/a"; empty_value "(empty)" }
    assert_equal "n/a", format_cell_value(User.new(name: nil), col, t)
    assert_equal "(empty)", format_cell_value(User.new(name: ""), col, t)
    assert_equal "Ann", format_cell_value(User.new(name: "Ann"), col, t)
  end

  test "named formatters use the same placeholders" do
    t = build_table { nil_value "n/a" }
    %i[currency date badge].each do |f|
      assert_equal "n/a", format_cell_value(User.new(salary: nil, created_at: nil, status: nil), col(name: { currency: :salary, date: :created_at, badge: :status }[f], formatter: f), t), f.to_s
    end
  end

  test "boolean and action formatters keep handling nil themselves" do
    t = build_table { nil_value "n/a" }
    assert_not_equal "n/a", format_cell_value(Author.new(verified: nil), col(name: :verified, type: :boolean, formatter: :boolean), t)
  end

  test "proc formatter receives value and record" do
    c = col(formatter: ->(value, record) { "#{value}/#{record.email}" })
    assert_equal "x/y", format_cell_value(User.new(name: "x", email: "y"), c, build_table)
  end

  test "hash formatter spec" do
    c = col(name: :status, formatter: { type: :badge, options: { colors: { active: "green" } } })
    assert_includes format_cell_value(User.new(status: "active"), c, build_table), "bg-green-100"
  end

  test "typo in formatter name raises instead of silently printing to_s" do
    err = assert_raises(Infotable::Error) { format_cell_value(User.new(name: "x"), col(formatter: :curency), build_table) }
    assert_match(/Unknown formatter :curency/, err.message)
  end

  test "custom formatter class is found" do
    c = col(formatter: :shout)
    assert_equal "X!", format_cell_value(User.new(name: "x"), c, build_table)
  end

  test "value proc feeds the formatter" do
    c = col(name: :virtual_thing, value: ->(r) { r.name.upcase })
    assert_equal "ANN", format_cell_value(User.new(name: "Ann"), c, build_table)
  end

  test "per_page_choices merges current limit and sorts" do
    t = build_table { per_page_options [ 25, 10 ] }
    assert_equal [ 10, 15, 25 ], per_page_choices(t, 15)
    assert_equal [ 10, 25 ], per_page_choices(t, 25)
  end

  test "drawer attributes sanitise width and side" do
    cfg = ActiveSupport::OrderedOptions.new.merge!(drawer_position: :left, drawer_width: "99px")
    attrs = infotable_drawer_attributes(cfg)
    assert_equal "left", attrs[:data][:drawer_side]
    assert_includes attrs[:style], "width: 99px"
    attrs = infotable_drawer_attributes(ActiveSupport::OrderedOptions.new.merge!(drawer_position: "x", drawer_width: "evil;"))
    assert_equal "right", attrs[:data][:drawer_side]
    assert_includes attrs[:style], "width: 26rem"
  end
end

class PageWindowTest < ActionView::TestCase
  include Infotable::TablesHelper

  Fake = Struct.new(:page, :last)

  test "page window keeps first, last and two either side of the current page" do
    assert_equal [ 1, 8, 9, 10, 11, 12, 20 ], infotable_page_window(Fake.new(10, 20))
    assert_equal [ 1, 2, 3, 20 ], infotable_page_window(Fake.new(1, 20))
    assert_equal [ 1, 18, 19, 20 ], infotable_page_window(Fake.new(20, 20))
    assert_equal [ 1 ], infotable_page_window(Fake.new(1, 1))
  end
end
