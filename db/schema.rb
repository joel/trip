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

ActiveRecord::Schema[8.1].define(version: 2026_03_22_093252) do
  create_table "access_requests", id: uuid, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "reviewed_at"
    t.string "reviewed_by_id", limit: 36
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_access_requests_on_email"
    t.index ["reviewed_by_id"], name: "index_access_requests_on_reviewed_by_id"
  end

  create_table "action_text_rich_texts", id: uuid, force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "record_id", limit: 36, null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", id: uuid, force: :cascade do |t|
    t.string "blob_id", limit: 36, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "record_id", limit: 36, null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: uuid, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: uuid, force: :cascade do |t|
    t.string "blob_id", limit: 36, null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "invitations", id: uuid, force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.string "inviter_id", limit: 36, null: false
    t.integer "status", default: 0, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_invitations_on_email"
    t.index ["inviter_id"], name: "index_invitations_on_inviter_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
  end

  create_table "user_email_auth_keys", id: uuid, force: :cascade do |t|
    t.datetime "deadline", null: false
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key", null: false
  end

  create_table "user_verification_keys", id: uuid, force: :cascade do |t|
    t.datetime "email_last_sent", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "key", null: false
    t.datetime "requested_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "user_webauthn_keys", primary_key: ["user_id", "webauthn_id"], force: :cascade do |t|
    t.datetime "last_use", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "public_key", null: false
    t.integer "sign_count", null: false
    t.string "user_id", limit: 36
    t.string "webauthn_id"
    t.index ["user_id"], name: "index_user_webauthn_keys_on_user_id"
  end

  create_table "user_webauthn_user_ids", id: uuid, force: :cascade do |t|
    t.string "webauthn_id", null: false
  end

  create_table "users", id: uuid, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.integer "roles_mask", default: 8, null: false
    t.integer "status", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "access_requests", "users", column: "reviewed_by_id"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "invitations", "users", column: "inviter_id"
  add_foreign_key "user_email_auth_keys", "users", column: "id"
  add_foreign_key "user_verification_keys", "users", column: "id"
  add_foreign_key "user_webauthn_keys", "users"
  add_foreign_key "user_webauthn_user_ids", "users", column: "id"
end
