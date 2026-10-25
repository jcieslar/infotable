require "test_helper"

class FilterOptionsRenderTest < ActionDispatch::IntegrationTest
  test "the drawer warns when a select filter was truncated" do
    Infotable.configuration.max_filter_options = 2
    3.times { |i| User.create!(name: "U#{i}", email: "u#{i}@example.com", company: "Company #{i}") }

    get "/users"
    doc = Nokogiri::HTML(response.body)
    select = doc.at_css("select[name='filters[company][value]']")

    assert_equal 3, select.css("option").size # "All" + 2
    assert_includes doc.at_css("[data-filter-options-truncated]").text, "first 2 of 3"
  ensure
    Infotable.reset_configuration!
  end

  test "no warning when everything fits" do
    User.create!(name: "A", email: "a@example.com", company: "Acme")
    get "/users"
    assert_nil Nokogiri::HTML(response.body).at_css("[data-filter-options-truncated]")
  end
end
