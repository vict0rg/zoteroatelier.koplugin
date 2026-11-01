# Auditoria upstream e correção da sincronização (01/11/2026)

## Repositórios avaliados

- Origem: `Atelier-Recherche/zoteroatelier.koplugin`, branch `master`, commit `8e8ce61951c2` (21/10/2026).
- Fork: `vict0rg/zoteroatelier.koplugin`, base experimental `feature/dropbox-on-demand` (15/10/2026), depois incorporada à `master`.
- O upstream tem **cinco commits** posteriores à ancestralidade comum: descoberta do plugin, sincronização/API, tratamento de nomes de usuário, anotações/EPUB e internacionalização.

## O que incorporamos agora

1. `annotations.lua`: função `Annotations.getAnnotationPage(annotation)` adaptada do original para ler `pageno`, `page`, `pos0` e `pos1`, inclusive valores numéricos textuais.
2. `annotations.lua`: `makeSortIndex` resiliente a página ausente; `convertKOReaderToZotero` usa página normalizada no índice, no rótulo e na posição enviada ao Zotero; criação e atualização usam o mesmo número de página.
3. `_meta.lua`: tratamento moderno de metadados (sem campo `name` depreciado) e identificação visual do fork.
4. `tools/test_annotation_page.lua`: teste isolado Lua 5.1, incluindo caso reproduzido no log: `page=11`, `pageno=nil`; e teste de posições Zotero.
5. GitHub Actions: sintaxe de arquivos do plugin, teste de regressão e sintaxe do instalador.
6. `tools/atualizar_atelier_kindle_anotacoes_2026-11-01.sh`: instalação de somente dois arquivos de código, backup automático e reversão básica em caso de falha de cópia.

## Evidência do erro

O `crash.log` de 01/11/2026 registrou `attempt to perform arithmetic on local 'page' (a nil value)` em `annotations.lua:174`, chamado em `convertKOReaderToZotero` durante atualização de destaque PDF. O mesmo log confirmou a criação bem-sucedida de um destaque cinza no Zotero. Na base anterior, `convertKOReaderToZotero` tentava usar diretamente `annotation.pageno` embora outras rotinas já aceitassem `annotation.page`. A normalização aborda precisamente essa inconsistência.

## O que não foi mesclado indiscriminadamente

O upstream reestruturou extensamente `main.lua`, `zoteroapi.lua`, `annotations.lua`, painéis e EPUB. Copiar tudo substituiria a integração `zotero_dropbox.lua`, ajustes de download por demanda, cache Kindle e gerenciamento seguro de espaço do nosso fork. Essas melhorias exigem portabilidade por módulos e não integram esta atualização emergencial.

Os auxiliares upstream `_tmp_*`, dumps `.db` e scripts de depuração não são necessários à instalação e não foram copiados.

## Escopo de validação

A revisão estática e os testes de Lua verificam a regressão específica, **não** certificam a execução no dispositivo. Para instalar o patch em um Kindle já configurado com Drop Sync, não é necessário refazer OAuth, sincronizar toda a biblioteca nem limpar o banco local.
