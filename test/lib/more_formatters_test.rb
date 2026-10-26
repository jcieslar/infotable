require "test_helper"

class MoreFormattersTest < ActiveSupport::TestCase
  def view = @view ||= ActionView::Base.empty
  def fmt(name) = Infotable::Formatters.built_in.fetch(name).new(view)

  # --- number

  test "number shows delimiters, precision, unit and zero placeholder" do
    assert_includes fmt(:number).format(1234567, nil), ">1,234,567<"
    assert_includes fmt(:number).format(3.14159, nil, precision: 2), ">3.14<"
    assert_includes fmt(:number).format(1234.5, nil, delimiter: " ", separator: ","), ">1 234,5<"
    assert_includes fmt(:number).format(250, nil, unit: "ms"), ">250 ms<"
    assert_equal "-", fmt(:number).format(0, nil, zero: "-")
  end

  test "number compact" do
    assert_includes fmt(:number).format(1500, nil, compact: true), ">1.5k<"
    assert_includes fmt(:number).format(3_400_000, nil, compact: true), ">3.4M<"
    assert_includes fmt(:number).format(2_000_000_000, nil, compact: true), ">2B<"
    assert_includes fmt(:number).format(999, nil, compact: true), ">999<"
  end

  test "number leaves blanks and non-numbers alone" do
    assert_equal "", fmt(:number).format(nil, nil)
    assert_equal "", fmt(:number).format("", nil)
    assert_equal "n/a", fmt(:number).format("n/a", nil)
  end

  # --- tags

  test "tags renders a badge per item from arrays, relations and comma strings" do
    html = fmt(:tags).format([ "ruby", "rails" ], nil)
    assert_equal 2, html.scan("<span").size
    assert_includes fmt(:tags).format("a, b, c", nil), ">c</span>"
    assert_includes fmt(:tags).format(Struct.new(:to_a).new([ "x" ]), nil), ">x</span>"
  end

  test "tags limit adds a +N with the rest in the tooltip" do
    html = fmt(:tags).format(%w[a b c d], nil, limit: 2)
    assert_includes html, ">+2</span>"
    assert_includes html, 'title="c, d"'
  end

  test "tags escapes items, takes a label proc, colors and a separator" do
    assert_not_includes fmt(:tags).format([ "<script>alert(1)</script>" ], nil), "<script>"
    assert_includes fmt(:tags).format([ Struct.new(:name).new("Ann") ], nil, label: ->(item) { item.name }), ">Ann</span>"
    assert_includes fmt(:tags).format([ "admin" ], nil, colors: { "admin" => "red" }), "bg-red-100"
    assert_equal "a, b", fmt(:tags).format(%w[a b], nil, separator: ", ")
    assert_equal "", fmt(:tags).format([], nil)
    assert_equal "", fmt(:tags).format(nil, nil)
  end

  # --- truncate

  test "truncate cuts long text and keeps the full text in the tooltip" do
    long = "x" * 100
    html = fmt(:truncate).format(long, nil, length: 10)
    assert_includes html, 'title="' + long + '"'
    assert_includes html, ">xxxxxxxxx…</span>"
    assert_equal "short", fmt(:truncate).format("short", nil)
    assert_equal "", fmt(:truncate).format(nil, nil)
  end

  test "truncate escapes the text" do
    assert_not_includes fmt(:truncate).format("<b>" * 40, nil, length: 10), "<b>"
  end

  # --- image

  test "image renders a lazy thumbnail only for safe urls" do
    html = fmt(:image).format("https://example.com/a.png", nil, alt: "A", size: :lg)
    assert_includes html, 'src="https://example.com/a.png"'
    assert_includes html, 'alt="A"'
    assert_includes html, "h-16 w-16"
    assert_includes html, 'loading="lazy"'
    assert_equal "", fmt(:image).format("javascript:alert(1)", nil)
    assert_equal "", fmt(:image).format("data:image/png;base64,AAAA", nil)
    assert_equal "", fmt(:image).format(nil, nil)
  end

  test "image alt can be a proc and the image can link to the original" do
    record = Struct.new(:name).new("Chair")
    html = fmt(:image).format("/img/chair.png", record, alt: ->(r) { r.name }, link: true)
    assert_includes html, 'alt="Chair"'
    assert_includes html, 'href="/img/chair.png"'
    assert_includes html, 'rel="noopener noreferrer"'
  end

  # --- filesize

  test "filesize shows a human size" do
    assert_equal "1.5 KB", fmt(:filesize).format(1536, nil)
    assert_equal "2 MB", fmt(:filesize).format(2 * 1024 * 1024, nil)
    assert_equal "", fmt(:filesize).format(nil, nil)
    assert_equal "huge", fmt(:filesize).format("huge", nil)
  end

  # --- duration

  test "duration short and long" do
    assert_equal "1h 05m", fmt(:duration).format(3900, nil)
    assert_equal "45s", fmt(:duration).format(45, nil)
    assert_equal "2d 03h", fmt(:duration).format(2 * 86_400 + 3 * 3600 + 5, nil)
    assert_equal "1h", fmt(:duration).format(3600, nil)
    assert_equal "0s", fmt(:duration).format(0, nil)
    assert_equal "1 hour 5 minutes", fmt(:duration).format(3900, nil, format: :long)
    assert_equal "2 hours", fmt(:duration).format(7200, nil, format: :long)
    assert_equal "", fmt(:duration).format(nil, nil)
    assert_equal "-5", fmt(:duration).format(-5, nil)
  end

  test "duration is translated" do
    I18n.with_locale(:pl) do
      assert_equal "1 godzina 5 minut", fmt(:duration).format(3900, nil, format: :long)
      assert_equal "1 godz. 05 min", fmt(:duration).format(3900, nil)
      assert_equal "2 godziny 3 minuty", fmt(:duration).format(2 * 3600 + 3 * 60, nil, format: :long)
      assert_equal "12 godzin 22 minuty", fmt(:duration).format(12 * 3600 + 22 * 60, nil, format: :long)
      assert_equal "5 godzin", fmt(:duration).format(5 * 3600, nil, format: :long)
      assert_equal "1 dzień 2 godziny", fmt(:duration).format(86_400 + 2 * 3600, nil, format: :long)
      assert_equal "3 dni 1 godzina", fmt(:duration).format(3 * 86_400 + 3600, nil, format: :long)
    end
  end

  # --- registry / existing formatters

  test "the registry lists every built-in and the error names them" do
    assert_equal Infotable::Formatters::TagsFormatter, Infotable::Formatters.built_in[:list]
    column = { name: :x, formatter: :nope }
    error = assert_raises(Infotable::Error) { ApplicationController.helpers.send(:format_with_named_formatter, "v", nil, column) }
    Infotable::Formatters.built_in.each_key { assert_includes error.message, _1.to_s }
  end

  test "currency takes unit and precision from options, the rest from I18n" do
    assert_equal "€1,234.50", fmt(:currency).format(1234.5, nil, unit: "€")
    assert_equal "$1,234.5", fmt(:currency).format(1234.5, nil, precision: 1)
  end

  test "relative dates keep the exact time in a tooltip" do
    html = fmt(:date).format(2.hours.ago, nil, format: :relative)
    assert_includes html, "title="
    assert_includes html, "ago"
  end
end
