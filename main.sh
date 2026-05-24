#!/bin/bash
set +e

export PYTHONUNBUFFERED=1
export PYTHONIOENCODING=UTF-8

blank() {
    printf ' \n'
}

XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
DATA_DIR="."
USERS_FILE="$DATA_DIR/users.json"
DOMAIN_FILE="$DATA_DIR/domain.txt"
CONFIG_FILE="$DATA_DIR/config.json"
KEY_FILE="$DATA_DIR/key.txt"
ACTION_LOG_FILE="$DATA_DIR/logs.txt"
API_TOKEN_FILE="$DATA_DIR/api_token.txt"
API_PORT_FILE="$DATA_DIR/api_port.txt"
API_PID_FILE="$DATA_DIR/api.pid"
REALITY_PRIVATE_KEY_FILE="$DATA_DIR/reality_private_key.txt"
REALITY_PUBLIC_KEY_FILE="$DATA_DIR/reality_public_key.txt"
REALITY_SHORT_ID_FILE="$DATA_DIR/reality_short_id.txt"
REALITY_SNI_FILE="$DATA_DIR/reality_sni.txt"
REALITY_DEST_FILE="$DATA_DIR/reality_dest.txt"
REALITY_PORT_FILE="$DATA_DIR/reality_port.txt"
REALITY_PUBLIC_PORT_FILE="$DATA_DIR/reality_public_port.txt"
SUB_TOKEN_FILE="$DATA_DIR/sub_token.txt"
SUB_PORT_FILE="$DATA_DIR/sub_port.txt"
SUB_PID_FILE="$DATA_DIR/sub.pid"
XRAY_BIN="$DATA_DIR/xray"
XRAY_PID=""
API_PID=""
SUB_PID=""
USERS_STATE=""
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

    touch "$KEY_FILE" "$ACTION_LOG_FILE" >/dev/null 2>&1

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

    ensure_reality_files || return 1

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

    blank
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

get_reality_port() {
    if [ -n "${REALITY_PORT:-}" ]; then
        echo "$REALITY_PORT"
        return 0
    fi

    if [ -f "$REALITY_PORT_FILE" ] && [ -s "$REALITY_PORT_FILE" ]; then
        head -n 1 "$REALITY_PORT_FILE"
        return 0
    fi

    BASE_PORT="$(get_port)"
    if echo "$BASE_PORT" | grep -Eq '^[0-9]+$'; then
        NEXT_PORT=$((BASE_PORT + 1))
        if [ "$NEXT_PORT" -le 65535 ]; then
            echo "$NEXT_PORT"
            return 0
        fi
    fi

    echo "8443"
    return 0
}

get_public_reality_port() {
    if [ -n "${PUBLIC_REALITY_PORT:-}" ]; then
        echo "$PUBLIC_REALITY_PORT"
        return 0
    fi

    if [ -f "$REALITY_PUBLIC_PORT_FILE" ] && [ -s "$REALITY_PUBLIC_PORT_FILE" ]; then
        head -n 1 "$REALITY_PUBLIC_PORT_FILE"
        return 0
    fi

    get_reality_port
    return 0
}

get_reality_sni() {
    if [ -n "${REALITY_SNI:-}" ]; then
        echo "$REALITY_SNI"
        return 0
    fi

    if [ -f "$REALITY_SNI_FILE" ] && [ -s "$REALITY_SNI_FILE" ]; then
        head -n 1 "$REALITY_SNI_FILE"
        return 0
    fi

    echo "www.microsoft.com"
    return 0
}

get_reality_dest() {
    if [ -n "${REALITY_DEST:-}" ]; then
        echo "$REALITY_DEST"
        return 0
    fi

    if [ -f "$REALITY_DEST_FILE" ] && [ -s "$REALITY_DEST_FILE" ]; then
        head -n 1 "$REALITY_DEST_FILE"
        return 0
    fi

    echo "$(get_reality_sni):443"
    return 0
}

get_sub_port() {
    if [ -n "${SUB_PORT:-}" ]; then
        echo "$SUB_PORT"
        return 0
    fi

    if [ -f "$SUB_PORT_FILE" ] && [ -s "$SUB_PORT_FILE" ]; then
        head -n 1 "$SUB_PORT_FILE"
        return 0
    fi

    echo ""
    return 0
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

validate_port() {
    PORT_VALUE="$1"

    if ! echo "$PORT_VALUE" | grep -Eq '^[0-9]+$'; then
        return 1
    fi

    if [ "$PORT_VALUE" -lt 1 ] || [ "$PORT_VALUE" -gt 65535 ]; then
        return 1
    fi

    return 0
}

remember_users_state() {
    USERS_STATE="$(cat "$USERS_FILE" 2>/dev/null || echo "[]")"
    return 0
}

log_action() {
    ACTION="$1"
    DETAIL="$2"
    TS="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)"
    echo "$TS | $ACTION | $DETAIL" >> "$ACTION_LOG_FILE" 2>/dev/null
    return 0
}

get_api_token() {
    if [ -f "$API_TOKEN_FILE" ] && [ -s "$API_TOKEN_FILE" ]; then
        head -n 1 "$API_TOKEN_FILE"
        return 0
    fi

    TOKEN="$(make_uuid)$(make_uuid)"
    # ВАЖНО: `-` должен быть в КОНЦЕ списка, иначе GNU tr примет его за флаг
    # и упадёт с "tr: invalid option -- '['" — токен станет пустым,
    # и в файле окажется обычный unix timestamp вместо нормального ключа.
    TOKEN="$(printf '%s' "$TOKEN" | tr -d '[:space:]-')"

    if [ -z "$TOKEN" ]; then
        TOKEN="$(date +%s)"
    fi

    echo "$TOKEN" > "$API_TOKEN_FILE"
    chmod 600 "$API_TOKEN_FILE" >/dev/null 2>&1
    echo "$TOKEN"
    return 0
}

get_sub_token() {
    if [ -f "$SUB_TOKEN_FILE" ] && [ -s "$SUB_TOKEN_FILE" ]; then
        head -n 1 "$SUB_TOKEN_FILE"
        return 0
    fi

    TOKEN="$(make_uuid)$(make_uuid)"
    TOKEN="$(printf '%s' "$TOKEN" | tr -d '[:space:]-')"

    if [ -z "$TOKEN" ]; then
        TOKEN="$(date +%s)"
    fi

    echo "$TOKEN" > "$SUB_TOKEN_FILE"
    chmod 600 "$SUB_TOKEN_FILE" >/dev/null 2>&1
    echo "$TOKEN"
    return 0
}

make_short_id() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 8 2>/dev/null
        return 0
    fi

    python3 - <<'PY'
import secrets
print(secrets.token_hex(8))
PY
}

