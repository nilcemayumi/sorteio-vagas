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

ActiveRecord::Schema[7.1].define(version: 2024_02_03_003257) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "apartamentos", force: :cascade do |t|
    t.string "numero"
    t.string "torre"
    t.string "vaga"
    t.string "apto_relacionado"
    t.boolean "sorteado", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "vaga_sorteadas", force: :cascade do |t|
    t.bigint "vagas_id", null: false
    t.bigint "apartamentos_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["apartamentos_id"], name: "index_vaga_sorteadas_on_apartamentos_id"
    t.index ["vagas_id"], name: "index_vaga_sorteadas_on_vagas_id"
  end

  create_table "vagas", force: :cascade do |t|
    t.string "numero"
    t.string "tipo"
    t.string "subtipo"
    t.string "andar"
    t.boolean "sorteada", default: false
    t.string "vaga_relacionada"
    t.string "pref_torre"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "vaga_sorteadas", "apartamentos", column: "apartamentos_id"
  add_foreign_key "vaga_sorteadas", "vagas", column: "vagas_id"
end
