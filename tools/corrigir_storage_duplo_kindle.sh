#!/usr/bin/env bash
# Repair a Kindle where Zotero Atelier uses both legacy and documents storage.
# - Updates only zoteroapi.lua (Kindle detection through Device:isKindle()).
# - Moves only non-conflicting Zotero attachment key directories to documents.
# - Never overwrites, deletes, or merges existing attachment directories.
# - Keeps SQLite, OAuth credentials, .sdr and KOReader cache unchanged.
set -Eeuo pipefail
umask 077

MOUNT="${KINDLE_MOUNT:-/media/$USER/Kindle}"
PLUGIN="$MOUNT/koreader/plugins/zoteroatelier.koplugin"
ZOTERO="$MOUNT/koreader/zotero"
OLD="$ZOTERO/storage"
NEW="$MOUNT/documents/Zotero/storage"
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand"
BACKUP="$HOME/Downloads/BACKUP-ZOTERO-REPARO-STORAGE-KINDLE-$(date +%Y%m%d-%H%M%S)"

die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }

echo "Reparo do armazenamento Zotero no Kindle"
echo "É obrigatório fechar totalmente o KOReader antes de conectar o Kindle por USB."
MP="$(findmnt -rn -T "$MOUNT" -o TARGET 2>/dev/null || true)"
[[ "$MP" == "$MOUNT" || "$MP" == "$MOUNT/" ]] ||
    die "Kindle não encontrado como unidade USB montada em $MOUNT (findmnt: $MP)."
[[ -d "$PLUGIN" && -f "$PLUGIN/_meta.lua" && -f "$PLUGIN/zoteroapi.lua" ]] ||
    die "Plugin Zotero Atelier não encontrado: $PLUGIN"
[[ -d "$ZOTERO" && -d "$MOUNT/documents" ]] ||
    die "Pastas do Kindle não encontradas. Operação cancelada."
for d in "$ZOTERO" "$MOUNT/documents" "$MOUNT/documents/Zotero" "$OLD" "$NEW"; do
    [[ ! -L "$d" ]] || die "Pasta simbólica inesperada: $d"
done
[[ ! -e "$OLD" || -d "$OLD" ]] || die "Storage antigo não é uma pasta."
[[ ! -e "$NEW" || -d "$NEW" ]] || die "Storage novo não é uma pasta."

# Preflight: avoid overwriting any folder or touching files not identified as
# Zotero attachment-key directories. Abort before writing if keys collide.
TO_MOVE=()
if [[ -d "$OLD" ]]; then
    while IFS= read -r -d '' entry; do
        base_name="$(basename "$entry")"
        [[ "$base_name" =~ ^[A-Za-z0-9]{8}$ ]] ||
            die "Pasta inesperada no storage antigo: $base_name. Verifique manualmente."
        [[ -d "$entry" && ! -L "$entry" ]] ||
            die "Entrada inesperada no storage antigo: $base_name"
        if [[ -e "$NEW/$base_name" ]]; then
            die "Conflito: $base_name existe nas duas pastas. Nada alterado; não mesclaremos nem sobrescreveremos."
        fi
        TO_MOVE+=("$entry")
    done < <(find "$OLD" -mindepth 1 -maxdepth 1 -type d -print0)
    while IFS= read -r -d '' other; do
        die "Arquivo inesperado na raiz do storage antigo: $(basename "$other"). Nada alterado."
    done < <(find "$OLD" -mindepth 1 -maxdepth 1 ! -type d -print0)
fi
echo "Pastas de anexo sem conflito encontradas: ${#TO_MOVE[@]}"
for entry in "${TO_MOVE[@]}"; do
    echo "  $(basename "$entry")"
done

command -v curl >/dev/null || die "curl não encontrado."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
    "$BASE/zoteroapi.lua" -o "$WORK/zoteroapi.lua" ||
    die "Download de código falhou; Kindle não alterado."
[[ -s "$WORK/zoteroapi.lua" ]] || die "Arquivo baixado vazio."
grep -Fq 'if Device:isKindle() then' "$WORK/zoteroapi.lua" ||
    die "A versão recebida não contém a correção Device:isKindle()."
grep -Fq '"/mnt/us/documents"' "$WORK/zoteroapi.lua" ||
    die "A versão recebida não contém o destino de documents."
if command -v luac5.1 >/dev/null 2>&1; then
    luac5.1 -p "$WORK/zoteroapi.lua" || die "Código Lua inválido."
elif command -v luac >/dev/null 2>&1; then
    luac -p "$WORK/zoteroapi.lua" || die "Código Lua inválido."
else
    echo "Aviso: não há compilador Lua para teste sintático."
fi

mkdir -p "$BACKUP"
cp -p "$PLUGIN/zoteroapi.lua" "$BACKUP/zoteroapi.lua" ||
    die "Não foi possível fazer backup do código antigo."
# The DB is not changed; save a backup in case further diagnosis is required.
for file in zotero.db zotero.db-wal zotero.db-shm; do
    [[ ! -f "$ZOTERO/$file" ]] ||
        cp -p "$ZOTERO/$file" "$BACKUP/$file" ||
        die "Não foi possível fazer backup do banco: $file."
done
echo "Backup de segurança: $BACKUP"

# Update the code first: if a subsequent move cannot complete, the new plugin
# can still discover legacy books through its existing search roots.
cp "$WORK/zoteroapi.lua" "$PLUGIN/zoteroapi.lua" ||
    die "Falha ao instalar código; backup anterior em $BACKUP"
cmp -s "$WORK/zoteroapi.lua" "$PLUGIN/zoteroapi.lua" ||
    die "Falha na verificação do código; restaure o backup anterior."

mkdir -p "$MOUNT/documents/Zotero" "$NEW" ||
    die "Falha ao criar documents/Zotero/storage (código atualizado, arquivos preservados)."
MOVED=0
for entry in "${TO_MOVE[@]}"; do
    name="$(basename "$entry")"
    [[ ! -e "$NEW/$name" ]] ||
        die "Conflito inesperado após verificação: $name. Código atualizado, nenhum arquivo sobrescrito."
    mv -- "$entry" "$NEW/$name" ||
        die "Falha ao mover $name. Outras pastas preservadas; nenhuma foi sobrescrita."
    MOVED=$((MOVED + 1))
done
sync
echo
echo "OK: corrigido zoteroapi.lua; $MOVED pasta(s) de anexo movida(s)."
echo "Livros no destino:"
find "$NEW" -maxdepth 2 -type f \( -iname '*.pdf' -o -iname '*.epub' \) -print
echo
echo "O storage antigo pode permanecer como pasta vazia; isso não prejudica."
echo "Não alteramos credenciais, banco Zotero nem o cache global cr3cache."
echo "Ejete o Kindle com segurança; reinicie completamente o KOReader."
