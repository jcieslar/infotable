class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.text :body
      t.references :post, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: true
      t.string :status
      t.integer :likes_count
      t.boolean :flagged

      t.timestamps
    end
  end
end
