#!/usr/bin/env bash
# Safe stopgap: disable only the experimental KOReader Zotero cleanup menu.
# No data/database/credential changes; backup previous main.lua.
set -Eeuo pipefail
umask 077
MOUNT="${KINDLE_MOUNT:-/media/$USER/Kindle}"
PLUGIN="$MOUNT/koreader/plugins/zoteroatelier.koplugin"
# Pin the emergency fallback to the known disabled-menu commit.
# Do not follow branch HEAD, where the read-only report is re-enabled.
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/9704e485874b723c8e800e659d1af9b48e654ae8"
BACKUP="$HOME/Downloads/BACKUP-ZOTERO-DESATIVAR-LIMPEZA-KINDLE-$(date +%Y%m%d-%H%M%S)"
die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }

echo "Desativacao temporaria da janela experimental de limpeza do Zotero Atelier"
echo "KOReader deve estar totalmente fechado; Kindle conectado por USB."
MP="$(findmnt -rn -T "$MOUNT" -o TARGET 2>/dev/null || true)"
[[ "$MP" == "$MOUNT" || "$MP" == "$MOUNT/" ]] ||
    die "Kindle USB nao montado em $MOUNT"
[[ -f "$PLUGIN/_meta.lua" && -f "$PLUGIN/main.lua" ]] ||
    die "Plugin Zotero Atelier nao encontrado."
[[ ! -L "$PLUGIN/main.lua" ]] || die "main.lua simbolico nao esperado."
command -v curl >/dev/null || die "curl nao encontrado."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
    "$BASE/main.lua" -o "$WORK/main.lua" || die "Download falhou; Kindle inalterado."
[[ -s "$WORK/main.lua" ]] || die "main.lua baixado vazio."
grep -Fq 'Zotero storage and cleanup (temporarily disabled)' "$WORK/main.lua" ||
    die "A versao baixada nao desativa a tela. Kindle inalterado."

if command -v luac5.1 >/dev/null 2>&1; then
    luac5.1 -p "$WORK/main.lua" || die "Sintaxe invalida."
elif command -v luac >/dev/null 2>&1; then
    luac -p "$WORK/main.lua" || die "Sintaxe invalida."
else
    echo "Aviso: Lua local indisponivel para verificacao de sintaxe."
fi

mkdir -p "$BACKUP"
cp -p "$PLUGIN/main.lua" "$BACKUP/main.lua" ||
    die "Falhou backup. Kindle inalterado."
if ! cp "$WORK/main.lua" "$PLUGIN/main.lua" ||
   ! cmp -s "$WORK/main.lua" "$PLUGIN/main.lua"; then
    cp -p "$BACKUP/main.lua" "$PLUGIN/main.lua" || true
    die "Falhou copia/verificacao. Backup: $BACKUP"
fi
sync
echo
echo "OK: somente main.lua atualizado para bloquear a tela de limpeza."
echo "Backup anterior: $BACKUP"
echo "PDFs, EPUBs, Zotero SQLite, Dropbox e anotacoes NAO foram alterados."
echo "Ejete o Kindle com seguranca e reinicie KOReader."
