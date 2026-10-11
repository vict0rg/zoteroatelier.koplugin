#!/usr/bin/env bash
# Install/restore a *desktop Flatpak* test of the experimental Dropbox integration.
# Personal Zotero metadata and keys are NOT changed by this installer.
set -Eeuo pipefail

APP_ID="rocks.koreader.KOReader"
DATA_DIR="$HOME/.var/app/$APP_ID/config/koreader"
PLUGIN_DIR="$DATA_DIR/plugins/zoteroatelier.koplugin"
BACKUP_ROOT="$HOME/Downloads/BACKUP-ZOTERO-ATELIER-DROPBOX"
BASE="https://raw.githubusercontent.com/vict0rg/zoteroatelier.koplugin/feature/dropbox-on-demand"
FILES=(annotation_panel.lua zoteroapi.lua zotero_dropbox.lua)
MODE="${1:-install}"

fail() { printf '\nERRO: %s\n' "$*" >&2; exit 1; }
say() { printf '\n>>> %s\n' "$*"; }
ensure_stopped() {
    if command -v flatpak >/dev/null 2>&1 &&
       flatpak ps --columns=application 2>/dev/null | grep -Fxq "$APP_ID"; then
        fail "Feche completamente o KOReader Flatpak antes de instalar/restaurar."
    fi
}
ensure_target() {
    [[ -d "$PLUGIN_DIR" && -f "$PLUGIN_DIR/main.lua" && -f "$PLUGIN_DIR/_meta.lua" ]] ||
        fail "Plugin existente não encontrado em: $PLUGIN_DIR"
}
case "$MODE" in
    status)
        say "KOReader Flatpak: $DATA_DIR"
        if [[ -f "$PLUGIN_DIR/zotero_dropbox.lua" ]]; then
            echo "Módulo Dropbox: PRESENTE (não implica que esteja configurado)"
        else
            echo "Módulo Dropbox: ausente"
        fi
        echo "Backups existentes:"
        if [[ -d "$BACKUP_ROOT" ]]; then
            find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r
        else
            echo "(nenhum)"
        fi
        exit 0
        ;;
    install)
        ensure_stopped
        ensure_target
        command -v curl >/dev/null || fail "curl não está instalado."
        mkdir -p "$BACKUP_ROOT"
        chmod 700 "$BACKUP_ROOT"
        WORK="$(mktemp -d)"
        trap 'rm -rf "$WORK"' EXIT
        say "Baixando somente os 3 arquivos da branch experimental"
        for name in "${FILES[@]}"; do
            curl -fLsS --retry 2 --connect-timeout 15 --max-time 90 \
                -o "$WORK/$name" "$BASE/$name" || fail "Falha ao baixar $name; plugin preservado."
            [[ -s "$WORK/$name" ]] || fail "Arquivo vazio: $name"
        done
        if command -v luac >/dev/null 2>&1; then
            say "Verificando sintaxe dos módulos Lua"
            for name in "${FILES[@]}"; do
                luac -p "$WORK/$name" || fail "Sintaxe Lua inválida: $name"
            done
        elif command -v luac5.1 >/dev/null 2>&1; then
            say "Verificando sintaxe dos módulos Lua 5.1"
            for name in "${FILES[@]}"; do
                luac5.1 -p "$WORK/$name" || fail "Sintaxe Lua inválida: $name"
            done
        else
            echo "Aviso: compilador Lua local indisponível; o teste de carregamento será feito no KOReader."
        fi
        STAMP="$(date +%Y%m%d-%H%M%S)"
        DEST="$BACKUP_ROOT/$STAMP"
        mkdir -m 700 "$DEST"
        say "Criando backup da pasta original (sem alterar metadados Zotero)"
        cp -a "$PLUGIN_DIR" "$DEST/zoteroatelier.koplugin" || fail "Falha no backup. Nada foi instalado."
        # Store exact backup location and original source for easy rollback.
        printf '%s\n' "$DEST" > "$BACKUP_ROOT/LAST_BACKUP"
        for name in "${FILES[@]}"; do
            install -m 0644 "$WORK/$name" "$PLUGIN_DIR/.$name.new"
            mv -f "$PLUGIN_DIR/.$name.new" "$PLUGIN_DIR/$name"
        done
        say "INSTALAÇÃO EXPERIMENTAL CONCLUÍDA"
        echo "Backup completo em: $DEST"
        echo "As credenciais Zotero e Dropbox NÃO foram modificadas."
        echo "Inicie o KOReader e confira se o Zotero Atelier abre e navega."
        echo "Dropbox fica DESATIVADO até configurar o OAuth."
        echo "Voltar atrás: bash <este_script> restore"
        ;;
    restore)
        ensure_stopped
        ensure_target
        [[ -f "$BACKUP_ROOT/LAST_BACKUP" ]] || fail "Nenhum backup encontrado."
        DEST="$(<"$BACKUP_ROOT/LAST_BACKUP")"
        case "$DEST" in "$BACKUP_ROOT"/*) ;; *) fail "Caminho de backup inválido.";; esac
        [[ -f "$DEST/zoteroatelier.koplugin/main.lua" ]] || fail "Backup incompleto."
        WORK="$(mktemp -d)"
        trap 'rm -rf "$WORK"' EXIT
        cp -a "$DEST/zoteroatelier.koplugin" "$WORK/zoteroatelier.koplugin"
        # Roll back by copying backed-up plugin files over installed files.
        # The new experimental module is removed if it wasn't present before.
        for name in "${FILES[@]}"; do
            if [[ -f "$WORK/zoteroatelier.koplugin/$name" ]]; then
                cp -a "$WORK/zoteroatelier.koplugin/$name" "$PLUGIN_DIR/$name"
            else
                rm -f "$PLUGIN_DIR/$name"
            fi
        done
        say "Arquivos do Atelier restaurados de: $DEST"
        echo "A pasta $DATA_DIR/zotero/ foi preservada."
        ;;
    *)
        fail "Modo desconhecido. Use: install, restore, status"
        ;;
esac