ensure_reality_files() {
    if [ ! -f "$REALITY_SNI_FILE" ] || [ ! -s "$REALITY_SNI_FILE" ]; then
        echo "$(get_reality_sni)" > "$REALITY_SNI_FILE"
    fi

    if [ ! -f "$REALITY_DEST_FILE" ] || [ ! -s "$REALITY_DEST_FILE" ]; then
        echo "$(get_reality_dest)" > "$REALITY_DEST_FILE"
    fi

    if [ ! -f "$REALITY_PORT_FILE" ] || [ ! -s "$REALITY_PORT_FILE" ]; then
        echo "$(get_reality_port)" > "$REALITY_PORT_FILE"
    fi

    if [ ! -f "$REALITY_PUBLIC_PORT_FILE" ] || [ ! -s "$REALITY_PUBLIC_PORT_FILE" ]; then
        echo "$(get_public_reality_port)" > "$REALITY_PUBLIC_PORT_FILE"
    fi

    if [ ! -f "$REALITY_SHORT_ID_FILE" ] || [ ! -s "$REALITY_SHORT_ID_FILE" ]; then
        SHORT_ID="$(make_short_id | head -n 1 | tr -d '[:space:]')"
        if [ -z "$SHORT_ID" ]; then
            echo "cannot generate reality short id"
            return 1
        fi
        echo "$SHORT_ID" > "$REALITY_SHORT_ID_FILE"
    fi

    if [ -f "$REALITY_PRIVATE_KEY_FILE" ] && [ -s "$REALITY_PRIVATE_KEY_FILE" ] && [ -f "$REALITY_PUBLIC_KEY_FILE" ] && [ -s "$REALITY_PUBLIC_KEY_FILE" ]; then
        return 0
    fi

    if [ ! -x "$XRAY_BIN" ]; then
        echo "xray binary is required to generate reality keys"
        return 1
    fi

    KEYS_OUTPUT="$("$XRAY_BIN" x25519 2>/dev/null)"
    # Старый формат: "Private key:" / "Public key:"
    # Новый формат (xray v25.3.6+): "PrivateKey:" / "Password:" (Password = публичный ключ)
    # см. XTLS/Xray-core#5159, #5160
    # Поддерживаем форматы:
    #   "Private key: ..." / "Public key: ..."           (старый)
    #   "PrivateKey: ..."  / "Password: ..."              (v25.3.6+)
    #   "PrivateKey: ..."  / "Password (PublicKey): ..."  (после PR XTLS/Xray-core#5759)
    PRIVATE_KEY="$(echo "$KEYS_OUTPUT" | sed -n -E 's/^[[:space:]]*Private[[:space:]]*[Kk]ey[[:space:]]*:[[:space:]]*//p' | head -n 1 | tr -d '[:space:]')"
    PUBLIC_KEY="$(echo "$KEYS_OUTPUT" | sed -n -E 's/^[[:space:]]*Public[[:space:]]*[Kk]ey[[:space:]]*:[[:space:]]*//p' | head -n 1 | tr -d '[:space:]')"
    if [ -z "$PUBLIC_KEY" ]; then
        # ловим "Password:" и "Password (PublicKey):" и т.п.
        PUBLIC_KEY="$(echo "$KEYS_OUTPUT" | sed -n -E 's/^[[:space:]]*Password[^:]*:[[:space:]]*//p' | head -n 1 | tr -d '[:space:]')"
    fi

    if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
        echo "cannot generate reality x25519 keys"
        echo "xray x25519 output was:"
        echo "$KEYS_OUTPUT"
        return 1
    fi

    echo "$PRIVATE_KEY" > "$REALITY_PRIVATE_KEY_FILE"
    echo "$PUBLIC_KEY" > "$REALITY_PUBLIC_KEY_FILE"
    chmod 600 "$REALITY_PRIVATE_KEY_FILE" "$REALITY_PUBLIC_KEY_FILE" >/dev/null 2>&1
    return 0
}

read_reality_private_key() {
    if [ -f "$REALITY_PRIVATE_KEY_FILE" ]; then
        head -n 1 "$REALITY_PRIVATE_KEY_FILE"
    fi
}

read_reality_public_key() {
    if [ -f "$REALITY_PUBLIC_KEY_FILE" ]; then
        head -n 1 "$REALITY_PUBLIC_KEY_FILE"
    fi
}

read_reality_short_id() {
    if [ -f "$REALITY_SHORT_ID_FILE" ]; then
        head -n 1 "$REALITY_SHORT_ID_FILE"
    fi
}

make_subscription_url() {
    NAME="$1"
    SUB_PORT_VALUE="$(get_sub_port)"

    if [ -z "$SUB_PORT_VALUE" ]; then
        return 1
    fi

    if ! validate_port "$SUB_PORT_VALUE"; then
        return 1
    fi

    PUBLIC_DOMAIN="$(read_domain)"
    TOKEN="$(get_sub_token)"
    echo "http://$PUBLIC_DOMAIN:$SUB_PORT_VALUE/sub/$NAME?token=$TOKEN"
    return 0
}

