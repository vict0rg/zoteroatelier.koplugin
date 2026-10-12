#!/usr/bin/env bash
# Emergency fallback: restore the last ON-DEVICE tested individual-selection
# viewer without any deletion code. Does not touch documents or Zotero data.
set -Eeuo pipefail
umask 077
MOUNT="${KINDLE_MOUNT:-/media/$USER/Kindle}"
PLUGIN="$MOUNT/koreader/plugins/zoteroatelier.koplugin"
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/8b3856343f4453d20f155d8b3bb72376721435a2"
BACKUP="$HOME/Downloads/BACKUP-ZOTERO-VOLTAR-SEM-EXCLUSAO-$(date +%Y%m%d-%H%M%S)"
FILES=(zotero_storage_manager.lua main.lua)
die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }
echo "Restaurar selecao individual SOMENTE LEITURA, versao testada no Kindle."
echo "Exige KOReader completamente fechado e Kindle conectado por USB."
MP="$(findmnt -rn -T "$MOUNT" -o TARGET 2>/dev/null || true)"
[[ "$MP" == "$MOUNT" || "$MP" == "$MOUNT/" ]] ||
    die "Kindle USB nao montado em $MOUNT."
[[ -f "$PLUGIN/_meta.lua" ]] || die "Zotero Atelier nao encontrado."
command -v curl >/dev/null || die "curl ausente."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
for name in "${FILES[@]}"; do
    [[ -f "$PLUGIN/$name" && ! -L "$PLUGIN/$name" ]] ||
        die "Modulo existente invalido: $name"
    curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
        "$BASE/$name" -o "$WORK/$name" ||
        die "Falha ao baixar codigo de reversao. Kindle inalterado."
done
grep -Fq 'local SAFE_READ_ONLY = true' "$WORK/zotero_storage_manager.lua" ||
    die "Modulo de reversao nao esta em modo somente leitura."
if grep -Eq 'os[[:space:]]*\.[[:space:]]*remove[[:space:]]*\(' "$WORK/zotero_storage_manager.lua"; then
    die "Modulo de reversao contem rotina de exclusao; cancelado."
fi
grep -Fq 'Zotero storage report (read-only test)' "$WORK/main.lua" ||
    die "Menu de reversao incorreto."
if command -v luac5.1 >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do luac5.1 -p "$WORK/$name" || die "Codigo invalido"; done
fi
mkdir -p "$BACKUP"
for name in "${FILES[@]}"; do cp -p "$PLUGIN/$name" "$BACKUP/$name" || die "Falha no backup"; done
for name in "${FILES[@]}"; do
    if ! cp "$WORK/$name" "$PLUGIN/$name" ||
       ! cmp -s "$WORK/$name" "$PLUGIN/$name"; then
        for previous in "${FILES[@]}"; do
            cp -p "$BACKUP/$previous" "$PLUGIN/$previous" || true
        done
        die "Falha de copia; restauracao anterior tentada."
    fi
    echo "Restaurado: $name"
done
sync
echo "OK: voltou para selecao individual SOMENTE LEITURA."
echo "Backup anterior: $BACKUP"
echo "Nenhum documento, .sdr, SQLite ou credencial foi alterado."
echo "Ejete o Kindle com seguranca e reinicie KOReader."
