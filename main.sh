#!/bin/bash
set -e

XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
DATA_DIR="."
USERS_FILE="$DATA_DIR/users.json"
DOMAIN_FILE="$DATA_DIR/domain.txt"
CONFIG_FILE="$DATA_DIR/config.json"
KEY_FILE="$DATA_DIR/key.txt"
XRAY_BIN="$DATA_DIR/xray"
XRAY_PID=""
CHECK_INTERVAL=300

need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "$1 is required"
        exit 1
    fi
}

init_files() {
    need_cmd curl
    need_cmd python3

    if [ ! -f "$USERS_FILE" ]; then
        echo "[]" > "$USERS_FILE"
    fi

    if [ ! -f "$XRAY_BIN" ]; then
        echo "downloading xray..."
        curl -L -o xray.zip "$XRAY_URL"

        if command -v unzip >/dev/null 2>&1; then
            unzip -o -q xray.zip
        else
            python3 -m zipfile -e xray.zip .
        fi

        rm -f xray.zip
        chmod +x "$XRAY_BIN"
    fi
}

get_domain() {
    if [ -f "$DOMAIN_FILE" ]; then
        cat "$DOMAIN_FILE"
        return
    fi

    if [ -n "${DOMAIN:-}" ]; then
        echo "$DOMAIN" > "$DOMAIN_FILE"
        cat "$DOMAIN_FILE"
        return
    fi

    echo "Enter domain connected in Pterodactyl Domains:" >&2
    read -r DOMAIN

    if [ -z "$DOMAIN" ]; then
        echo "domain is empty"
        exit 1
    fi

    echo "$DOMAIN" > "$DOMAIN_FILE"
    cat "$DOMAIN_FILE"
}

get_port() {
    echo "${SERVER_PORT:-25565}"
}

get_public_port() {
    echo "${PUBLIC_PORT:-443}"
}

make_uuid() {
    if [ -f /proc/sys/kernel/random/uuid ]; then
        cat /proc/sys/kernel/random/uuid
    else
        python3 -c "import uuid; print(uuid.uuid4())"
    fi
}

validate_name() {
    NAME="$1"
    if [ -z "$NAME" ]; then
        return 1
    fi

    case "$NAME" in
        *[!a-zA-Z0-9._-]*)
            return 1
            ;;
    esac

    return 0
}

prune_expired() {
    python3 - "$USERS_FILE" <<'PY'
import json, sys, time

path = sys.argv[1]
now = int(time.time())

try:
    with open(path, "r", encoding="utf-8") as f:
        users = json.load(f)
except Exception:
    users = []

active = []
removed = []

for u in users:
    exp = int(u.get("expires_at", 0))
    if exp > now:
        active.append(u)
    else:
        removed.append(u.get("name", "unknown"))

with open(path, "w", encoding="utf-8") as f:
    json.dump(active, f, ensure_ascii=False, indent=2)

if removed:
    print("expired users removed: " + ", ".join(removed))
PY
}

