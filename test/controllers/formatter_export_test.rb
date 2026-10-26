require "test_helper"

# Formatters are for the screen; the CSV export keeps the raw values.
class FormatterExportTest < ActionDispatch::IntegrationTest
  test "export ignores :number and :tags formatters and keeps the raw values" do
    author = Author.create!(name: "Ann")
    Post.create!(author: author, title: "Hello", views_count: 1500, reading_time: 7, status: "published", featured: true)

    get "/infotable/tables/posts_table/export"
    assert_response :success

    csv = CSV.parse(response.body, headers: true)
    row = csv.first
    assert_equal "1500", row["Views"]
    assert_equal "7", row["Read Time"]
    assert_equal "published, featured", row["Labels"]
    assert_not_includes response.body, "1.5k"
  end
end
