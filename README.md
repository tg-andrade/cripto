# CryptoHub

Aplicativo Flutter/Dart baseado no wireframe do Figma, com dados da CryptoCompare em BRL.

## Abrir agora

- **Windows:** execute `ABRIR-CRYPTOHUB.cmd`. Ele abre a versão compilada, quando disponível.
- **Android:** instale `build/app/outputs/flutter-apk/app-debug.apk` no seu celular ou emulador.
- **Prévia web:** a pasta compilada é `build/web`; sirva-a por HTTP, em vez de abrir o HTML diretamente.

Na primeira abertura, toque no ícone de ajustes e informe sua chave da CryptoCompare. A chave digitada fica apenas na sessão. Favoritos, quantidades e últimas cotações ficam salvos no dispositivo.

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

A chave passada por `dart-define` fica embutida no aplicativo. O formulário de ajustes evita gravá-la em preferências locais. Não publique arquivos com sua chave.

## Funcionalidades

- Mercado com oito moedas principais, pesquisa por nome/símbolo e favoritos.
- Detalhes por moeda: preço, variação, máxima/mínima, abertura, volumes, capitalização, oferta, exchange e atualização.
- Gráfico interativo de preços: 1D, 7D, 30D, 90D e 1A; consulta por toque, arraste e teclado.
- Carteira virtual: adicionar, editar e remover quantidades; valor total, distribuição e percentual por ativo.
- Evolução simulada: quantidades atuais multiplicadas pelos preços históricos de todos os ativos nas datas comuns. Não representa rentabilidade de compras reais.
- Notícias em português com resumo, fonte, data, imagem quando fornecida e abertura do link original.
- Favoritos e carteira persistidos com SharedPreferences; cache de cotações para falhas de conexão.
- Estados de carregamento, vazio, erro, dados ausentes e nova tentativa. Total indisponível quando falta preço válido, há excesso numérico ou os ativos têm cotações de consultas diferentes.
- Identidade escura, fonte Manrope local e ícones próprios. Atribuição “Powered by CryptoCompare”.

Atualize as cotações puxando a lista para baixo ou usando o botão de atualização. Carteira e favoritos são locais a cada instalação.

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

Todas as requisições ficam em `CryptoApiService`. Os testes usam respostas controladas; o aplicativo utiliza somente a API real.

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

No Android, iOS e Windows, a chave vai no cabeçalho `Authorization: Apikey …`. Na web, é enviada pelo parâmetro `api_key`, aceito pela API, para evitar a consulta prévia de autenticação que o navegador bloqueia. Há limite de tempo de 15 segundos, tratamento de HTTP 401/403/429/5xx, erros JSON da API e requisições em lotes.

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

A suíte final passou com 144 testes em 04/10/2026. `flutter analyze` terminou sem problemas.

Após alterar o código, compile novamente a plataforma desejada. `ABRIR-CRYPTOHUB.cmd` abre o último executável compilado.

## Correções da revisão

- Edições de favoritos e carteira informam o resultado da própria gravação e só aparecem como salvas depois do sucesso. Uma falha de leitura bloqueia edições até a recuperação dos dados locais.
- Respostas obtidas com uma chave anterior são descartadas. Mercado, notícias e catálogo repetem a consulta com a chave atual; detalhes e histórico também protegem seus resultados.
- Respostas parciais preservam preços anteriores com a data de atualização de cada moeda. A carteira exige cotações da mesma consulta para somar seu total; preços zero/negativos não representam um ativo sem valor.
- Preços inferiores a um centavo mantêm precisão visível. Gráficos permitem selecionar registros com a mesma data e interrompem a linha em preços inválidos, zero ou negativos. Texto ampliado recebe espaço para leitura.
- O formulário de quantidade consulta o preço de moedas fora da lista principal. Chaves recusadas mantêm o formulário aberto com o erro; buscas reutilizam o catálogo já carregado.
- A autenticação web usa o parâmetro documentado pela CryptoCompare, permitindo consultar dados no navegador sem a falha de conexão causada pela consulta prévia CORS.
- Textos de notícias decodificam apóstrofos e referências Unicode de HTML. A indicação de carregamento para leitores de tela identifica corretamente as notícias. O feed em português retornou publicações antigas, cujas datas são preservadas.

Para compartilhar o aplicativo Windows, leve a pasta inteira `build/windows/x64/runner/Release`, incluindo DLLs e `data`. O APK é uma compilação de desenvolvimento para teste local.

Wireframe: [CryptoHub no Figma](https://www.figma.com/design/sOa8cCNPwOAPCqcYLKgwWi?node-id=4-62).
