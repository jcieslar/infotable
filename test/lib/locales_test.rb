require "test_helper"

class LocalesTest < ActiveSupport::TestCase
  LOCALES = %w[pl de fr es el it].freeze

  def keys(h, prefix = nil)
    h.flat_map { |k, v| v.is_a?(Hash) ? keys(v, [ prefix, k ].compact.join(".")) : [ [ prefix, k ].compact.join(".") ] }
  end

  def flat(h, prefix = nil)
    h.each_with_object({}) do |(k, v), out|
      path = [ prefix, k ].compact.join(".")
      v.is_a?(Hash) ? out.merge!(flat(v, path)) : out[path] = v
    end
  end

  def load_locale(locale)
    YAML.load_file(Infotable::Engine.root.join("config/locales/#{locale}.yml"))[locale]
  end

  LOCALES.each do |locale|
    test "en and #{locale} have identical keys" do
      en = keys(load_locale("en"))
      other = keys(load_locale(locale))
      assert_empty en - other, "missing in #{locale}"
      assert_empty other - en, "extra in #{locale}"
    end

    test "#{locale} uses the same interpolation variables as en" do
      en = flat(load_locale("en"))
      flat(load_locale(locale)).each do |key, value|
        assert_equal en[key].scan(/%\{(\w+)\}/).sort, value.scan(/%\{(\w+)\}/).sort, "#{locale}: #{key}"
      end
    end
  end

  test "an app can override a shipped translation" do
    I18n.backend.store_translations(:de, infotable: { table: { buttons: { export_csv: "Mein Export" } } })
    assert_equal "Mein Export", I18n.t("infotable.table.buttons.export_csv", locale: :de)
    assert_equal "Filter", I18n.t("infotable.table.buttons.filters", locale: :de)
  ensure
    I18n.backend.reload!
  end
end
