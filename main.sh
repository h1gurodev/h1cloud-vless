#!/bin/bash
set +e

XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
DATA_DIR="."
USERS_FILE="$DATA_DIR/users.json"
DOMAIN_FILE="$DATA_DIR/domain.txt"
CONFIG_FILE="$DATA_DIR/config.json"
KEY_FILE="$DATA_DIR/key.txt"
XRAY_BIN="$DATA_DIR/xray"
XRAY_PID=""
CHECK_INTERVAL=300

print_line() {
    echo "========================================"
}

need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "$1 is required"
        return 1
    fi
    return 0
}

init_files() {
    need_cmd curl || return 1
    need_cmd python3 || return 1

    if [ ! -f "$USERS_FILE" ]; then
        echo "[]" > "$USERS_FILE"
    fi

    python3 - "$USERS_FILE" <<'PY' >/dev/null 2>&1
import json, sys
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise ValueError("users.json is not list")
except Exception:
    with open(path + ".bad", "w", encoding="utf-8") as f:
        f.write("broken users.json backup\n")
    with open(path, "w", encoding="utf-8") as f:
        json.dump([], f)
PY

    if [ ! -f "$XRAY_BIN" ]; then
        echo "downloading xray..."

        curl -fL -o xray.zip "$XRAY_URL"
        if [ "$?" -ne 0 ]; then
            echo "xray download failed"
            rm -f xray.zip
            return 1
        fi

        if command -v unzip >/dev/null 2>&1; then
            unzip -o -q xray.zip
            UNZIP_STATUS="$?"
        else
            python3 -m zipfile -e xray.zip .
            UNZIP_STATUS="$?"
        fi

        rm -f xray.zip

        if [ "$UNZIP_STATUS" -ne 0 ]; then
            echo "xray extract failed"
            return 1
        fi

        chmod +x "$XRAY_BIN"

        if [ ! -f "$XRAY_BIN" ]; then
            echo "xray binary not found after extract"
            return 1
        fi
    fi

    return 0
}

ensure_domain() {
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
        return 0
    fi

    if [ -n "${DOMAIN:-}" ]; then
        echo "$DOMAIN" > "$DOMAIN_FILE"
        return 0
    fi

    echo ""
    echo "Enter domain connected in Pterodactyl Domains:"
    read -r INPUT_DOMAIN

    if [ -z "$INPUT_DOMAIN" ]; then
        echo "domain is empty"
        return 1
    fi

    echo "$INPUT_DOMAIN" > "$DOMAIN_FILE"
    return 0
}

