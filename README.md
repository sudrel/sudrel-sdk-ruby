# integrobr-nfse-sdk (Ruby)

Cliente oficial Ruby para a [API pública do IntegroBR NFS-e Recebidas](https://recebidas.integrobr.com/docs) — consulte e gerencie, de forma programática, as NFS-e (notas de serviço) monitoradas pela sua conta IntegroBR.

- Documentação completa da API: **https://recebidas.integrobr.com/docs**
- Requer Ruby **3.0+**. Usa só `net/http` da stdlib — sem dependências de runtime.

## Instalação

```bash
gem install integrobr-nfse-sdk
```

Ou no `Gemfile`:

```ruby
gem "integrobr-nfse-sdk"
```

## Uso rápido

```ruby
require "integrobr/nfse_sdk"

client = Integrobr::NfseSdk::Client.new(api_key: ENV.fetch("INTEGROBR_API_KEY"))

conta = client.obter_conta
puts "#{conta['nome']} #{conta['ambiente']}" # "Empresa Exemplo LTDA PRODUCAO"

empresas = client.listar_empresas
notas = client.listar_documentos(situacao: "AUTORIZADA", limite: 50)
```

Gere uma chave em **Painel → Chaves de API** (`/painel/chaves-api`). Ela só é exibida uma vez — se perder, revogue e crie outra. Existem dois ambientes de chave, que nunca se misturam:

| Prefixo | Ambiente |
|---|---|
| `ibr_test_...` | Sandbox — dados de teste, nunca reais, nunca geram cobrança. |
| `ibr_live_...` | Produção — dados fiscais reais da sua conta. |

## Empresas (CNPJs monitorados)

```ruby
# Listar (GET /companies não é paginado)
empresas = client.listar_empresas

# Cadastrar um CNPJ novo
empresa = client.criar_empresa(cnpj: "12345678000195", nomeExibicao: "Filial São Paulo")

# Enviar o certificado A1 (.pfx/.p12)
client.enviar_certificado(empresa["id"], "/caminho/para/certificado.pfx", "senha-do-certificado")

# Pausar / retomar
client.pausar_empresa(empresa["id"])
client.retomar_empresa(empresa["id"])

# Solicitar remoção (primeiro passo — a confirmação final é feita pelo painel)
client.remover_empresa(empresa["id"])
```

## Documentos (notas fiscais)

`GET /documents` usa paginação por cursor — passe `proximoCursor` de volta em `cursor` na próxima chamada:

```ruby
cursor = nil
loop do
  pagina = client.listar_documentos(cursor: cursor, limite: 100)
  pagina["itens"].each do |nota|
    puts "#{nota['numero']} #{nota['valorServicos']} #{nota['situacao']}"
  end
  break if pagina["proximoCursor"].nil?
  cursor = pagina["proximoCursor"]
end
```

Ou use `paginar_documentos`, que faz esse loop por você (com bloco, ou devolve um `Enumerator` sem bloco):

```ruby
client.paginar_documentos(situacao: "AUTORIZADA") do |nota|
  puts nota["numero"]
end

# ou, como Enumerator:
primeiras_10 = client.paginar_documentos.first(10)
```

Detalhe de uma nota (inclui XML original e linha do tempo de eventos):

```ruby
detalhe = client.obter_documento(nota["id"])
pp detalhe["eventos"]
```

## Consumo do ciclo atual

```ruby
consumo = client.obter_consumo
if consumo["temCicloAtivo"]
  puts "#{consumo['eventosIncluidos']}/#{consumo['franquiaEventos']} eventos usados neste ciclo"
end
```

## Tratamento de erros

Toda chamada que falha levanta `Integrobr::NfseSdk::ApiError`, com `status_code`, `mensagens` (sempre um array, mesmo quando a API devolve uma string única) e predicados pros casos mais comuns:

```ruby
begin
  client.obter_empresa("id-que-nao-existe")
rescue Integrobr::NfseSdk::ApiError => e
  if e.nao_encontrado?
    # 404 — não existe nesta conta, ou existe só no outro ambiente (sandbox/produção)
  end
  if e.rate_limited?
    # 429 — 120 requisições/minuto por chave; espere e tente de novo
  end
  warn "#{e.status_code}: #{e.mensagens.join(' ')}"
end
```

## Webhooks

Configure webhooks pelo painel (**Painel → Webhooks**) pra ser avisado em tempo real (`NOTA_RECEBIDA`, `EVENTO_FISCAL_RECEBIDO`) em vez de ficar consultando `GET /documents`. Cada entrega assina o corpo com HMAC-SHA256 no cabeçalho `X-IntegroBR-Signature` — **sempre verifique antes de confiar no payload**:

```ruby
require "integrobr/nfse_sdk"

# Exemplo com Sinatra — o importante é ler o corpo BRUTO, não decodificado
post "/webhooks/integrobr" do
  corpo_bruto = request.body.read
  assinatura = request.env["HTTP_X_INTEGROBR_SIGNATURE"] || ""

  valido = Integrobr::NfseSdk::Webhooks.verificar_assinatura(corpo_bruto, assinatura, ENV.fetch("INTEGROBR_WEBHOOK_SECRET"))
  halt 401, "assinatura inválida" unless valido

  payload = JSON.parse(corpo_bruto)
  puts payload["tipo"]
  status 200
end
```

O segredo do webhook só é exibido uma vez, na criação (ou ao rotacionar) — guarde com o mesmo cuidado de uma senha.

## Limite de requisições

120 requisições por minuto, por chave de API (janela fixa de 60s). Passar do limite devolve `429`, exposto como `e.rate_limited?`.

## Desenvolvimento

```bash
bundle install
bundle exec rspec
```

## Licença

MIT — veja [LICENSE](./LICENSE).
