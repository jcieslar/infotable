require "test_helper"

# Cheap static guards for JS regressions (no JS runner in this repo yet).
class JavascriptHygieneTest < ActionDispatch::IntegrationTest
  JS = Dir[Infotable::Engine.root.join("app/assets/javascripts/**/*.js")]

  test "no console.log in shipped controllers" do
    offenders = JS.select { |f| File.read(f).match?(/console\.log\(/) }
    assert_empty offenders
  end

  test "document listeners are removed with the same capture flag they were added with" do
    JS.each do |f|
      src = File.read(f)
      added = src.scan(/document\.addEventListener\("click", ([^,)]+)(?:, (true|false))?\)/)
      added.each do |handler, capture|
        removed = src.scan(/document\.removeEventListener\("click", #{Regexp.escape(handler)}(?:, (true|false))?\)/)
        assert removed.any?, "#{f}: #{handler} never removed"
        assert removed.all? { |(c)| c == capture }, "#{f}: #{handler} removed with different capture flag"
      end
    end
  end

  test "per-page select does not spawn a nested table controller" do
    User.create!(name: "x", email: "x@x.io")
    get "/infotable/tables/users_table"
    select = Nokogiri::HTML(response.body).at_css("select[data-action*=changePerPage]")
    assert select
    assert_nil select["data-controller"]
  end
end
