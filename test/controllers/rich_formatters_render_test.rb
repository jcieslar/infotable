require "test_helper"

class RichFormattersRenderTest < ActionDispatch::IntegrationTest
  setup do
    Author.create!(name: "Ann Lee", email: "ann@example.com", website: "https://ann.example.com", avatar_url: "https://img.example.com/ann.png")
    Author.create!(name: "Bad Link", email: "bad@example.com", website: "javascript:alert(1)")
    get "/infotable/tables/authors_table/data"
    @doc = Nokogiri::HTML(response.body)
  end

  test "website column renders a safe external link" do
    link = @doc.at_css("a[href='https://ann.example.com']")
    assert_equal "_blank", link["target"]
    assert_equal "noopener noreferrer", link["rel"]
  end

  test "javascript: urls are not linked" do
    assert_nil @doc.at_css("a[href^='javascript']")
    assert_includes response.body, "javascript:alert(1)"
  end

  test "avatar column renders the picture or initials" do
    assert @doc.at_css("img[src='https://img.example.com/ann.png'][alt='Ann Lee']")
    assert(@doc.css("span[aria-hidden=true]").any? { _1.text == "BL" })
  end
end
