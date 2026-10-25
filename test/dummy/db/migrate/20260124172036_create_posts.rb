class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.string :title
      t.text :body
      t.references :author, null: false, foreign_key: true
      t.string :status
      t.string :category
      t.integer :views_count
      t.integer :likes_count
      t.datetime :published_at
      t.boolean :featured
      t.integer :reading_time

      t.timestamps
    end
  end
end
