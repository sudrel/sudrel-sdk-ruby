# frozen_string_literal: true

require "openssl"

module Sudrel
  module NfseSdk
    module Webhooks
      module_function

      # Verifica a assinatura HMAC-SHA256 (cabeçalho `X-Sudrel-Signature`)
      # de uma entrega de webhook, comparando em tempo constante pra evitar
      # ataques de timing.
      #
      # @param corpo_bruto [String] corpo bruto exatamente como recebido —
      #   não o objeto já parseado, já que reserializar JSON pode mudar a
      #   ordem/espaçamento e invalidar a assinatura.
      # @param assinatura_recebida [String] valor do cabeçalho `X-Sudrel-Signature`.
      # @param segredo [String] segredo do webhook, obtido na criação (ou
      #   rotação) dele pelo painel — só é exibido uma vez.
      # @return [Boolean]
      def verificar_assinatura(corpo_bruto, assinatura_recebida, segredo)
        esperada = OpenSSL::HMAC.hexdigest("SHA256", segredo, corpo_bruto)
        comparar_tempo_constante(esperada, assinatura_recebida)
      end

      # @return [Boolean]
      def comparar_tempo_constante(a, b)
        return false unless a.is_a?(String) && b.is_a?(String)
        return false unless a.bytesize == b.bytesize

        resultado = 0
        a.bytes.zip(b.bytes) { |x, y| resultado |= x ^ y }
        resultado.zero?
      end
    end
  end
end
