# Guia de uso — Zotero Atelier + Dropbox no KOReader

**Estado em 11/10/2026:** integração experimental. A autorização do Dropbox e a abertura de **um PDF e um EPUB** foram confirmadas no **KOReader Flatpak / Linux Mint**. **No Kindle Oasis, após corrigir a inicialização do SQLite, o usuário confirmou que a sincronização passou a funcionar e conseguiu abrir um artigo e um livro EPUB pelo Zotero Atelier.** **A reabertura sem Wi-Fi já foi confirmada:** os anexos permaneceram no diretório `storage` local do Kindle e abriram normalmente offline. A confirmação independente da origem de download de cada arquivo ainda não foi feita.

Este guia descreve o comportamento **implementado no código**; os testes pendentes são indicados explicitamente.

## 1. O que fica no Zotero, no Dropbox e no aparelho?

| Origem | Função |
| --- | --- |
| **Zotero Web API** | Metadados: referências, coleções, títulos, autores, descrição dos anexos e dados de anotações |
| **Dropbox** | Arquivos PDF/EPUB da biblioteca pessoal, em pastas `storage/CHAVE_DO_ANEXO/NOME_DO_ARQUIVO` |
| **KOReader + Zotero Atelier** | Banco local das referências e cópias locais dos anexos que foram baixados |

**Não é leitura por streaming.** O Dropbox é acessado para baixar um arquivo quando necessário; o documento é gravado no armazenamento local do aparelho. O recurso de Dropbox é **somente leitura**: não envia alterações, anotações ou PDFs ao Dropbox.

As chaves de anexos não são as chaves das referências bibliográficas correspondentes.

**Novo teste confirmado em 11/10/2026:** depois da leitura inicial, os arquivos permaneceram no `storage` local do Kindle Oasis e puderam ser abertos normalmente com o Wi-Fi desligado. Isso valida o funcionamento do cache de leitura offline no aparelho.

## 2. Pré-requisitos

