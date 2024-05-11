class CreateApartamentos < ActiveRecord::Migration[7.1]
  def change
    create_table :apartamentos do |t|
      t.string :numero
      t.string :torre
      t.string :vaga
      t.string :apto_relacionado
      t.boolean :sorteado, default: false

      t.timestamps
    end
  end
end
