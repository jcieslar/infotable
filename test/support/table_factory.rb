# Builds anonymous Infotable::Base subclasses and seed data for tests.
module TableFactory
  def build_table(model = User, &block)
    klass = Class.new(Infotable::Base)
    klass.query { model.all }
    klass.class_eval(&block) if block
    klass
  end

  def create_users
    [
      User.create!(name: "Alice Smith", email: "alice@example.com", company: "Acme", status: "active", age: 30, salary: 5000, score: 1.5),
      User.create!(name: "Bob_100%", email: "bob@example.com", company: "Globex", status: "inactive", age: 45, salary: 7000, score: 2.5),
      User.create!(name: "Carol Jones", email: "carol@other.org", company: nil, status: "pending", age: 22, salary: 3000, score: nil)
    ]
  end

  def filter(table, filters, relation = nil)
    relation ||= table.base_query
    Infotable::FilterProcessor.new(relation, table, filters).apply
  end
end

class ActiveSupport::TestCase
  include TableFactory
end
