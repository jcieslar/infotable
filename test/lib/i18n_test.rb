require "test_helper"

class I18nTest < ActionDispatch::IntegrationTest
  teardown { I18n.locale = I18n.default_locale }

  test "no missing translations in filter partials, both locales" do
    User.create!(name: "A", email: "a@x.io")
    %w[en pl de fr es el it].each do |locale|
      I18n.with_locale(locale) do
        get "/users"
        assert_response :success
        assert_no_match(/translation missing|class="translation_missing"/i, response.body, locale)
      end
    end
  end

  test "all keys referenced via t('infotable...') exist in en and pl" do
    root = Infotable::Engine.root
    keys = Dir[root.join("app/**/*.erb"), root.join("lib/**/*.rb")].flat_map { |f| File.read(f).scan(/\bt\(\s*['"](infotable\.[\w.]+)['"]/).flatten }.uniq
    assert_operator keys.size, :>, 20
    %i[en pl de fr es el it].each do |loc|
      missing = keys.reject { |k| I18n.exists?(k, loc) }
      assert_empty missing, "missing in #{loc}"
    end
  end

  test "date formats use the locale's month names, relative time is translated" do
    view = ActionView::Base.empty
    date = Time.zone.local(2026, 3, 5, 14, 30)
    { en: "Mar 05, 2026", de: "05. Mär 2026", fr: "05 mars 2026", es: "05 mar 2026", it: "05 mar 2026", el: "05 Μαρ 2026", pl: "05 mar 2026" }.each do |locale, expected|
      I18n.with_locale(locale) do
        assert_equal expected, Infotable::Formatters::DateFormatter.new(view).format(date, nil, format: :short), locale
        assert_no_match(/translation missing/i, Infotable::Formatters::DateFormatter.new(view).format(3.days.ago, nil, format: :relative), locale)
      end
    end
  end

  test "formatters are translated" do
    view = ActionView::Base.empty
    I18n.with_locale(:pl) do
      assert_equal "Tak", Infotable::Formatters::BooleanFormatter.new(view).format(true, nil, style: :text)
      assert_match(%r{temu</span>\z}, Infotable::Formatters::DateFormatter.new(view).format(3.days.ago, nil, format: :relative))
    end
    I18n.with_locale(:en) do
      assert_equal "No", Infotable::Formatters::BooleanFormatter.new(view).format(false, nil, style: :text)
    end
  end
end
