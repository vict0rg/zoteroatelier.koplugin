#!/usr/bin/env bash
# Install confirm-before-delete extension for the existing Zotero Atelier Drop Sync.
# Only lua plugin code; NEVER modifies PDFs, .sdr files, SQLite or credentials.
set -Eeuo pipefail
umask 077

MOUNT="${KINDLE_MOUNT:-/media/$USER/Kindle}"
PLUGIN="$MOUNT/koreader/plugins/zoteroatelier.koplugin"
REV="809b41950fdd689f174b0fd8767730c4b065d617"
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/$REV"
BACKUP="$HOME/Downloads/BACKUP-ZOTERO-ATELIER-EXCLUSOES-$(date +%Y%m%d-%H%M%S)"
FILES=(annotation_delete_state.lua zoteroapi.lua main.lua)
REQUIRED_EXISTING=(zoteroapi.lua main.lua annotations.lua zotero_dropbox.lua)

die() { printf 'ERRO: %s\n' "$*" >&2; exit 1; }
echo "Atelier Drop Sync — exclusoes bidirecionais com confirmacao obrigatoria."
echo "Feche completamente o KOReader e conecte o Kindle por USB."
command -v curl >/dev/null || die "curl ausente."
command -v findmnt >/dev/null || die "findmnt ausente."
[[ -d "$MOUNT" ]] || die "Kindle nao encontrado em $MOUNT."
MP="$(findmnt -rn -T "$MOUNT" -o TARGET 2>/dev/null || true)"
[[ "$MP" == "$MOUNT" || "$MP" == "$MOUNT/" ]] ||
    die "O Kindle nao esta montado como dispositivo USB em $MOUNT."
[[ -d "$PLUGIN" && ! -L "$PLUGIN" ]] || die "Plugin ausente."
for name in "${REQUIRED_EXISTING[@]}"; do
    [[ -f "$PLUGIN/$name" && ! -L "$PLUGIN/$name" ]] ||
        die "Instalacao anterior incompleta: $name"
done
for name in "${FILES[@]}"; do
    [[ ! -e "$PLUGIN/$name" || ( -f "$PLUGIN/$name" && ! -L "$PLUGIN/$name" ) ]] ||
        die "Arquivo de destino inseguro: $name"
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
for name in "${FILES[@]}"; do
    curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
        "$BASE/$name" -o "$WORK/$name" ||
        die "Download falhou; Kindle ainda inalterado: $name"
    [[ -s "$WORK/$name" ]] || die "Download vazio: $name"
done
grep -Fq 'function API.planAnnotationDeletions(parent_key, file_path)' "$WORK/zoteroapi.lua" ||
    die "Preflight ausente."
grep -Fq 'function API.applyConfirmedAnnotationDeletions(plan)' "$WORK/zoteroapi.lua" ||
    die "Exclusoes confirmadas ausentes."
grep -Fq 'zoteroDeletedAnnotationArchiveV1' "$WORK/zoteroapi.lua" ||
    die "Arquivo de recuperacao de anotacoes ausente."
grep -Fq 'ConfirmBox:new({' "$WORK/main.lua" ||
    die "Confirmacao de exclusao ausente."
grep -Fq 'fresh:saveSetting("zoteroConfirmedAnnotationKeysV1", baseline_snapshot)' "$WORK/main.lua" ||
    die "Persistencia da referencia inicial ausente."
grep -Fq 'function M.plan(saved, local_keys, remote_keys)' "$WORK/annotation_delete_state.lua" ||
    die "Regras conservadoras ausentes."

if command -v luac5.1 >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do
        luac5.1 -p "$WORK/$name" || die "Sintaxe invalida: $name"
    done
elif command -v luac >/dev/null 2>&1; then
    for name in "${FILES[@]}"; do
        luac -p "$WORK/$name" || die "Sintaxe invalida: $name"
    done
else
    echo "Aviso: Lua indisponivel no PC. GitHub Actions verificou sintaxe e testes."
fi

mkdir -p "$BACKUP"
# Back up CURRENT Kindle document metadata before enabling destructive sync.
# The archive contains only .sdr directories, not PDFs, EPUBs or Dropbox files.
if [[ -d "$MOUNT/documents/Zotero" ]]; then
    (
        cd "$MOUNT"
        find documents/Zotero -type d -name '*.sdr' -print0 \
            | tar --null -cf "$BACKUP/sidecars-antes-exclusoes.tar" -T -
    ) || die "Nao foi possivel guardar os .sdr atuais; Kindle inalterado."
    [[ -s "$BACKUP/sidecars-antes-exclusoes.tar" ]] ||
        die "Backup de .sdr vazio; Kindle inalterado."
fi
for name in "${FILES[@]}"; do
    if [[ -f "$PLUGIN/$name" ]]; then
        cp -p "$PLUGIN/$name" "$BACKUP/$name" ||
            die "Backup falhou: $name; Kindle inalterado."
    fi
done

for name in "${FILES[@]}"; do
    if ! cp "$WORK/$name" "$PLUGIN/$name" ||
       ! cmp -s "$WORK/$name" "$PLUGIN/$name"; then
        for previous in "${FILES[@]}"; do
            if [[ -f "$BACKUP/$previous" ]]; then
                cp -p "$BACKUP/$previous" "$PLUGIN/$previous" || true
            else
                rm -f "$PLUGIN/$previous"
            fi
        done
        die "Falha de instalacao. Tentativa de retorno executada."
    fi
    echo "Instalado: $name"
done
sync
echo
echo "OK: exclusoes confirmadas instaladas. Backup dos modulos: $BACKUP"
echo "O backup tambem inclui os arquivos .sdr encontrados no Kindle."
echo "Nenhum PDF, EPUB, .sdr, SQLite ou credencial foi modificado."
echo "No PRIMEIRO 'Sync document annotations', o plugin somente estabelece"
echo "quais anotacoes estao em ambos os lugares. NAO apaga nada."
echo "Exclusoes feitas DEPOIS dessa etapa requerem confirmacao na tela."
echo "Ejete o Kindle e reinicie o KOReader."
