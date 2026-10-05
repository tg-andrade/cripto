# Lista de pendências — CryptoHub

## Para concluir a entrega acadêmica

- [ ] Preencher o nome de quem fará a entrega e o nome do colega em [ENTREGA.md](ENTREGA.md).
- [ ] Publicar no GitHub a documentação e os prints preparados nesta pasta.
- [ ] Conferir os links e imagens no GitHub após o envio.
- [ ] Um integrante da dupla enviar a entrega ao professor, identificando os dois alunos.

O código, as instruções de execução e a arquitetura estão descritos no [README](../README.md). Os prints são organizados em [TELAS.md](TELAS.md).

## Limitações atuais

| Item | Situação atual | Ação, se necessária |
| --- | --- | --- |
| Acesso à API | As consultas reais dependem de internet e de uma chave válida da CryptoCompare. A chave informada no formulário vale somente para a sessão. A API pode limitar consultas. | Informar uma chave própria na demonstração; se houver limite, aguardar e tentar novamente. |
| Validação de iOS | O projeto inclui iOS, mas a compilação e execução não foram validadas neste computador Windows. | Validar em macOS com Xcode se a avaliação exigir iOS. |
| Distribuição Android | O APK documentado é de desenvolvimento. A configuração `release` também usa a assinatura de debug. | Configurar assinatura de produção se houver futura distribuição em loja. |
| Histórico da carteira | A evolução é simulada com as quantidades atuais e preços históricos; não há registro de compras e datas de aquisição. | Acrescentar transações e datas apenas se o projeto for ampliado para calcular rentabilidade real. |

Esses limites estão documentados e não exigem publicação em loja para a entrega acadêmica solicitada.

## Melhorias opcionais

- Configurar integração contínua no GitHub para executar `flutter analyze` e `flutter test` a cada alteração.
- Ampliar a validação em dispositivos físicos e plataformas adicionais conforme o uso futuro do aplicativo.

As melhorias opcionais não fazem parte dos itens pedidos pelo professor.
