#!/bin/bash

CONFIG="rsync_manager.conf"
LOGFILE="rsync_manager.log"

touch "$CONFIG"
touch "$LOGFILE"

########################################
# INIT
########################################

init_config() {
    if ! grep -q "\[SYNC\]" "$CONFIG"; then
cat > "$CONFIG" << EOF
[SYNC]
EOF
    fi
}

cek_rsync() {
    command -v rsync >/dev/null 2>&1 || {
        echo "rsync belum terinstall"
        exit 1
    }
}

pause() {
    read -p "ENTER..."
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

########################################
# PARSE CONFIG
########################################

list_sync() {
    awk '
    /^\[SYNC\]/ {flag=1; next}
    flag && NF
    ' "$CONFIG"
}

########################################
# CONFLICT HANDLER
########################################

resolve_conflict() {

    local file_src="$1"
    local file_dst="$2"

    echo ""
    echo "CONFLICT DETECTED:"
    echo "SRC: $file_src"
    echo "DST: $file_dst"
    echo ""
    echo "1. Source wins"
    echo "2. Destination wins"
    echo "3. Skip"
    echo "4. Newest wins"
    read -p "Choose: " c

    case $c in
        1) return 1 ;;
        2) return 2 ;;
        3) return 3 ;;
        4) return 4 ;;
        *) return 4 ;;
    esac
}

########################################
# SMART SYNC ENGINE
########################################

sync_pair() {

    src="$1"
    mode="$2"
    dst="$3"

    echo ""
    echo "======================================"
    echo "SRC : $src"
    echo "DST : $dst"
    echo "MODE: $mode"
    echo "======================================"

    mkdir -p "$dst" 2>/dev/null

    case "$mode" in

    ##################################
    # ONE WAY (SRC -> DST)
    ##################################
    oneway)
        rsync -avh --progress "$src/" "$dst/"
        log "ONEWAY $src -> $dst"
    ;;

    ##################################
    # MIRROR (STRICT SYNC)
    ##################################
    mirror)
        rsync -avh --delete "$src/" "$dst/"
        log "MIRROR $src <-> $dst (src dominant)"
    ;;

    ##################################
    # TWO WAY SYNC
    ##################################
    twoway)

        # STEP 1: SRC -> DST
        rsync -avh --update "$src/" "$dst/"

        # STEP 2: DST -> SRC
        rsync -avh --update "$dst/" "$src/"

        log "TWOWAY $src <-> $dst"
    ;;

    esac
}

########################################
# SYNC ALL
########################################

sync_all() {

    mapfile -t lines < <(list_sync)

    if [ ${#lines[@]} -eq 0 ]; then
        echo "No sync config"
        pause
        return
    fi

    for line in "${lines[@]}"; do

        src=$(echo "$line" | cut -d'|' -f1)
        mode=$(echo "$line" | cut -d'|' -f2)
        dst=$(echo "$line" | cut -d'|' -f3)

        sync_pair "$src" "$mode" "$dst"

    done

    echo ""
    echo "SYNC DONE"
    pause
}

add_sync() {

    echo ""
    echo "=== ADD SYNC CONFIG ==="

    read -p "Source folder: " src

    if [ ! -d "$src" ]; then
        echo "WARNING: source folder tidak ada (boleh lanjut untuk SSH juga)"
    fi

    echo ""
    echo "Mode:"
    echo "1. oneway"
    echo "2. twoway"
    echo "3. mirror"
    read -p "Choose mode: " m

    case $m in
        1) mode="oneway" ;;
        2) mode="twoway" ;;
        3) mode="mirror" ;;
        *) echo "invalid"; return ;;
    esac

    echo ""
    read -p "Destination (local or user@ip:/path): " dst

    if [ -z "$dst" ]; then
        echo "Destination kosong"
        return
    fi

    # append safely after [SYNC]
    awk -v line="$src|$mode|$dst" '
    BEGIN{added=0}
    /^\[SYNC\]/{print; print line; added=1; next}
    {print}
    ' "$CONFIG" > "$CONFIG.tmp"

    mv "$CONFIG.tmp" "$CONFIG"

    echo "ADDED: $src -> $dst [$mode]"
    log "CONFIG ADD $src|$mode|$dst"
    pause
}

delete_sync() {

    echo ""
    echo "=== DELETE SYNC CONFIG ==="
    echo ""

    mapfile -t lines < <(list_sync)

    if [ ${#lines[@]} -eq 0 ]; then
        echo "No data"
        pause
        return
    fi

    for i in "${!lines[@]}"; do
        echo "$((i+1)). ${lines[$i]}"
    done

    echo ""
    read -p "Choose number to delete: " n

    target="${lines[$((n-1))]}"

    grep -vF "$target" "$CONFIG" > "$CONFIG.tmp"
    mv "$CONFIG.tmp" "$CONFIG"

    echo "DELETED"
    log "CONFIG DELETE $target"
    pause
}

manage_config() {

while true; do
    clear
    echo "======================="
    echo "   CONFIG MANAGER"
    echo "======================="
    echo "1. Add Sync"
    echo "2. Delete Sync"
    echo "3. List"
    echo "0. Back"
    echo "======================="

    read -p "Choose: " c

    case $c in
        1) add_sync ;;
        2) delete_sync ;;
        3) clear; list_sync; pause ;;
        0) break ;;
    esac

done
}

########################################
# MENU
########################################

menu() {

while true; do
    clear
    echo "=============================="
    echo "   SIMPLE RSYNC MANAGER - BY WePey"
    echo "=============================="
    echo "1. Sync Now"
    echo "2. Manage Config"
    echo "3. View Config"
    echo "4. View Log"
    echo "0. Exit"
    echo "=============================="

    read -p "Choose: " p

    case $p in
        1) sync_all ;;
        2) manage_config ;;
        3) clear; cat "$CONFIG"; pause ;;
        4) clear; cat "$LOGFILE"; pause ;;
        0) exit ;;
    esac

done
}

########################################
# START
########################################

cek_rsync
init_config
menu