# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   e
require 'csv'

puts "Limpando banco de dados"
VagaSorteada.destroy_all
Apartamento.destroy_all
Vaga.destroy_all


#criar os apartamentos
puts "Cadastrando apartamentos"
filepath = "csv/sorteio vagas - aptos.csv"
CSV.foreach(filepath, headers: :first_row) do |row|
  Apartamento.create(numero:row[0], torre: row[1], vaga: row[2])
end

#criar as vagas
puts "Cadastrando as vagas"
filepath = "csv/sorteio vagas - vagas.csv"
CSV.foreach(filepath, headers: :first_row) do |row|
  Vaga.create(numero:row[0],
              tipo: row[1],
              subtipo: row[2],
              andar: row[3],
              vaga_relacionada: row[4],
              pref_torre: row[5])
end

