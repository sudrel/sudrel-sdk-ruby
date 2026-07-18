# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe Integrobr::NfseSdk::Client do
  def resposta(status, corpo)
    { status: status, body: corpo.nil? ? "" : JSON.generate(corpo) }
  end

  it "exige api_key" do
    expect { described_class.new(api_key: "") }.to raise_error(ArgumentError)
  end

  it "obter_conta faz GET /v1/account com o Bearer correto" do
    chamadas = []
    transporte = lambda do |metodo, url, headers, _corpo, _multipart|
      chamadas << [metodo, url, headers]
      resposta(200, { "id" => "123", "nome" => "Empresa X", "status" => "ATIVA", "ambiente" => "PRODUCAO", "criadaEm" => "2026-01-01T00:00:00.000Z" })
    end
    client = described_class.new(api_key: "ibr_live_abc", transporte: transporte)

    conta = client.obter_conta

    expect(conta["nome"]).to eq("Empresa X")
    expect(chamadas.size).to eq(1)
    metodo, url, headers = chamadas.first
    expect(metodo).to eq(:get)
    expect(url).to end_with("/v1/account")
    expect(headers["Authorization"]).to eq("Bearer ibr_live_abc")
  end

  it "listar_empresas devolve o array direto (sem paginação)" do
    transporte = ->(*) { resposta(200, [{ "id" => "1" }, { "id" => "2" }]) }
    client = described_class.new(api_key: "ibr_test_abc", transporte: transporte)

    expect(client.listar_empresas.size).to eq(2)
  end

  it "lança ApiError com status_code e mensagem no erro" do
    transporte = ->(*) { resposta(404, { "statusCode" => 404, "message" => "Empresa não encontrada nesta conta.", "error" => "Not Found" }) }
    client = described_class.new(api_key: "ibr_test_abc", transporte: transporte)

    expect { client.obter_empresa("inexistente") }.to raise_error(Integrobr::NfseSdk::ApiError) do |erro|
      expect(erro.status_code).to eq(404)
      expect(erro.nao_encontrado?).to be(true)
      expect(erro.mensagens).to eq(["Empresa não encontrada nesta conta."])
    end
  end

  it "listar_documentos monta a query string a partir dos filtros" do
    url_capturada = nil
    transporte = lambda do |_metodo, url, *_resto|
      url_capturada = url
      resposta(200, { "itens" => [], "proximoCursor" => nil })
    end
    client = described_class.new(api_key: "ibr_test_abc", transporte: transporte)

    client.listar_documentos(situacao: "AUTORIZADA", limite: 50, cnpjs: %w[111 222])

    expect(url_capturada).to include("situacao=AUTORIZADA")
    expect(url_capturada).to include("limite=50")
    expect(url_capturada).to include("cnpjs=111%2C222")
  end

  it "paginar_documentos segue proximoCursor até vir nil" do
    chamada = 0
    transporte = lambda do |*_args|
      chamada += 1
      if chamada == 1
        resposta(200, { "itens" => [{ "id" => "a" }, { "id" => "b" }], "proximoCursor" => "b" })
      else
        resposta(200, { "itens" => [{ "id" => "c" }], "proximoCursor" => nil })
      end
    end
    client = described_class.new(api_key: "ibr_test_abc", transporte: transporte)

    ids = client.paginar_documentos.map { |doc| doc["id"] }

    expect(ids).to eq(%w[a b c])
    expect(chamada).to eq(2)
  end
end
