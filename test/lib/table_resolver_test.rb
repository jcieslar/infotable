require "test_helper"

class TableResolverTest < ActiveSupport::TestCase
  def resolve(name) = Infotable::TableResolver.resolve(name)

  test "single word" do
    assert_equal UsersTable, resolve(:users_table)
    assert_equal UsersTable, resolve("users")
  end

  test "multi word table name" do
    assert_equal OrderItemsTable, resolve(:order_items_table)
  end

  test "namespaced" do
    assert_equal Cms::UsersTable, resolve("cms_users_table")
    assert_equal Cms::Admins::UsersTable, resolve("cms_admins_users_table")
  end

  test "unknown raises NotFound" do
    assert_raises(Infotable::TableResolver::NotFound) { resolve("nope_table") }
  end

  test "class not inheriting Base is rejected" do
    assert_raises(Infotable::TableResolver::NotFound) { resolve("not_a_table") }
  end

  test "blank and oversized names are rejected" do
    assert_raises(Infotable::TableResolver::NotFound) { resolve("") }
    assert_raises(Infotable::TableResolver::NotFound) { resolve("a_b_c_d_e_f_g_h_i_j_table") }
    assert_raises(Infotable::TableResolver::NotFound) { resolve("users__table") }
  end

  test "flat name preferred over namespace" do
    assert_equal [ "OrderItemsTable" ], Infotable::TableResolver.candidates("order_items_table").first(1)
  end
end
