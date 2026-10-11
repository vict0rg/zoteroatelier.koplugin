# Guia de uso — Zotero Atelier + Dropbox no KOReader

**Estado em 11/10/2026:** integração experimental. A autorização do Dropbox e a abertura de **um PDF e um EPUB** foram confirmadas no **KOReader Flatpak / Linux Mint**. O plugin foi copiado para um **Kindle Oasis**, cuja sincronização inicial de referências está em andamento; **a abertura e a reabertura sem Wi-Fi no Kindle ainda não foram confirmadas**.

Este guia descreve o comportamento **implementado no código**; os testes pendentes são indicados explicitamente.

## 1. O que fica no Zotero, no Dropbox e no aparelho?

| Origem | Função |
| --- | --- |
| **Zotero Web API** | Metadados: referências, coleções, títulos, autores, descrição dos anexos e dados de anotações |
| **Dropbox** | Arquivos PDF/EPUB da biblioteca pessoal, em pastas `storage/CHAVE_DO_ANEXO/NOME_DO_ARQUIVO` |
| **KOReader + Zotero Atelier** | Banco local das referências e cópias locais dos anexos que foram baixados |

**Não é leitura por streaming.** O Dropbox é acessado para baixar um arquivo quando necessário; o documento é gravado no armazenamento local do aparelho. O recurso de Dropbox é **somente leitura**: não envia alterações, anotações ou PDFs ao Dropbox.

As chaves de anexos não são as chaves das referências bibliográficas correspondentes.

## 2. Pré-requisitos

