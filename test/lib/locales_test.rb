require "test_helper"

class LocalesTest < ActiveSupport::TestCase
  def keys(h, prefix = nil)
    h.flat_map { |k, v| v.is_a?(Hash) ? keys(v, [ prefix, k ].compact.join(".")) : [ [ prefix, k ].compact.join(".") ] }
  end

  test "en and pl have identical keys" do
    root = Infotable::Engine.root.join("config/locales")
    en = keys(YAML.load_file(root.join("en.yml"))["en"])
    pl = keys(YAML.load_file(root.join("pl.yml"))["pl"])
    assert_empty en - pl, "missing in pl"
    assert_empty pl - en, "missing in en"
  end
end
