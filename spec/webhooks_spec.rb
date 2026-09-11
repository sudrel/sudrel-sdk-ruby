# frozen_string_literal: true

require "spec_helper"
require "openssl"
require "json"

RSpec.describe Sudrel::NfseSdk::Webhooks do
  let(:segredo) { "segredo-do-webhook" }
  let(:corpo) { JSON.generate({ "tipo" => "NOTA_RECEBIDA", "dados" => { "id" => "1" } }) }

  it "aceita uma assinatura válida" do
    assinatura = OpenSSL::HMAC.hexdigest("SHA256", segredo, corpo)
    expect(described_class.verificar_assinatura(corpo, assinatura, segredo)).to be(true)
  end

  it "rejeita uma assinatura de outro segredo" do
    assinatura = OpenSSL::HMAC.hexdigest("SHA256", "segredo-errado", corpo)
    expect(described_class.verificar_assinatura(corpo, assinatura, segredo)).to be(false)
  end

  it "rejeita uma assinatura de outro corpo (payload adulterado)" do
    assinatura = OpenSSL::HMAC.hexdigest("SHA256", segredo, corpo)
    corpo_adulterado = JSON.generate({ "tipo" => "NOTA_RECEBIDA", "dados" => { "id" => "2" } })
    expect(described_class.verificar_assinatura(corpo_adulterado, assinatura, segredo)).to be(false)
  end

  it "rejeita uma assinatura com tamanho diferente sem lançar erro" do
    expect(described_class.verificar_assinatura(corpo, "abc123", segredo)).to be(false)
  end
end