sync_keys_file() {
    PUBLIC_DOMAIN="$(read_domain)"
    WS_PUBLIC_PORT_VALUE="$(get_public_port)"
    REALITY_PUBLIC_PORT_VALUE="$(get_public_reality_port)"
    REALITY_SNI_VALUE="$(get_reality_sni)"
    REALITY_PUBLIC_KEY_VALUE="$(read_reality_public_key)"
    REALITY_SHORT_ID_VALUE="$(read_reality_short_id)"
    SUB_PORT_VALUE="$(get_sub_port)"
    SUB_TOKEN_VALUE=""

    if [ -n "$SUB_PORT_VALUE" ] && validate_port "$SUB_PORT_VALUE"; then
        SUB_TOKEN_VALUE="$(get_sub_token)"
    fi

    python3 - "$USERS_FILE" "$KEY_FILE" "$PUBLIC_DOMAIN" "$WS_PUBLIC_PORT_VALUE" "$REALITY_PUBLIC_PORT_VALUE" "$REALITY_SNI_VALUE" "$REALITY_PUBLIC_KEY_VALUE" "$REALITY_SHORT_ID_VALUE" "$SUB_PORT_VALUE" "$SUB_TOKEN_VALUE" <<'PY'
import datetime
import json
import sys
import time
import urllib.parse

users_file = sys.argv[1]
key_file = sys.argv[2]
domain = sys.argv[3]
ws_port = sys.argv[4]
reality_port = sys.argv[5]
reality_sni = sys.argv[6]
reality_public_key = sys.argv[7]
reality_short_id = sys.argv[8]
sub_port = sys.argv[9]
sub_token = sys.argv[10]
now = int(time.time())

try:
    with open(users_file, "r", encoding="utf-8") as f:
        users = json.load(f)
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

lines = []
generated = datetime.datetime.fromtimestamp(now).strftime("%Y-%m-%d %H:%M:%S")
lines.append(f"generated_at: {generated}")
lines.append(f"domain: {domain}")
lines.append(f"ws_public_port: {ws_port}")
lines.append(f"reality_public_port: {reality_port}")
lines.append(f"reality_sni: {reality_sni}")
if sub_port and sub_token:
    lines.append(f"sub_public_port: {sub_port}")
lines.append(" ")

def ws_link(name, uuid):
    tag = urllib.parse.quote(f"{name}-ws", safe="")
    return f"vless://{uuid}@{domain}:{ws_port}?type=ws&security=tls&sni={domain}&host={domain}&path=%2Fxray&encryption=none#{tag}"

def reality_link(name, uuid):
    tag = urllib.parse.quote(f"{name}-reality", safe="")
    return (
        f"vless://{uuid}@{domain}:{reality_port}"
        f"?type=tcp&security=reality&pbk={reality_public_key}&fp=chrome"
        f"&sni={reality_sni}&sid={reality_short_id}&spx=%2F"
        f"&flow=xtls-rprx-vision&encryption=none#{tag}"
    )

def subscription_url(name):
    if not sub_port or not sub_token:
        return ""
    quoted_name = urllib.parse.quote(name, safe="")
    return f"http://{domain}:{sub_port}/sub/{quoted_name}?token={sub_token}"

active_count = 0
for u in users:
    try:
        name = str(u["name"])
        uuid = str(u["uuid"])
        exp = int(u["expires_at"])
    except Exception:
        continue

    if exp <= now or not uuid:
        continue

    left = max(0, exp - now)
    days_left = left // 86400
    hours_left = (left % 86400) // 3600
    date = datetime.datetime.fromtimestamp(exp).strftime("%Y-%m-%d %H:%M")

    active_count += 1
    lines.append(f"{name} | uuid: {uuid} | expires: {date} | left: {days_left}d {hours_left}h")
    lines.append("ws:")
    lines.append(ws_link(name, uuid))
    lines.append("reality:")
    lines.append(reality_link(name, uuid))
    sub = subscription_url(name)
    if sub:
        lines.append("subscription:")
        lines.append(sub)
    lines.append(" ")

if active_count == 0:
    lines.append("no users")

with open(key_file, "w", encoding="utf-8") as f:
    f.write("\n".join(lines).rstrip() + "\n")
PY

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
    REALITY_LOCAL_PORT="$(get_reality_port)"
    REALITY_SNI_VALUE="$(get_reality_sni)"
    REALITY_DEST_VALUE="$(get_reality_dest)"

    prune_expired >/dev/null 2>&1
    ensure_reality_files || return 1

    REALITY_PRIVATE_KEY_VALUE="$(read_reality_private_key)"
    REALITY_SHORT_ID_VALUE="$(read_reality_short_id)"

    if [ "$LOCAL_PORT" = "$REALITY_LOCAL_PORT" ]; then
        echo "ws port and reality port must be different"
        return 1
    fi

    python3 - "$USERS_FILE" "$CONFIG_FILE" "$LOCAL_PORT" "$REALITY_LOCAL_PORT" "$REALITY_SNI_VALUE" "$REALITY_DEST_VALUE" "$REALITY_PRIVATE_KEY_VALUE" "$REALITY_SHORT_ID_VALUE" <<'PY'
import json, sys

users_file = sys.argv[1]
config_file = sys.argv[2]

try:
    port = int(sys.argv[3])
except Exception:
    port = 25565

try:
    reality_port = int(sys.argv[4])
except Exception:
    reality_port = 8443

reality_sni = sys.argv[5]
reality_dest = sys.argv[6]
reality_private_key = sys.argv[7]
reality_short_id = sys.argv[8]

try:
    with open(users_file, "r", encoding="utf-8") as f:
        users = json.load(f)
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

clients = []
reality_clients = []

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
    reality_clients.append({
        "id": uuid,
        "email": name + "-reality",
        "flow": "xtls-rprx-vision"
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
        },
        {
            "port": reality_port,
            "listen": "0.0.0.0",
            "protocol": "vless",
            "settings": {
                "clients": reality_clients,
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": False,
                    "dest": reality_dest,
                    "xver": 0,
                    "serverNames": [
                        reality_sni
                    ],
                    "privateKey": reality_private_key,
                    "shortIds": [
                        reality_short_id
                    ]
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
    WS_PUBLIC_PORT_VALUE="$(get_public_port)"
    REALITY_PUBLIC_PORT_VALUE="$(get_public_reality_port)"
    REALITY_SNI_VALUE="$(get_reality_sni)"
    REALITY_PUBLIC_KEY_VALUE="$(read_reality_public_key)"
    REALITY_SHORT_ID_VALUE="$(read_reality_short_id)"
    SUB_URL_VALUE="$(make_subscription_url "$NAME" 2>/dev/null || true)"

    python3 - "$USERS_FILE" "$NAME" "$PUBLIC_DOMAIN" "$WS_PUBLIC_PORT_VALUE" "$REALITY_PUBLIC_PORT_VALUE" "$REALITY_SNI_VALUE" "$REALITY_PUBLIC_KEY_VALUE" "$REALITY_SHORT_ID_VALUE" "$SUB_URL_VALUE" <<'PY'
import json, sys
import urllib.parse

users_file = sys.argv[1]
name = sys.argv[2]
domain = sys.argv[3]
ws_port = sys.argv[4]
reality_port = sys.argv[5]
reality_sni = sys.argv[6]
reality_public_key = sys.argv[7]
reality_short_id = sys.argv[8]
sub_url = sys.argv[9]

try:
    with open(users_file, "r", encoding="utf-8") as f:
        users = json.load(f)
except Exception:
    users = []

for u in users:
    if u.get("name") == name:
        uuid = u.get("uuid")
        ws_tag = urllib.parse.quote(f"{name}-ws", safe="")
        reality_tag = urllib.parse.quote(f"{name}-reality", safe="")
        ws_link = f"vless://{uuid}@{domain}:{ws_port}?type=ws&security=tls&sni={domain}&host={domain}&path=%2Fxray&encryption=none#{ws_tag}"
        reality_link = (
            f"vless://{uuid}@{domain}:{reality_port}"
            f"?type=tcp&security=reality&pbk={reality_public_key}&fp=chrome"
            f"&sni={reality_sni}&sid={reality_short_id}&spx=%2F"
            f"&flow=xtls-rprx-vision&encryption=none#{reality_tag}"
        )
        print("ws:")
        print(ws_link)
        print("reality:")
        print(reality_link)
        if sub_url:
            print("subscription:")
            print(sub_url)
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
    echo "vpn info NAME              show user info"
    echo "vpn link NAME              show user link"
    echo "vpn keys                   show all keys and recent logs"
    echo "vpn logs [COUNT]           show action logs"
    echo "vpn renew NAME DAYS        extend user by DAYS"
    echo "vpn domain DOMAIN          set public domain"
    echo "vpn reality PORT [SNI]     set Reality port and SNI mask"
    echo "vpn api PORT               start API on 0.0.0.0:PORT"
    echo "vpn api stop               stop API"
    echo "vpn api status             show API status"
    echo "vpn api token              show API token"
    echo "vpn sub PORT               start subscription on 0.0.0.0:PORT"
    echo "vpn sub stop/status/token  manage subscription server"
    echo "vpn restart                restart xray"
    echo "vpn stop                   stop server"
    print_line
    echo "examples:"
    echo "vpn add test 30"
    echo "vpn link test"
    echo "vpn renew test 15"
    echo "vpn del test"
    echo "vpn domain vpn.example.com"
    echo "vpn reality 8443 www.microsoft.com"
    echo "vpn api 25626"
    echo "vpn sub 25627"
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
    sync_keys_file >/dev/null 2>&1
    remember_users_state
    log_action "client_create" "$NAME days=$DAYS"

    echo "link:"
    make_link "$NAME"
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
        sync_keys_file >/dev/null 2>&1
        remember_users_state
        log_action "client_delete" "$NAME"
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

cmd_info() {
    NAME="$1"

    if ! validate_name "$NAME"; then
        echo "usage: vpn info NAME"
        return 0
    fi

    prune_expired >/dev/null 2>&1

    python3 - "$USERS_FILE" "$NAME" <<'PY'
import datetime
import json
import sys
import time

path = sys.argv[1]
name = sys.argv[2]
now = int(time.time())

try:
    with open(path, "r", encoding="utf-8") as f:
        users = json.load(f)
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

for u in users:
    if u.get("name") == name:
        exp = int(u.get("expires_at", 0))
        left = max(0, exp - now)
        days_left = left // 86400
        hours_left = (left % 86400) // 3600
        date = datetime.datetime.fromtimestamp(exp).strftime("%Y-%m-%d %H:%M")
        print(f"name: {u.get('name')}")
        print(f"uuid: {u.get('uuid')}")
        print(f"created_at: {datetime.datetime.fromtimestamp(int(u.get('created_at', 0))).strftime('%Y-%m-%d %H:%M')}")
        print(f"expires: {date}")
        print(f"left: {days_left}d {hours_left}h")
        sys.exit(0)

print("user not found")
sys.exit(1)
PY

    if [ "$?" -eq 0 ]; then
        echo "link:"
        make_link "$NAME"
    fi

    return 0
}

cmd_keys() {
    prune_expired >/dev/null 2>&1
    sync_keys_file >/dev/null 2>&1

    if [ -f "$KEY_FILE" ]; then
        cat "$KEY_FILE"
    else
        echo "no keys"
    fi

    if [ -f "$ACTION_LOG_FILE" ] && [ -s "$ACTION_LOG_FILE" ]; then
        print_line
        echo "recent logs:"
        tail -n 20 "$ACTION_LOG_FILE"
    fi

    return 0
}

cmd_logs() {
    COUNT="${1:-50}"

    if ! echo "$COUNT" | grep -Eq '^[0-9]+$'; then
        COUNT=50
    fi

    if [ -f "$ACTION_LOG_FILE" ] && [ -s "$ACTION_LOG_FILE" ]; then
        tail -n "$COUNT" "$ACTION_LOG_FILE"
    else
        echo "no logs"
    fi

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
        sync_keys_file >/dev/null 2>&1
        remember_users_state
        log_action "client_renew" "$NAME days=$DAYS"
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

    sync_keys_file >/dev/null 2>&1

    log_action "domain_set" "$NEW_DOMAIN"

    return 0
}

cmd_reality() {
    ACTION="${1:-}"

    case "$ACTION" in
        status|"")
            ensure_reality_files >/dev/null 2>&1
            print_line
            echo "Reality settings"
            print_line
            echo "local port: $(get_reality_port)"
            echo "public port: $(get_public_reality_port)"
            echo "sni: $(get_reality_sni)"
            echo "dest: $(get_reality_dest)"
            echo "public key: $(read_reality_public_key)"
            echo "short id: $(read_reality_short_id)"
            print_line
            ;;
        *)
            if ! validate_port "$ACTION"; then
                echo "usage: vpn reality PORT [PUBLIC_PORT] [SNI] [DEST]"
                echo "example: vpn reality 8443 8443 www.microsoft.com"
                return 0
            fi

            LOCAL_REALITY_PORT="$ACTION"
            PUBLIC_REALITY_PORT_VALUE="$LOCAL_REALITY_PORT"
            REALITY_SNI_VALUE="${2:-}"
            REALITY_DEST_VALUE="${3:-}"

            if validate_port "${2:-}"; then
                PUBLIC_REALITY_PORT_VALUE="$2"
                REALITY_SNI_VALUE="${3:-}"
                REALITY_DEST_VALUE="${4:-}"
            fi

            if [ -z "$REALITY_SNI_VALUE" ]; then
                REALITY_SNI_VALUE="$(get_reality_sni)"
            fi

            if [ -z "$REALITY_DEST_VALUE" ]; then
                REALITY_DEST_VALUE="$REALITY_SNI_VALUE:443"
            fi

            echo "$LOCAL_REALITY_PORT" > "$REALITY_PORT_FILE"
            echo "$PUBLIC_REALITY_PORT_VALUE" > "$REALITY_PUBLIC_PORT_FILE"
            echo "$REALITY_SNI_VALUE" > "$REALITY_SNI_FILE"
            echo "$REALITY_DEST_VALUE" > "$REALITY_DEST_FILE"

            ensure_reality_files >/dev/null 2>&1
            restart_xray >/dev/null 2>&1
            sync_keys_file >/dev/null 2>&1
            remember_users_state
            if sub_is_running; then
                restart_sub_if_running
            else
                restart_api_if_running
            fi
            log_action "reality_set" "port=$LOCAL_REALITY_PORT public=$PUBLIC_REALITY_PORT_VALUE sni=$REALITY_SNI_VALUE dest=$REALITY_DEST_VALUE"

            echo "reality saved"
            echo "local port: $LOCAL_REALITY_PORT"
            echo "public port: $PUBLIC_REALITY_PORT_VALUE"
            echo "sni: $REALITY_SNI_VALUE"
            echo "dest: $REALITY_DEST_VALUE"
            ;;
    esac

    return 0
}

api_is_running() {
    PID="${API_PID:-}"

    if [ -z "$PID" ] && [ -f "$API_PID_FILE" ]; then
        PID="$(cat "$API_PID_FILE" 2>/dev/null)"
    fi

    if [ -n "$PID" ] && kill -0 "$PID" >/dev/null 2>&1; then
        API_PID="$PID"
        return 0
    fi

    return 1
}

stop_api_process() {
    KEEP_PORT="${1:-}"
    PID="${API_PID:-}"

    if [ -z "$PID" ] && [ -f "$API_PID_FILE" ]; then
        PID="$(cat "$API_PID_FILE" 2>/dev/null)"
    fi

    if [ -n "$PID" ] && kill -0 "$PID" >/dev/null 2>&1; then
        kill "$PID" >/dev/null 2>&1
        wait "$PID" 2>/dev/null
        log_action "api_stop" "pid=$PID"
    fi

    API_PID=""
    rm -f "$API_PID_FILE" >/dev/null 2>&1
    if [ "$KEEP_PORT" != "keep" ]; then
        rm -f "$API_PORT_FILE" >/dev/null 2>&1
    fi
    return 0
}

start_api_process() {
    PORT_VALUE="$1"

    if ! validate_port "$PORT_VALUE"; then
        echo "usage: vpn api PORT"
        echo "port must be 1-65535"
        return 0
    fi

    if api_is_running; then
        RUNNING_PORT="$(cat "$API_PORT_FILE" 2>/dev/null)"
        echo "api already running: 0.0.0.0:${RUNNING_PORT:-unknown}"
        echo "token: $(get_api_token)"
        return 0
    fi

    TOKEN="$(get_api_token)"
    LOCAL_PORT="$(get_port)"
    PUBLIC_PORT_VALUE="$(get_public_port)"
    ensure_reality_files >/dev/null 2>&1
    REALITY_LOCAL_PORT_VALUE="$(get_reality_port)"
    REALITY_PUBLIC_PORT_VALUE="$(get_public_reality_port)"
    REALITY_SNI_VALUE="$(get_reality_sni)"
    REALITY_DEST_VALUE="$(get_reality_dest)"
    REALITY_PRIVATE_KEY_VALUE="$(read_reality_private_key)"
    REALITY_PUBLIC_KEY_VALUE="$(read_reality_public_key)"
    REALITY_SHORT_ID_VALUE="$(read_reality_short_id)"
    SUB_PORT_VALUE="$(get_sub_port)"
    SUB_TOKEN_VALUE=""

    if [ -n "$SUB_PORT_VALUE" ] && validate_port "$SUB_PORT_VALUE"; then
        SUB_TOKEN_VALUE="$(get_sub_token)"
    fi

    python3 -u - "$USERS_FILE" "$KEY_FILE" "$CONFIG_FILE" "$DOMAIN_FILE" "$API_TOKEN_FILE" "$ACTION_LOG_FILE" "$PORT_VALUE" "$LOCAL_PORT" "$PUBLIC_PORT_VALUE" "$REALITY_LOCAL_PORT_VALUE" "$REALITY_PUBLIC_PORT_VALUE" "$REALITY_SNI_VALUE" "$REALITY_DEST_VALUE" "$REALITY_PRIVATE_KEY_VALUE" "$REALITY_PUBLIC_KEY_VALUE" "$REALITY_SHORT_ID_VALUE" "$SUB_PORT_VALUE" "$SUB_TOKEN_VALUE" <<'PY' &
import datetime
import json
import os
import re
import sys
import time
import urllib.parse
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

USERS_FILE = sys.argv[1]
KEY_FILE = sys.argv[2]
CONFIG_FILE = sys.argv[3]
DOMAIN_FILE = sys.argv[4]
TOKEN_FILE = sys.argv[5]
ACTION_LOG_FILE = sys.argv[6]
API_PORT = int(sys.argv[7])
XRAY_PORT = int(sys.argv[8])
PUBLIC_PORT = sys.argv[9]
REALITY_PORT = int(sys.argv[10])
PUBLIC_REALITY_PORT = sys.argv[11]
REALITY_SNI = sys.argv[12]
REALITY_DEST = sys.argv[13]
REALITY_PRIVATE_KEY = sys.argv[14]
REALITY_PUBLIC_KEY = sys.argv[15]
REALITY_SHORT_ID = sys.argv[16]
SUB_PORT = sys.argv[17]
SUB_TOKEN = sys.argv[18]

NAME_RE = re.compile(r"^[A-Za-z0-9._-]+$")


def now_ts():
    return int(time.time())


def read_token():
    try:
        with open(TOKEN_FILE, "r", encoding="utf-8") as f:
            return f.readline().strip()
    except Exception:
        return ""


API_TOKEN = read_token()
if not API_TOKEN:
    raise SystemExit("api token is empty")


def read_domain():
    try:
        with open(DOMAIN_FILE, "r", encoding="utf-8") as f:
            value = f.read().strip()
            return value or "localhost"
    except Exception:
        return "localhost"


def atomic_json(path, data):
    tmp = f"{path}.tmp.{os.getpid()}"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def atomic_text(path, text):
    tmp = f"{path}.tmp.{os.getpid()}"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def load_users(prune=True):
    try:
        with open(USERS_FILE, "r", encoding="utf-8") as f:
            users = json.load(f)
        if not isinstance(users, list):
            users = []
    except Exception:
        users = []

    clean = []
    changed = False
    current = now_ts()

    for item in users:
        if not isinstance(item, dict):
            changed = True
            continue

        try:
            name = str(item.get("name", ""))
            client_id = str(item.get("uuid", ""))
            expires_at = int(item.get("expires_at", 0))
        except Exception:
            changed = True
            continue

        if not name or not client_id:
            changed = True
            continue

        if prune and expires_at <= current:
            changed = True
            continue

        clean.append(item)

    if prune and changed:
        atomic_json(USERS_FILE, clean)
        write_keys(clean)
        write_config(clean)
        log_action("prune_expired", "api removed expired users")

    return clean


def save_users(users):
    atomic_json(USERS_FILE, users)
    write_keys(users)
    write_config(users)


def make_ws_link(user):
    name = str(user.get("name", ""))
    client_id = str(user.get("uuid", ""))
    domain = read_domain()
    tag = urllib.parse.quote(f"{name}-ws", safe="")
    return (
        f"vless://{client_id}@{domain}:{PUBLIC_PORT}"
        f"?type=ws&security=tls&sni={domain}&host={domain}&path=%2Fxray&encryption=none#{tag}"
    )


def make_reality_link(user):
    name = str(user.get("name", ""))
    client_id = str(user.get("uuid", ""))
    domain = read_domain()
    tag = urllib.parse.quote(f"{name}-reality", safe="")
    return (
        f"vless://{client_id}@{domain}:{PUBLIC_REALITY_PORT}"
        f"?type=tcp&security=reality&pbk={REALITY_PUBLIC_KEY}&fp=chrome"
        f"&sni={REALITY_SNI}&sid={REALITY_SHORT_ID}&spx=%2F"
        f"&flow=xtls-rprx-vision&encryption=none#{tag}"
    )


def make_links(user):
    return {
        "ws": make_ws_link(user),
        "reality": make_reality_link(user),
    }


def make_subscription_url(user):
    if not SUB_PORT or not SUB_TOKEN:
        return ""
    name = urllib.parse.quote(str(user.get("name", "")), safe="")
    return f"http://{read_domain()}:{SUB_PORT}/sub/{name}?token={SUB_TOKEN}"


def client_payload(user):
    current = now_ts()
    expires_at = int(user.get("expires_at", 0))
    left = max(0, expires_at - current)
    links = make_links(user)
    subscription_url = make_subscription_url(user)
    return {
        "name": user.get("name"),
        "uuid": user.get("uuid"),
        "created_at": int(user.get("created_at", 0)),
        "expires_at": expires_at,
        "left_seconds": left,
        "left_days": left // 86400,
        "link": links["ws"],
        "links": links,
        "subscription_url": subscription_url,
    }


def write_config(users):
    clients = []
    reality_clients = []
    for user in users:
        try:
            clients.append({"id": str(user["uuid"]), "email": str(user["name"])})
            reality_clients.append({
                "id": str(user["uuid"]),
                "email": f"{user['name']}-reality",
                "flow": "xtls-rprx-vision",
            })
        except Exception:
            pass

    config = {
        "log": {"loglevel": "warning"},
        "inbounds": [
            {
                "port": XRAY_PORT,
                "listen": "0.0.0.0",
                "protocol": "vless",
                "settings": {"clients": clients, "decryption": "none"},
                "streamSettings": {"network": "ws", "wsSettings": {"path": "/xray"}},
            },
            {
                "port": REALITY_PORT,
                "listen": "0.0.0.0",
                "protocol": "vless",
                "settings": {"clients": reality_clients, "decryption": "none"},
                "streamSettings": {
                    "network": "tcp",
                    "security": "reality",
                    "realitySettings": {
                        "show": False,
                        "dest": REALITY_DEST,
                        "xver": 0,
                        "serverNames": [REALITY_SNI],
                        "privateKey": REALITY_PRIVATE_KEY,
                        "shortIds": [REALITY_SHORT_ID],
                    },
                },
            }
        ],
        "outbounds": [{"protocol": "freedom"}],
    }
    atomic_json(CONFIG_FILE, config)


def write_keys(users):
    current = now_ts()
    generated = datetime.datetime.fromtimestamp(current).strftime("%Y-%m-%d %H:%M:%S")
    lines = [
        f"generated_at: {generated}",
        f"domain: {read_domain()}",
        f"ws_public_port: {PUBLIC_PORT}",
        f"reality_public_port: {PUBLIC_REALITY_PORT}",
        f"reality_sni: {REALITY_SNI}",
        " ",
    ]

    if SUB_PORT and SUB_TOKEN:
        lines.insert(4, f"sub_public_port: {SUB_PORT}")

    active_count = 0
    for user in users:
        try:
            expires_at = int(user["expires_at"])
            if expires_at <= current:
                continue
            left = max(0, expires_at - current)
            date = datetime.datetime.fromtimestamp(expires_at).strftime("%Y-%m-%d %H:%M")
            active_count += 1
            lines.append(
                f"{user['name']} | uuid: {user['uuid']} | expires: {date} | "
                f"left: {left // 86400}d {(left % 86400) // 3600}h"
            )
            lines.append("ws:")
            lines.append(make_ws_link(user))
            lines.append("reality:")
            lines.append(make_reality_link(user))
            sub_url = make_subscription_url(user)
            if sub_url:
                lines.append("subscription:")
                lines.append(sub_url)
            lines.append(" ")
        except Exception:
            pass

    if active_count == 0:
        lines.append("no users")

    atomic_text(KEY_FILE, "\n".join(lines).rstrip() + "\n")


def log_action(action, detail):
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        with open(ACTION_LOG_FILE, "a", encoding="utf-8") as f:
            f.write(f"{stamp} | {action} | {detail}\n")
    except Exception:
        pass


def validate_name(name):
    return bool(name and NAME_RE.match(str(name)))


def parse_int(value, default=None):
    try:
        return int(str(value))
    except Exception:
        return default


def first_value(mapping, *names):
    for name in names:
        if name in mapping:
            value = mapping[name]
            if isinstance(value, list):
                return value[0] if value else ""
            return value
    return ""


class Handler(BaseHTTPRequestHandler):
    server_version = "H1CloudVPNAPI/1.0"

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "authorization,x-api-key,content-type")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
        super().end_headers()

    def log_message(self, fmt, *args):
        try:
            log_action("http", f"{self.client_address[0]} {fmt % args}")
        except Exception:
            pass

    def send_json(self, status, data):
        body = json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_text(self, status, text):
        body = text.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        self.route("GET")

    def do_POST(self):
        self.route("POST")

    def do_PUT(self):
        self.route("PUT")

    def do_PATCH(self):
        self.route("PATCH")

    def do_DELETE(self):
        self.route("DELETE")

    def read_body(self):
        length = parse_int(self.headers.get("Content-Length", "0"), 0) or 0
        if length <= 0:
            return {}

        raw = self.rfile.read(length)
        ctype = self.headers.get("Content-Type", "")

        if "application/json" in ctype:
            try:
                data = json.loads(raw.decode("utf-8"))
                return data if isinstance(data, dict) else {}
            except Exception:
                return {}

        parsed = urllib.parse.parse_qs(raw.decode("utf-8", "ignore"))
        return {key: values[0] if values else "" for key, values in parsed.items()}

    def authorized(self, params):
        header = self.headers.get("Authorization", "")
        api_key = self.headers.get("X-API-Key", "")
        query_token = first_value(params, "token")

        if header == f"Bearer {API_TOKEN}":
            return True
        if api_key == API_TOKEN:
            return True
        if query_token == API_TOKEN:
            return True
        return False

    def route(self, method):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path.strip("/")
        parts = [urllib.parse.unquote(p) for p in path.split("/") if p]
        params = urllib.parse.parse_qs(parsed.query)

        if parts and parts[0] == "api":
            parts = parts[1:]
            path = "/".join(parts)

        if method == "GET" and path in ("", "health"):
            payload = {
                "ok": True,
                "service": "vpn-api",
                "api_port": API_PORT,
                "endpoints": [
                    "GET /clients",
                    "GET /info?name=NAME",
                    "POST /create",
                    "PATCH /edit",
                    "DELETE /clients/NAME",
                    "GET /keys",
                    "GET /logs",
                ],
                "auth": "Authorization: Bearer TOKEN or X-API-Key: TOKEN",
            }
            self.send_json(200, payload)
            return

        if not self.authorized(params):
            self.send_json(401, {"ok": False, "error": "unauthorized"})
            return

        body = self.read_body() if method in ("POST", "PUT", "PATCH", "DELETE") else {}
        merged = {}
        for key, values in params.items():
            merged[key] = values[0] if values else ""
        merged.update(body)

        try:
            self.dispatch(method, parts, path, merged)
        except Exception as exc:
            log_action("api_error", repr(exc))
            self.send_json(500, {"ok": False, "error": "internal_error"})

    def dispatch(self, method, parts, path, data):
        users = load_users(prune=True)

        if method == "GET" and parts and parts[0] in ("clients", "users") and len(parts) == 1:
            self.send_json(200, {"ok": True, "clients": [client_payload(u) for u in users]})
            return

        if method == "GET" and parts and parts[0] in ("keys",):
            write_keys(users)
            self.send_json(200, {"ok": True, "clients": [client_payload(u) for u in users]})
            return

        if method == "GET" and path == "key.txt":
            write_keys(users)
            try:
                with open(KEY_FILE, "r", encoding="utf-8") as f:
                    text = f.read()
            except Exception:
                text = "no keys\n"
            self.send_text(200, text)
            return

        if method == "GET" and parts and parts[0] == "logs":
            count = parse_int(first_value(data, "count"), 100) or 100
            count = max(1, min(count, 1000))
            try:
                with open(ACTION_LOG_FILE, "r", encoding="utf-8") as f:
                    lines = f.readlines()[-count:]
            except Exception:
                lines = []
            self.send_json(200, {"ok": True, "logs": [line.rstrip("\n") for line in lines]})
            return

        if method == "GET" and (
            (parts and parts[0] == "info")
            or (parts and parts[0] in ("clients", "users") and len(parts) == 2)
        ):
            name = parts[1] if len(parts) == 2 and parts[0] in ("clients", "users") else first_value(data, "name")
            for user in users:
                if user.get("name") == name:
                    self.send_json(200, {"ok": True, "client": client_payload(user)})
                    return
            self.send_json(404, {"ok": False, "error": "user_not_found"})
            return

        if method == "POST" and ((parts and parts[0] == "create") or (parts and parts[0] in ("clients", "users") and len(parts) == 1)):
            self.create_client(users, data)
            return

        if method in ("PUT", "PATCH", "POST") and (
            (parts and parts[0] == "edit")
            or (parts and parts[0] in ("clients", "users") and len(parts) == 2)
        ):
            name = parts[1] if len(parts) == 2 and parts[0] in ("clients", "users") else first_value(data, "name")
            self.edit_client(users, name, data)
            return

        if method in ("DELETE", "POST") and (
            (parts and parts[0] == "delete")
            or (parts and parts[0] in ("clients", "users") and len(parts) == 2)
        ):
            name = parts[1] if len(parts) == 2 and parts[0] in ("clients", "users") else first_value(data, "name")
            self.delete_client(users, name)
            return

        self.send_json(404, {"ok": False, "error": "not_found"})

    def create_client(self, users, data):
        name = str(first_value(data, "name")).strip()
        days = parse_int(first_value(data, "days"), None)

        if not validate_name(name):
            self.send_json(400, {"ok": False, "error": "bad_name"})
            return
        if days is None or days <= 0:
            self.send_json(400, {"ok": False, "error": "bad_days"})
            return
        if any(user.get("name") == name for user in users):
            self.send_json(409, {"ok": False, "error": "user_already_exists"})
            return

        current = now_ts()
        user = {
            "name": name,
            "uuid": str(uuid.uuid4()),
            "created_at": current,
            "expires_at": current + days * 86400,
        }
        users.append(user)
        save_users(users)
        log_action("api_client_create", f"{name} days={days}")
        self.send_json(201, {"ok": True, "client": client_payload(user)})

    def edit_client(self, users, name, data):
        if not validate_name(name):
            self.send_json(400, {"ok": False, "error": "bad_name"})
            return

        target = None
        for user in users:
            if user.get("name") == name:
                target = user
                break

        if target is None:
            self.send_json(404, {"ok": False, "error": "user_not_found"})
            return

        changed = []
        new_name = str(first_value(data, "new_name")).strip()
        if new_name:
            if not validate_name(new_name):
                self.send_json(400, {"ok": False, "error": "bad_new_name"})
                return
            if any(user.get("name") == new_name and user is not target for user in users):
                self.send_json(409, {"ok": False, "error": "user_already_exists"})
                return
            target["name"] = new_name
            changed.append(f"name={new_name}")

        days = parse_int(first_value(data, "days"), None)
        if days is not None:
            if days <= 0:
                self.send_json(400, {"ok": False, "error": "bad_days"})
                return
            base = max(now_ts(), int(target.get("expires_at", now_ts())))
            target["expires_at"] = base + days * 86400
            changed.append(f"days=+{days}")

        set_days = parse_int(first_value(data, "set_days"), None)
        if set_days is not None:
            if set_days <= 0:
                self.send_json(400, {"ok": False, "error": "bad_set_days"})
                return
            target["expires_at"] = now_ts() + set_days * 86400
            changed.append(f"set_days={set_days}")

        expires_at = parse_int(first_value(data, "expires_at"), None)
        if expires_at is not None:
            if expires_at <= now_ts():
                self.send_json(400, {"ok": False, "error": "bad_expires_at"})
                return
            target["expires_at"] = expires_at
            changed.append(f"expires_at={expires_at}")

        if not changed:
            self.send_json(400, {"ok": False, "error": "nothing_to_edit"})
            return

        save_users(users)
        log_action("api_client_edit", f"{name} {' '.join(changed)}")
        self.send_json(200, {"ok": True, "client": client_payload(target)})

    def delete_client(self, users, name):
        if not validate_name(name):
            self.send_json(400, {"ok": False, "error": "bad_name"})
            return

        new_users = [user for user in users if user.get("name") != name]
        if len(new_users) == len(users):
            self.send_json(404, {"ok": False, "error": "user_not_found"})
            return

        save_users(new_users)
        log_action("api_client_delete", name)
        self.send_json(200, {"ok": True, "deleted": name})


class ReuseServer(ThreadingHTTPServer):
    allow_reuse_address = True

    def server_bind(self):
        import socket
        try:
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        except (AttributeError, OSError):
            pass
        super().server_bind()


log_action("api_start", f"0.0.0.0:{API_PORT}")
try:
    server = ReuseServer(("0.0.0.0", API_PORT), Handler)
except OSError as exc:
    if exc.errno == 98:
        sys.stderr.write(
            f"port {API_PORT} is already in use.\n"
            "on Pterodactyl: используй порт, который реально выделен этому серверу\n"
            "(Configuration -> Allocations в панели). docker-proxy от wings уже сидит\n"
            "на не-выделенных портах внутри netns, поэтому bind() падает.\n"
        )
    else:
        sys.stderr.write(f"api bind failed on port {API_PORT}: {exc}\n")
    sys.exit(1)
server.serve_forever()
PY

    API_PID="$!"
    echo "$API_PID" > "$API_PID_FILE"
    echo "$PORT_VALUE" > "$API_PORT_FILE"

    sleep 1

    if kill -0 "$API_PID" >/dev/null 2>&1; then
        echo "api started: 0.0.0.0:$PORT_VALUE"
        echo "url: http://$(read_domain):$PORT_VALUE"
        echo "token: $TOKEN"
        echo "auth: Authorization: Bearer $TOKEN"
        log_action "api_start" "0.0.0.0:$PORT_VALUE pid=$API_PID"
        return 0
    fi

    echo "api failed to start"
    rm -f "$API_PID_FILE" "$API_PORT_FILE" >/dev/null 2>&1
    API_PID=""
    return 0
}

cmd_api() {
    ACTION="${1:-}"

    if validate_port "$ACTION"; then
        start_api_process "$ACTION"
        return 0
    fi

    case "$ACTION" in
        start|run)
            start_api_process "${2:-}"
            ;;
        stop)
            stop_api_process
            echo "api stopped"
            ;;
        restart)
            PORT_VALUE="${2:-}"
            if [ -z "$PORT_VALUE" ] && [ -f "$API_PORT_FILE" ]; then
                PORT_VALUE="$(cat "$API_PORT_FILE" 2>/dev/null)"
            fi
            stop_api_process keep
            start_api_process "$PORT_VALUE"
            ;;
        status)
            if api_is_running; then
                RUNNING_PORT="$(cat "$API_PORT_FILE" 2>/dev/null)"
                echo "api running: 0.0.0.0:${RUNNING_PORT:-unknown}"
                echo "pid: $API_PID"
            else
                echo "api stopped"
            fi
            ;;
        token)
            echo "$(get_api_token)"
            ;;
        create)
            cmd_add "${2:-}" "${3:-}"
            ;;
        info)
            cmd_info "${2:-}"
            ;;
        edit|renew)
            cmd_renew "${2:-}" "${3:-}"
            ;;
        delete|del|remove)
            cmd_del "${2:-}"
            ;;
        help|"")
            print_line
            echo "VPN API commands"
            print_line
            echo "vpn api PORT                 start API on 0.0.0.0:PORT"
            echo "vpn api start PORT           start API"
            echo "vpn api stop                 stop API"
            echo "vpn api restart [PORT]       restart API"
            echo "vpn api status               show status"
            echo "vpn api token                show token"
            print_line
            echo "HTTP examples:"
            echo "GET    /clients"
            echo "GET    /info?name=NAME"
            echo "POST   /create {\"name\":\"test\",\"days\":30}"
            echo "PATCH  /edit {\"name\":\"test\",\"days\":15}"
            echo "DELETE /clients/test"
            echo "GET    /keys"
            echo "GET    /logs"
            echo "auth header: Authorization: Bearer TOKEN"
            print_line
            ;;
        *)
            echo "unknown api command: $ACTION"
            echo "type: vpn api help"
            ;;
    esac

    return 0
}

