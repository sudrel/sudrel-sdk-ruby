# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Sudrel
  module NfseSdk
    # Cliente oficial da API pública da Sudrel NFS-e Recebidas.
    #
    #   client = Sudrel::NfseSdk::Client.new(api_key: ENV.fetch("SUDREL_API_KEY"))
    #   empresas = client.listar_empresas
    class Client
      BASE_URL_PADRAO = "https://api.sudrel.com.br/api"

      # @param api_key [String] chave de API — `sdr_live_...` (produção) ou `sdr_test_...` (sandbox).
      # @param base_url [String] sobrescreve a URL base — usado só em testes/desenvolvimento.
      # @param timeout [Integer] timeout por requisição, em segundos.
      # @param transporte [#call, nil] função de transporte HTTP customizada — usada em testes.
      def initialize(api_key:, base_url: BASE_URL_PADRAO, timeout: 30, transporte: nil)
        raise ArgumentError, "api_key é obrigatório" if api_key.nil? || api_key.empty?

        @api_key = api_key
        @base_url = base_url
        @timeout = timeout
        @transporte = transporte || method(:transporte_padrao)
      end

      # GET /v1/account — identifica a conta dona da chave de API usada.
      def obter_conta
        requisitar(:get, "/v1/account")
      end

      # GET /v1/usage — franquia, consumo e excedente do ciclo em andamento.
      def obter_consumo
        requisitar(:get, "/v1/usage")
      end

      # GET /v1/companies — todas as empresas do ambiente da chave usada. Não é paginado.
      def listar_empresas
        requisitar(:get, "/v1/companies")
      end

      # GET /v1/companies/{id}
      def obter_empresa(id)
        requisitar(:get, "/v1/companies/#{URI.encode_www_form_component(id)}")
      end

      # POST /v1/companies — cadastra um CNPJ para monitoramento.
      # @param dados [Hash] cnpj (obrigatório), nomeExibicao, nsuInicial.
      def criar_empresa(dados)
        requisitar(:post, "/v1/companies", corpo: dados)
      end

      # POST /v1/companies/{id}/certificate — envia (ou troca) o certificado A1 (.pfx/.p12, até 10MB).
      def enviar_certificado(id, caminho_arquivo, senha)
        raise ArgumentError, "arquivo de certificado não encontrado ou sem permissão de leitura: #{caminho_arquivo}" unless File.readable?(caminho_arquivo)

        arquivo = File.open(caminho_arquivo, "rb")
        multipart = [
          ["certificado", arquivo, { filename: File.basename(caminho_arquivo) }],
          ["senha", senha],
        ]
        requisitar(:post, "/v1/companies/#{URI.encode_www_form_component(id)}/certificate", multipart: multipart)
      ensure
        arquivo&.close
      end

      # POST /v1/companies/{id}/pause
      def pausar_empresa(id)
        requisitar(:post, "/v1/companies/#{URI.encode_www_form_component(id)}/pause")
      end

      # POST /v1/companies/{id}/resume
      def retomar_empresa(id)
        requisitar(:post, "/v1/companies/#{URI.encode_www_form_component(id)}/resume")
      end

      # DELETE /v1/companies/{id} — solicita a remoção (primeiro passo; a confirmação é feita pelo painel).
      def remover_empresa(id)
        requisitar(:delete, "/v1/companies/#{URI.encode_www_form_component(id)}")
      end

      # GET /v1/documents — uma página de notas. Use `paginar_documentos` pra percorrer tudo.
      # @param filtros [Hash] cnpjs (String ou Array), situacao, papel, prestador, numero,
      #   chaveAcesso, valorMinCentavos, valorMaxCentavos, dataInicio, dataFim, cursor, limite.
      def listar_documentos(filtros = {})
        filtros = filtros.dup
        filtros[:cnpjs] = filtros[:cnpjs].join(",") if filtros[:cnpjs].is_a?(Array)
        requisitar(:get, "/v1/documents", query: filtros)
      end

      # GET /v1/documents/{id} — inclui XML original e linha do tempo de eventos.
      def obter_documento(id)
        requisitar(:get, "/v1/documents/#{URI.encode_www_form_component(id)}")
      end

      # Percorre todas as páginas automaticamente, seguindo `proximoCursor` até
      # ele vir vazio/nil. Sem bloco, devolve um Enumerator (dá pra usar
      # `.lazy`, `.first(n)` etc). Útil pra sincronizações completas — pra
      # volumes grandes, prefira filtrar por `dataInicio`/`dataFim` e usar
      # webhooks pra novidades em tempo real, em vez de repetir isso com
      # frequência.
      def paginar_documentos(filtros = {})
        return enum_for(:paginar_documentos, filtros) unless block_given?

        cursor = filtros[:cursor]
        loop do
          pagina = listar_documentos(filtros.merge(cursor: cursor))
          pagina["itens"].each { |item| yield item }
          break if pagina["proximoCursor"].nil? || pagina["proximoCursor"].to_s.empty?

          cursor = pagina["proximoCursor"]
        end
      end

      private

      def requisitar(metodo, caminho, query: {}, corpo: nil, multipart: nil)
        query = query.compact
        url = "#{@base_url}#{caminho}"
        url += "?#{URI.encode_www_form(query)}" unless query.empty?

        headers = { "Authorization" => "Bearer #{@api_key}" }
        corpo_para_enviar = nil

        if multipart
          corpo_para_enviar = nil
        elsif corpo
          headers["Content-Type"] = "application/json"
          corpo_para_enviar = JSON.generate(corpo)
        end

        resultado = @transporte.call(metodo, url, headers, corpo_para_enviar, multipart)
        status = resultado[:status]
        body = resultado[:body]

        return nil if status == 204 || body.nil? || body.empty?

        dados = JSON.parse(body)

        if status < 200 || status >= 300
          mensagem = dados["message"] || "Erro desconhecido."
          raise ApiError.new(status, mensagem, dados["error"])
        end

        dados
      end

      def transporte_padrao(metodo, url, headers, corpo, multipart)
        uri = URI(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: @timeout) do |http|
          request = montar_requisicao(metodo, uri, headers, corpo, multipart)
          resposta = http.request(request)
          { status: resposta.code.to_i, body: resposta.body }
        end
      end

      def montar_requisicao(metodo, uri, headers, corpo, multipart)
        request = case metodo
                  when :get then Net::HTTP::Get.new(uri)
                  when :post then Net::HTTP::Post.new(uri)
                  when :delete then Net::HTTP::Delete.new(uri)
                  else raise ArgumentError, "método não suportado: #{metodo}"
                  end
        headers.each { |k, v| request[k] = v }

        if multipart
          request.set_form(multipart, "multipart/form-data")
        elsif corpo
          request.body = corpo
        end

        request
      end
    end
  end
end
