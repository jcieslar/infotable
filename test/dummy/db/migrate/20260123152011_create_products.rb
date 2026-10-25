class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name
      t.string :sku
      t.text :description
      t.string :category
      t.decimal :price
      t.decimal :cost
      t.integer :stock_quantity
      t.decimal :rating
      t.boolean :active
      t.boolean :featured
      t.string :manufacturer
      t.date :manufactured_date
      t.datetime :discontinued_at

      t.timestamps
    end
  end
end
