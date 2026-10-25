require "application_system_test_case"

class TableLoadingTest < ApplicationSystemTestCase
  setup { create_users }

  test "table frame loads rows in a real browser" do
    visit "/users"
    wait_for_table("users_table")

    assert_text "Alice Smith"
    assert_text "Carol Jones"
    assert_equal 3, table_rows("users_table")
  end
end
