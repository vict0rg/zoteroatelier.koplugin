#!/usr/bin/env bash
# Install ONLY the safe, read-only, per-document selection screen on a Kindle.
# Requires the already-tested Zotero storage report and preserves all user data.
set -Eeuo pipefail
umask 077

MOUNT="${KINDLE_MOUNT:-/media/$USER/Kindle}"
PLUGIN="$MOUNT/koreader/plugins/zoteroatelier.koplugin"
# Verified fixed commit, so the CDN cannot deliver a mismatched branch state.
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/8b3856343f4453d20f155d8b3bb72376721435a2"
BACKUP="$HOME/Downloads/BACKUP-ZOTERO-SELECAO-INDIVIDUAL-KINDLE-$(date +%Y%m%d-%H%M%S)"
FILE="zotero_storage_manager.lua"

die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }

echo "Zotero Atelier: selecao individual de arquivos, SOMENTE LEITURA."
echo "Feche o KOReader completamente antes de conectar o Kindle por USB."
MP="$(findmnt -rn -T "$MOUNT" -o TARGET 2>/dev/null || true)"
[[ "$MP" == "$MOUNT" || "$MP" == "$MOUNT/" ]] ||
    die "O Kindle USB nao esta montado em $MOUNT."
[[ -f "$PLUGIN/_meta.lua" && -f "$PLUGIN/main.lua" && -f "$PLUGIN/$FILE" ]] ||
    die "Zotero Atelier / gerenciador atual nao encontrado."
[[ ! -L "$PLUGIN" && ! -L "$PLUGIN/$FILE" ]] ||
    die "Destino simbolico inesperado; nada alterado."
grep -Fq 'Zotero storage report (read-only test)' "$PLUGIN/main.lua" ||
    die "Nao foi encontrado o menu de relatorio de teste ja validado."
command -v curl >/dev/null || die "curl nao encontrado."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
    "$BASE/$FILE" -o "$WORK/$FILE" ||
    die "Falhou download do modulo. Kindle inalterado."
[[ -s "$WORK/$FILE" ]] || die "Modulo recebido vazio."
grep -Fq 'local SAFE_READ_ONLY = true' "$WORK/$FILE" ||
    die "Modulo nao esta no modo somente leitura."
grep -Fq 'function M.showIndividual' "$WORK/$FILE" ||
    die "Modulo nao contem a nova selecao individual."
grep -Fq 'Select individual downloads' "$WORK/$FILE" ||
    die "O menu de selecao individual nao foi encontrado."
# Regression guard for the underscore/gettext collision that previously exited KOReader.
if grep -Eq 'for[[:space:]]+_,' "$WORK/$FILE"; then
    die "Modulo reutiliza '_' como indice e pode quebrar gettext; nada alterado."
fi
if grep -Eq 'os[[:space:]]*\.[[:space:]]*remove[[:space:]]*\(' "$WORK/$FILE"; then
    die "Modulo contem codigo de exclusao; operacao cancelada."
fi

if command -v luac5.1 >/dev/null 2>&1; then
    luac5.1 -p "$WORK/$FILE" || die "Falha na sintaxe Lua 5.1."
elif command -v luac >/dev/null 2>&1; then
    luac -p "$WORK/$FILE" || die "Falha na sintaxe Lua."
else
    echo "Aviso: luac indisponivel localmente; verificar inicializacao no Kindle."
fi

mkdir -p "$BACKUP"
cp -p "$PLUGIN/$FILE" "$BACKUP/$FILE" ||
    die "Falha ao salvar backup. Kindle inalterado."
if ! cp "$WORK/$FILE" "$PLUGIN/$FILE" ||
   ! cmp -s "$WORK/$FILE" "$PLUGIN/$FILE"; then
    cp -p "$BACKUP/$FILE" "$PLUGIN/$FILE" || true
    die "Falha ao instalar; tentativa de restauracao realizada."
fi
sync
echo
echo "OK: selecao individual SOMENTE LEITURA instalada e conferida."
echo "Backup anterior: $BACKUP"
echo "Maintenance > Zotero storage report (read-only test) > Select individual downloads"
echo "Nenhum arquivo PDF/EPUB ou .sdr foi apagado, movido ou alterado."
echo "Banco SQLite, credenciais e codigo de download Zotero/Dropbox preservados."
echo "Ejete o Kindle com seguranca e reinicie KOReader."