- KOReader instalado e funcional. No Kindle, isso pressupõe um modelo/firmware com jailbreak compatível; a instalação do jailbreak não faz parte deste projeto.
- A **branch experimental** [`feature/dropbox-on-demand`](https://github.com/vict0rg/zoteroatelier.koplugin/tree/feature/dropbox-on-demand) instalada, contendo `zotero_dropbox.lua` juntamente com o plugin original; reinicie completamente o KOReader após copiar.
- Uma conta Zotero pessoal com uma chave API configurada no Atelier.
- Arquivos efetivamente existentes no **Dropbox remoto** com o padrão `/PASTA/storage/CHAVE_DO_ANEXO/NOME.pdf` ou `.epub`.
- Aplicativo no [Dropbox App Console](https://www.dropbox.com/developers/apps) com acesso `Scoped access / Full Dropbox`, permissão **`files.content.read`**, PKCE/cliente público habilitado e uma App key pública. A permissão de gravação não é necessária.

A integração foi implementada para anexos do Zotero dos tipos `imported_file` ou `imported_url`. Arquivos `linked_file` com caminhos arbitrários não são resolvidos automaticamente por essa funcionalidade.

## 3. Instalar no Linux Mint, testar e configurar o Dropbox

1. Faça backup do plugin. Para KOReader **Flatpak** (`rocks.koreader.KOReader`), com o aplicativo totalmente fechado, utilize o instalador experimental [`tools/testar_flatpak.sh`](../tools/testar_flatpak.sh), que faz backup e atualiza quatro arquivos do plugin.
2. Reinicie o KOReader. Em **Zotero Atelier**, configure seu **Zotero User ID** e sua **API Key**, se necessário.
3. Execute **Synchronize** para criar/atualizar o banco local de referências.
4. Abra **Zotero Atelier → Settings → Configure Dropbox account → Dropbox app and storage folder**. Informe **App key** e o caminho **remoto** da pasta `storage` dentro do Dropbox. Exemplo: se a pasta no Linux for `/home/usuario/Dropbox/100-BIBLIOTECA_ZOTERO/storage`, o caminho **remoto** será `/100-BIBLIOTECA_ZOTERO/storage`.
5. No mesmo menu, selecione **Authorize Dropbox (QR code)**. Abra o endereço no celular/navegador, permita o acesso somente leitura e obtenha o código temporário.
6. Selecione **Enter Dropbox authorization code** no Atelier e informe o novo código **uma única vez**.
7. Em **Dropbox connection status**, confira `Authorization saved: yes` e `On-demand downloads: enabled`.
8. Abra uma referência pessoal com anexo PDF ou EPUB. Se o arquivo não estiver no computador, o plugin tentará baixá-lo individualmente do Dropbox.

Nunca compartilhe códigos OAuth, chaves privadas, arquivos de credenciais ou capturas contendo esses dados.

## 4. Levar a configuração do computador ao Kindle Oasis

Com o Kindle conectado por USB e o KOReader fechado no aparelho:

1. Copie para o Kindle a versão experimental **completa** do diretório `zoteroatelier.koplugin`; não basta copiar a versão antiga do plugin original.
2. É possível evitar a digitação das credenciais no Kindle copiando apenas os arquivos de configuração **`meta.lua`** (Zotero) e **`dropbox_atelier.lua`** (Dropbox) da pasta de dados do KOReader no computador para a pasta correspondente do Kindle, **sem colocar esses arquivos no repositório GitHub**.
3. Caminho de origem confirmado para o Flatpak de Linux Mint: `~/.var/app/rocks.koreader.KOReader/config/koreader/zotero/`.
4. Caminho usado no teste de transferência por USB: `/media/usuario/Kindle/koreader/zotero/` (o nome do ponto de montagem pode variar). Faça backup se houver arquivos já existentes com esses nomes.
5. Ejete o Kindle, abra o KOReader, confirme o **Dropbox connection status** e execute **Zotero Atelier → Synchronize** com Wi-Fi ativo.

**Por que sincronizar novamente no Kindle?** Porque `meta.lua` e `dropbox_atelier.lua` transportam **credenciais/configuração**, mas não o banco de dados local das referências, coleções e respectivos índices. Cada dispositivo mantém o próprio banco. Da mesma forma, os documentos que você baixou no Linux **não aparecem automaticamente** no Kindle.

Transferir uma credencial OAuth entre dispositivos é uma possibilidade técnica de uso pessoal; proteja os arquivos de configuração e revogue os acessos em caso de perda do aparelho.

## 5. Abertura e leitura offline

1. **Primeira vez, com Wi-Fi:** sincronize os metadados do Zotero no Kindle, selecione uma referência e abra seu PDF ou EPUB. Se o anexo ainda não existir localmente, o Dropbox será consultado e **somente aquele arquivo** será baixado.
2. **Depois do download:** o plugin grava uma cópia em `<pasta de dados do KOReader>/zotero/storage/<CHAVE_DO_ANEXO>/<NOME_DO_ARQUIVO>`. No Kindle que utiliza `/mnt/us/koreader` como pasta de dados, isso corresponde normalmente a `/mnt/us/koreader/zotero/storage/...`.
3. **Nas aberturas seguintes:** o Zotero Atelier **procura o arquivo local primeiro**. Se o arquivo existir, estiver utilizável e as verificações de versão o aceitarem, deve ser possível abri-lo **sem Wi-Fi**. O documento também pode ser acessível pelo navegador de arquivos do KOReader.
4. **Teste indispensável no Kindle:** abra um documento com o Wi-Fi ligado; saia dele; **desative o Wi-Fi**; volte ao Atelier e abra **o mesmo documento**. Em seguida, se necessário, localize o arquivo no navegador do KOReader. **Esse cenário ainda não foi validado no Oasis.**
5. Arquivos **não baixados** exigem conexão na primeira abertura. **Synchronize**, download de novos arquivos e sincronização de anotações também exigem acesso à rede.
6. Se a cópia local for apagada, o espaço de dados do KOReader for limpo ou uma verificação de versão exigir nova busca, uma nova transferência poderá ser necessária.

**Atenção:** a sincronização de anotações é uma função distinta do download de arquivos. A existência do PDF/EPUB local não significa que as anotações já estejam sincronizadas na nuvem. Durante os primeiros testes, desative **Write highlights into PDF files** para não modificar acidentalmente o PDF original.

## 6. Posso preparar uma coleção para uma viagem sem Wi-Fi?

O Zotero Atelier original tem a opção **Download this collection during sync** no menu de uma coleção. O código chama uma rotina de download em lote durante a **próxima sincronização**, e a integração Dropbox participa como origem alternativa dos anexos compatíveis.

Isso **não baixa automaticamente a biblioteca inteira**. A opção é por coleção e os arquivos ocuparão espaço no dispositivo. **O download em lote com Dropbox ainda não foi validado no Kindle:** teste inicialmente com uma coleção pequena, confirme cada documento e só então desligue a rede.

## 7. Indicador de progresso da sincronização (atualização experimental)

A branch experimental passou a mostrar um aviso **persistente, que não desaparece ao toque**, durante **Synchronize**. O aviso identifica quatro etapas:

1. **Step 1/4:** verificar a chave e o acesso à API Zotero.
2. **Step 2/4:** buscar coleções, com contagem real `X/Y` e porcentagem daquela etapa.
3. **Step 3/4:** buscar referências/itens, com contagem real `X/Y` e porcentagem daquela etapa.
4. **Step 4/4:** conferir e, se necessário, baixar os anexos das coleções marcadas para uso offline, com `X/Y` e porcentagem dos arquivos.

As porcentagens referem-se **à etapa atual**, não são estimativas do tempo total. Ainda não há medição contínua de **KB/s** nem uma indicação independente de atividade durante uma única requisição HTTPS longa. A tela pode ficar momentaneamente estática enquanto espera a rede; não interprete isso como conclusão nem como prova de que travou.

O último estado da sincronização é gravado em um pequeno arquivo de texto **sem credenciais**:

```text
<dados do KOReader>/zotero/sync_status.txt
```

No Kindle da instalação de teste, esse arquivo pode ser acessado pelo USB em `/media/usuario/Kindle/koreader/zotero/sync_status.txt`. Se a tela ficar parada por muito tempo, o arquivo ajuda a identificar a etapa em que o processo permaneceu. Ele **não comprova que a transferência está ativa**: registra apenas a última etapa atingida.

### Como atualizar apenas o indicador no Kindle

**Somente após encerrar o KOReader no Kindle** e conectá-lo ao Linux Mint por USB, execute:

```bash
curl -fL https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand/tools/atualizar_progresso_kindle.sh \
  -o ~/Downloads/atualizar_progresso_kindle.sh \
  && bash ~/Downloads/atualizar_progresso_kindle.sh
```

O script salva backup dos dois arquivos anteriores e atualiza **somente `main.lua` e `zoteroapi.lua`**, preservando credenciais, banco de dados, anexos e anotações. **Não desmonte o Kindle durante uma sincronização ou enquanto o KOReader estiver utilizando os arquivos.**

Esta interface nova **ainda precisa de validação prática no Kindle Oasis**. Não altere uma instalação funcional durante um processo de sincronização em andamento.

### Falha corrigida na primeira sincronização do Kindle (11/10/2026)

O primeiro teste no Kindle Oasis revelou o erro SQLite:

```text
ljsqlite3[error] no such column: "victorgianordoli"
zoteroapi.lua:1539: in function 'checkZoteroKey'
```

**Causa:** a versão original do Atelier montava o SQL de inicialização com `name="%s"`, usando aspas duplas para o nome de usuário. O SQLite interpretou o conteúdo como identificador de coluna, não como valor textual. O problema pode não aparecer em instalações com banco já inicializado.

**Correção experimental publicada:** a instrução usa `db:prepare(...)` e parâmetros ligados por `:bind(...)`, tanto para o nome quanto para os demais campos. **Não foi necessário apagar `zotero.db`, alterar a conta Zotero nem configurar novamente o Dropbox.** O instalador `tools/atualizar_progresso_kindle.sh` atualiza `zoteroapi.lua` e `main.lua` preservando o banco local.

**Situação:** a causa foi confirmada pelo log e a correção está no fork; a nova tentativa de sincronização no Kindle ainda precisa ser validada.

## 8. Dúvidas frequentes

**Os PDFs e EPUBs somem quando desligo o Wi-Fi?**  
Não por desligar o Wi-Fi: um download concluído corresponde a um arquivo gravado no aparelho, não a um streaming. A reabertura offline no Kindle ainda precisa ser confirmada experimentalmente.

**Preciso sincronizar todas as referências a cada leitura?**  
Não. A primeira sincronização cria o banco local; depois, `Synchronize` é usado quando quiser atualizar referências ou dados. Os anexos são transferidos sob demanda ou por download de coleção.

**Posso baixar no computador e encontrar automaticamente no Kindle?**  
Não. Cada KOReader mantém **seu próprio cache** e banco. Copiar os dois arquivos de configuração não transfere nem o cache de PDFs/EPUBs nem o banco sincronizado.

**Dropbox é usado para enviar anotações?**  
Não. O novo conector Dropbox possui apenas escopo `files.content.read`. A sincronização Zotero de anotações, quando ativada/configurada, é outra funcionalidade do Atelier e requer conexão.

**Onde ficam minhas senhas/tokens?**  
Na pasta local `<KOReader data directory>/zotero/`, principalmente `meta.lua` e `dropbox_atelier.lua`. Não publique, fotografe nem anexe esses arquivos a uma issue.

## Referências e acompanhamento

- [README do fork](../README.md)
- [Notas técnicas da integração](dropbox-on-demand.md)
- [Resultados dos testes manuais](manual-test-results.md)
- [Projeto original Zotero Atelier](https://github.com/Atelier-Recherche/zoteroatelier.koplugin)

Créditos: autores do Zotero Atelier (GPL-3.0); requisitos e testes de [@vict0rg](https://github.com/vict0rg); apoio à implementação por OpenAI ChatGPT (GPT-6).