build_config() {
    LOCAL_PORT="$(get_port)"

    prune_expired >/dev/null 2>&1 || true

    python3 - "$USERS_FILE" "$CONFIG_FILE" "$LOCAL_PORT" <<'PY'
import json, sys

users_file = sys.argv[1]
config_file = sys.argv[2]
port = int(sys.argv[3])

try:
    with open(users_file, "r", encoding="utf-8") as f:
        users = json.load(f)
except Exception:
    users = []

clients = []

for u in users:
    clients.append({
        "id": u["uuid"],
        "email": u["name"]
    })

config = {
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": port,
            "listen": "0.0.0.0",
            "protocol": "vless",
            "settings": {
                "clients": clients,
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/xray"
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}

with open(config_file, "w", encoding="utf-8") as f:
    json.dump(config, f, ensure_ascii=False, indent=2)
PY
}

make_link() {
    NAME="$1"

    if ! validate_name "$NAME"; then
        echo "bad user name. use only: a-z A-Z 0-9 . _ -"
        return 1
    fi

    PUBLIC_DOMAIN="$(get_domain)"
    PUBLIC_PORT_VALUE="$(get_public_port)"

    python3 - "$USERS_FILE" "$NAME" "$PUBLIC_DOMAIN" "$PUBLIC_PORT_VALUE" <<'PY'
import json, sys

users_file = sys.argv[1]
name = sys.argv[2]
domain = sys.argv[3]
port = sys.argv[4]

with open(users_file, "r", encoding="utf-8") as f:
    users = json.load(f)

for u in users:
    if u["name"] == name:
        uuid = u["uuid"]
        print(f"vless://{uuid}@{domain}:{port}?type=ws&security=tls&sni={domain}&host={domain}&path=%2Fxray&encryption=none#{name}")
        sys.exit(0)

print("user not found")
sys.exit(1)
PY
}

restart_xray() {
    build_config

    if [ -n "$XRAY_PID" ] && kill -0 "$XRAY_PID" >/dev/null 2>&1; then
        kill "$XRAY_PID" >/dev/null 2>&1 || true
        wait "$XRAY_PID" 2>/dev/null || true
    fi

    "$XRAY_BIN" run -config "$CONFIG_FILE" &
    XRAY_PID="$!"

    echo "xray restarted"
}

cmd_help() {
    echo "========================================"
    echo "H1CLOUD VLESS commands"
    echo "========================================"
    echo "vpn help                  show commands"
    echo "vpn add NAME DAYS          add user for DAYS"
    echo "vpn del NAME               delete user"
    echo "vpn list                   show users"
    echo "vpn link NAME              show user link"
    echo "vpn renew NAME DAYS        extend user by DAYS"
    echo "vpn domain DOMAIN          set public domain"
    echo "vpn restart                restart xray"
    echo "vpn stop                   stop server"
    echo "========================================"
    echo "examples:"
    echo "vpn add test 30"
    echo "vpn link test"
    echo "vpn renew test 15"
    echo "vpn del test"
    echo "vpn domain vpn.example.com"
    echo "========================================"
}

cmd_add() {
    NAME="$1"
    DAYS="$2"

    if ! validate_name "$NAME"; then
        echo "bad user name. use only: a-z A-Z 0-9 . _ -"
        echo "usage: vpn add NAME DAYS"
        return
    fi

    if ! echo "$DAYS" | grep -Eq '^[0-9]+$'; then
        echo "days must be number"
        echo "usage: vpn add NAME DAYS"
        return
    fi

    UUID="$(make_uuid)"

    python3 - "$USERS_FILE" "$NAME" "$DAYS" "$UUID" <<'PY'
import json, sys, time

path = sys.argv[1]
name = sys.argv[2]
days = int(sys.argv[3])
uuid = sys.argv[4]

with open(path, "r", encoding="utf-8") as f:
    users = json.load(f)

for u in users:
    if u["name"] == name:
        print("user already exists")
        sys.exit(1)

now = int(time.time())
expires_at = now + days * 86400

users.append({
    "name": name,
    "uuid": uuid,
    "created_at": now,
    "expires_at": expires_at
})

with open(path, "w", encoding="utf-8") as f:
    json.dump(users, f, ensure_ascii=False, indent=2)

print("user added")
PY

    restart_xray >/dev/null
    echo "link:"
    make_link "$NAME"
    make_link "$NAME" > "$KEY_FILE"
}

cmd_del() {
    NAME="$1"

    if ! validate_name "$NAME"; then
        echo "usage: vpn del NAME"
        return
    fi

    python3 - "$USERS_FILE" "$NAME" <<'PY'
import json, sys

path = sys.argv[1]
name = sys.argv[2]

with open(path, "r", encoding="utf-8") as f:
    users = json.load(f)

new_users = [u for u in users if u["name"] != name]

if len(new_users) == len(users):
    print("user not found")
    sys.exit(1)

with open(path, "w", encoding="utf-8") as f:
    json.dump(new_users, f, ensure_ascii=False, indent=2)

print("user deleted")
PY

    restart_xray >/dev/null
}

cmd_list() {
    prune_expired >/dev/null 2>&1 || true

    python3 - "$USERS_FILE" <<'PY'
import json, sys, time, datetime

path = sys.argv[1]
now = int(time.time())

with open(path, "r", encoding="utf-8") as f:
    users = json.load(f)

if not users:
    print("no users")
    sys.exit(0)

for u in users:
    exp = int(u["expires_at"])
    seconds_left = max(0, exp - now)
    days_left = seconds_left // 86400
    hours_left = (seconds_left % 86400) // 3600
    date = datetime.datetime.fromtimestamp(exp).strftime("%Y-%m-%d %H:%M")
    print(f"{u['name']} | uuid: {u['uuid']} | expires: {date} | left: {days_left}d {hours_left}h")
PY
}

cmd_renew() {
    NAME="$1"
    DAYS="$2"

    if ! validate_name "$NAME"; then
        echo "usage: vpn renew NAME DAYS"
        return
    fi

    if ! echo "$DAYS" | grep -Eq '^[0-9]+$'; then
        echo "days must be number"
        echo "usage: vpn renew NAME DAYS"
        return
    fi

    python3 - "$USERS_FILE" "$NAME" "$DAYS" <<'PY'
import json, sys, time

path = sys.argv[1]
name = sys.argv[2]
days = int(sys.argv[3])
now = int(time.time())

with open(path, "r", encoding="utf-8") as f:
    users = json.load(f)

found = False

for u in users:
    if u["name"] == name:
        base = max(now, int(u["expires_at"]))
        u["expires_at"] = base + days * 86400
        found = True

if not found:
    print("user not found")
    sys.exit(1)

with open(path, "w", encoding="utf-8") as f:
    json.dump(users, f, ensure_ascii=False, indent=2)

print("user renewed")
PY

    restart_xray >/dev/null
}

cmd_domain() {
    NEW_DOMAIN="$1"

    if [ -z "$NEW_DOMAIN" ]; then
        echo "usage: vpn domain DOMAIN"
        return
    fi

    echo "$NEW_DOMAIN" > "$DOMAIN_FILE"
    echo "domain saved: $NEW_DOMAIN"

    FIRST_USER="$(python3 - "$USERS_FILE" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    users = json.load(f)
print(users[0]["name"] if users else "")
PY
)"

    if [ -n "$FIRST_USER" ]; then
        make_link "$FIRST_USER" > "$KEY_FILE" || true
    fi
}

