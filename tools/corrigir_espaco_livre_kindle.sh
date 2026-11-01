#!/usr/bin/env bash
# Read-only report improvement: fix total/available Kindle disk space.
# Installs ONLY the manager; leaves the menu and all Zotero data untouched.
set -Eeuo pipefail
umask 077

MOUNT="${KINDLE_MOUNT:-/media/$USER/Kindle}"
PLUGIN="$MOUNT/koreader/plugins/zoteroatelier.koplugin"
# Immutable revision, avoiding CDN/branch mismatch during experimental tests.
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/da0034af721c1361764e308054daea4f27ca283c"
BACKUP="$HOME/Downloads/BACKUP-ZOTERO-ESPACO-LIVRE-KINDLE-$(date +%Y%m%d-%H%M%S)"
FILE="zotero_storage_manager.lua"

die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }
echo "Zotero Atelier: melhorar exibicao do espaco livre (relatorio SOMENTE LEITURA)"
echo "KOReader deve estar totalmente fechado; Kindle deve estar conectado por USB."
MP="$(findmnt -rn -T "$MOUNT" -o TARGET 2>/dev/null || true)"
[[ "$MP" == "$MOUNT" || "$MP" == "$MOUNT/" ]] ||
    die "Kindle USB nao montado em $MOUNT."
[[ -f "$PLUGIN/_meta.lua" && -f "$PLUGIN/main.lua" && -f "$PLUGIN/$FILE" ]] ||
    die "Zotero Atelier atualizado nao encontrado."
[[ ! -L "$PLUGIN" && ! -L "$PLUGIN/$FILE" ]] ||
    die "Pasta ou arquivo simbolico inesperado."
# The crash-fixed report menu must already be installed.
grep -Fq 'Zotero storage report (read-only test)' "$PLUGIN/main.lua" ||
    die "O menu do relatorio de teste nao esta instalado. Nada alterado."
command -v curl >/dev/null || die "curl nao encontrado."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
    "$BASE/$FILE" -o "$WORK/$FILE" ||
    die "Falha ao baixar correcao; Kindle inalterado."
[[ -s "$WORK/$FILE" ]] || die "Codigo baixado vazio."
grep -Fq 'local SAFE_READ_ONLY = true' "$WORK/$FILE" ||
    die "Codigo nao esta em modo leitura; nada alterado."
grep -Fq 'df -k /mnt/us' "$WORK/$FILE" ||
    die "Codigo nao contem o fallback seguro de espaco."
if command -v luac5.1 >/dev/null 2>&1; then
    luac5.1 -p "$WORK/$FILE" || die "Erro de sintaxe Lua."
elif command -v luac >/dev/null 2>&1; then
    luac -p "$WORK/$FILE" || die "Erro de sintaxe Lua."
else
    echo "Aviso: compilador Lua indisponivel neste computador."
fi

mkdir -p "$BACKUP"
cp -p "$PLUGIN/$FILE" "$BACKUP/$FILE" ||
    die "Falha no backup; nada alterado."
if ! cp "$WORK/$FILE" "$PLUGIN/$FILE" ||
   ! cmp -s "$WORK/$FILE" "$PLUGIN/$FILE"; then
    cp -p "$BACKUP/$FILE" "$PLUGIN/$FILE" || true
    die "Falha na instalacao; restauracao do backup tentada."
fi
sync
echo
echo "OK: atualizado SOMENTE $FILE"
echo "Backup: $BACKUP"
echo "Exclusao continua totalmente desativada no relatorio de teste."
echo "Documentos, .sdr, SQLite, credenciais e codigo de sincronizacao preservados."
echo "Ejete o Kindle com seguranca e reinicie KOReader."