- KOReader instalado e funcional. No Kindle, isso pressupõe um modelo/firmware com jailbreak compatível; a instalação do jailbreak não faz parte deste projeto.
- A **branch experimental** [`feature/dropbox-on-demand`](https://github.com/vict0rg/zoteroatelier.koplugin/tree/feature/dropbox-on-demand) instalada, contendo `zotero_dropbox.lua` juntamente com o plugin original; reinicie completamente o KOReader após copiar.
- Uma conta Zotero pessoal com uma chave API configurada no Atelier.
- Arquivos efetivamente existentes no **Dropbox remoto** com o padrão `/PASTA/storage/CHAVE_DO_ANEXO/NOME.pdf` ou `.epub`.
- Aplicativo no [Dropbox App Console](https://www.dropbox.com/developers/apps) com acesso `Scoped access / Full Dropbox`, permissão **`files.content.read`**, PKCE/cliente público habilitado e uma App key pública. A permissão de gravação não é necessária.

A integração foi implementada para anexos do Zotero dos tipos `imported_file` ou `imported_url`. Arquivos `linked_file` com caminhos arbitrários não são resolvidos automaticamente por essa funcionalidade.

## 3. Instalar no Linux Mint, testar e configurar o Dropbox

1. Faça backup do plugin. Para KOReader **Flatpak** (`rocks.koreader.KOReader`), com o aplicativo totalmente fechado, utilize o instalador experimental [`tools/testar_flatpak.sh`](../tools/testar_flatpak.sh), que faz backup e atualiza seis arquivos do plugin.
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
2. **Depois do download (branch atual):** no **Kindle Oasis**, o plugin salva o anexo em `/mnt/us/documents/Zotero/storage/<CHAVE_DO_ANEXO>/<NOME_DO_ARQUIVO>`, permitindo mostrar as capas no mosaico de `documents` quando estiver habilitada a exibição recursiva de subpastas. No **Flatpak**, permanece em `<pasta de dados do KOReader>/zotero/storage/<CHAVE_DO_ANEXO>/<NOME_DO_ARQUIVO>`. Os metadados, o banco SQLite e as credenciais continuam no diretório `koreader/zotero`.
3. **Nas aberturas seguintes:** o Zotero Atelier **procura o arquivo local primeiro**. Se o arquivo existir, estiver utilizável e as verificações de versão o aceitarem, deve ser possível abri-lo **sem Wi-Fi**. O documento também pode ser acessível pelo navegador de arquivos do KOReader.
4. **Teste offline:** abra um documento com o Wi-Fi ligado; saia dele; **desative o Wi-Fi**; volte ao Atelier e abra **o mesmo documento**. **Esse cenário foi validado pelo usuário no Kindle Oasis antes da migração de pasta.** Após mudar para `documents`, repita a abertura para confirmar o novo caminho.
5. Arquivos **não baixados** exigem conexão na primeira abertura. **Synchronize**, download de novos arquivos e sincronização de anotações também exigem acesso à rede.
6. Se a cópia local for apagada, o espaço de dados do KOReader for limpo ou uma verificação de versão exigir nova busca, uma nova transferência poderá ser necessária.

**Atenção:** a sincronização de anotações é uma função distinta do download de arquivos. A existência do PDF/EPUB local não significa que as anotações já estejam sincronizadas na nuvem. Durante os primeiros testes, desative **Write highlights into PDF files** para não modificar acidentalmente o PDF original.

## 5.1. Colocar os livros do Zotero no mosaico de capas do Kindle

A partir desta versão experimental, no Kindle com KOReader em `/mnt/us/koreader`, os anexos baixados vão para:

```text
/mnt/us/documents/Zotero/storage/CHAVE_DO_ANEXO/Livro.epub
```

O Dropbox **não muda de endereço**. O prefixo `storage` no Dropbox continua sendo apenas a pasta **remota**; o `documents/Zotero/storage` é a cópia **local** do Kindle. Os metadados da biblioteca, o banco `zotero.db`, os arquivos de credenciais e o histórico do andamento da sincronização continuam em `/mnt/us/koreader/zotero`. No Linux Mint/Flatpak, os downloads permanecem na localização anterior.

**Migração da instalação já funcional:** com o KOReader completamente fechado e o Kindle montado via USB no Linux Mint, execute:

```bash
curl -fL https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand/tools/mover_storage_para_documents_kindle.sh \
  -o ~/Downloads/mover_storage_para_documents_kindle.sh \
  && bash ~/Downloads/mover_storage_para_documents_kindle.sh
```

O script verifica o volume USB, baixa e valida a sintaxe de `zoteroapi.lua` (se houver compilador Lua), cria backup do código anterior e do banco SQLite, e **move a pasta `storage` inteira** — com seus PDFs, EPUBs, `.sdr` e demais arquivos auxiliares — para dentro de `documents/Zotero`. O movimento ocorre dentro do mesmo volume do Kindle; não faz cópia integral dos livros para o computador. **Se ambas as pastas `storage` já existirem, interrompe sem mesclar ou substituir arquivos.** Não copie só os PDFs: os arquivos de configuração de leitura podem estar ao lado deles.

Ejete o dispositivo antes de abrir o KOReader. Caso os atalhos de documentos recentes apontem para o endereço antigo, abra o livro novamente pelo Zotero Atelier ou pelo navegador `documents/Zotero`. Com a opção do navegador do KOReader de exibir conteúdo das subpastas, os documentos poderão aparecer no mosaico. A reabertura após a **migração** ainda precisa ser testada em aparelho real.

**Travamento observado:** houve um congelamento relatado durante a navegação por um diretório interno `/mnt/.../storage` no Kindle, seguido de reinício forçado. A causa não foi identificada. A mudança de pasta melhora a organização e a descoberta de livros no navegador, mas **não constitui diagnóstico ou correção comprovada do travamento**.

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

O script salva backup dos arquivos anteriores e atualiza cinco módulos de código (`main.lua`, `zoteroapi.lua`, `zotero_dropbox.lua`, `zotero_file_validation.lua` e `zotero_storage_manager.lua`), preservando credenciais, banco de dados, anexos e anotações. **Não desmonte o Kindle durante uma sincronização ou enquanto o KOReader estiver utilizando os arquivos.**

Esta interface nova **ainda precisa de validação prática no Kindle Oasis**. Não altere uma instalação funcional durante um processo de sincronização em andamento.

### Falha corrigida na primeira sincronização do Kindle (11/10/2026)

O primeiro teste no Kindle Oasis revelou o erro SQLite:

```text
ljsqlite3[error] no such column: "victorgianordoli"
zoteroapi.lua:1539: in function 'checkZoteroKey'
```

**Causa:** a versão original do Atelier montava o SQL de inicialização com `name="%s"`, usando aspas duplas para o nome de usuário. O SQLite interpretou o conteúdo como identificador de coluna, não como valor textual. O problema pode não aparecer em instalações com banco já inicializado.

**Correção experimental publicada:** a instrução usa `db:prepare(...)` e parâmetros ligados por `:bind(...)`, tanto para o nome quanto para os demais campos. **Não foi necessário apagar `zotero.db`, alterar a conta Zotero nem configurar novamente o Dropbox.** O instalador `tools/atualizar_progresso_kindle.sh` atualiza `zoteroapi.lua` e `main.lua` preservando o banco local.

**Situação:** a correção foi validada em teste no Kindle Oasis; sincronização, navegação e abertura de documentos passaram após a atualização.

### Problema adicional no Kindle: versão remota atualizada, banco local vazio

A comparação em modo somente leitura confirmou no Kindle: `PRAGMA user_version = 0`, **0 coleções**, **0 itens**, **0 anexos**, **sem a coleção raiz `/`**, mas a biblioteca já marcada com o cursor remoto `38750`. O Flatpak, por contraste, apresentou 85 coleções, 602 itens e 260 anexos.

A investigação do bootstrap revelou **aspas duplas** em valores textuais da inserção em `itemTypes` (por exemplo `"attachment"`). Dependendo da configuração SQLite, isso é interpretado como nome de coluna e pode interromper a inicialização antes de criar a coleção raiz. A consequência é especialmente grave porque as instruções `INSERT ... SELECT` não inserem nenhuma coleção sem o pai `/` nem itens sem suas definições de tipo, e a versão remota ainda podia ser gravada como sincronizada.

A branch experimental agora:
- usa literais SQL entre aspas simples na população de `itemTypes`;
- assegura a presença da coleção raiz e das definições de tipos;
- verifica a versão do esquema antes de considerá-lo inicializado;
- reconhece um banco **comprovadamente vazio e parcialmente inicializado**, e zera **somente o cursor remoto**, forçando a recuperação dos metadados no próximo `Synchronize`;
- recusa concluir uma primeira sincronização se a API retornou dados, mas o banco persistiu com zero registros;
- preserva a última etapa no arquivo de diagnóstico.

Com o KOReader **fechado** e o Kindle conectado por USB, execute novamente o script de atualização do tópico anterior. O script fará backup do `zotero.db` presente no Kindle, bem como do código anterior, antes de copiar o fix. Em seguida, ejete o Kindle, inicie o KOReader e use **Synchronize**, sem escolher `Resync entire collection` e **sem excluir arquivos manualmente**.

**Resultado em 11/10/2026: confirmado pelo usuário.** Depois da atualização, o Kindle Oasis sincronizou e abriu um artigo e um livro EPUB. A reabertura offline foi posteriormente confirmada; persistem a verificação independente da origem exata dos arquivos no Dropbox e testes de robustez de sincronizações futuras.

## 7.1. Visualizar espaço livre e selecionar downloads para exclusão

O fork agora inclui **Zotero Atelier → Maintenance → Zotero storage and cleanup**, com leitura do espaço disponível no aparelho pela função `ffi/util.df` do próprio KOReader. Mostra os PDFs/EPUBs que correspondem exatamente a referências de anexos importados e existem na pasta atual de download do Zotero; quando o caminho antigo também existir, ele aparece **separadamente**.

A interface possui seleções no formato `[ ]`, **todas inicialmente desmarcadas**, um botão de exclusão e uma **segunda confirmação** informando o número de arquivos e espaço estimado a recuperar. A limpeza remove apenas os PDFs/EPUBs dessas pastas que constam do banco de metadados do Zotero; **não apaga** o próprio `zotero.db`, as credenciais Zotero/Dropbox, arquivos `.sdr` (posição de leitura e preferências), outros documentos do Kindle nem `koreader/cache/cr3cache`, que é compartilhado pelo leitor.

Esta funcionalidade é experimental, ainda sem teste prático no Kindle. **Não a instale antes de esclarecer a localização da pasta `storage` e o congelamento do navegador relatado anteriormente.** Quando for apropriado, com KOReader fechado e Kindle conectado por USB, o instalador com backup é:

```bash
curl -fL https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand/tools/instalar_gerenciador_espaco_kindle.sh \
  -o ~/Downloads/instalar_gerenciador_espaco_kindle.sh \
  && bash ~/Downloads/instalar_gerenciador_espaco_kindle.sh
```

Ele atualiza só o código da interface (`main.lua` e `zotero_storage_manager.lua`) e **não executa nenhuma exclusão**. Após instalá-lo, a exclusão ocorre exclusivamente quando selecionada e confirmada dentro do KOReader. Depois de remover um anexo, ele poderá ser recuperado pela integração Dropbox, quando houver conexão com a internet.

### Reparar armazenamento dividido entre `koreader/zotero/storage` e `documents/Zotero/storage`

O primeiro script de migração funcionou, mas um teste posterior identificou **3 documentos (14 MB)** em `documents/Zotero/storage` e **1 documento (616 KB)** ainda em `koreader/zotero/storage`. O arquivo antigo aparecia em `/mnt/us/koreader/zotero/storage/A7YLM757`. A versão instalada do plugin ainda utilizava uma condição exata sobre `API.zotero_dir == "/mnt/us/koreader/zotero"`; no fork essa condição foi substituída por `Device:isKindle()`, método do próprio KOReader.

**Não execute novamente o migrador inicial** quando as duas pastas já existem: ele interrompe de propósito para evitar perda de arquivos. Há um reparador específico, `tools/corrigir_storage_duplo_kindle.sh`, que atualiza **somente** `zoteroapi.lua`, faz backup de segurança, verifica conflitos de chaves de anexo e move **apenas pastas inteiras sem conflito** da raiz antiga para `documents/Zotero/storage`. Não apaga documentos, PDFs, EPUBs, anotações, dados SQLite nem credenciais.

Com KOReader completamente fechado e Kindle conectado via USB, execute:

```bash
curl -fL https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand/tools/corrigir_storage_duplo_kindle.sh \
  -o ~/Downloads/corrigir_storage_duplo_kindle.sh \
  && bash ~/Downloads/corrigir_storage_duplo_kindle.sh
```

**Atenção:** esse reparador ainda precisa de validação no Kindle. Se apontar conflito, **pare e envie a saída**; não remova as pastas manualmente. O fato de o navegador continuar mostrando uma pasta antiga também pode ser um endereço lembrado pelo KOReader, diferente do caminho configurado como `Home` em `documents`.


### PDF com poucos bytes não abre — reparo experimental

Uma falha confirmada no Kindle foi um arquivo `.pdf` com **9 bytes de texto**, enquanto o PDF original no Dropbox sincronizado no Linux tinha **5.052.243 bytes** e era reconhecido como PDF de 16 páginas. Nesse caso, a mensagem do KOReader **"nenhum mecanismo de leitura"** decorre do arquivo local inválido, não de uma ausência de suporte a PDF.

A branch foi corrigida para verificar assinaturas de PDFs/EPUBs, rejeitar arquivos locais inválidos e não permitir que o texto de uma resposta HTTP de erro seja gravado diretamente como documento final. Existe um instalador de código com backup:

```bash
curl -fL https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand/tools/corrigir_download_pdf_kindle.sh \
  -o ~/Downloads/corrigir_download_pdf_kindle.sh \
  && bash ~/Downloads/corrigir_download_pdf_kindle.sh
```

Executar **somente com o KOReader fechado e Kindle montado por USB**. Esse script atualiza `zoteroapi.lua`, `zotero_dropbox.lua` e `zotero_file_validation.lua`, mantendo os downloads, arquivos `.sdr`, banco Zotero e credenciais existentes. **Não repara automaticamente um PDF já corrompido.** Para esse, faça backup dos poucos bytes inválidos e copie ou baixe novamente o PDF correto. A recuperação e o código ainda aguardam validação prática no Kindle.

### Aviso: janela experimental de limpeza desativada temporariamente

Após instalar o gerenciador de espaço, um teste real no Kindle causou o fechamento inesperado do KOReader ao tocar em **Maintenance → Zotero storage and cleanup**. A causa ainda depende da leitura do `crash.log`, portanto **não há confirmação de que a funcionalidade esteja pronta para uso**. Abrir a janela de relatório não executa o fluxo separado de exclusão confirmado.

A branch foi atualizada para substituir essa opção por uma mensagem informativa, sem abrir a janela que causou o travamento. Para instalar **somente a desativação protetiva** sem tocar nos PDFs/EPUBs, banco Zotero, credenciais e anotações, feche o KOReader, conecte o Kindle por USB e execute:

```bash
curl -fL https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand/tools/desativar_limpeza_kindle.sh \
  -o ~/Downloads/desativar_limpeza_kindle.sh \
  && bash ~/Downloads/desativar_limpeza_kindle.sh
```

Essa funcionalidade permanecerá desativada até a análise do log e testes práticos de correção no Oasis.

## 8. Dúvidas frequentes

**Os PDFs e EPUBs somem quando desligo o Wi-Fi?**  
Não por desligar o Wi-Fi: um download concluído corresponde a um arquivo gravado no aparelho, não a um streaming. A reabertura offline já foi confirmada em teste manual no Kindle Oasis com o caminho antigo, antes da migração para `documents`.

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
