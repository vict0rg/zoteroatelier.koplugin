# Zotero Atelier Drop Sync

**Zotero + Dropbox + KOReader (Kindle / Linux)** — fork comunitário do [Zotero Atelier original](https://github.com/Atelier-Recherche/zoteroatelier.koplugin), com integração específica para bibliotecas cujos anexos do Zotero são armazenados na pasta `storage` do **Dropbox**.

> **Fork independente:** baseado no trabalho de Atelier-Recherche e nos projetos Zotero/KOReader precedentes, todos devidamente creditados. Não é um aplicativo oficial do Zotero, Dropbox, Amazon ou KOReader. Mantém a licença GPL-3.0 do projeto de origem.

## O que o Drop Sync acrescenta

O Zotero Atelier original oferece navegação na biblioteca, anotações e sincronização pelo Zotero Web API. **Nosso diferencial** é reconhecer a organização de anexos da biblioteca do Zotero dentro de uma pasta Dropbox configurada:

```text
Dropbox/
└── 100-BIBLIOTECA_ZOTERO/
    └── storage/
        ├── CHAVE_DO_ANEXO_1/
        │   └── artigo.pdf
        └── CHAVE_DO_ANEXO_2/
            └── livro.epub
```

O plugin relaciona a **chave do anexo do Zotero** à subpasta `storage/CHAVE_DO_ANEXO` e procura o nome do arquivo conhecido no cadastro bibliográfico. Pode **baixar um PDF/EPUB por vez, sob demanda, para leitura offline**, sem baixar toda a biblioteca nem exigir o armazenamento de anexos na nuvem do Zotero.

- **Dropbox → Kindle / KOReader:** download dos PDFs e EPUBs de uma pasta `storage` configurada (somente leitura no Dropbox), cache local e reabertura offline.
- **Zotero ↔ KOReader:** busca de referências/coleções e sincronização de destaques/anotações pelos serviços do **Zotero**; o Dropbox não é utilizado como destino das anotações.
- **Kindle:** cache de anexos em `documents/Zotero/storage/CHAVE`; metadados, credenciais e configurações permanecem separados em `koreader/zotero`.
- **Gerenciamento local:** visualização e seleção de anexos baixados para liberar espaço; remoção local requer confirmação, sem exclusão de arquivos do Dropbox, do Zotero ou de pastas `.sdr`.

**Importante:** o plugin não pesquisa todas as pastas arbitrariamente no Dropbox. É necessário informar o diretório remoto que contém `storage/CHAVE_DO_ANEXO/arquivo`. Não sincroniza alterações do PDF para o Dropbox, nem oferece sincronização de grupos Zotero nessa integração experimental.

## Estado atual — validado em Kindle real (01/11/2026)

**Funcionalidade confirmada em 1º de novembro de 2026:** sincronização bidirecional de **criação e exclusão de destaques de PDF** entre **Kindle Oasis 3 / KOReader 2026.07.2** e **Zotero desktop**, usando a API do Zotero. Após instalar a correção de exclusões confirmadas, a pessoa que utiliza este fork verificou sucessivamente:

- Excluir destaques no Kindle, confirmar pelo plugin e vê-los desaparecer do Zotero depois da sincronização.
- Criar destaque no Zotero, sincronizar o desktop com a nuvem e recebê-lo no Kindle.
- Excluir esse destaque no Zotero, confirmar a exclusão no Kindle e verificar sua remoção.
- Criar destaque no Kindle e recebê-lo no Zotero.
- Excluir esse destaque no Kindle e confirmar sua exclusão no Zotero.
- Repetir a criação/exclusão em ambos os sentidos, sem novas duplicações nos testes realizados.

**Esses são testes práticos reais, não apenas simulações.** O GitHub Actions também executa testes Lua 5.1 para sincronização, duplicações, conflitos, falhas de rede, exclusões confirmadas e persistência das anotações ao reabrir o documento. Isso confirma o funcionamento no ambiente testado, mas não substitui testes para outros dispositivos, formatos ou versões.

**Versão de referência:** implementação integrada pelo [PR #7](https://github.com/vict0rg/zoteroatelier.koplugin/pull/7), commit de merge `241fbd40e285e5c7e57889fafda846d5a5984ff7`. O instalador de exclusões confirmadas aponta para módulos de código que correspondem aos arquivos publicados na `master`.

## Como usar a sincronização de anotações

O comando correto no KOReader é **`Sync document annotations`**, com o PDF aberto no leitor. **`Synchronize` atualiza o catálogo de referências**, mas não realiza a sincronização manual das anotações do documento. Abrir ou fechar um PDF **não** envia automaticamente destaques: essa escolha evita operações inesperadas.

**Criar destaques no Kindle → Zotero**

1. Faça um destaque ou sublinhado no PDF aberto no KOReader.
2. Execute **`Sync document annotations`** no plugin.
3. Sincronize o Zotero desktop com a conta Zotero para receber a anotação.

**Criar destaques no Zotero → Kindle**

1. Faça um destaque no PDF pelo Zotero desktop.
2. Aguarde a conclusão da sincronização do Zotero desktop com a nuvem.
3. No Kindle, abra **o mesmo PDF vinculado àquele anexo** e execute **`Sync document annotations`**.

**Excluir no Kindle → Zotero**

1. Remova a anotação no KOReader.
2. Execute **`Sync document annotations`**.
3. Se a anotação já estava registrada em ambos os lados numa sincronização anterior, o plugin informa quantas exclusões serão feitas no Zotero e pede **confirmação explícita**.
4. Confirme somente se a quantidade estiver correta. Depois, sincronize o Zotero desktop para ver a exclusão.

**Excluir no Zotero → Kindle**

1. Remova a anotação no Zotero desktop e sincronize com a nuvem.
2. Execute **`Sync document annotations`** no Kindle.
3. O plugin verifica se a anotação realmente foi excluída do servidor Zotero e pede **confirmação explícita** antes de retirá-la do KOReader.

**A primeira sincronização após instalar o recurso estabelece a referência inicial** das anotações existentes em ambos os dispositivos. Não propaga retroativamente exclusões anteriores à instalação. Nas sincronizações seguintes, apenas exclusões de anotações previamente confirmadas nos dois lados são propostas. Se a mensagem indicar mais exclusões do que você efetuou, **cancele** e preserve os dados para diagnóstico.

## Como funciona tecnicamente

O fluxo foi desenvolvido a partir do projeto original Zotero Atelier, com adaptações para a organização de anexos no Dropbox e salvaguardas acrescentadas após erros reais de sincronização:

1. **Identidade da anotação:** cada destaque sincronizado possui sua chave Zotero (`zoteroKey`). O plugin reconcilia anotações equivalentes usando página, texto e posição geométrica antes de enviar novos itens. Isso evita recriar como novas anotações que vieram originalmente do Zotero.
2. **Recebimento antes do envio:** no comando manual, o plugin consulta as anotações do anexo pela API Zotero (`/items/{chave}/children`), incorpora as alterações e somente depois envia anotações novas ou modificadas do Kindle.
3. **Persistência no KOReader:** anotações recebidas são armazenadas no estado do documento (`.sdr`). O mecanismo de recarga preserva os dados importados durante o fechamento interno e a reabertura do PDF, quando o KOReader poderia salvar uma cópia antiga que ainda estava na memória.
4. **Histórico durável de exclusões:** `annotation_delete_state.lua` e o campo `zoteroConfirmedAnnotationKeysV1` mantêm, por documento, a referência das chaves que constavam **em ambos os lados após uma sincronização manual concluída**. A ausência de uma anotação antes desse registro não é considerada exclusão.
5. **Exclusões verificadas e confirmadas:** `planAnnotationDeletions` compara os estados e prepara uma proposta; o usuário confirma em uma caixa de diálogo. Para exclusão do lado Zotero, o servidor é consultado novamente antes do `DELETE`, com proteção de versão. Para exclusão do lado Kindle, a anotação ausente no Zotero é conferida também por consulta individual (HTTP 404) antes da remoção do `.sdr`.
6. **Conservação de dados:** quando uma anotação é retirada do `.sdr` após exclusão confirmada no Zotero, seus dados ficam arquivados no campo `zoteroDeletedAnnotationArchiveV1`. Falhas de rede, situações ambíguas e mais de 20 exclusões candidatas interrompem a operação por segurança. O sistema não faz limpeza automática das duplicatas históricas.

**Separação dos serviços:** o **Dropbox serve apenas para localizar e baixar PDFs/EPUBs** a partir de `storage/CHAVE_DO_ANEXO`; a sincronização de destaques e exclusões usa a **API do Zotero**. O plugin não reenvia os próprios PDFs alterados ao Dropbox.

**Limites:** o resultado final foi verificado em PDFs no Kindle indicado acima. Não presumir o mesmo comportamento para todos os EPUBs ou versões do KOReader. Se um destaque estiver gravado diretamente *dentro do arquivo PDF* (além do `.sdr`), remover o registro no KOReader não reescreve o conteúdo binário do PDF. Em caso de dúvida, manter as cópias de segurança e não utilizar comandos de limpeza ou de reinicialização da coleção.

## Instalação e atualização

**Se a versão já está funcionando no Kindle, não é necessário reinstalar.** Para atualizar outra instalação que já contenha a integração Dropbox deste fork, feche completamente o KOReader, conecte o Kindle via USB ao Linux Mint e execute o **instalador final de exclusões confirmadas**:

```bash
curl -fLsS https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/master/tools/instalar_exclusoes_confirmadas_kindle.sh -o ~/Downloads/instalar_exclusoes_confirmadas_kindle.sh && bash ~/Downloads/instalar_exclusoes_confirmadas_kindle.sh
```

Esse instalador atualiza apenas `annotation_delete_state.lua`, `zoteroapi.lua` e `main.lua`, verifica a versão esperada, conserva backup dos módulos substituídos e arquiva as pastas `.sdr` encontradas antes da instalação. **Não altera PDFs, EPUBs, banco SQLite nem credenciais.** Para dispositivos montados fora de `/media/$USER/Kindle`, usar `KINDLE_MOUNT` para indicar o caminho correto.

**Não usar os instaladores históricos de correções pontuais como forma de atualização final:** eles foram criados para etapas anteriores do desenvolvimento e não contêm necessariamente todos os módulos desta versão.

Para instalar do zero e configurar Dropbox, ver o [guia detalhado em português](doc/guia-kindle-dropbox-pt-BR.md) e a [documentação técnica](doc/dropbox-on-demand.md). O acesso ao Dropbox usa OAuth PKCE com permissão de leitura `files.content.read`.

## Histórico dos problemas solucionados

- **Página e geometria dos destaques:** tratamento de anotações PDF com `page` sem `pageno`, conversão de posição, cores e campos compatíveis com o Zotero.
- **HTTP 412 e atualizações:** proteção contra versão de escrita desatualizada e edição concorrente; alterações no Zotero não devem ser sobrescritas sem verificação.
- **Duplicação:** correção da ordem de sincronização e perda do vínculo `zoteroKey` na reabertura de PDFs, além da desativação de envios automáticos em abertura/fechamento ou na atualização do catálogo.
- **Exclusões indevidas (incidente anterior):** a primeira implementação inferia uma exclusão quando uma chave não aparecia no `.sdr`, e isso apagou anotações no Zotero. O mecanismo foi substituído por referências duráveis, verificação individual e confirmação na interface.
- **Exclusões bidirecionais:** implementadas no [PR #7](https://github.com/vict0rg/zoteroatelier.koplugin/pull/7) e confirmadas em testes completos no Kindle em **01/11/2026**.

## Atualizações provenientes do projeto original

O projeto original avançou após a criação deste fork, inclusive com melhorias nas anotações PDF/EPUB, interface, localização e tratamento de falhas. Mantemos uma integração **seletiva** para não quebrar o código de Dropbox, os caminhos de armazenamento e as ferramentas de instalação do Kindle.

Em 01/11/2026 integramos o resolvedor robusto de página de anotações, a prevenção da falha em `annotationSortIndex` e a correção de metadados de carregamento do KOReader. Veja [auditoria de alterações do projeto original](doc/atualizacao-upstream-2026-11-01.md). As mudanças restantes continuam em avaliação de compatibilidade; **não** afirmamos ter mesclado todo o upstream.

## Créditos e licença

- **Projeto original:** [Atelier-Recherche / zoteroatelier.koplugin](https://github.com/Atelier-Recherche/zoteroatelier.koplugin), sucessor do plugin Zotero para KOReader. Agradecemos aos autores e mantenedores por disponibilizar o código.
- **Adaptação Dropbox/Kindle e documentação:** [vict0rg](https://github.com/vict0rg), com apoio do ChatGPT na implementação e na análise técnica.
- **Referência arquitetural:** [provedor Dropbox do KOReader](https://github.com/koreader/koreader/blob/master/plugins/cloudstorage.koplugin/providers/dropbox.lua), sem incorporação do código daquele provedor.
- **Licença:** [GPL-3.0](LICENSE). Não enviar credenciais, tokens, arquivos de biblioteca ou `crash.log` com dados privados para o GitHub.

A marca **Zotero Atelier Drop Sync** identifica este fork e diferencia explicitamente seu suporte a anexos no Dropbox do projeto original.