sub_is_running() {
    PID="${SUB_PID:-}"

    if [ -z "$PID" ] && [ -f "$SUB_PID_FILE" ]; then
        PID="$(cat "$SUB_PID_FILE" 2>/dev/null)"
    fi

    if [ -n "$PID" ] && kill -0 "$PID" >/dev/null 2>&1; then
        SUB_PID="$PID"
        return 0
    fi

    return 1
}

stop_sub_process() {
    KEEP_PORT="${1:-}"
    PID="${SUB_PID:-}"

    if [ -z "$PID" ] && [ -f "$SUB_PID_FILE" ]; then
        PID="$(cat "$SUB_PID_FILE" 2>/dev/null)"
    fi

    if [ -n "$PID" ] && kill -0 "$PID" >/dev/null 2>&1; then
        kill "$PID" >/dev/null 2>&1
        wait "$PID" 2>/dev/null
        log_action "sub_stop" "pid=$PID"
    fi

    SUB_PID=""
    rm -f "$SUB_PID_FILE" >/dev/null 2>&1
    if [ "$KEEP_PORT" != "keep" ]; then
        rm -f "$SUB_PORT_FILE" >/dev/null 2>&1
    fi
    return 0
}

start_sub_process() {
    PORT_VALUE="$1"

    if ! validate_port "$PORT_VALUE"; then
        echo "usage: vpn sub PORT"
        echo "port must be 1-65535"
        return 0
    fi

    if sub_is_running; then
        RUNNING_PORT="$(cat "$SUB_PORT_FILE" 2>/dev/null)"
        echo "subscription already running: 0.0.0.0:${RUNNING_PORT:-unknown}"
        echo "token: $(get_sub_token)"
        return 0
    fi

    ensure_reality_files >/dev/null 2>&1
    TOKEN="$(get_sub_token)"
    WS_PUBLIC_PORT_VALUE="$(get_public_port)"
    echo "$PORT_VALUE" > "$SUB_PORT_FILE"

    python3 -u - "$USERS_FILE" "$DOMAIN_FILE" "$REALITY_PUBLIC_KEY_FILE" "$REALITY_SHORT_ID_FILE" "$REALITY_SNI_FILE" "$REALITY_PUBLIC_PORT_FILE" "$SUB_TOKEN_FILE" "$PORT_VALUE" "$WS_PUBLIC_PORT_VALUE" <<'PY' &
import base64
import datetime
import json
import sys
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

USERS_FILE = sys.argv[1]
DOMAIN_FILE = sys.argv[2]
REALITY_PUBLIC_KEY_FILE = sys.argv[3]
REALITY_SHORT_ID_FILE = sys.argv[4]
REALITY_SNI_FILE = sys.argv[5]
REALITY_PUBLIC_PORT_FILE = sys.argv[6]
SUB_TOKEN_FILE = sys.argv[7]
SUB_PORT = int(sys.argv[8])
WS_PUBLIC_PORT = sys.argv[9]


def read_first(path, default=""):
    try:
        with open(path, "r", encoding="utf-8") as f:
            value = f.readline().strip()
            return value or default
    except Exception:
        return default


def read_domain():
    return read_first(DOMAIN_FILE, "localhost")


def read_token():
    return read_first(SUB_TOKEN_FILE, "")


def load_users():
    try:
        with open(USERS_FILE, "r", encoding="utf-8") as f:
            users = json.load(f)
        if not isinstance(users, list):
            return []
        return users
    except Exception:
        return []


def find_user(name):
    now = int(time.time())
    for user in load_users():
        try:
            if user.get("name") == name and int(user.get("expires_at", 0)) > now:
                return user
        except Exception:
            pass
    return None


def make_links(user):
    name = str(user.get("name", ""))
    client_id = str(user.get("uuid", ""))
    domain = read_domain()
    reality_public_key = read_first(REALITY_PUBLIC_KEY_FILE)
    reality_short_id = read_first(REALITY_SHORT_ID_FILE)
    reality_sni = read_first(REALITY_SNI_FILE, "www.microsoft.com")
    reality_public_port = read_first(REALITY_PUBLIC_PORT_FILE, "8443")
    ws_tag = urllib.parse.quote(f"{name}-ws", safe="")
    reality_tag = urllib.parse.quote(f"{name}-reality", safe="")

    ws = (
        f"vless://{client_id}@{domain}:{WS_PUBLIC_PORT}"
        f"?type=ws&security=tls&sni={domain}&host={domain}&path=%2Fxray&encryption=none#{ws_tag}"
    )
    reality = (
        f"vless://{client_id}@{domain}:{reality_public_port}"
        f"?type=tcp&security=reality&pbk={reality_public_key}&fp=chrome"
        f"&sni={reality_sni}&sid={reality_short_id}&spx=%2F"
        f"&flow=xtls-rprx-vision&encryption=none#{reality_tag}"
    )
    return [ws, reality]


class Handler(BaseHTTPRequestHandler):
    server_version = "H1CloudVPNSub/1.0"

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "authorization,content-type")
        self.send_header("Access-Control-Allow-Methods", "GET,OPTIONS")
        super().end_headers()

    def log_message(self, fmt, *args):
        return

    def send_text(self, status, text, content_type="text/plain; charset=utf-8"):
        body = text.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_json(self, status, data):
        self.send_text(status, json.dumps(data, ensure_ascii=False, indent=2), "application/json; charset=utf-8")

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        parts = [urllib.parse.unquote(p) for p in parsed.path.strip("/").split("/") if p]
        params = urllib.parse.parse_qs(parsed.query)

        if not parts or parts[0] == "health":
            self.send_json(200, {"ok": True, "service": "vpn-sub", "port": SUB_PORT})
            return

        token = ""
        auth = self.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            token = auth.split(" ", 1)[1].strip()
        if not token:
            token = params.get("token", [""])[0]

        if token != read_token():
            self.send_json(401, {"ok": False, "error": "unauthorized"})
            return

        if parts[0] == "sub":
            if len(parts) < 2:
                self.send_json(400, {"ok": False, "error": "name_required"})
                return
            name = parts[1]
            mode = parts[2] if len(parts) > 2 else "base64"
        else:
            name = parts[0]
            mode = parts[1] if len(parts) > 1 else "base64"

        user = find_user(name)
        if not user:
            self.send_json(404, {"ok": False, "error": "user_not_found"})
            return

        links = make_links(user)
        raw = "\n".join(links) + "\n"

        if mode == "raw":
            self.send_text(200, raw)
            return

        if mode == "json":
            expires_at = int(user.get("expires_at", 0))
            self.send_json(200, {
                "ok": True,
                "name": user.get("name"),
                "expires_at": expires_at,
                "expires": datetime.datetime.fromtimestamp(expires_at).strftime("%Y-%m-%d %H:%M"),
                "links": {"ws": links[0], "reality": links[1]},
            })
            return

        encoded = base64.b64encode(raw.encode("utf-8")).decode("ascii")
        self.send_text(200, encoded + "\n")


