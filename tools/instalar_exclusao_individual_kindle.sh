#!/usr/bin/env bash
# Kindle Oasis: enable double-confirmed deletion of individual LOCAL Zotero PDFs/EPUBs.
# Installer itself never deletes documents, database, .sdr, or credentials.
set -Eeuo pipefail
umask 077

MOUNT="${KINDLE_MOUNT:-/media/$USER/Kindle}"
PLUGIN="$MOUNT/koreader/plugins/zoteroatelier.koplugin"
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/31421b263b531e70c159a49a53ffc1805a0224e0"
BACKUP="$HOME/Downloads/BACKUP-ZOTERO-EXCLUSAO-INDIVIDUAL-KINDLE-$(date +%Y%m%d-%H%M%S)"
FILES=(main.lua zotero_storage_manager.lua)

die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }
echo "Instalar exclusao SELETIVA de downloads locais Zotero com duas confirmacoes."
echo "Feche KOReader totalmente e conecte o Kindle por USB."
MP="$(findmnt -rn -T "$MOUNT" -o TARGET 2>/dev/null || true)"
[[ "$MP" == "$MOUNT" || "$MP" == "$MOUNT/" ]] ||
    die "Kindle nao esta montado em $MOUNT."
[[ -f "$PLUGIN/_meta.lua" && -f "$PLUGIN/main.lua" &&
   -f "$PLUGIN/zotero_storage_manager.lua" ]] ||
    die "Plugin Zotero Atelier nao encontrado."
[[ ! -L "$PLUGIN" && ! -L "$PLUGIN/main.lua" &&
   ! -L "$PLUGIN/zotero_storage_manager.lua" ]] ||
    die "Caminho simbolico inesperado."
grep -Fq 'Zotero storage report (read-only test)' "$PLUGIN/main.lua" ||
    die "A versao anterior do relatorio nao foi encontrada; nada alterado."
command -v curl >/dev/null || die "curl nao encontrado."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
for name in "${FILES[@]}"; do
    curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
        "$BASE/$name" -o "$WORK/$name" ||
        die "Falha ao baixar $name; Kindle inalterado."
    [[ -s "$WORK/$name" ]] || die "Arquivo vazio: $name"
done
grep -Fq 'Zotero storage and cleanup' "$WORK/main.lua" ||
    die "O menu atualizado nao foi encontrado."
grep -Fq 'local ENABLE_LOCAL_DELETION = true' "$WORK/zotero_storage_manager.lua" ||
    die "A funcao de exclusao individual nao foi encontrada."
grep -Fq 'FINAL CONFIRMATION' "$WORK/zotero_storage_manager.lua" ||
    die "Falta a confirmacao final."
grep -Fq 'trustedRoot(root.path)' "$WORK/zotero_storage_manager.lua" ||
    die "Falta validacao estrita de destino local."
if grep -Eq 'for[[:space:]]+_,' "$WORK/zotero_storage_manager.lua"; then
    die "Variavel de traducao '_' sobrescrita; abortando."
fi
if command -v luac5.1 >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do luac5.1 -p "$WORK/$name" || die "Erro sintaxe Lua $name"; done
elif command -v luac >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do luac -p "$WORK/$name" || die "Erro sintaxe Lua $name"; done
else
    echo "Aviso: luac local nao encontrado; fonte passou nos testes GitHub Actions."
fi

mkdir -p "$BACKUP"
for name in "${FILES[@]}"; do
    cp -p "$PLUGIN/$name" "$BACKUP/$name" ||
        die "Nao foi possivel criar backup de $name; Kindle inalterado."
done
echo "Backup anterior: $BACKUP"
restore() {
    for name in "${FILES[@]}"; do
        cp -p "$BACKUP/$name" "$PLUGIN/$name" || true
    done
}
for name in "${FILES[@]}"; do
    if ! cp "$WORK/$name" "$PLUGIN/$name" ||
       ! cmp -s "$WORK/$name" "$PLUGIN/$name"; then
        restore
        die "Falha ao atualizar $name; restauracao tentada com backup."
    fi
    echo "Atualizado e verificado: $name"
done
sync
echo
echo "OK: exclusao individual instalada (nenhum PDF ou EPUB apagado pelo instalador)."
echo "Menu: Zotero Atelier > Maintenance > Zotero storage and cleanup."
echo "Apagar downloads exige marcar arquivos e confirmar DUAS vezes."
echo "O banco, arquivos .sdr, PDFs/EPUBs existentes e credenciais foram preservados."
echo "IMPORTANTE: antes de apagar arquivos anotados, faca backup/sincronize as anotacoes."
echo "Ejete o Kindle com seguranca e reinicie o KOReader."