handle_cmd() {
    LINE="$1"

    set -- $LINE

    if [ "${1:-}" = "vpn" ]; then
        shift
    fi

    case "${1:-}" in
        help|"")
            cmd_help
            ;;
        add)
            cmd_add "${2:-}" "${3:-}"
            ;;
        del|delete|remove)
            cmd_del "${2:-}"
            ;;
        list)
            cmd_list
            ;;
        link)
            make_link "${2:-}"
            ;;
        renew)
            cmd_renew "${2:-}" "${3:-}"
            ;;
        domain)
            cmd_domain "${2:-}"
            ;;
        restart)
            restart_xray
            ;;
        stop|exit|quit)
            echo "stopping..."
            if [ -n "$XRAY_PID" ]; then
                kill "$XRAY_PID" >/dev/null 2>&1 || true
            fi
            exit 0
            ;;
        *)
            echo "unknown command: ${1:-}"
            echo "type: vpn help"
            ;;
    esac
}

check_expired_loop_tick() {
    BEFORE="$(cat "$USERS_FILE" 2>/dev/null || echo "[]")"
    prune_expired >/dev/null 2>&1 || true
    AFTER="$(cat "$USERS_FILE" 2>/dev/null || echo "[]")"

    if [ "$BEFORE" != "$AFTER" ]; then
        restart_xray >/dev/null 2>&1 || true
        echo "expired users cleaned"
    fi
}

start_server() {
    init_files
    get_domain >/dev/null
    build_config

    echo "========================================"
    echo "h1cloud vless is ready"
    echo "local port: $(get_port)"
    echo "domain: $(cat "$DOMAIN_FILE")"
    echo "public port: $(get_public_port)"
    echo "type: vpn help"
    echo "========================================"
    echo ""
    echo "h1cloud.su - лучший хостинг"
    echo "t.me/h1cloudbot"
    echo "Программист - h1guro.ovh"
    echo "========================================"

    "$XRAY_BIN" run -config "$CONFIG_FILE" &
    XRAY_PID="$!"

    LAST_CHECK=0

    while true; do
        if IFS= read -r -t 5 LINE; then
            handle_cmd "$LINE"
        fi

        NOW="$(date +%s)"
        if [ $((NOW - LAST_CHECK)) -ge "$CHECK_INTERVAL" ]; then
            check_expired_loop_tick
            LAST_CHECK="$NOW"
        fi

        if ! kill -0 "$XRAY_PID" >/dev/null 2>&1; then
            echo "xray stopped"
            exit 1
        fi
    done
}

if [ "${1:-}" = "vpn" ]; then
    shift
    init_files
    get_domain >/dev/null
    build_config
    handle_cmd "vpn $*"
else
    start_server
fi
