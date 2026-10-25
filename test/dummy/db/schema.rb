# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_24_172040) do
  create_table "authors", force: :cascade do |t|
    t.string "avatar_url"
    t.text "bio"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "email"
    t.integer "followers_count"
    t.string "name"
    t.datetime "updated_at", null: false
    t.boolean "verified"
    t.string "website"
  end

  create_table "comments", force: :cascade do |t|
    t.integer "author_id", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.boolean "flagged"
    t.integer "likes_count"
    t.integer "post_id", null: false
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_comments_on_author_id"
    t.index ["post_id"], name: "index_comments_on_post_id"
  end

  create_table "posts", force: :cascade do |t|
    t.integer "author_id", null: false
    t.text "body"
    t.string "category"
    t.datetime "created_at", null: false
    t.boolean "featured"
    t.integer "likes_count"
    t.datetime "published_at"
    t.integer "reading_time"
    t.string "status"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "views_count"
    t.index ["author_id"], name: "index_posts_on_author_id"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "active"
    t.string "category"
    t.decimal "cost"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "discontinued_at"
    t.boolean "featured"
    t.date "manufactured_date"
    t.string "manufacturer"
    t.string "name"
    t.decimal "price"
    t.decimal "rating"
    t.string "sku"
    t.integer "stock_quantity"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.integer "age"
    t.string "company"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.decimal "salary"
    t.decimal "score"
    t.string "status", default: "active"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["status"], name: "index_users_on_status"
  end

  add_foreign_key "comments", "authors"
  add_foreign_key "comments", "posts"
  add_foreign_key "posts", "authors"
end
