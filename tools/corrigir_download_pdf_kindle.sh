#!/usr/bin/env bash
# Zotero Atelier hotfix: validate cached PDF/EPUB and download responses.
# Installs only three Lua files; keeps personal documents, .sdr, DB and tokens.
set -Eeuo pipefail
umask 077
MOUNT="${KINDLE_MOUNT:-/media/$USER/Kindle}"
PLUGIN="$MOUNT/koreader/plugins/zoteroatelier.koplugin"
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand"
BACKUP="$HOME/Downloads/BACKUP-ZOTERO-DOWNLOAD-PDF-KINDLE-$(date +%Y%m%d-%H%M%S)"
FILES=(zotero_file_validation.lua zotero_dropbox.lua zoteroapi.lua)
die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }

echo "Zotero Atelier: proteção contra PDF/EPUB inválido (sem mover arquivos)."
echo "Feche o KOReader completamente antes de conectar o Kindle via USB."
MP="$(findmnt -rn -T "$MOUNT" -o TARGET 2>/dev/null || true)"
[[ "$MP" == "$MOUNT" || "$MP" == "$MOUNT/" ]] ||
    die "Kindle não está montado em $MOUNT"
[[ -d "$PLUGIN" && -f "$PLUGIN/_meta.lua" ]] ||
    die "Plugin não encontrado: $PLUGIN"
for name in zotero_dropbox.lua zoteroapi.lua; do
    [[ -f "$PLUGIN/$name" ]] || die "Falta arquivo no Kindle: $name"
done
command -v curl >/dev/null || die "curl não está instalado"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
for name in "${FILES[@]}"; do
    curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
        "$BASE/$name" -o "$WORK/$name" ||
        die "Falha ao baixar $name. Kindle inalterado."
    [[ -s "$WORK/$name" ]] || die "Arquivo vazio: $name"
done
grep -Fq 'require("zotero_file_validation")' "$WORK/zoteroapi.lua" ||
    die "A versão da API não usa a nova proteção."
grep -Fq 'FileValidation.isValid' "$WORK/zotero_dropbox.lua" ||
    die "A versão do Dropbox não usa a nova proteção."
if command -v luac5.1 >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do luac5.1 -p "$WORK/$name" || die "Lua inválido: $name"; done
elif command -v luac >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do luac -p "$WORK/$name" || die "Lua inválido: $name"; done
else
    echo "Aviso: sem luac para verificar sintaxe local; GitHub CI deve validar."
fi

mkdir -p "$BACKUP"
for name in "${FILES[@]}"; do
    if [[ -f "$PLUGIN/$name" ]]; then cp -p "$PLUGIN/$name" "$BACKUP/$name"; fi
done
echo "Backup do código anterior: $BACKUP"

restore() {
    for name in "${FILES[@]}"; do
        if [[ -f "$BACKUP/$name" ]]; then
            cp "$BACKUP/$name" "$PLUGIN/$name" || true
        else
            rm -f -- "$PLUGIN/$name"
        fi
    done
}
for name in "${FILES[@]}"; do
    if ! cp "$WORK/$name" "$PLUGIN/$name" ||
       ! cmp -s "$WORK/$name" "$PLUGIN/$name"; then
        restore
        die "Falha ao instalar $name; tentando restaurar backup anterior."
    fi
    echo "Conferido: $name"
done
sync
echo
echo "Proteção instalada. Nenhum PDF, EPUB, .sdr, banco ou credencial foi alterado."
echo "Para recuperar o PDF de Carrey já inválido, substitua sua cópia local"
echo "por uma cópia válida do Dropbox, mantendo a pasta .sdr."
echo "Ejete o Kindle e reinicie KOReader."
