#!/bin/bash

CONFIG="rsync_manager.conf"
LOGFILE="rsync_manager.log"

touch "$CONFIG"
touch "$LOGFILE"

########################################
# INIT
########################################

init_config() {

    if ! grep -q "^\[SYNC\]" "$CONFIG"; then

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

    command -v sshpass >/dev/null 2>&1 || {
        echo "sshpass belum terinstall. Install dengan: apt install sshpass (Ubuntu/Debian) atau yum install sshpass (CentOS)"
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
    /^\[SYNC\]/ {
        flag=1
        next
    }

    /^\[/ {
        flag=0
    }

    flag && NF && $0 !~ /^#/ {
        print
    }
    ' "$CONFIG"
}

########################################
# DETECT LOCAL PATH
########################################

is_local_path() {

    local path="$1"

    # Remote SSH
    if [[ "$path" =~ ^[^/@]+@[^/:]+: ]]; then
        return 1
    fi

    # Local
    return 0
}

########################################
# GET LOCAL USER
########################################

get_local_owner() {

    local path="$1"

    # Jika path berada di /home/user
    if [[ "$path" =~ ^/home/([^/]+)(/|$) ]]; then

        echo "${BASH_REMATCH[1]}:${BASH_REMATCH[1]}"

        return
    fi

    # Fallback
    echo "root:root"
}

########################################
# FIX LOCAL OWNERSHIP
########################################

fix_local_owner() {

    local path="$1"

    if ! is_local_path "$path"; then
        return
    fi

    # Hanya proses path absolut
    if [[ "$path" != /* ]]; then
        return
    fi

    local owner
    owner=$(get_local_owner "$path")

    echo ""
    echo "Memastikan owner lokal:"
    echo "PATH  : $path"
    echo "OWNER : $owner"

    chown -R "$owner" "$path" 2>/dev/null

    if [ $? -eq 0 ]; then
        log "LOCAL OWNER FIX $path -> $owner"
    else
        echo "WARNING: gagal mengubah owner $path"
        log "LOCAL OWNER FIX FAILED $path -> $owner"
    fi
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
# RSYNC OPTIONS
########################################

RSYNC_COPY_OPTIONS=(
    -rvh
    --no-owner
    --no-group
    --no-perms
    # Tambahan opsi agar rsync otomatis skip strict host key checking saat pakai sshpass
    -e "ssh -o StrictHostKeyChecking=no" 
)

########################################
# SMART SYNC ENGINE
########################################

sync_pair() {

    local src="$1"
    local mode="$2"
    local dst="$3"
    local pass="$4"

    echo ""
    echo "======================================"
    echo "SRC : $src"
    echo "DST : $dst"
    echo "MODE: $mode"
    if [ -n "$pass" ]; then
        echo "PASS: Tersimpan (Menggunakan sshpass)"
    else
        echo "PASS: Tidak Ada / Default SSH Key"
    fi
    echo "======================================"

    local CMD_PREFIX=()
    if [ -n "$pass" ]; then
        CMD_PREFIX=(sshpass -p "$pass")
    fi

    ####################################
    # CREATE LOCAL DESTINATION
    ####################################

    if is_local_path "$dst"; then

        mkdir -p "$dst" 2>/dev/null

        if [ $? -ne 0 ]; then
            echo "ERROR: tidak bisa membuat destination:"
            echo "$dst"
            log "SYNC ERROR mkdir $dst"
            return 1
        fi
    fi

    ####################################
    # ONE WAY
    ####################################

    case "$mode" in

        oneway)
            echo ""
            echo ">>> ONE WAY"
            echo "$src"
            echo "    ↓"
            echo "$dst"
            echo ""

            "${CMD_PREFIX[@]}" rsync \
                "${RSYNC_COPY_OPTIONS[@]}" \
                --progress \
                "$src/" \
                "$dst/"

            local result=$?

            if [ $result -eq 0 ]; then
                fix_local_owner "$dst"
                log "ONEWAY $src -> $dst"
            else
                echo ""
                echo "SYNC ERROR"
                log "ONEWAY FAILED $src -> $dst"
            fi
            ;;

        ##################################
        # MIRROR
        ##################################

        mirror)
            echo ""
            echo ">>> MIRROR"
            echo "$src"
            echo "    ↓"
            echo "$dst"
            echo ""

            "${CMD_PREFIX[@]}" rsync \
                "${RSYNC_COPY_OPTIONS[@]}" \
                --delete \
                --progress \
                "$src/" \
                "$dst/"

            local result=$?

            if [ $result -eq 0 ]; then
                fix_local_owner "$dst"
                log "MIRROR $src -> $dst"
            else
                echo ""
                echo "MIRROR ERROR"
                log "MIRROR FAILED $src -> $dst"
            fi
            ;;

        ##################################
        # TWO WAY
        ##################################

        twoway)
            echo ""
            echo "======================================"
            echo "       TWO WAY SYNC"
            echo "======================================"

            echo ""
            echo "STEP 1"
            echo "$src"
            echo "    ↓"
            echo "$dst"
            echo ""

            "${CMD_PREFIX[@]}" rsync \
                "${RSYNC_COPY_OPTIONS[@]}" \
                --update \
                --progress \
                "$src/" \
                "$dst/"

            local result1=$?

            if [ $result1 -ne 0 ]; then
                echo ""
                echo "ERROR: SRC -> DST gagal"
                log "TWOWAY FAILED SRC->DST $src -> $dst"
                return 1
            fi

            fix_local_owner "$dst"

            echo ""
            echo "STEP 2"
            echo "$dst"
            echo "    ↓"
            echo "$src"
            echo ""

            "${CMD_PREFIX[@]}" rsync \
                "${RSYNC_COPY_OPTIONS[@]}" \
                --update \
                --progress \
                "$dst/" \
                "$src/"

            local result2=$?

            if [ $result2 -ne 0 ]; then
                echo ""
                echo "ERROR: DST -> SRC gagal"
                log "TWOWAY FAILED DST->SRC $dst -> $src"
                return 1
            fi

            fix_local_owner "$src"
            log "TWOWAY $src <-> $dst"
            ;;

        *)
            echo "Mode tidak dikenal: $mode"
            log "UNKNOWN MODE $mode"
            return 1
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

    echo ""
    echo "======================================"
    echo "         START SYNC ALL"
    echo "======================================"

    for line in "${lines[@]}"; do
        [ -z "$line" ] && continue

        src=$(echo "$line" | cut -d'|' -f1)
        mode=$(echo "$line" | cut -d'|' -f2)
        dst=$(echo "$line" | cut -d'|' -f3)
        pass=$(echo "$line" | cut -d'|' -f4-)

        if [ -z "$src" ] || [ -z "$mode" ] || [ -z "$dst" ]; then
            echo ""
            echo "Config invalid: $line"
            log "CONFIG INVALID $line"
            continue
        fi

        sync_pair "$src" "$mode" "$dst" "$pass"
    done

    echo ""
    echo "======================================"
    echo "             SYNC DONE"
    echo "======================================"
    pause
}

########################################
# ADD SYNC
########################################

add_sync() {

    echo ""
    echo "=== ADD SYNC CONFIG ==="

    read -p "Source folder: " src

    if [ -z "$src" ]; then
        echo "Source kosong"
        pause
        return
    fi

    if [ ! -d "$src" ]; then
        echo ""
        echo "WARNING:"
        echo "Source folder tidak ada (Abaikan jika ini remote path)."
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
        *) echo "invalid"; pause; return ;;
    esac

    echo ""
    read -p "Destination (local or user@ip:/path): " dst

    if [ -z "$dst" ]; then
        echo "Destination kosong"
        pause
        return
    fi
    
    echo ""
    read -p "SSH Password (kosongkan jika local atau menggunakan SSH Key): " pass

    ##################################
    # VALIDASI PIPE
    ##################################

    if [[ "$src" == *"|"* ]] || [[ "$dst" == *"|"* ]] || [[ "$pass" == *"|"* ]]; then
        echo ""
        echo "ERROR:"
        echo "Path atau password tidak boleh mengandung karakter |"
        pause
        return
    fi

    ##################################
    # ADD CONFIG
    ##################################

    awk -v line="$src|$mode|$dst|$pass" '
    /^\[SYNC\]/ {
        print
        print line
        added=1
        next
    }
    { print }
    ' "$CONFIG" > "$CONFIG.tmp"

    mv "$CONFIG.tmp" "$CONFIG"

    echo ""
    echo "ADDED:"
    echo "$src -> $dst [$mode]"

    log "CONFIG ADD $src|$mode|$dst"
    pause
}

########################################
# DELETE SYNC
########################################

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
        # Jangan tampilkan password di layar saat delete
        display_line=$(echo "${lines[$i]}" | cut -d'|' -f1-3)
        echo "$((i+1)). $display_line"
    done

    echo ""
    read -p "Choose number to delete: " n

    if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "${#lines[@]}" ]; then
        echo "Nomor tidak valid"
        pause
        return
    fi

    target="${lines[$((n-1))]}"
    grep -vF -- "$target" "$CONFIG" > "$CONFIG.tmp"
    mv "$CONFIG.tmp" "$CONFIG"

    echo ""
    echo "DELETED: $(echo "$target" | cut -d'|' -f1-3)"
    log "CONFIG DELETE $target"
    pause
}

########################################
# MANAGE CONFIG
########################################

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
            3)
                clear
                echo "=== SYNC CONFIG ==="
                echo ""
                # Sembunyikan password saat dilist
                list_sync | cut -d'|' -f1-3 | awk -F'|' '{print $1 " -> " $3 " [" $2 "]"}'
                echo ""
                pause
                ;;
            0) break ;;
            *) echo "Invalid"; sleep 1 ;;
        esac
    done
}

########################################
# VIEW CONFIG
########################################

view_config() {

    clear
    echo "=============================="
    echo "          CONFIG"
    echo "=============================="
    echo ""
    cat "$CONFIG"
    echo ""
    pause
}

########################################
# VIEW LOG
########################################

view_log() {

    clear
    echo "=============================="
    echo "            LOG"
    echo "=============================="
    echo ""
    cat "$LOGFILE"
    echo ""
    pause
}

########################################
# MAIN MENU
########################################

menu() {

    while true; do
        clear
        echo "=============================="
        echo "   SIMPLE RSYNC MANAGER"
        echo "        BY WePey"
        echo "=============================="
        echo "1. Sync Now"
        echo "2. Manage Config"
        echo "3. View Config (with passwords)"
        echo "4. View Log"
        echo "0. Exit"
        echo "=============================="

        read -p "Choose: " p

        case $p in
            1) sync_all ;;
            2) manage_config ;;
            3) view_config ;;
            4) view_log ;;
            0) exit 0 ;;
            *) echo "Invalid"; sleep 1 ;;
        esac
    done
}

########################################
# START
########################################

cek_rsync
init_config
menu