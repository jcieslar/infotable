require "test_helper"
require "rails/generators/test_case"
require "generators/infotable/table/table_generator"

class TableGeneratorTest < Rails::Generators::TestCase
  tests Infotable::Generators::TableGenerator
  destination File.expand_path("../tmp/table_generator", __dir__)

  setup { prepare_destination }

  def generated(path)
    File.read(File.join(destination_root, path))
  end

  # Evaluates the generated table under a throwaway name (the dummy app already has a UsersTable)
  def load_table(source, name)
    mod = Module.new
    mod.module_eval(source.sub(/class \S+ </, "class #{name} <"), "generated_#{name}.rb")
    mod.const_get(name)
  end

  test "writes app/infotable/<model>s_table.rb with the model's columns" do
    run_generator %w[User]

    assert_file "app/infotable/users_table.rb" do |content|
      assert_match(/class UsersTable < Infotable::Base/, content)
      assert_match(/query \{ User\.all \}/, content)
      assert_match(/column :name,\n\s+type: :string,\n\s+sortable: true,\n\s+searchable: true,\n\s+filterable: true,\n\s+filter_type: :text/, content)
      assert_match(/column :age,\n\s+type: :integer/, content)
      assert_match(/default_sort :created_at, :desc/, content)
    end
  end

  test "the primary key is sortable but hidden and not filterable" do
    run_generator %w[User]

    table = load_table(generated("app/infotable/users_table.rb"), "GeneratedUsersTable")
    id = table.columns.find { _1[:name] == :id }
    assert_equal [ true, false, false ], [ id[:sortable], id[:filterable], id[:visible] ]
  end

  test "maps column types to types and filters" do
    run_generator %w[Product]
    table = load_table(generated("app/infotable/products_table.rb"), "GeneratedProductsTable")
    by_name = table.columns.index_by { _1[:name] }

    assert_equal :boolean, by_name[:active][:type]
    assert_equal :boolean, by_name[:active][:filter_type]
    assert_equal :decimal, by_name[:price][:type]
    assert_equal :number, by_name[:price][:filter_type]
    assert_equal :date, by_name[:manufactured_date][:type]
    assert_equal :datetime, by_name[:created_at][:type]
    assert_equal :date, by_name[:created_at][:filter_type]
  end

  test "the generated table builds a working query that filters and sorts" do
    create_users
    run_generator %w[User]
    table = load_table(generated("app/infotable/users_table.rb"), "GeneratedUsersQueryTable")

    result = filter(table, { "name" => { "op" => "contains", "value" => "alice" } })
    assert_equal [ "Alice Smith" ], result.map(&:name)
    assert_equal [ "Carol Jones", "Bob_100%", "Alice Smith" ], table.base_query.reorder(name: :desc).map(&:name)
  end

  test "--only and --skip choose the columns" do
    run_generator %w[User --only=id name email --skip=email]

    table = load_table(generated("app/infotable/users_table.rb"), "GeneratedOnlyTable")
    assert_equal %i[id name], table.columns.map { _1[:name] }
  end

  test "leaves out secrets" do
    model = Class.new(ApplicationRecord) do
      self.table_name = "users"
      def self.name = "SecretUser"
    end
    Object.const_set(:SecretUser, model)
    model.define_singleton_method(:columns) do
      super() + [ ActiveRecord::ConnectionAdapters::Column.new("password_digest", nil, ActiveRecord::Type::Value.new.then { ActiveRecord::ConnectionAdapters::SqlTypeMetadata.new(sql_type: "varchar", type: :string) }) ]
    end
    run_generator %w[SecretUser]

    assert_no_match(/password_digest/, generated("app/infotable/secret_users_table.rb"))
  ensure
    Object.send(:remove_const, :SecretUser) if Object.const_defined?(:SecretUser)
  end

  test "turns enums into select filters with their values" do
    model = Class.new(ApplicationRecord) do
      self.table_name = "users"
      enum :status, { active: "active", inactive: "inactive", pending: "pending" }, default: "active"
      def self.name = "EnumUser"
    end
    Object.const_set(:EnumUser, model)
    run_generator %w[EnumUser]

    content = generated("app/infotable/enum_users_table.rb")
    assert_match(/column :status,\n\s+type: :badge,.*filter_type: :select,\n\s+filter_options: %w\[active inactive pending\]/m, content)
  ensure
    Object.send(:remove_const, :EnumUser) if Object.const_defined?(:EnumUser)
  end

  test "namespaced models go into a matching folder and module" do
    module_name = "GenSpace"
    Object.const_set(module_name, Module.new)
    GenSpace.const_set(:Product, Class.new(ApplicationRecord) { self.table_name = "products" })
    run_generator %w[GenSpace::Product]

    assert_file "app/infotable/gen_space/products_table.rb", /class GenSpace::ProductsTable < Infotable::Base/
  ensure
    Object.send(:remove_const, :GenSpace) if Object.const_defined?(:GenSpace)
  end

  test "hints at belongs_to associations instead of generating foreign keys" do
    run_generator %w[Post]

    content = generated("app/infotable/posts_table.rb")
    assert_no_match(/column :author_id/, content)
    assert_match(/column :author, sql: "authors\.name", includes: :author/, content)
  end

  test "unknown models produce an empty table to fill in" do
    output = run_generator %w[Spaceship]

    assert_match(/Spaceship not found/, output)
    assert_file "app/infotable/spaceships_table.rb" do |content|
      assert_match(/class SpaceshipsTable < Infotable::Base/, content)
      assert_no_match(/^\s+column :/, content)
    end
  end
end
