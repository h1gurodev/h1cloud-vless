#!/bin/sh
# 3x-ui bootstrap for Pterodactyl WITHOUT root.
# The stock image keeps state in /etc/x-ui (DB) and /app/bin (xray+geo) — neither
# survives container recreation in Pterodactyl (only /home/container is the
# persistent volume). We point all 3x-ui state into /home/container and pin the
# panel port to the Pterodactyl allocation.
#
# Arg $1 = panel port (Pterodactyl substitutes {{SERVER_PORT}} in the egg startup).

PANEL_PORT="${1:-${SERVER_PORT:-2053}}"

BASE="/home/container"
export XUI_DB_FOLDER="$BASE/db"
export XUI_BIN_FOLDER="$BASE/bin"
export XUI_LOG_FOLDER="$BASE/logs"
export XUI_ENABLE_FAIL2BAN="false"   # needs root/iptables; not available non-root
mkdir -p "$XUI_DB_FOLDER" "$XUI_BIN_FOLDER" "$XUI_LOG_FOLDER"

XUI="/app/x-ui"

# Seed the xray core + geo databases into the persistent bin folder on first run
# (the image ships them under /app/bin; an empty XUI_BIN_FOLDER => xray won't run).
if [ ! -e "$XUI_BIN_FOLDER/geoip.dat" ]; then
    echo "[start] seeding xray core + geo files into $XUI_BIN_FOLDER"
    cp -a /app/bin/. "$XUI_BIN_FOLDER"/ 2>/dev/null || true
fi

rnd() { tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "${1:-16}"; }

# First-run init: random admin credentials + random web base path (unless the
# operator pinned them via egg variables). Done ONCE so panel changes survive.
INIT_MARK="$BASE/.xui-initialized"
if [ ! -f "$INIT_MARK" ]; then
    USER_VALUE="${XUI_USERNAME:-$(rnd 12)}"
    PASS_VALUE="${XUI_PASSWORD:-$(rnd 20)}"
    PATH_VALUE="${XUI_WEBBASEPATH:-$(rnd 16)}"
    "$XUI" setting -username "$USER_VALUE" -password "$PASS_VALUE" >/dev/null 2>&1
    "$XUI" setting -webBasePath "$PATH_VALUE" >/dev/null 2>&1
    {
        echo "username=$USER_VALUE"
        echo "password=$PASS_VALUE"
        echo "webBasePath=/$PATH_VALUE/"
    } > "$BASE/panel-credentials.txt"
    touch "$INIT_MARK"
    echo "=============================================================="
    echo "[start] 3x-ui first run — panel credentials (saved to"
    echo "        /home/container/panel-credentials.txt):"
    echo "        username    : $USER_VALUE"
    echo "        password    : $PASS_VALUE"
    echo "        webBasePath : /$PATH_VALUE/"
    echo "=============================================================="
fi

# Always pin the panel port to the Pterodactyl primary allocation. The panel port
# MUST equal the allocation, otherwise it is unreachable — don't let it drift.
"$XUI" setting -port "$PANEL_PORT" >/dev/null 2>&1

# Subscription server. Pterodactyl auto-assigns ONLY the primary port, so the
# built-in sub server (default :2096) can't grab a second one by itself. Default:
# OFF, so nothing dangles. To enable it, give the server an extra allocation and
# set XUI_SUB_PORT to that port. 3x-ui has no CLI flag for this -> edit x-ui.db.
DB="$XUI_DB_FOLDER/x-ui.db"
xui_set() {  # key value -> upsert into the settings table
    sqlite3 "$DB" "INSERT INTO settings(key,value) SELECT '$1','$2' WHERE NOT EXISTS(SELECT 1 FROM settings WHERE key='$1'); UPDATE settings SET value='$2' WHERE key='$1';" 2>/dev/null
}
if [ -f "$DB" ] && command -v sqlite3 >/dev/null 2>&1; then
    if [ -n "$XUI_SUB_PORT" ]; then
        xui_set subEnable true
        xui_set subPort "$XUI_SUB_PORT"
        echo "[start] subscription server ENABLED on port $XUI_SUB_PORT"
    else
        xui_set subEnable false
        echo "[start] subscription server disabled (set XUI_SUB_PORT to a spare allocation to enable)"
    fi
fi

# Dashboard spec spoof. 3x-ui is a Go binary; it reads /proc directly via syscalls,
# so an LD_PRELOAD shim can't touch it. But its stats lib (gopsutil) honors the
# HOST_PROC env var, so we point it at a mirror of /proc with faked meminfo/loadavg
# (everything else symlinks back to the real /proc). Hides the shared dedi's real
# RAM + load on the panel dashboard. Tunables: FAKE_RAM_MB (MB), FAKE_LOAD.
# Set either to "0"/"off"/blank to leave that metric real.
is_pos() { case "$1" in ''|0|off|OFF|false|no) return 1 ;; *[!0-9.]*) return 1 ;; *) return 0 ;; esac; }
FAKE_RAM_MB="${FAKE_RAM_MB:-2048}"
FAKE_LOAD="${FAKE_LOAD:-0.10}"
if is_pos "$FAKE_RAM_MB" || is_pos "$FAKE_LOAD"; then
    FP="$BASE/.fakeproc"
    rm -rf "$FP" 2>/dev/null
    if mkdir -p "$FP"; then
        for e in /proc/*; do ln -s "$e" "$FP/${e##*/}" 2>/dev/null; done
        ln -sfn /proc/self "$FP/self" 2>/dev/null
        if is_pos "$FAKE_RAM_MB"; then
            kb=$(( FAKE_RAM_MB * 1024 )); av=$(( kb * 85 / 100 ))
            rm -f "$FP/meminfo"
            printf 'MemTotal:%15d kB\nMemFree:%15d kB\nMemAvailable:%15d kB\nBuffers:%15d kB\nCached:%15d kB\nSwapTotal:%15d kB\nSwapFree:%15d kB\n' \
                "$kb" "$av" "$av" 0 0 0 0 > "$FP/meminfo"
        fi
        if is_pos "$FAKE_LOAD"; then
            rm -f "$FP/loadavg"
            printf '%s %s %s 1/200 1\n' "$FAKE_LOAD" "$FAKE_LOAD" "$FAKE_LOAD" > "$FP/loadavg"
        fi
        export HOST_PROC="$FP"
        echo "[start] dashboard spoof on (FAKE_RAM_MB=$FAKE_RAM_MB FAKE_LOAD=$FAKE_LOAD) via HOST_PROC"
    fi
fi

echo "[start] 3x-ui panel port = $PANEL_PORT (DB=$XUI_DB_FOLDER)"
"$XUI" setting -show 2>/dev/null | grep -iE 'port|path|username|listen' | sed 's/^/[start] /'

echo "[xui] starting"
exec "$XUI"
