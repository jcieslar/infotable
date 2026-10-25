require "test_helper"

class FillHeightTest < ActionDispatch::IntegrationTest
  setup { Author.create!(name: "A") }

  test "fill tables mark the rows area with the offset" do
    get "/infotable/tables/authors_table"
    area = Nokogiri::HTML(response.body).at_css("[data-fill-height]")

    assert area
    assert_equal "16", area["data-fill-offset"]
    assert_match(/min-height: 400px; max-height: 600px/, area["style"]) # fallback without JS
  end

  test "fixed tables are left alone" do
    User.create!(name: "u", email: "u@x.io")
    get "/infotable/tables/users_table"

    assert_nil Nokogiri::HTML(response.body).at_css("[data-fill-height]")
  end
end
