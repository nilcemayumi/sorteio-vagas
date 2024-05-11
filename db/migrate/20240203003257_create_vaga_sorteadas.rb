class CreateVagaSorteadas < ActiveRecord::Migration[7.1]
  def change
    create_table :vaga_sorteadas do |t|
      t.references :vagas, null: false, foreign_key: true
      t.references :apartamentos, null: false, foreign_key: true
      t.timestamps
    end
  end
end
