# CryptoHub

Aplicativo Flutter/Dart baseado no wireframe do Figma, com dados da CryptoCompare em BRL.

## Material para a entrega

- [Resumo da entrega e identificação da dupla](docs/ENTREGA.md).
- [Lista de pendências e limitações atuais](docs/PENDENCIAS.md).
- [Prints de todas as telas e formulários](docs/TELAS.md).

Os nomes da dupla são preenchidos em `docs/ENTREGA.md`. Um integrante envia a entrega incluindo o nome do colega.

## Abrir agora

- **Windows:** execute `ABRIR-CRYPTOHUB.cmd`. Ele abre a versão compilada, quando disponível; caso contrário, procura Flutter no PATH e depois no caminho local descrito abaixo.
- **Android:** instale `build/app/outputs/flutter-apk/app-debug.apk` no seu celular ou emulador.
- **Prévia web:** a pasta compilada é `build/web`; sirva-a por HTTP, em vez de abrir o HTML diretamente.

Na primeira configuração, toque no ícone de ajustes e cole suas chaves da CryptoCompare, uma por linha. O aplicativo salva a lista no armazenamento seguro deste aparelho, carrega-a ao abrir e alterna entre as chaves automaticamente. A API própria mantém a carteira; uma cópia local permite preservar os dados neste dispositivo. Favoritos e últimas cotações continuam locais.

A consulta real sem chave retornou HTTP 401. Na revisão de 04/10/2026, a chave fornecida respondeu a consultas de preços, catálogo, notícias e históricos diário e por minuto. Um limite temporário de consultas também foi observado; o aplicativo mostra esse erro e preserva as cotações salvas. A chave não foi gravada no código nem nos arquivos compilados.

## Executar o código

Requisitos usados na validação: Flutter 3.44.5 e Dart 3.12.2.

No terminal desta pasta:

```powershell
flutter pub get
flutter run -d windows
```

O SDK encontrado neste computador está em `C:\Users\Ezequiel\Desktop\DSDM\flutter`. Se Flutter não estiver no PATH:

```powershell
& "$env:USERPROFILE\Desktop\DSDM\flutter\bin\flutter.bat" run -d windows
```

Com um dispositivo Android conectado:

```powershell
flutter devices
flutter run -d ID_DO_DISPOSITIVO
```

Para executar no navegador disponível, sem depender da instalação do Chrome:

```powershell
flutter run -d web-server --web-hostname=127.0.0.1 --web-port=8766
```

Abra o endereço que o Flutter informar.

Também é possível configurar a chave durante a execução/compilação:

```powershell
flutter run -d windows --dart-define=CRYPTOCOMPARE_API_KEY=SUA_CHAVE
```

A chave passada por `dart-define` fica embutida no aplicativo. Para uso local, prefira configurar pelo formulário: as chaves ficam no armazenamento seguro do aparelho, não em preferências comuns nem no repositório. Não publique arquivos com suas chaves.

## Funcionalidades

- Mercado com oito moedas principais, pesquisa por nome/símbolo e favoritos.
- Detalhes por moeda: preço, variação, máxima/mínima, abertura, volumes, capitalização, oferta, exchange e atualização.
- Gráfico interativo de preços: 1D, 7D, 30D, 90D e 1A; consulta por toque, arraste e teclado.
- Carteira virtual: adicionar, editar e remover quantidades; valor total, distribuição e percentual por ativo.
- Evolução simulada: quantidades atuais multiplicadas pelos preços históricos de todos os ativos nas datas comuns. Não representa rentabilidade de compras reais.
- Notícias em português com resumo, fonte, data, imagem quando fornecida e abertura do link original.
- Carteira persistida pela API REST própria, com cópia local; favoritos e cache de cotações persistidos no dispositivo.
- Estados de carregamento, vazio, erro, dados ausentes e nova tentativa. Total indisponível quando falta preço válido, há excesso numérico ou os ativos têm cotações de consultas diferentes.
- Identidade escura, fonte Manrope local e ícones próprios. Atribuição “Powered by CryptoCompare”.

Atualize as cotações puxando a lista para baixo ou usando o botão de atualização. A carteira vem da API e os favoritos são locais a cada instalação.

## API REST própria

O projeto inclui uma API Node.js para a carteira virtual. Ela mantém os ativos em `api/data/portfolio.json` e oferece:

| Método | Rota | Ação |
| --- | --- | --- |
| GET | `/api/health` | Verificar se a API está disponível |
| GET | `/api/portfolio` | Consultar ativos da carteira |
| POST | `/api/portfolio/assets` | Adicionar um ativo |
| PUT | `/api/portfolio/assets/:symbol` | Criar ou atualizar um ativo |
| DELETE | `/api/portfolio/assets/:symbol` | Remover um ativo |

Exemplo de corpo para POST ou PUT: `{"symbol":"BTC","coinName":"Bitcoin","quantity":0.01,"imageUrl":null}`. A API retorna `400` para dados inválidos, `404` para rota ou ativo inexistente e `409` ao tentar adicionar um símbolo já cadastrado com POST.

Inicie a API em um terminal nesta pasta antes de usar a carteira:

```powershell
node api/src/server.mjs
```

No Windows e na web, o endereço padrão é `http://localhost:3000/api`. Para Android Emulator, inicie o Flutter apontando para o endereço especial do computador host:

