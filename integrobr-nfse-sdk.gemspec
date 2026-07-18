# frozen_string_literal: true

require_relative "lib/integrobr/nfse_sdk/version"

Gem::Specification.new do |spec|
  spec.name = "integrobr-nfse-sdk"
  spec.version = Integrobr::NfseSdk::VERSION
  spec.authors = ["IntegroBR"]
  spec.email = ["comercial@integrobr.com"]

  spec.summary = "Cliente oficial Ruby para a API pública do IntegroBR NFS-e Recebidas"
  spec.description = "Consulte e gerencie, de forma programática, as NFS-e (notas de serviço) " \
                      "monitoradas pela sua conta IntegroBR — as mesmas empresas e documentos " \
                      "que aparecem no painel."
  spec.homepage = "https://recebidas.integrobr.com/docs"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/integrobr/integrobr-sdk-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/integrobr/integrobr-sdk-ruby/releases"

  spec.files = Dir["lib/**/*.rb"] + ["README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.13"
end