class ReuseServer(ThreadingHTTPServer):
    allow_reuse_address = True

    def server_bind(self):
        import socket
        try:
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        except (AttributeError, OSError):
            pass
        super().server_bind()


try:
    server = ReuseServer(("0.0.0.0", SUB_PORT), Handler)
except OSError as exc:
    if exc.errno == 98:
        sys.stderr.write(
            f"port {SUB_PORT} is already in use.\n"
            "on Pterodactyl используй только порт, который выделен серверу в панели.\n"
        )
    else:
        sys.stderr.write(f"sub bind failed on port {SUB_PORT}: {exc}\n")
    sys.exit(1)
server.serve_forever()
PY

    SUB_PID="$!"
    echo "$SUB_PID" > "$SUB_PID_FILE"

    sleep 1

    if kill -0 "$SUB_PID" >/dev/null 2>&1; then
        echo "subscription started: 0.0.0.0:$PORT_VALUE"
        echo "token: $TOKEN"
        echo "url example: http://$(read_domain):$PORT_VALUE/sub/NAME?token=$TOKEN"
        log_action "sub_start" "0.0.0.0:$PORT_VALUE pid=$SUB_PID"
        sync_keys_file >/dev/null 2>&1
        restart_api_if_running
        return 0
    fi

    echo "subscription failed to start"
    rm -f "$SUB_PID_FILE" "$SUB_PORT_FILE" >/dev/null 2>&1
    SUB_PID=""
    return 0
}

