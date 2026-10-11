#!/usr/bin/env bash
# Kindle Oasis: install only the corrected, read-only Zotero storage report.
# The previous crash was caused by shadowing gettext "_" inside freeSpace().
# All downloads/deletion are disabled in this diagnostic release.
set -Eeuo pipefail
umask 077

MOUNT="${KINDLE_MOUNT:-/media/$USER/Kindle}"
PLUGIN="$MOUNT/koreader/plugins/zoteroatelier.koplugin"
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand"
BACKUP="$HOME/Downloads/BACKUP-ZOTERO-RELATORIO-ESPACO-KINDLE-$(date +%Y%m%d-%H%M%S)"
FILES=(main.lua zotero_storage_manager.lua)

die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }
echo "Zotero Atelier: teste corrigido do relatorio de espaco (SOMENTE LEITURA)"
echo "Feche completamente o KOReader no Kindle antes de conectar por USB."

MP="$(findmnt -rn -T "$MOUNT" -o TARGET 2>/dev/null || true)"
[[ "$MP" == "$MOUNT" || "$MP" == "$MOUNT/" ]] ||
    die "Kindle nao montado em $MOUNT (findmnt: $MP)."
[[ -f "$PLUGIN/_meta.lua" && -f "$PLUGIN/main.lua" ]] ||
    die "Zotero Atelier nao encontrado em $PLUGIN."
[[ ! -L "$PLUGIN" && ! -L "$PLUGIN/main.lua" ]] ||
    die "Destino simbolico inesperado; operacao cancelada."
[[ -f "$PLUGIN/zoteroapi.lua" && -f "$PLUGIN/zotero_dropbox.lua" &&
   -f "$PLUGIN/zotero_file_validation.lua" ]] ||
    die "Modulos principais do Atelier incompletos. Nao atualizar parcialmente."
command -v curl >/dev/null || die "curl nao encontrado."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
for name in "${FILES[@]}"; do
    curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
        "$BASE/$name" -o "$WORK/$name" ||
        die "Falha ao baixar $name; nada foi alterado."
    [[ -s "$WORK/$name" ]] || die "Arquivo vazio: $name"
done
grep -Fq 'Zotero storage report (read-only test)' "$WORK/main.lua" ||
    die "A versao do menu nao eh a versao segura, Kindle inalterado."
grep -Fq 'local SAFE_READ_ONLY = true' "$WORK/zotero_storage_manager.lua" ||
    die "O gerenciador nao esta em modo read-only, Kindle inalterado."
grep -Fq 'free_bytes, available = pcall(util.df' "$WORK/zotero_storage_manager.lua" ||
    die "A versao nao contem a correcao de gettext, Kindle inalterado."
if command -v luac5.1 >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do
        luac5.1 -p "$WORK/$name" || die "Erro de sintaxe Lua: $name"
    done
elif command -v luac >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do
        luac -p "$WORK/$name" || die "Erro de sintaxe Lua: $name"
    done
else
    echo "Aviso: compilador Lua indisponivel, verificar o teste no Kindle."
fi

mkdir -p "$BACKUP"
cp -p "$PLUGIN/main.lua" "$BACKUP/main.lua" || die "Falha no backup main.lua"
if [[ -f "$PLUGIN/zotero_storage_manager.lua" ]]; then
    cp -p "$PLUGIN/zotero_storage_manager.lua" "$BACKUP/zotero_storage_manager.lua" ||
        die "Falha no backup do gerenciador."
fi

restore() {
    cp -p "$BACKUP/main.lua" "$PLUGIN/main.lua" || true
    if [[ -f "$BACKUP/zotero_storage_manager.lua" ]]; then
        cp -p "$BACKUP/zotero_storage_manager.lua" "$PLUGIN/zotero_storage_manager.lua" || true
    else
        rm -f -- "$PLUGIN/zotero_storage_manager.lua"
    fi
}
for name in "${FILES[@]}"; do
    if ! cp "$WORK/$name" "$PLUGIN/$name" ||
       ! cmp -s "$WORK/$name" "$PLUGIN/$name"; then
        restore
        die "Falha ao instalar $name; tentativa de restauracao realizada."
    fi
    echo "Atualizado: $name"
done
sync

echo
echo "OK: relatorio de espaco SOMENTE LEITURA instalado."
echo "Backup anterior: $BACKUP"
echo "Zotero Atelier > Maintenance > Zotero storage report (read-only test)"
echo "Nenhum PDF, EPUB, anotacao, banco Zotero, token ou cache foi alterado."
echo "Ejete o Kindle com seguranca; reinicie o KOReader."
