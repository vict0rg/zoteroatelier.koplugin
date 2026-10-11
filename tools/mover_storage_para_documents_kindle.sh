#!/usr/bin/env bash
# Kindle Oasis: move Zotero Atelier's cached books into /documents
# and install a Kindle-only attachment path update.
# The Zotero database, API keys, Dropbox credentials and Flatpak are untouched.
set -Eeuo pipefail
umask 077

MOUNT="${KINDLE_MOUNT:-/media/$USER/Kindle}"
PLUGIN="$MOUNT/koreader/plugins/zoteroatelier.koplugin"
ZOTERO="$MOUNT/koreader/zotero"
SOURCE="$ZOTERO/storage"
DOCUMENTS="$MOUNT/documents"
DEST_PARENT="$DOCUMENTS/Zotero"
DEST="$DEST_PARENT/storage"
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand"
BACKUP="$HOME/Downloads/BACKUP-ZOTERO-DOCUMENTS-KINDLE-$(date +%Y%m%d-%H%M%S)"

die() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }

echo "MIGRAÇÃO ZOTERO ATELIER: /koreader/zotero/storage -> /documents/Zotero/storage"
echo "O KOReader DEVE estar completamente fechado e o Kindle conectado por USB."
[[ -d "$PLUGIN" && -f "$PLUGIN/_meta.lua" ]] ||
  die "Plugin não encontrado: $PLUGIN"
[[ -d "$ZOTERO" && -d "$DOCUMENTS" ]] ||
  die "Kindle incompleto ou não montado corretamente (faltou /koreader/zotero ou /documents)."
[[ ! -L "$DOCUMENTS" && ! -L "$ZOTERO" ]] ||
  die "Diretório inesperadamente simbólico; operação cancelada."

# Prevent writing into a stray empty Linux directory if the USB device is
# not mounted. The path must be the real removable Kindle volume.
MOUNT_POINT="$(findmnt -rn -T "$MOUNT" -o TARGET 2>/dev/null || true)"
[[ "$MOUNT_POINT" == "$MOUNT" || "$MOUNT_POINT" == "$MOUNT/" ]] ||
  die "Kindle não identificado como volume USB montado em $MOUNT (findmnt: $MOUNT_POINT)."

[[ -f "$PLUGIN/zoteroapi.lua" ]] || die "Falta zoteroapi.lua no plugin Kindle."
[[ ! -L "$SOURCE" && ! -L "$DEST" && ! -L "$DEST_PARENT" ]] ||
  die "Pasta de storage simbólica inesperada; operação cancelada."
if [[ -e "$SOURCE" && ! -d "$SOURCE" ]]; then
  die "A origem de storage existe mas não é um diretório."
fi
if [[ -e "$DEST" && ! -d "$DEST" ]]; then
  die "O destino existe mas não é um diretório."
fi
if [[ -d "$SOURCE" && -e "$DEST" ]]; then
  die "Existem storage antigo e novo. Nenhum arquivo foi alterado. Precisamos conferir conflitos antes de mesclar as pastas."
fi

command -v curl >/dev/null || die "curl não está instalado."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo
echo "1/4 Baixando o arquivo atualizado..."
curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
  "$BASE/zoteroapi.lua" -o "$WORK/zoteroapi.lua" ||
  die "Não foi possível baixar o código; Kindle inalterado."
[[ -s "$WORK/zoteroapi.lua" ]] || die "Código baixado está vazio."
# Match the runtime language when available.
if command -v luac5.1 >/dev/null 2>&1; then
  luac5.1 -p "$WORK/zoteroapi.lua" || die "Erro de sintaxe no código baixado."
elif command -v luac >/dev/null 2>&1; then
  luac -p "$WORK/zoteroapi.lua" || die "Erro de sintaxe no código baixado."
else
  echo "Aviso: sem compilador Lua local para checagem sintática."
fi
grep -Fq '"/mnt/us/koreader/zotero"' "$WORK/zoteroapi.lua" ||
  die "O código baixado não contém a mudança específica para o Kindle; nada alterado."

echo
echo "2/4 Salvando backup do plugin..."
mkdir -p "$BACKUP"
cp -p "$PLUGIN/zoteroapi.lua" "$BACKUP/zoteroapi.lua" ||
  die "Não foi possível fazer backup do código."
for file in zotero.db zotero.db-wal zotero.db-shm; do
  if [[ -f "$ZOTERO/$file" ]]; then
    cp -p "$ZOTERO/$file" "$BACKUP/$file" ||
      die "Não foi possível fazer backup de $file."
  fi
done
echo "Backup em: $BACKUP"
echo "O backup NÃO duplica todos os livros; os arquivos de leitura serão movidos dentro do mesmo volume."

echo
echo "3/4 Colocando os livros em documents..."
mkdir -p "$DEST_PARENT" || die "Não foi possível criar $DEST_PARENT"
MOVED=0
if [[ -d "$SOURCE" ]]; then
  # Rename the entire storage folder *within the same Kindle partition*.
  # Includes all attachment folders and KOReader .sdr sidecars; does not
  # copy gigabytes over USB, delete any file or merge duplicate keys.
  mv -- "$SOURCE" "$DEST" ||
    die "Falhou a transferência do storage. Código ainda não atualizado."
  MOVED=1
else
  mkdir "$DEST" || die "Não foi possível criar $DEST"
fi
[[ -d "$DEST" ]] || die "O storage novo não foi localizado após a migração."

echo
echo "4/4 Atualizando somente zoteroapi.lua no Kindle..."
if ! cp "$WORK/zoteroapi.lua" "$PLUGIN/zoteroapi.lua" ||
   ! cmp -s "$WORK/zoteroapi.lua" "$PLUGIN/zoteroapi.lua"; then
  echo "Falha ao instalar código. Tentando restaurar a versão anterior..." >&2
  cp "$BACKUP/zoteroapi.lua" "$PLUGIN/zoteroapi.lua" || true
  if [[ "$MOVED" -eq 1 && ! -e "$SOURCE" && -d "$DEST" ]]; then
    mv -- "$DEST" "$SOURCE" || true
  fi
  die "Instalação falhou; confira backup: $BACKUP"
fi

sync
echo
echo "OK! Arquivos armazenados em: $DEST"
echo "Arquivos PDF/EPUB encontrados: $(find "$DEST" -type f \( -iname '*.pdf' -o -iname '*.epub' \) | wc -l)"
echo "O banco Zotero, as credenciais e o KOReader Flatpak não foram alterados."
echo "Ejete o Kindle com segurança e reinicie o KOReader."
echo "Aviso: atalhos antigos do histórico podem apontar para o caminho anterior;"
echo "abra o documento pela pasta documents/Zotero ou pelo Zotero Atelier."