cmd_sub() {
    ACTION="${1:-}"

    if validate_port "$ACTION"; then
        start_sub_process "$ACTION"
        return 0
    fi

    case "$ACTION" in
        start|run)
            start_sub_process "${2:-}"
            ;;
        stop)
            stop_sub_process
            sync_keys_file >/dev/null 2>&1
            restart_api_if_running
            echo "subscription stopped"
            ;;
        restart)
            PORT_VALUE="${2:-}"
            if [ -z "$PORT_VALUE" ] && [ -f "$SUB_PORT_FILE" ]; then
                PORT_VALUE="$(cat "$SUB_PORT_FILE" 2>/dev/null)"
            fi
            stop_sub_process keep
            start_sub_process "$PORT_VALUE"
            ;;
        status)
            if sub_is_running; then
                RUNNING_PORT="$(cat "$SUB_PORT_FILE" 2>/dev/null)"
                echo "subscription running: 0.0.0.0:${RUNNING_PORT:-unknown}"
                echo "pid: $SUB_PID"
                echo "url example: http://$(read_domain):${RUNNING_PORT:-PORT}/sub/NAME?token=$(get_sub_token)"
            else
                echo "subscription stopped"
            fi
            ;;
        token)
            echo "$(get_sub_token)"
            ;;
        url)
            NAME="${2:-}"
            if ! validate_name "$NAME"; then
                echo "usage: vpn sub url NAME"
                return 0
            fi
            make_subscription_url "$NAME" || echo "subscription is not configured"
            ;;
        help|"")
            print_line
            echo "VPN subscription commands"
            print_line
            echo "vpn sub PORT            start subscription on 0.0.0.0:PORT"
            echo "vpn sub stop            stop subscription server"
            echo "vpn sub restart [PORT]  restart subscription server"
            echo "vpn sub status          show status"
            echo "vpn sub token           show subscription token"
            echo "vpn sub url NAME        show subscription URL"
            print_line
            echo "subscription URL: http://DOMAIN:PORT/sub/NAME?token=TOKEN"
            echo "raw links:        http://DOMAIN:PORT/sub/NAME/raw?token=TOKEN"
            echo "json:             http://DOMAIN:PORT/sub/NAME/json?token=TOKEN"
            print_line
            ;;
        *)
            echo "unknown sub command: $ACTION"
            echo "type: vpn sub help"
            ;;
    esac

    return 0
}

