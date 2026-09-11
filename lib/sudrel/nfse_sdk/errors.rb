# frozen_string_literal: true

module Sudrel
  module NfseSdk
    # Erro devolvido pela API pública da Sudrel — sempre no formato
    # `{ statusCode, message, error }`, onde `message` pode ser uma string
    # única ou uma lista (um item por campo inválido, em erros 400).
    class ApiError < StandardError
      attr_reader :status_code, :mensagens, :erro_tipo

      def initialize(status_code, mensagem, erro_tipo = nil)
        @status_code = status_code
        @mensagens = mensagem.is_a?(Array) ? mensagem : [mensagem]
        @erro_tipo = erro_tipo
        super(@mensagens.join(" "))
      end

      # 429 — limite de 120 requisições/minuto por chave excedido.
      def rate_limited?
        status_code == 429
      end

      # 401 — chave ausente, inválida ou revogada.
      def nao_autenticado?
        status_code == 401
      end

      # 404 — cobre tanto "não existe" quanto "existe, mas no outro
      # ambiente (sandbox/produção)" da mesma conta.
      def nao_encontrado?
        status_code == 404
      end
    end
  end
end
