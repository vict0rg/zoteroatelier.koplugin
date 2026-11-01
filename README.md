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

## Situação verificada

- Kindle Oasis 3, KOReader 2026.07.2: biblioteca Zotero navegável, PDFs abertos e anotações anteriores do Zotero exibidas.
- **1º de novembro de 2026:** um destaque produzido no Kindle foi criado com sucesso no Zotero desktop (identificado no `crash.log`).
- **Correção integrada nesta branch:** anotações PDF cuja página está em `page` mas não em `pageno` não devem mais interromper a sincronização com `makeSortIndex(nil)`. A correção foi adaptada do projeto original posterior à nossa base de outubro.
- A verificação de regressão roda em Lua 5.1 pelo GitHub Actions; isso não substitui a validação final de funcionamento em um Kindle real.

## Instalação / atualização da versão Kindle

Para uma instalação **já funcionando** com o nosso Dropbox, use o instalador de atualização pontual: fecha-se o KOReader, conecta-se o Kindle ao Linux Mint e executa-se:

```bash
curl -fLsS https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/master/tools/atualizar_atelier_kindle_anotacoes_2026-11-01.sh -o ~/Downloads/atualizar_atelier_kindle_anotacoes_2026-11-01.sh \
  && bash ~/Downloads/atualizar_atelier_kindle_anotacoes_2026-11-01.sh
```

O script valida que a integração Dropbox está presente, baixa apenas o `annotations.lua` corrigido e o `_meta.lua`, confere os arquivos e mantém backup do código anterior. **Não sobrescreve PDFs, EPUBs, destaques, arquivos `.sdr`, base SQLite ou credenciais.**

Se a montagem USB não for `/media/$USER/Kindle`, informe o caminho de montagem via variável `KINDLE_MOUNT`. Não copie a pasta do repositório inteiro por cima de uma instalação já configurada.

Para instalações novas e configuração de Dropbox, consulte o [guia detalhado em português](doc/guia-kindle-dropbox-pt-BR.md). Configuração de credenciais: [documentação de desenvolvimento](doc/dropbox-on-demand.md). O módulo do Dropbox usa OAuth PKCE e permissão **`files.content.read`**, sem escrita no Dropbox.

## Atualizações provenientes do projeto original

O projeto original avançou após a criação deste fork, inclusive com melhorias nas anotações PDF/EPUB, interface, localização e tratamento de falhas. Mantemos uma integração **seletiva** para não quebrar o código de Dropbox, os caminhos de armazenamento e as ferramentas de instalação do Kindle.

Em 01/11/2026 integramos o resolvedor robusto de página de anotações, a prevenção da falha em `annotationSortIndex` e a correção de metadados de carregamento do KOReader. Veja [auditoria de alterações do projeto original](doc/atualizacao-upstream-2026-11-01.md). As mudanças restantes continuam em avaliação de compatibilidade; **não** afirmamos ter mesclado todo o upstream.

## Créditos e licença

- **Projeto original:** [Atelier-Recherche / zoteroatelier.koplugin](https://github.com/Atelier-Recherche/zoteroatelier.koplugin), sucessor do plugin Zotero para KOReader. Agradecemos aos autores e mantenedores por disponibilizar o código.
- **Adaptação Dropbox/Kindle e documentação:** [vict0rg](https://github.com/vict0rg), com apoio do ChatGPT na implementação e na análise técnica.
- **Referência arquitetural:** [provedor Dropbox do KOReader](https://github.com/koreader/koreader/blob/master/plugins/cloudstorage.koplugin/providers/dropbox.lua), sem incorporação do código daquele provedor.
- **Licença:** [GPL-3.0](LICENSE). Não enviar credenciais, tokens, arquivos de biblioteca ou `crash.log` com dados privados para o GitHub.

A marca **Zotero Atelier Drop Sync** identifica este fork e diferencia explicitamente seu suporte a anexos no Dropbox do projeto original.