```powershell
flutter run -d ID_DO_DISPOSITIVO --dart-define=CRYPTOHUB_API_URL=http://10.0.2.2:3000/api
```

Em um aparelho físico, inicie a API no PowerShell com `$env:HOST='0.0.0.0'; node api/src/server.mjs` e configure `CRYPTOHUB_API_URL` com o IP local do computador, por exemplo `http://192.168.0.10:3000/api`. Esta API é um protótipo acadêmico para execução local; não a exponha diretamente à internet.

Os ativos existentes no armazenamento local são copiados para a API quando ela inicia sem carteira cadastrada. Depois disso, a API é a fonte principal da carteira; favoritos e cotações continuam locais. A CryptoCompare permanece como fonte externa de cotações.

## Organização

```text
lib/
  models/      Dados da API e posição da carteira
  services/    CryptoApiService e armazenamento local
  providers/   Estado do aplicativo, detalhes e histórico da carteira
  screens/     Abas, detalhes, pesquisa e formulários
  widgets/     Cards, estados, gráficos e distribuição
  theme/       Cores, tipografia e componentes Material
  utils/       JSON seguro, formatação e feedback
  main.dart    Inicialização e injeção de serviços
test/          Testes HTTP, persistência, concorrência, gráficos e fluxos
tools/         Gerador dos ícones a partir do desenho vetorial
```

O serviço Node.js da API fica em `api/src/server.mjs`.

As consultas à CryptoCompare ficam em `CryptoApiService`; a comunicação com a API da carteira fica em `PortfolioApiService`. Os testes existentes usam respostas controladas para os serviços da CryptoCompare e armazenamento; a API própria roda separadamente.

## Endpoints

Base: `https://min-api.cryptocompare.com/data/`

| Método do serviço | Endpoint |
| --- | --- |
| getPrices | pricemulti |
| getQuotes / getCoinDetails | pricemultifull |
| getDailyHistory | v2/histoday |
| getHourlyHistory | v2/histohour |
| getMinuteHistory | v2/histominute |
| getCoinList | all/coinlist |
| getNews | v2/news/?lang=PT |

O gráfico de 1D usa registros por hora; os demais períodos usam registros diários. O método de histórico por minuto está disponível no serviço.

No Android, iOS e Windows, cada chamada usa uma chave do conjunto no cabeçalho `Authorization: Apikey …`. Na web, ela é enviada pelo parâmetro `api_key`, aceito pela API, para evitar a consulta prévia de autenticação que o navegador bloqueia. Em caso de limite (429) ou chave recusada, o serviço tenta as demais chaves configuradas. A API ainda pode compartilhar cotas entre chaves da mesma conta. Há limite de tempo de 15 segundos, tratamento de erros HTTP e JSON e requisições em lotes.

## Verificar e compilar

```powershell
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug
flutter build windows --release
```

As validações incluem campos nulos, números inválidos, timestamps Unix, cache, reabertura, falhas de leitura e gravação, respostas concorrentes, troca de chave durante consultas, carteira parcial, edição decimal e layout em 320/360 px com texto ampliado até 2 vezes.

Android, web e Windows foram compilados neste computador. O projeto inclui iOS, cuja compilação exige macOS/Xcode e não foi executada aqui.

A análise estática mais recente, em 13/10/2026, terminou sem problemas. A última execução da suíte, em 05/10/2026, passou com 144 testes.

Após alterar o código, compile novamente a plataforma desejada. `ABRIR-CRYPTOHUB.cmd` abre o último executável compilado.

## Correções da revisão

- Edições de favoritos e carteira informam o resultado da própria gravação e só aparecem como salvas depois do sucesso. Uma falha de leitura bloqueia edições até a recuperação dos dados locais.
- Respostas obtidas com uma configuração anterior de chaves são descartadas. Mercado, notícias, catálogo, detalhes e histórico repetem a consulta com a configuração atual.
- Respostas parciais preservam preços anteriores com a data de atualização de cada moeda. A carteira exige cotações da mesma consulta para somar seu total; preços zero/negativos não representam um ativo sem valor.
- Preços inferiores a um centavo mantêm precisão visível. Gráficos permitem selecionar registros com a mesma data e interrompem a linha em preços inválidos, zero ou negativos. Texto ampliado recebe espaço para leitura.
- O formulário de quantidade consulta o preço de moedas fora da lista principal. Chaves recusadas mantêm o formulário aberto com o erro; buscas reutilizam o catálogo já carregado.
- A autenticação web usa o parâmetro documentado pela CryptoCompare, permitindo consultar dados no navegador sem a falha de conexão causada pela consulta prévia CORS.
- Textos de notícias decodificam apóstrofos e referências Unicode de HTML. A indicação de carregamento para leitores de tela identifica corretamente as notícias. O feed em português retornou publicações antigas, cujas datas são preservadas.

Para compartilhar o aplicativo Windows, leve a pasta inteira `build/windows/x64/runner/Release`, incluindo DLLs e `data`. O APK é uma compilação de desenvolvimento para teste local.

Wireframe: [CryptoHub no Figma](https://www.figma.com/design/sOa8cCNPwOAPCqcYLKgwWi?node-id=4-62).