read_domain() {
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
        cat "$DOMAIN_FILE"
        return 0
    fi

    if [ -n "${DOMAIN:-}" ]; then
        echo "$DOMAIN"
        return 0
    fi

    echo "localhost"
    return 0
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
        python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null
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

validate_days() {
    DAYS="$1"

    if ! echo "$DAYS" | grep -Eq '^[0-9]+$'; then
        return 1
    fi

    if [ "$DAYS" -le 0 ]; then
        return 1
    fi

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
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

active = []
removed = []

for u in users:
    try:
        exp = int(u.get("expires_at", 0))
        name = str(u.get("name", "unknown"))
        uuid = str(u.get("uuid", ""))
    except Exception:
        continue

    if exp > now and uuid:
        active.append(u)
    else:
        removed.append(name)

with open(path, "w", encoding="utf-8") as f:
    json.dump(active, f, ensure_ascii=False, indent=2)

if removed:
    print("expired users removed: " + ", ".join(removed))
PY
    return 0
}

build_config() {
    LOCAL_PORT="$(get_port)"

    prune_expired >/dev/null 2>&1

    python3 - "$USERS_FILE" "$CONFIG_FILE" "$LOCAL_PORT" <<'PY'
import json, sys

users_file = sys.argv[1]
config_file = sys.argv[2]

try:
    port = int(sys.argv[3])
except Exception:
    port = 25565

try:
    with open(users_file, "r", encoding="utf-8") as f:
        users = json.load(f)
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

clients = []

for u in users:
    try:
        uuid = str(u["uuid"])
        name = str(u["name"])
    except Exception:
        continue

    clients.append({
        "id": uuid,
        "email": name
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

    if [ "$?" -ne 0 ]; then
        echo "config build failed"
        return 1
    fi

    return 0
}

make_link() {
    NAME="$1"

    if ! validate_name "$NAME"; then
        echo "bad user name. use only: a-z A-Z 0-9 . _ -"
        return 1
    fi

    PUBLIC_DOMAIN="$(read_domain)"
    PUBLIC_PORT_VALUE="$(get_public_port)"

    python3 - "$USERS_FILE" "$NAME" "$PUBLIC_DOMAIN" "$PUBLIC_PORT_VALUE" <<'PY'
import json, sys

users_file = sys.argv[1]
name = sys.argv[2]
domain = sys.argv[3]
port = sys.argv[4]

try:
    with open(users_file, "r", encoding="utf-8") as f:
        users = json.load(f)
except Exception:
    users = []

for u in users:
    if u.get("name") == name:
        uuid = u.get("uuid")
        print(f"vless://{uuid}@{domain}:{port}?type=ws&security=tls&sni={domain}&host={domain}&path=%2Fxray&encryption=none#{name}")
        sys.exit(0)

print("user not found")
sys.exit(1)
PY

    return $?
}

start_xray_process() {
    if [ ! -x "$XRAY_BIN" ]; then
        echo "xray binary is missing"
        return 1
    fi

    "$XRAY_BIN" run -config "$CONFIG_FILE" &
    XRAY_PID="$!"

    sleep 1

    if kill -0 "$XRAY_PID" >/dev/null 2>&1; then
        return 0
    fi

    echo "xray failed to start"
    XRAY_PID=""
    return 1
}

stop_xray_process() {
    if [ -n "$XRAY_PID" ] && kill -0 "$XRAY_PID" >/dev/null 2>&1; then
        kill "$XRAY_PID" >/dev/null 2>&1
        wait "$XRAY_PID" 2>/dev/null
    fi

    XRAY_PID=""
    return 0
}

restart_xray() {
    build_config
    if [ "$?" -ne 0 ]; then
        echo "restart skipped because config build failed"
        return 1
    fi

    stop_xray_process
    start_xray_process

    if [ "$?" -eq 0 ]; then
        echo "xray restarted"
        return 0
    fi

    echo "xray restart failed, console is still alive"
    return 1
}

cmd_help() {
    print_line
    echo "H1CLOUD VLESS commands"
    print_line
    echo "vpn help                  show commands"
    echo "vpn add NAME DAYS          add user for DAYS"
    echo "vpn del NAME               delete user"
    echo "vpn list                   show users"
    echo "vpn link NAME              show user link"
    echo "vpn renew NAME DAYS        extend user by DAYS"
    echo "vpn domain DOMAIN          set public domain"
    echo "vpn restart                restart xray"
    echo "vpn stop                   stop server"
    print_line
    echo "examples:"
    echo "vpn add test 30"
    echo "vpn link test"
    echo "vpn renew test 15"
    echo "vpn del test"
    echo "vpn domain vpn.example.com"
    print_line
}

cmd_add() {
    NAME="$1"
    DAYS="$2"

    if ! validate_name "$NAME"; then
        echo "bad user name. use only: a-z A-Z 0-9 . _ -"
        echo "usage: vpn add NAME DAYS"
        return 0
    fi

    if ! validate_days "$DAYS"; then
        echo "days must be number bigger than 0"
        echo "usage: vpn add NAME DAYS"
        return 0
    fi

    UUID="$(make_uuid)"

    if [ -z "$UUID" ]; then
        echo "cannot generate uuid"
        return 0
    fi

    python3 - "$USERS_FILE" "$NAME" "$DAYS" "$UUID" <<'PY'
import json, sys, time

path = sys.argv[1]
name = sys.argv[2]
days = int(sys.argv[3])
uuid = sys.argv[4]

try:
    with open(path, "r", encoding="utf-8") as f:
        users = json.load(f)
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

for u in users:
    if u.get("name") == name:
        print("user already exists")
        sys.exit(2)

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

    RC="$?"

    if [ "$RC" -ne 0 ]; then
        return 0
    fi

    restart_xray >/dev/null 2>&1

    echo "link:"
    make_link "$NAME"
    make_link "$NAME" > "$KEY_FILE" 2>/dev/null
    return 0
}

cmd_del() {
    NAME="$1"

    if ! validate_name "$NAME"; then
        echo "usage: vpn del NAME"
        return 0
    fi

    python3 - "$USERS_FILE" "$NAME" <<'PY'
import json, sys

path = sys.argv[1]
name = sys.argv[2]

try:
    with open(path, "r", encoding="utf-8") as f:
        users = json.load(f)
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

new_users = [u for u in users if u.get("name") != name]

if len(new_users) == len(users):
    print("user not found")
    sys.exit(2)

with open(path, "w", encoding="utf-8") as f:
    json.dump(new_users, f, ensure_ascii=False, indent=2)

print("user deleted")
PY

    RC="$?"

    if [ "$RC" -eq 0 ]; then
        restart_xray >/dev/null 2>&1
    fi

    return 0
}

cmd_list() {
    prune_expired >/dev/null 2>&1

    python3 - "$USERS_FILE" <<'PY'
import json, sys, time, datetime

path = sys.argv[1]
now = int(time.time())

try:
    with open(path, "r", encoding="utf-8") as f:
        users = json.load(f)
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

if not users:
    print("no users")
    sys.exit(0)

for u in users:
    try:
        exp = int(u["expires_at"])
        seconds_left = max(0, exp - now)
        days_left = seconds_left // 86400
        hours_left = (seconds_left % 86400) // 3600
        date = datetime.datetime.fromtimestamp(exp).strftime("%Y-%m-%d %H:%M")
        print(f"{u['name']} | uuid: {u['uuid']} | expires: {date} | left: {days_left}d {hours_left}h")
    except Exception:
        pass
PY

    return 0
}

cmd_renew() {
    NAME="$1"
    DAYS="$2"

    if ! validate_name "$NAME"; then
        echo "usage: vpn renew NAME DAYS"
        return 0
    fi

    if ! validate_days "$DAYS"; then
        echo "days must be number bigger than 0"
        echo "usage: vpn renew NAME DAYS"
        return 0
    fi

    python3 - "$USERS_FILE" "$NAME" "$DAYS" <<'PY'
import json, sys, time

path = sys.argv[1]
name = sys.argv[2]
days = int(sys.argv[3])
now = int(time.time())

try:
    with open(path, "r", encoding="utf-8") as f:
        users = json.load(f)
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

found = False

for u in users:
    if u.get("name") == name:
        base = max(now, int(u.get("expires_at", now)))
        u["expires_at"] = base + days * 86400
        found = True

if not found:
    print("user not found")
    sys.exit(2)

with open(path, "w", encoding="utf-8") as f:
    json.dump(users, f, ensure_ascii=False, indent=2)

print("user renewed")
PY

    RC="$?"

    if [ "$RC" -eq 0 ]; then
        restart_xray >/dev/null 2>&1
    fi

    return 0
}

cmd_domain() {
    NEW_DOMAIN="$1"

    if [ -z "$NEW_DOMAIN" ]; then
        echo "usage: vpn domain DOMAIN"
        return 0
    fi

    echo "$NEW_DOMAIN" > "$DOMAIN_FILE"
    echo "domain saved: $NEW_DOMAIN"

    FIRST_USER="$(python3 - "$USERS_FILE" <<'PY'
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        users = json.load(f)
    print(users[0]["name"] if users else "")
except Exception:
    print("")
PY
)"

    if [ -n "$FIRST_USER" ]; then
        make_link "$FIRST_USER" > "$KEY_FILE" 2>/dev/null
    fi

    return 0
}

handle_cmd() {
    LINE="$1"

    if [ -z "$LINE" ]; then
        return 0
    fi

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
        list|users)
            cmd_list
            ;;
        link)
            make_link "${2:-}" || true
            ;;
        renew)
            cmd_renew "${2:-}" "${3:-}"
            ;;
        domain)
            cmd_domain "${2:-}"
            ;;
        restart)
            restart_xray || true
            ;;
        stop|exit|quit)
            echo "stopping..."
            stop_xray_process
            exit 0
            ;;
        *)
            echo "unknown command: ${1:-}"
            echo "type: vpn help"
            ;;
    esac

    return 0
}

