require "test_helper"

class RangeFilterRenderTest < ActionDispatch::IntegrationTest
  setup { create_users }

  def drawer
    get "/users"
    Nokogiri::HTML(response.body)
  end

  test "number filter has an operator select with every comparison and the range as default" do
    select = drawer.at_css("select[name='filters[age][op]'][data-range-op]")

    assert select
    assert_equal [ "", "eq", "neq", "gt", "gte", "lt", "lte", "is_empty", "is_not_empty" ], select.css("option").map { _1["value"] }
    assert_equal "Between", select.at_css("option[value='']").text
  end

  test "date filter offers on, before and after" do
    select = drawer.at_css("select[name='filters[created_at][op]'][data-range-op]")

    assert_equal [ "", "on", "before", "after", "is_empty", "is_not_empty" ], select.css("option").map { _1["value"] }
  end

  test "number filter keeps from, to and a single value input" do
    doc = drawer
    assert_equal "number", doc.at_css("input[name='filters[age][from]']")["type"]
    assert_equal "number", doc.at_css("input[name='filters[age][to]']")["type"]
    assert_equal "number", doc.at_css("input[name='filters[age][value]']")["type"]
    assert_equal "date", doc.at_css("input[name='filters[created_at][value]']")["type"]
  end

  test "the single value input starts hidden" do
    group = drawer.at_css("input[name='filters[age][value]']").ancestors("[data-range-fields]").first

    assert_equal "single", group["data-range-fields"]
    assert_match(/display: none/, group["style"])
  end

  test "operator labels exist in en and pl" do
    %i[en pl].each do |locale|
      %w[range_ops.between number_ops.gte number_ops.eq date_ops.before date_ops.on].each do |key|
        assert I18n.exists?("infotable.filters.#{key}", locale), "#{locale} #{key}"
      end
    end
  end

  test "the operators the drawer sends are the ones the server filters with" do
    names = ->(filters) { response_names(filters) }

    assert_equal [ "Bob_100%" ], names.call(age: { op: "gte", value: "45" })
    assert_equal [ "Carol Jones" ], names.call(age: { op: "lt", value: "30" })
    assert_equal [ "Alice Smith", "Bob_100%" ], names.call(age: { op: "", from: "30", to: "45" }).sort
    assert_equal [ "Carol Jones" ], names.call(score: { op: "is_empty" })
  end

  private

  def response_names(filters)
    get "/infotable/tables/users_table", params: { filters: filters }
    Nokogiri::HTML(response.body).css("tbody td strong").map(&:text)
  end
end