sync_external_user_changes() {
    CURRENT_USERS_STATE="$(cat "$USERS_FILE" 2>/dev/null || echo "[]")"

    if [ -z "$USERS_STATE" ]; then
        USERS_STATE="$CURRENT_USERS_STATE"
        return 0
    fi

    if [ "$CURRENT_USERS_STATE" != "$USERS_STATE" ]; then
        restart_xray >/dev/null 2>&1
        sync_keys_file >/dev/null 2>&1
        USERS_STATE="$(cat "$USERS_FILE" 2>/dev/null || echo "[]")"
        echo "users synced from api"
    fi

    return 0
}

keep_api_alive() {
    if [ -n "$API_PID" ] && ! kill -0 "$API_PID" >/dev/null 2>&1; then
        PORT_VALUE="$(cat "$API_PORT_FILE" 2>/dev/null)"
        API_PID=""
        if validate_port "$PORT_VALUE"; then
            echo "api stopped, trying to restart..."
            start_api_process "$PORT_VALUE" >/dev/null 2>&1
        fi
    fi

    return 0
}

keep_sub_alive() {
    if [ -n "$SUB_PID" ] && ! kill -0 "$SUB_PID" >/dev/null 2>&1; then
        PORT_VALUE="$(cat "$SUB_PORT_FILE" 2>/dev/null)"
        SUB_PID=""
        if validate_port "$PORT_VALUE"; then
            echo "subscription stopped, trying to restart..."
            start_sub_process "$PORT_VALUE" >/dev/null 2>&1
        fi
    fi

    return 0
}

