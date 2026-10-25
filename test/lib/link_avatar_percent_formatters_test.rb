require "test_helper"

class LinkAvatarPercentFormattersTest < ActiveSupport::TestCase
  def view = @view ||= ActionView::Base.empty
  def link = Infotable::Formatters::LinkFormatter.new(view)
  def avatar = Infotable::Formatters::AvatarFormatter.new(view)
  def percent = Infotable::Formatters::PercentFormatter.new(view)

  # --- link

  test "link uses the value as the url by default" do
    html = link.format("https://example.com", nil)
    assert_includes html, 'href="https://example.com"'
    assert_includes html, ">https://example.com</a>"
  end

  test "link takes a Proc url and label evaluated for the record" do
    record = Struct.new(:id, :email).new(7, "a@b.c")
    html = link.format("ignored", record, url: ->(r) { "/users/#{r.id}" }, label: ->(r) { r.email })
    assert_includes html, 'href="/users/7"'
    assert_includes html, ">a@b.c</a>"
  end

  test "link external opens in a new tab safely" do
    html = link.format("https://example.com", nil, external: true)
    assert_includes html, 'target="_blank"'
    assert_includes html, 'rel="noopener noreferrer"'
    assert_not_includes link.format("https://example.com", nil), "target="
  end

  test "link supports mailto and tel" do
    assert_includes link.format("a@b.c", nil, url: ->(_) { "mailto:a@b.c" }), 'href="mailto:a@b.c"'
    assert_includes link.format("1", nil, url: "tel:+48123"), 'href="tel:+48123"'
  end

  test "link refuses dangerous schemes and renders the text only" do
    [ "javascript:alert(1)", " JaVaScRiPt:alert(1)", "java\tscript:alert(1)", "data:text/html,<script>alert(1)</script>", "vbscript:x" ].each do |url|
      html = link.format("click", nil, url: url)
      assert_equal "click", html, url.inspect
    end
  end

  test "link escapes the label" do
    html = link.format("<img src=x onerror=alert(1)>", nil, url: "/x")
    assert_not_includes html, "<img"
    assert_includes html, "&lt;img"
  end

  test "link is blank for blank values and relative urls pass" do
    assert_equal "", link.format(nil, nil)
    assert Infotable::Formatters::LinkFormatter.safe_url?("/a/b?c=d#e")
    assert Infotable::Formatters::LinkFormatter.safe_url?("//cdn.example.com/x")
    assert_not Infotable::Formatters::LinkFormatter.safe_url?("")
  end

  # --- avatar

  test "avatar renders an image for url values" do
    html = avatar.format("https://img.example.com/a.png", nil, name: "Ann Lee")
    assert_includes html, '<img src="https://img.example.com/a.png"'
    assert_includes html, 'alt="Ann Lee"'
    assert_includes html, "Ann Lee</span>"
  end

  test "avatar falls back to initials without an image" do
    html = avatar.format(nil, nil, name: "ann lee", label: false)
    assert_includes html, ">AL</span>"
    assert_not_includes html, "<img"
  end

  test "avatar resolves the name from the record and supports sizes" do
    record = Struct.new(:name).new("Bob")
    html = avatar.format(nil, record, name: ->(r) { r.name }, size: :lg, label: false)
    assert_includes html, ">B</span>"
    assert_includes html, "h-10 w-10"
  end

  test "avatar does not render javascript urls as images and escapes names" do
    html = avatar.format("javascript:alert(1)", nil, name: "<b>x</b>")
    assert_not_includes html, "<img"
    assert_not_includes html, "<b>"
  end

  test "avatar is empty with neither image nor name" do
    assert_equal "", avatar.format(nil, nil)
  end

  # --- percent

  test "percent formats 0-100 values" do
    assert_equal "45%", percent.format(45, nil)
    assert_equal "45.5%", percent.format(45.5, nil, precision: 1)
    assert_equal "46%", percent.format("45.6", nil)
  end

  test "percent scales ratios" do
    assert_equal "25%", percent.format(0.25, nil, scale: :ratio)
    assert_equal "12.5%", percent.format(0.125, nil, scale: :ratio, precision: 1)
  end

  test "percent bar width is clamped" do
    assert_includes percent.format(150, nil, bar: true), "width: 100%"
    assert_includes percent.format(-5, nil, bar: true), "width: 0%"
    assert_includes percent.format(40, nil, bar: true), "width: 40%"
  end

  test "percent copes with blanks and junk" do
    assert_equal "", percent.format(nil, nil)
    assert_equal "", percent.format("", nil)
    assert_equal "n/a", percent.format("n/a", nil)
  end
end
