require 'csv'

class SorteiosController < ApplicationController
  def index

  end

  def sorteio
    # numero(seed) para realização dos sorteios, pode ser definido ou gerado automaticamente
    @seed = params[:seed].present? ? params[:seed].to_i : Random.new_seed
    dados_sorteio = preparar_dados_sorteio(@seed)
    efetuar_sorteio(dados_sorteio, @seed)

    vagas_sorteadas = VagaSorteada.all.order(apartamentos_id: :asc)
    @floresta = []
    @campos = []
    vagas_sorteadas.each do |resultado|
      apto = Apartamento.find(resultado.apartamentos_id)
      vaga = Vaga.find(resultado.vagas_id)
      if apto.vaga == 'dupla'
        numero_vaga = vaga.numero < vaga.vaga_relacionada ? "#{vaga.numero}/#{vaga.vaga_relacionada}" : "#{vaga.vaga_relacionada}/#{vaga.numero}"
      else
        numero_vaga = vaga.numero
      end
      if apto.torre == "A"
        @floresta << { apto: apto.numero,
                       vaga: numero_vaga,
                       andar: vaga.andar,
                       tipo_vaga: vaga.tipo }
      else
        @campos << { apto: apto.numero,
                     vaga: numero_vaga,
                     andar: vaga.andar,
                     tipo_vaga: vaga.tipo }
      end
    end
    @floresta.uniq!
    @campos.uniq!
    salvar_csv(@seed)
  end

  private

  def preparar_dados_sorteio(seed)
    # zera o banco de dados excluindo as vagas sorteadas e a relação entre apartamentos com vaga presa
    limpar_banco_de_dados
    # insere no banco de dados os apartamentos com vagas definidas
    alocar_vagas_definidas
    # relaciona os apartamentos de vagas simples que decidiram dividir uma vaga dupla voluntariamente
    aptos_vagas_divididas = duplas_apartamentos_definidos
    # determinar quantidade de vagas simples/individuais livres e cobertas restantes
    qtd_vagas_simples = Vaga.where("tipo= 'simples' AND subtipo = 'coberta' AND sorteada = false").count
    # apartamentos com direito a uma vaga e não determinadas
    aptos_vagas_simples = Apartamento.where("vaga = 'simples' AND sorteado = false AND apto_relacionado IS NULL").order(id: :asc)
    # sorteio dos apartamentos que irão ficar com uma vaga individual
    aptos_vagas_simples_cobertas = aptos_vagas_simples.sample(qtd_vagas_simples, random: Random.new(seed))
    # restante dos apartamentos que ficarão com vaga dividida
    aptos_vagas_simples_nao_sorteados = aptos_vagas_simples - aptos_vagas_simples_cobertas
    # juntar apartamentos para dividir vagas (preferencialmente mesma torre)
    aptos_vagas_divididas[:coberto] << definir_duplas_vagas_divididas(aptos_vagas_simples_nao_sorteados, @seed)
    aptos_vagas_divididas[:coberto].flatten!
    aptos_vagas_duplas_cobertas = Apartamento.where("vaga = 'dupla'").order(id: :asc)
    aptos_vagas_duplas_cobertas += aptos_vagas_divididas[:coberto]

    #tratar aptos vagas descobertas
    aptos_vagas_descobertas = []
    aptos_vagas_descobertas << Apartamento.where("vaga = 'descoberta' AND sorteado = false AND apto_relacionado IS NULL").order(id: :asc)
    aptos_vagas_descobertas.flatten!
    {
      aptos_vagas_simples_cobertas: aptos_vagas_simples_cobertas,
      aptos_vagas_duplas_cobertas: aptos_vagas_duplas_cobertas.shuffle!(random: Random.new(seed)),
      aptos_vagas_descobertas: aptos_vagas_descobertas.shuffle!(random: Random.new(seed)),
      aptos_vagas_duplas_descobertas: aptos_vagas_divididas[:descoberto].shuffle!(random: Random.new(seed))
    }

  end

  def alocar_vagas_definidas
    filepath = "csv/sorteio vagas - vagas definidas.csv"
    CSV.foreach(filepath, headers: :first_row) do |row|
      apartamento = Apartamento.find_by(numero: row[0])
      vaga = Vaga.find_by(numero: row[2])
      vaga_definida = VagaSorteada.new
      vaga_definida.vagas_id = vaga.id
      vaga_definida.apartamentos_id = apartamento.id
      vaga_definida.save
      apartamento.sorteado = true
      apartamento.save
      vaga.sorteada = true
      vaga.save
    end
  end

  def limpar_banco_de_dados
    VagaSorteada.destroy_all
    apartamentos = Apartamento.all
    apartamentos.each do |apartamento|
      apartamento.apto_relacionado = nil
      apartamento.sorteado = false
      apartamento.save
    end
    vagas = Vaga.all
    vagas.each do |vaga|
      vaga.sorteada = false
      vaga.save
    end
  end

  def duplas_apartamentos_definidos
    filepath = "csv/sorteio vagas - aptos relacionados.csv"
    coberto = []
    descoberto = []
    CSV.foreach(filepath, headers: :first_row) do |row|
      apto1 = Apartamento.find_by(numero: row[0])
      apto2 = Apartamento.find_by(numero: row[1])
      relacionar_aptos(apto1, apto2)
      if apto1.vaga == 'descoberta'
        descoberto << apto1
      else
       unless apto1.torre == apto2.torre
          apto1.torre == 'B'  ? coberto << apto1 : coberto << apto2
        else
          coberto << apto1
        end
      end
    end
    {coberto: coberto, descoberto: descoberto}
  end

  def definir_duplas_vagas_divididas(aptos, seed)
    aptos.shuffle!(random: Random.new(seed))
    resultado = []
    aptos_floresta = []
    aptos_campos = []
    aptos.each do |apto|
      apto.torre == 'A' ? aptos_floresta << apto : aptos_campos << apto
    end
    while aptos_floresta.count > 1 do
      apto1 = aptos_floresta.shift
      apto2 = aptos_floresta.shift
      relacionar_aptos(apto1, apto2)
      resultado << apto1
    end
    while aptos_campos.count > 1 do
      apto1 = aptos_campos.shift
      apto2 = aptos_campos.shift
      relacionar_aptos(apto1, apto2)
      resultado << apto1
    end
    unless aptos_floresta.empty?
      relacionar_aptos(aptos_floresta.first, aptos_campos.first)
      if aptos_floresta.first.vaga == 'descoberta'
        resultado << aptos_campos.first
      else
        vaga1 = Vaga.where("sorteada = false AND pref_torre IS NULL AND andar != '-3' AND subtipo = 'coberta'").order(id: :asc).shuffle(random: Random.new(seed)).first
        vaga2 = Vaga.find_by(numero: vaga1.vaga_relacionada)
        relacionar_vaga_apto(vaga1, aptos_floresta.first)
        relacionar_vaga_apto(vaga2, aptos_campos.first)
      end
    end
    resultado
  end

  def relacionar_aptos(apto1, apto2)
    apto1.apto_relacionado = apto2.numero
    apto2.apto_relacionado = apto1.numero
    apto1.save
    apto2.save
  end

  def efetuar_sorteio(dados, seed)
    # sorteio_vagas -3
    sorteio_subsolo_floresta(dados)
    # sorteio vagas duplas cobertas -2, -1
    sorteio_vagas_duplas_cobertas(dados)
    #sorteio vagas individuais cobertas -2, -1
    sorteio_vagas_individuais_cobertas(dados)
    # sorteio vagas descobertas
    sorteio_vagas_descobertas(dados,seed)
  end

  def relacionar_vaga_apto(vaga, apartamento)
    vaga_definida = VagaSorteada.new
    vaga_definida.vagas_id = vaga.id
    vaga_definida.apartamentos_id = apartamento.id
    vaga_definida.save
    apartamento.sorteado = true
    apartamento.save
    vaga.sorteada = true
    vaga.save
  end

  def salvar_csv(seed)
    resultados = VagaSorteada.all.order(vagas_id: :asc)
    filepath = "csv/sorteio vagas - resultado sorteio.csv"
    CSV.open(filepath, "wb") do |csv|
      csv << ["seed: #{seed}"]
      csv << ["numero vaga", "andar", "apartamento"]
      resultados.each do |resultado|
        apto = Apartamento.find(resultado.apartamentos_id)
        vaga = Vaga.find(resultado.vagas_id)
        csv << [vaga.numero, vaga.andar, apto.numero]
      end
    end
  end

  def sorteio_subsolo_floresta(dados)
    while vaga = Vaga.where("sorteada = false AND andar = '-3'").order(id: :asc).first
      if vaga.tipo == 'dupla'
        apto1 = dados[:aptos_vagas_duplas_cobertas].find{|apto| apto.sorteado == false &&
                                                                  apto.torre == 'A'}
        apto2 = apto1.apto_relacionado.nil? ? apto1 : Apartamento.find_by(numero: apto1.apto_relacionado)
        vaga2 = Vaga.find_by(numero: vaga.vaga_relacionada)
        relacionar_vaga_apto(vaga2, apto2)
      else
        apto1 = dados[:aptos_vagas_simples_cobertas].find{|apto| apto.sorteado == false &&
                                                                 apto.torre == 'A'}
      end
      relacionar_vaga_apto(vaga,apto1)
    end
  end

  def sorteio_vagas_duplas_cobertas(dados)
    aptos_vagas_duplas = dados["aptos_vagas_duplas_cobertas".to_sym].reject {|apto| apto.sorteado}
    aptos_vagas_duplas.each do |apto|
      vaga1 = Vaga.where("sorteada = false AND tipo = 'dupla' AND subtipo = 'coberta' AND pref_torre = ?", apto.torre).order(id: :asc).first
      vaga1 = Vaga.where("sorteada = false AND tipo = 'dupla' AND subtipo = 'coberta'AND pref_torre IS NULL").order(id: :asc).first if vaga1.nil?
      relacionar_vaga_apto(vaga1, apto)
      vaga2 = Vaga.find_by(numero: vaga1.vaga_relacionada)
      apto2 = apto.apto_relacionado.nil? ? apto : Apartamento.find_by(numero: apto.apto_relacionado)
      relacionar_vaga_apto(vaga2, apto2)
    end
  end

  def sorteio_vagas_individuais_cobertas(dados)
    aptos_vagas_individuais = dados["aptos_vagas_simples_cobertas".to_sym].reject {|apto| apto.sorteado}
    aptos_vagas_individuais.each do |apto|
      vaga = Vaga.where("sorteada = false AND subtipo = 'coberta' AND pref_torre = ?", apto.torre).order(id: :asc).first
      vaga = Vaga.where("sorteada = false AND subtipo = 'coberta'AND pref_torre IS NULL").order(id: :asc).first if vaga.nil?
      relacionar_vaga_apto(vaga, apto)
    end
  end

  def sorteio_vagas_descobertas(dados,seed)
    unless dados[:aptos_vagas_duplas_descobertas].empty?
      vagas_duplas = Vaga.where("sorteada = false AND tipo = 'dupla' AND subtipo = 'descoberta'").order(id: :asc).drop(1)
      vagas_duplas.shuffle!(random: Random.new(seed))
      dados[:aptos_vagas_duplas_descobertas].each do |apto|
        vaga1 = vagas_duplas.shift
        relacionar_vaga_apto(vaga1, apto)
        vaga2 = Vaga.find_by(numero: vaga1.vaga_relacionada)
        apto2 = Apartamento.find_by(numero: apto.apto_relacionado)
        relacionar_vaga_apto(vaga2, apto2)
      end
    end
    vagas_descobertas = Vaga.where("sorteada = false AND subtipo = 'descoberta'").order(id: :asc)
    aptos = dados[:aptos_vagas_descobertas]
    vagas_descobertas.each do |vaga|
      relacionar_vaga_apto(vaga, aptos.shift)
    end
  end
end