restart_api_if_running() {
    if api_is_running; then
        PORT_VALUE="$(cat "$API_PORT_FILE" 2>/dev/null)"
        stop_api_process keep
        if validate_port "$PORT_VALUE"; then
            start_api_process "$PORT_VALUE" >/dev/null 2>&1
        fi
    fi
    return 0
}

restart_sub_if_running() {
    if sub_is_running; then
        PORT_VALUE="$(cat "$SUB_PORT_FILE" 2>/dev/null)"
        stop_sub_process keep
        if validate_port "$PORT_VALUE"; then
            start_sub_process "$PORT_VALUE" >/dev/null 2>&1
        fi
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
        info)
            cmd_info "${2:-}"
            ;;
        link)
            make_link "${2:-}" || true
            ;;
        keys)
            cmd_keys
            ;;
        logs)
            cmd_logs "${2:-}"
            ;;
        renew)
            cmd_renew "${2:-}" "${3:-}"
            ;;
        domain)
            cmd_domain "${2:-}"
            ;;
        reality)
            cmd_reality "${2:-}" "${3:-}" "${4:-}" "${5:-}"
            ;;
        api)
            cmd_api "${2:-}" "${3:-}" "${4:-}"
            ;;
        sub|subscription)
            cmd_sub "${2:-}" "${3:-}" "${4:-}"
            ;;
        restart)
            restart_xray || true
            ;;
        stop|exit|quit)
            echo "stopping..."
            stop_api_process keep
            stop_sub_process keep
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
        sync_keys_file >/dev/null 2>&1
        remember_users_state
        log_action "expired_cleanup" "users pruned"
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
    stop_api_process keep
    stop_sub_process keep
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

    sync_keys_file >/dev/null 2>&1
    remember_users_state

    print_line
    echo "h1cloud vless is ready"
    echo "local port: $(get_port)"
    echo "domain: $(read_domain)"
    echo "public port: $(get_public_port)"
    echo "reality local port: $(get_reality_port)"
    echo "reality public port: $(get_public_reality_port)"
    echo "reality sni: $(get_reality_sni)"
    echo "type: vpn help"
    print_line
    blank
    echo "https://h1cloud.su - лучший хостинг"
    echo "https://t.me/h1cloudbot"
    echo "Программист - https://h1guro.ovh"
    print_line

    start_xray_process
    if [ "$?" -ne 0 ]; then
        echo "xray start failed, console will stay alive"
    fi

    if [ -f "$API_PORT_FILE" ]; then
        SAVED_API_PORT="$(cat "$API_PORT_FILE" 2>/dev/null)"
        if validate_port "$SAVED_API_PORT"; then
            start_api_process "$SAVED_API_PORT" >/dev/null 2>&1
        fi
    fi

    if [ -f "$SUB_PORT_FILE" ]; then
        SAVED_SUB_PORT="$(cat "$SUB_PORT_FILE" 2>/dev/null)"
        if validate_port "$SAVED_SUB_PORT"; then
            start_sub_process "$SAVED_SUB_PORT" >/dev/null 2>&1
        fi
    fi

    LAST_CHECK=0

    while true; do
        sync_external_user_changes

        if IFS= read -r -t 5 LINE; then
            handle_cmd "$LINE"
        fi

        sync_external_user_changes

        NOW="$(date +%s)"
        if [ $((NOW - LAST_CHECK)) -ge "$CHECK_INTERVAL" ]; then
            check_expired_loop_tick
            LAST_CHECK="$NOW"
        fi

        keep_xray_alive
        keep_api_alive
        keep_sub_alive
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
    sync_keys_file >/dev/null 2>&1
    remember_users_state
    handle_cmd "vpn $*"
    exit 0
else
    start_server
fi
