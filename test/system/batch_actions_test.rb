require "application_system_test_case"

class BatchActionsTest < ApplicationSystemTestCase
  setup do
    author = Author.create!(name: "Writer", email: "writer@example.com")
    @posts = 3.times.map do |i|
      Post.create!(author: author, title: "Post #{i + 1}", body: "Body", status: "published", category: "tech")
    end
    visit "/posts"
    wait_for_table("posts_table")
  end

  def row_boxes
    all("turbo-frame#posts_table_content tbody input[type=checkbox]")
  end

  test "selecting rows shows the action bar with a count" do
    assert_no_selector "[data-infotable--table-target='batchBar']:not(.hidden)", visible: :all

    row_boxes.first.check
    assert_text "1 selected"

    row_boxes.last.check
    assert_text "2 selected"
  end

  test "select all checks every row and clear unchecks them" do
    find("thead input[data-infotable--table-target='selectAll']").check
    assert_text "3 selected"
    assert(row_boxes.all?(&:checked?))

    click_button "Clear selection" if has_button?("Clear selection")
    click_button(I18n.t("infotable.batch.clear")) unless has_no_button?(I18n.t("infotable.batch.clear"))
    assert_no_text "3 selected"
    assert(row_boxes.none?(&:checked?))
  end

  test "a batch action sends the selected ids to the app" do
    row_boxes.first.check
    row_boxes.last.check
    click_button "Feature"

    ids = [ @posts.first.id, @posts.last.id ].sort
    assert_text "PATCH ids=#{ids.join(',')}", normalize_ws: true
  end
end
