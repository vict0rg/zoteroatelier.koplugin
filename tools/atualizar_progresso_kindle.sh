#!/usr/bin/env bash
# Update only Zotero Atelier synchronization-progress code on a USB-mounted Kindle.
# Preserves personal Zotero/Dropbox settings, DB, PDFs, EPUBs and annotations.
set -Eeuo pipefail
umask 077

MOUNT="${KINDLE_MOUNT:-/media/$USER/Kindle}"
PLUGIN="$MOUNT/koreader/plugins/zoteroatelier.koplugin"
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand"
BACKUP="$HOME/Downloads/BACKUP-ATELIER-PROGRESSO-KINDLE-$(date +%Y%m%d-%H%M%S)"
FILES=(main.lua zoteroapi.lua)

die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }

echo "Feche completamente o KOReader no Kindle antes de continuar."
echo "Este procedimento atualiza SOMENTE main.lua e zoteroapi.lua; não apaga a biblioteca."
[[ -d "$PLUGIN" && -f "$PLUGIN/_meta.lua" ]] || die "Pasta do Zotero Atelier não encontrada: $PLUGIN"

# Verify that the target is a removable/non-root mount, not a stray directory.
MOUNT_POINT="$(findmnt -rn -T "$MOUNT" -o TARGET 2>/dev/null || true)"
[[ "$MOUNT_POINT" == "$MOUNT" || "$MOUNT_POINT" == "$MOUNT/" ]] ||
    die "Kindle não identificado como volume USB montado em $MOUNT (findmnt: $MOUNT_POINT)"
for name in "${FILES[@]}"; do
    [[ -f "$PLUGIN/$name" ]] || die "Falta arquivo no plugin Kindle: $name"
done
command -v curl >/dev/null || die "curl não está instalado"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo
echo "Baixando as duas atualizações..."
for name in "${FILES[@]}"; do
    curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
        "$BASE/$name" -o "$WORK/$name" || die "Falhou download de $name, Kindle inalterado."
    [[ -s "$WORK/$name" ]] || die "Arquivo vazio: $name"
done

if command -v luac >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do luac -p "$WORK/$name" || die "Erro de sintaxe em $name"; done
elif command -v luac5.1 >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do luac5.1 -p "$WORK/$name" || die "Erro de sintaxe em $name"; done
elif command -v texluac >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do texluac -p "$WORK/$name" || die "Erro de sintaxe em $name"; done
else
    echo "Aviso: verificação sintática local indisponível; teste carregamento no Kindle."
fi

mkdir -p "$BACKUP"
for name in "${FILES[@]}"; do cp -p "$PLUGIN/$name" "$BACKUP/$name"; done

echo "Backup salvo em: $BACKUP"
for name in "${FILES[@]}"; do
    cp "$WORK/$name" "$PLUGIN/$name" || die "Erro durante a cópia de $name. Backup disponível em $BACKUP"
    cmp -s "$WORK/$name" "$PLUGIN/$name" || die "Verificação falhou em $name"
    echo "Atualizado e conferido: $name"
done
sync

echo
echo "ATUALIZAÇÃO CONCLUÍDA. Ejete o Kindle, reinicie KOReader e tente Synchronize."
echo "Durante a sincronização, o progresso é mostrado em etapas e salvo em:"
echo "  /koreader/zotero/sync_status.txt (no volume USB Kindle)"
echo "Se precisar restaurar, copie os dois arquivos de $BACKUP de volta para $PLUGIN"
