class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :status, default: "active"
      t.string :company

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :status
  end
end
