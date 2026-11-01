#!/usr/bin/env bash
# Install the double-confirmed, per-document LOCAL Kindle Zotero cleanup.
# Replaces ONLY main.lua and zotero_storage_manager.lua, with local backups.
# Zotero library, Dropbox originals, PDFs, EPUBs, annotations and .sdr intact
# during installation. Deletion later requires two confirmations in KOReader.
set -Eeuo pipefail
umask 077

MOUNT="${KINDLE_MOUNT:-/media/$USER/Kindle}"
PLUGIN="$MOUNT/koreader/plugins/zoteroatelier.koplugin"
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/621f5a387c4e6689be8a9459ebed3e9192503e20"
BACKUP="$HOME/Downloads/BACKUP-ZOTERO-EXCLUSAO-INDIVIDUAL-KINDLE-$(date +%Y%m%d-%H%M%S)"
FILES=(zotero_storage_manager.lua main.lua)

die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }
echo "Zotero Atelier: habilitar exclusao individual SOMENTE dos downloads locais."
echo "Feche completamente KOReader antes de conectar Kindle por USB."
echo "Nenhum documento sera apagado durante a instalacao."

MP="$(findmnt -rn -T "$MOUNT" -o TARGET 2>/dev/null || true)"
[[ "$MP" == "$MOUNT" || "$MP" == "$MOUNT/" ]] ||
    die "O Kindle nao esta montado por USB em $MOUNT."
[[ -f "$PLUGIN/_meta.lua" ]] ||
    die "Plugin Zotero Atelier nao encontrado."
[[ ! -L "$PLUGIN" ]] || die "Pasta simbolica inesperada."
for name in "${FILES[@]}"; do
    [[ -f "$PLUGIN/$name" && ! -L "$PLUGIN/$name" ]] ||
        die "Modulo existente nao encontrado ou simbolico: $name."
done
grep -Fq 'Zotero storage report (read-only test)' "$PLUGIN/main.lua" ||
    die "A versao do menu nao corresponde a instalada no Oasis; nada alterado."
[[ -f "$PLUGIN/zotero_file_validation.lua" &&
   -f "$PLUGIN/zotero_dropbox.lua" &&
   -f "$PLUGIN/zoteroapi.lua" ]] ||
    die "Modulos Zotero/Dropbox incompletos; nada alterado."
command -v curl >/dev/null || die "curl nao encontrado."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
for name in "${FILES[@]}"; do
    curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
        "$BASE/$name" -o "$WORK/$name" ||
        die "Falhou download do codigo $name. Kindle inalterado."
    [[ -s "$WORK/$name" ]] || die "Codigo vazio: $name"
done

grep -Fq 'Zotero storage and cleanup' "$WORK/main.lua" ||
    die "Novo menu nao encontrado. Kindle inalterado."
grep -Fq 'local ENABLE_LOCAL_DELETION = true' "$WORK/zotero_storage_manager.lua" ||
    die "Funcao de exclusao nao encontrada. Kindle inalterado."
grep -Fq 'FINAL CONFIRMATION: permanently remove' "$WORK/zotero_storage_manager.lua" ||
    die "Protecao de segunda confirmacao ausente. Kindle inalterado."
grep -Fq 'plainFile(fresh.path)' "$WORK/zotero_storage_manager.lua" ||
    die "Rechecagem do arquivo ausente. Kindle inalterado."
grep -Fq 'PRIMARY_KINDLE_ROOT = "/mnt/us/documents/Zotero/storage"' "$WORK/zotero_storage_manager.lua" ||
    die "Limite de pasta segura ausente. Kindle inalterado."
if grep -Eq 'for[[:space:]]+_,' "$WORK/zotero_storage_manager.lua"; then
    die "Variavel de iteracao insegura para gettext. Kindle inalterado."
fi

if command -v luac5.1 >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do
        luac5.1 -p "$WORK/$name" || die "Sintaxe Lua 5.1 invalida: $name."
    done
elif command -v luac >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do
        luac -p "$WORK/$name" || die "Sintaxe Lua invalida: $name."
    done
else
    echo "Aviso: sem compilador Lua local; sintaxe verificada no GitHub CI."
fi

mkdir -p "$BACKUP"
for name in "${FILES[@]}"; do
    cp -p "$PLUGIN/$name" "$BACKUP/$name" ||
        die "Backup do modulo $name falhou; atualizacao nao iniciada."
done

rollback() {
    for name in "${FILES[@]}"; do
        cp -p "$BACKUP/$name" "$PLUGIN/$name" || true
    done
}
for name in "${FILES[@]}"; do
    if ! cp "$WORK/$name" "$PLUGIN/$name" ||
       ! cmp -s "$WORK/$name" "$PLUGIN/$name"; then
        rollback
        die "Copia/verificacao falhou em $name; tentativa de rollback feita. Backup: $BACKUP"
    fi
    echo "Atualizado e conferido: $name"
done
sync
echo
echo "OK: exclusao SELETIVA local instalada."
echo "Backup dos arquivos anteriores: $BACKUP"
echo "Instalacao nao apaga nada. O KOReader exigira DUAS confirmacoes."
echo "Zotero, Dropbox, SQLite, .sdr e codigo de download nao foram alterados."
echo "Ejete o Kindle com seguranca e reinicie o KOReader."