check_expired_loop_tick() {
    BEFORE="$(cat "$USERS_FILE" 2>/dev/null || echo "[]")"
    prune_expired >/dev/null 2>&1
    AFTER="$(cat "$USERS_FILE" 2>/dev/null || echo "[]")"

    if [ "$BEFORE" != "$AFTER" ]; then
        restart_xray >/dev/null 2>&1
        echo "expired users cleaned"
    fi

    return 0
}

keep_xray_alive() {
    if [ -z "$XRAY_PID" ]; then
        echo "xray is not running, trying to start..."
        restart_xray >/dev/null 2>&1
        return 0
    fi

    if ! kill -0 "$XRAY_PID" >/dev/null 2>&1; then
        echo "xray stopped, trying to restart..."
        restart_xray >/dev/null 2>&1
    fi

    return 0
}

cleanup() {
    stop_xray_process
    exit 0
}

start_server() {
    init_files
    if [ "$?" -ne 0 ]; then
        echo "init failed, console will stay alive"
        while true; do
            sleep 60
        done
    fi

    ensure_domain
    if [ "$?" -ne 0 ]; then
        echo "domain setup failed, console will stay alive"
        while true; do
            sleep 60
        done
    fi

    build_config
    if [ "$?" -ne 0 ]; then
        echo "config build failed, console will stay alive"
        while true; do
            sleep 60
        done
    fi

    print_line
    echo "h1cloud vless is ready"
    echo "local port: $(get_port)"
    echo "domain: $(read_domain)"
    echo "public port: $(get_public_port)"
    echo "type: vpn help"
    print_line
    echo ""
    echo "h1cloud.su - лучший хостинг"
    echo "t.me/h1cloudbot"
    echo "Программист - h1guro.ovh"
    print_line

    start_xray_process
    if [ "$?" -ne 0 ]; then
        echo "xray start failed, console will stay alive"
    fi

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

        keep_xray_alive
    done
}

trap cleanup INT TERM

if [ "${1:-}" = "vpn" ]; then
    shift
    init_files
    if [ "$?" -ne 0 ]; then
        exit 0
    fi

    ensure_domain >/dev/null 2>&1
    build_config >/dev/null 2>&1
    handle_cmd "vpn $*"
    exit 0
else
    start_server
fi
