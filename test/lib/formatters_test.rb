require "test_helper"

class FormattersTest < ActiveSupport::TestCase
  def view = @view ||= ActionView::Base.empty
  def fmt(klass) = klass.new(view)

  test "date formats" do
    t = Time.utc(2024, 3, 5, 14, 7)
    f = fmt(Infotable::Formatters::DateFormatter)
    assert_equal "Mar 05, 2024", f.format(t, nil, format: :short)
    assert_equal "March 05, 2024", f.format(t, nil, format: :long)
    assert_equal "02:07 PM", f.format(t, nil, format: :time)
    assert_equal "Mar 05, 2024 02:07 PM", f.format(t, nil, format: :datetime)
    assert_equal "05.03.2024", f.format(t, nil, format: :dot_date)
    assert_equal "2024-03-05 14:07", f.format(t, nil)
    assert_equal "2024/03", f.format(t, nil, format: "%Y/%m")
    assert_equal "", f.format(nil, nil)
  end

  test "date relative" do
    assert_match(/ago\z/, fmt(Infotable::Formatters::DateFormatter).format(3.days.ago, nil, format: :relative))
  end

  test "date accepts a date-like string" do
    assert_nothing_raised { fmt(Infotable::Formatters::DateFormatter).format("2024-03-05", nil, format: :short) }
  end

  test "currency" do
    f = fmt(Infotable::Formatters::CurrencyFormatter)
    assert_equal "$1,234.50", f.format(1234.5, nil)
    assert_equal "€1.234,5", f.format(1234.5, nil, unit: "€", delimiter: ".", separator: ",", precision: 1)
    assert_equal "", f.format(nil, nil)
  end

  test "boolean text, badge, icon" do
    f = fmt(Infotable::Formatters::BooleanFormatter)
    assert_equal "Yes", f.format(true, nil, style: :text)
    assert_equal "No", f.format(false, nil, style: :text)
    assert_equal "On", f.format(true, nil, style: :text, true_text: "On")
    assert_includes f.format(true, nil), "bg-green-100"
    assert_includes f.format(false, nil), "bg-gray-100"
    assert_includes f.format(true, nil, style: :icon), "<svg"
    assert_includes f.format(true, nil, style: :icon), 'aria-label="Yes"'
    assert_includes f.format(false, nil, style: :icon, false_text: "Off"), 'aria-label="Off"'
  end

  test "badge colors and sizes" do
    f = fmt(Infotable::Formatters::BadgeFormatter)
    assert_includes f.format("active", nil), "bg-green-100"
    assert_includes f.format("whatever", nil), "bg-gray-100"
    assert_includes f.format("x", nil, colors: { x: "red" }), "bg-red-100"
    assert_includes f.format("x", nil, colors: { x: "cyan" }), "bg-cyan-100"
    assert_includes f.format("x", nil, size: :large), "px-3"
    assert_equal "", f.format(nil, nil)
    assert_includes f.format("pending_review", nil), "Pending Review"
  end

  test "badge escapes value" do
    assert_not_includes fmt(Infotable::Formatters::BadgeFormatter).format("<script>", nil), "<script>"
  end

  test "action formatter renders links and escapes labels" do
    f = fmt(Infotable::Formatters::ActionFormatter)
    rec = User.new(id: 9)
    out = f.format(nil, rec, actions: [ { label: "<b>x</b>", url: ->(r) { "/u/#{r.id}" } } ])
    assert_includes out, "/u/9"
    assert_not_includes out, "<b>x</b>"
  end

  test "action delete is turbo compatible" do
    f = fmt(Infotable::Formatters::ActionFormatter)
    out = f.format(nil, User.new(id: 1), actions: [ { label: "Del", url: "/x", method: :delete, confirm: "sure?" } ])
    assert_match(/turbo-method|<form/, out)
    assert_includes out, "sure?"
  end

  test "action dropdown is a details menu with escaped labels and turbo delete" do
    out = fmt(Infotable::Formatters::ActionFormatter).format(nil, User.new(id: 4), style: :dropdown, actions: [
      { label: "<b>View</b>", url: ->(r) { "/u/#{r.id}" } },
      { label: "Delete", url: "/x", method: :delete, confirm: "sure?", color: "danger" }
    ])
    doc = Nokogiri::HTML.fragment(out)
    assert doc.at_css("details > summary[aria-haspopup=menu]")
    items = doc.css("details [role=menuitem]")
    assert_equal 2, items.size
    assert_equal "/u/4", items.first["href"]
    assert_equal "<b>View</b>", items.first.text
    assert_nil doc.at_css("b")
    assert_equal "delete", items.last["data-turbo-method"]
    assert_equal "sure?", items.last["data-turbo-confirm"]
  end
end
