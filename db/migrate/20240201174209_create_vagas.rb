class CreateVagas < ActiveRecord::Migration[7.1]
  def change
    create_table :vagas do |t|
      t.string :numero
      t.string :tipo
      t.string :subtipo
      t.string :andar
      t.boolean :sorteada, default: false
      t.string :vaga_relacionada, default: nil
      t.string :pref_torre

      t.timestamps
    end
  end
end
