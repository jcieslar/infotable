require "application_system_test_case"

class SelectAllMatchingTest < ApplicationSystemTestCase
  setup do
    # The search matches posts.author_id as text: a sequence id containing "0" would make the
    # term "0" match every post (the filter test below searches "Post 0")
    author = Author.create!(id: 1, name: "Writer", email: "writer@example.com")
    @posts = 60.times.map { |i| Post.create!(author: author, title: "Post #{format('%02d', i)}", body: "Body", status: i < 40 ? "published" : "draft", category: "tech") }
    visit "/posts"
    wait_for_table("posts_table")
  end

  teardown { Infotable.reset_configuration! }

  def select_page
    find("thead input[data-infotable--table-target='selectAll']").check
  end

  def offer
    "[data-infotable--table-target='selectAllMatching']"
  end

  test "ticking the header offers every matching row, not just the page" do
    assert_no_selector offer, visible: :visible

    select_page
    assert_text "50 selected"
    assert_selector offer, text: "Select all 60 matching"
  end

  test "taking the offer selects rows from other pages and the batch action receives them all" do
    select_page
    find(offer).click

    assert_text "60 selected"
    assert_no_selector offer, visible: :visible

    click_button "Feature"
    assert_text "PATCH ids=#{@posts.map(&:id).sort.join(',')}", normalize_ws: true
  end

  test "the offer counts only rows matching the current filters" do
    visit "/posts?posts_table[search]=Post+0"
    assert_selector "turbo-frame#posts_table_content tbody tr", count: 15
    select_page

    # "Post 0" matches Post 00..09 and Post 10, 20, 30, 40, 50
    assert_text "15 selected"
    assert_no_selector offer, visible: :visible
  end

  test "changing the filter drops the selection with the old scope" do
    select_page
    find(offer).click
    assert_text "60 selected"

    fill_in "search", with: "Post 1"
    assert_no_text "60 selected"
  end

  test "a capped selection says it is capped" do
    Infotable.configuration.max_select_all = 55
    select_page
    find(offer).click

    assert_text "55 selected"
    assert_text "Only the first 55 rows are selected"
  end
end
