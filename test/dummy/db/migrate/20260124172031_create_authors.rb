class CreateAuthors < ActiveRecord::Migration[8.1]
  def change
    create_table :authors do |t|
      t.string :name
      t.string :email
      t.text :bio
      t.string :website
      t.string :avatar_url
      t.string :country
      t.boolean :verified
      t.integer :followers_count

      t.timestamps
    end
  end
end
