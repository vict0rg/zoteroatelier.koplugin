#!/usr/bin/env bash
# Install the experimental Zotero Atelier managed-download space viewer.
# This updates only plugin code. It does not move/delete downloaded books.
set -Eeuo pipefail
umask 077
MOUNT="${KINDLE_MOUNT:-/media/$USER/Kindle}"
PLUGIN="$MOUNT/koreader/plugins/zoteroatelier.koplugin"
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand"
BACKUP="$HOME/Downloads/BACKUP-ATELIER-ESPACO-KINDLE-$(date +%Y%m%d-%H%M%S)"
FILES=(main.lua zotero_storage_manager.lua)

die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }
echo "Instalar Zotero Atelier: Maintenance > Zotero storage and cleanup"
echo "IMPORTANTE: encerre completamente o KOReader antes de conectar o Kindle via USB."
[[ -d "$PLUGIN" && -f "$PLUGIN/_meta.lua" ]] || die "Plugin não encontrado: $PLUGIN"
MOUNT_POINT="$(findmnt -rn -T "$MOUNT" -o TARGET 2>/dev/null || true)"
[[ "$MOUNT_POINT" == "$MOUNT" || "$MOUNT_POINT" == "$MOUNT/" ]] ||
  die "O Kindle não está montado no volume USB esperado: $MOUNT."
[[ -f "$PLUGIN/main.lua" ]] || die "Falta main.lua no plugin Kindle."
command -v curl >/dev/null || die "curl não está instalado."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
for name in "${FILES[@]}"; do
  curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
    "$BASE/$name" -o "$WORK/$name" || die "Falhou download de $name. Kindle inalterado."
  [[ -s "$WORK/$name" ]] || die "Arquivo vazio: $name"
done
if command -v luac5.1 >/dev/null 2>&1; then
  for name in "${FILES[@]}"; do luac5.1 -p "$WORK/$name" || die "Sintaxe inválida: $name"; done
elif command -v luac >/dev/null 2>&1; then
  for name in "${FILES[@]}"; do luac -p "$WORK/$name" || die "Sintaxe inválida: $name"; done
else
  echo "Aviso: compilador Lua não encontrado para verificação de sintaxe."
fi
grep -Fq 'require("zotero_storage_manager")' "$WORK/main.lua" ||
  die "A versão baixada do main.lua não contém o painel de limpeza."

mkdir -p "$BACKUP"
cp -p "$PLUGIN/main.lua" "$BACKUP/main.lua" || die "Falha de backup do main.lua."
if [[ -f "$PLUGIN/zotero_storage_manager.lua" ]]; then
  cp -p "$PLUGIN/zotero_storage_manager.lua" "$BACKUP/zotero_storage_manager.lua" ||
    die "Falha de backup do gerenciador existente."
fi

restore() {
  if [[ -f "$BACKUP/main.lua" ]]; then
    cp "$BACKUP/main.lua" "$PLUGIN/main.lua" || true
  fi
  if [[ -f "$BACKUP/zotero_storage_manager.lua" ]]; then
    cp "$BACKUP/zotero_storage_manager.lua" "$PLUGIN/zotero_storage_manager.lua" || true
  else
    rm -f -- "$PLUGIN/zotero_storage_manager.lua"
  fi
}
if ! cp "$WORK/zotero_storage_manager.lua" "$PLUGIN/zotero_storage_manager.lua" ||
   ! cmp -s "$WORK/zotero_storage_manager.lua" "$PLUGIN/zotero_storage_manager.lua" ||
   ! cp "$WORK/main.lua" "$PLUGIN/main.lua" ||
   ! cmp -s "$WORK/main.lua" "$PLUGIN/main.lua"; then
  restore
  die "Falha ao instalar. O backup foi restaurado ou está em $BACKUP."
fi

sync
echo
echo "Painel instalado. Backup em $BACKUP"
echo "Zotero Atelier > Maintenance > Zotero storage and cleanup"
echo "Nenhum banco, credencial, cache ou documento foi alterado pelo instalador."
echo "Ejete o Kindle com segurança e reinicie o KOReader."
