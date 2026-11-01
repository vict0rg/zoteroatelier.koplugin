#!/usr/bin/env bash
# Update the installed Zotero Atelier Dropbox fork on Kindle from this project's
# pinned GitHub revision. Only the three synchronisation modules change.
# Never touches PDFs, EPUBs, sidecars, Zotero SQLite, OAuth or API credentials.
set -Eeuo pipefail
umask 077

MOUNT="${KINDLE_MOUNT:-/media/$USER/Kindle}"
PLUGIN="$MOUNT/koreader/plugins/zoteroatelier.koplugin"
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/c47fddd9ae55212d015167b00d759363072675de"
BACKUP="$HOME/Downloads/BACKUP-ZOTERO-ATELIER-DUPLA-SYNC-$(date +%Y%m%d-%H%M%S)"
FILES=(zoteroapi.lua annotations.lua main.lua)

die() { printf 'ERRO: %s\n' "$*" >&2; exit 1; }

echo "Zotero Atelier Drop Sync: sincronizacao de anotacoes nos dois sentidos, sem exclusoes implicitas."
echo "Feche COMPLETAMENTE o KOReader; conecte o Kindle via USB."
command -v findmnt >/dev/null 2>&1 || die "findmnt nao encontrado."
command -v curl >/dev/null 2>&1 || die "curl nao encontrado."
[[ -d "$MOUNT" ]] || die "Kindle nao encontrado em $MOUNT. Use KINDLE_MOUNT=/caminho/Kindle."
MP="$(findmnt -rn -T "$MOUNT" -o TARGET 2>/dev/null || true)"
[[ "$MP" == "$MOUNT" || "$MP" == "$MOUNT/" ]] ||
    die "O caminho $MOUNT nao e o ponto de montagem USB esperado."
[[ -d "$PLUGIN" && ! -L "$PLUGIN" ]] || die "Plugin atual nao encontrado: $PLUGIN"
[[ -f "$PLUGIN/zotero_dropbox.lua" ]] ||
    die "Esta instalacao nao contem nossa integracao Dropbox; nada foi alterado."
for name in "${FILES[@]}"; do
    [[ -f "$PLUGIN/$name" && ! -L "$PLUGIN/$name" ]] ||
        die "Arquivo existente invalido/ausente: $name"
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
for name in "${FILES[@]}"; do
    curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
        "$BASE/$name" -o "$WORK/$name" ||
        die "Falhou download de $name; Kindle inalterado."
    [[ -s "$WORK/$name" ]] || die "Download vazio: $name"
done

grep -Fq 'local function postZoteroItems(url, request_json, is_update, requested_items)' "$WORK/zoteroapi.lua" ||
    die "Versao inesperada: tratamento de envio 412 ausente."
grep -Fq 'API.lastAnnotationSyncError' "$WORK/zoteroapi.lua" ||
    die "Versao inesperada: diagnostico de erro ausente."
grep -Fq 'function API.pullAnnotationsForAttachment(key, file_path)' "$WORK/zoteroapi.lua" ||
    die "Versao inesperada: importacao de anotacoes ausente."
grep -Fq 'Remote annotation is absent from this SDR; preserving item' "$WORK/zoteroapi.lua" ||
    die "Versao insegura: protecao de exclusoes ausente."
grep -Fq 'function Annotations.fingerprint(ann)' "$WORK/annotations.lua" ||
    die "Versao inesperada: protecao de conflitos ausente."
grep -Fq 'pull = true' "$WORK/main.lua" ||
    die "Versao inesperada: sincronizacao bidirecional ausente."
if command -v luac5.1 >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do
        luac5.1 -p "$WORK/$name" || die "Falha na sintaxe de $name; Kindle inalterado."
    done
elif command -v luac >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do
        luac -p "$WORK/$name" || die "Falha na sintaxe de $name; Kindle inalterado."
    done
else
    echo "Aviso: compilador Lua indisponivel; a sintaxe e conferida pelo CI do projeto."
fi

mkdir -p "$BACKUP" || die "Nao foi possivel criar backup."
for name in "${FILES[@]}"; do
    cp -p "$PLUGIN/$name" "$BACKUP/$name" ||
        die "Backup falhou em $name; Kindle inalterado."
done

for name in "${FILES[@]}"; do
    if ! cp "$WORK/$name" "$PLUGIN/$name" ||
       ! cmp -s "$WORK/$name" "$PLUGIN/$name"; then
        for previous in "${FILES[@]}"; do
            cp -p "$BACKUP/$previous" "$PLUGIN/$previous" || true
        done
        die "Falha ao instalar $name; restauracao anterior tentada."
    fi
    echo "Atualizado: $name"
done
sync
echo
echo "OK: modulos de sincronizacao bidirecional instalados com backup; configuracoes mantidas."
echo "Backup de retorno: $BACKUP"
echo "PDFs, EPUBs, .sdr, SQLite e credenciais nao foram alterados."
echo "Ejete o Kindle com seguranca e reinicie o KOReader."
