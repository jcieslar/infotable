require "test_helper"

class BatchActionsDslTest < ActiveSupport::TestCase
  test "disabled by default" do
    t = build_table
    assert_not t.checkbox_enabled?
    assert_empty t.batch_action_list
  end

  test "checkbox_column enables checkboxes without actions" do
    assert build_table { checkbox_column }.checkbox_enabled?
    assert_not build_table { checkbox_column enabled: false }.checkbox_enabled?
  end

  test "batch_actions enables checkboxes and normalises actions" do
    t = build_table do
      batch_actions do
        action :archive, url: "/a", method: :PATCH
        action :delete, label: "Remove", url: "/d", method: :delete, confirm: "Sure %{count}?", color: "danger"
      end
    end
    assert t.checkbox_enabled?
    assert_equal({ name: :archive, label: "Archive", url: "/a", method: :patch, confirm: nil, color: :default }, t.batch_action_list.first)
    assert_equal [ :delete, "Remove", :danger ], t.batch_action_list.last.values_at(:name, :label, :color)
  end

  test "invalid definitions are rejected" do
    assert_raises(ArgumentError) { build_table { batch_actions { action :x, url: "/x", method: :trace } } }
    assert_raises(ArgumentError) { build_table { batch_actions { action :x, url: "" } } }
    assert_raises(ArgumentError) { build_table { batch_actions { action :x, url: ->(ids) { "/x" } } } }
    assert_raises(ArgumentError) { build_table { batch_actions { action :x, url: "/x", color: :neon } } }
  end

  test "checkbox_value uses id_method" do
    t = build_table { checkbox_column id_method: :email }
    assert_equal "a@x.io", t.checkbox_value(User.new(id: 1, email: "a@x.io"))
  end

  test "settings are per table and inherited by subclasses" do
    a = build_table { batch_actions { action :x, url: "/x" } }
    assert_not build_table.checkbox_enabled?
    child = Class.new(a)
    assert_equal [ :x ], child.batch_action_list.map { _1[:name] }
    child.batch_actions { action :y, url: "/y" }
    assert_equal [ :x ], a.batch_action_list.map { _1[:name] }
  end
end
