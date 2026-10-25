require "test_helper"

class BatchActionsRenderTest < ActionDispatch::IntegrationTest
  setup do
    author = Author.create!(name: "A")
    @posts = 3.times.map { |i| Post.create!(author: author, title: "p#{i}") }
  end

  test "frame renders a select-all header and a checkbox per row with the record id" do
    get "/infotable/tables/posts_table", params: { per_page: 50 }
    doc = Nokogiri::HTML(response.body)
    assert doc.at_css('thead input[type=checkbox][data-infotable--table-target="selectAll"]')
    values = doc.css('tbody input[data-infotable--table-target="rowCheckbox"]').map { _1["value"].to_i }
    assert_equal @posts.map(&:id).sort, values.sort
  end

  test "tables without batch actions render no checkboxes" do
    User.create!(name: "u", email: "u@x.io")
    get "/infotable/tables/users_table"
    assert_select "input[type=checkbox]", 0
  end

  test "host page renders the action bar with data attributes" do
    get "/posts"
    doc = Nokogiri::HTML(response.body)
    buttons = doc.css("[data-infotable--table-target=batchBar] button[data-batch-url]")
    assert_equal %w[export feature delete], buttons.map { _1["data-batch-name"] }
    delete = buttons.last
    assert_equal "delete", delete["data-batch-method"]
    assert_equal "Delete %{count} posts?", delete["data-batch-confirm"]
    assert_match(/bg-red-600/, delete["class"])
    assert_equal "%{count} selected".sub("%{count}", "__COUNT__"), doc.at_css("[data-infotable--table-target=batchCount]")["data-template"]
  end

  test "action bar is absent for tables without batch actions" do
    get "/users"
    assert_select "[data-infotable--table-target=batchBar]", 0
  end

  test "dummy endpoint receives ids[] with the verbs the JS uses" do
    get "/posts/batch", params: { ids: [ "1", "2" ] }
    assert_equal "GET ids=1,2", response.body
    delete "/posts/batch", params: { ids: [ "3" ] }
    assert_equal "DELETE ids=3", response.body
    post "/posts/batch", params: { ids: [ "4" ], _method: "patch" }
    assert_equal "PATCH ids=4", response.body
  end

  test "pl and en have the batch strings" do
    %i[en pl].each do |loc|
      %w[selected clear select_all select_row].each { assert I18n.exists?("infotable.batch.#{_1}", loc), "#{loc} #{_1}" }
    end
  end
end
