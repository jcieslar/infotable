class AddNumericColumnsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :age, :integer
    add_column :users, :score, :decimal
    add_column :users, :salary, :decimal
  end
end
