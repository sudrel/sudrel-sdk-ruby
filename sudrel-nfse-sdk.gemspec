# frozen_string_literal: true

require_relative "lib/sudrel/nfse_sdk/version"

Gem::Specification.new do |spec|
  spec.name = "sudrel-nfse-sdk"
  spec.version = Sudrel::NfseSdk::VERSION
  spec.authors = ["Sudrel"]
  spec.email = ["contato@sudrel.com.br"]

  spec.summary = "Cliente oficial Ruby para a API pública da Sudrel NFS-e Recebidas"
  spec.description = "Consulte e gerencie, de forma programática, as NFS-e (notas de serviço) " \
                      "monitoradas pela sua conta Sudrel — as mesmas empresas e documentos " \
                      "que aparecem no painel."
  spec.homepage = "https://sudrel.com.br/docs"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/sudrel/sudrel-sdk-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/sudrel/sudrel-sdk-ruby/releases"

  spec.files = Dir["lib/**/*.rb"] + ["README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.13"
end
