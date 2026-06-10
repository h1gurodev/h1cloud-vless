#!/bin/bash
set +e

export PYTHONUNBUFFERED=1
export PYTHONIOENCODING=UTF-8

SCRIPT_VERSION="2026.06.05-mws-xhttp"
DEFAULT_UPDATE_URL="https://raw.githubusercontent.com/h1gurodev/h1cloud-vless/refs/heads/main/main.sh"

blank() {
    printf ' \n'
}

XRAY_URL="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"
DATA_DIR="."
USERS_FILE="$DATA_DIR/users.json"
DEVICES_FILE="$DATA_DIR/devices.json"
TRAFFIC_FILE="$DATA_DIR/traffic.json"
DOMAIN_FILE="$DATA_DIR/domain.txt"
CONFIG_FILE="$DATA_DIR/config.json"
KEY_FILE="$DATA_DIR/key.txt"
NODE_NAME_FILE="$DATA_DIR/node_name.txt"
ACTION_LOG_FILE="$DATA_DIR/logs.txt"
API_TOKEN_FILE="$DATA_DIR/api_token.txt"
API_PORT_FILE="$DATA_DIR/api_port.txt"
API_PID_FILE="$DATA_DIR/api.pid"
REALITY_ENABLED_FILE="$DATA_DIR/reality_enabled.txt"
REALITY_PRIVATE_KEY_FILE="$DATA_DIR/reality_private_key.txt"
PUBLIC_IP_FILE="$DATA_DIR/public_ip.txt"
REALITY_PUBLIC_KEY_FILE="$DATA_DIR/reality_public_key.txt"
REALITY_SHORT_ID_FILE="$DATA_DIR/reality_short_id.txt"
REALITY_SNI_FILE="$DATA_DIR/reality_sni.txt"
REALITY_DEST_FILE="$DATA_DIR/reality_dest.txt"
REALITY_PORT_FILE="$DATA_DIR/reality_port.txt"
REALITY_PUBLIC_PORT_FILE="$DATA_DIR/reality_public_port.txt"
SUB_TOKEN_FILE="$DATA_DIR/sub_token.txt"
SUB_PORT_FILE="$DATA_DIR/sub_port.txt"
SUB_PID_FILE="$DATA_DIR/sub.pid"
SUB_NAME_FILE="$DATA_DIR/sub_name.txt"
TRANSPORT_FILE="$DATA_DIR/transport.txt"
XHTTP_PATH_FILE="$DATA_DIR/xhttp_path.txt"
XHTTP_METHOD_FILE="$DATA_DIR/xhttp_method.txt"
XHTTP_ALPN_FILE="$DATA_DIR/xhttp_alpn.txt"
MWS_ENABLED_FILE="$DATA_DIR/mws_enabled.txt"
MWS_DOMAIN_FILE="$DATA_DIR/mws_domain.txt"
MWS_CERT_FILE="$DATA_DIR/mws_cert_file.txt"
MWS_KEY_FILE="$DATA_DIR/mws_key_file.txt"
CDN_WS_ENABLED_FILE="$DATA_DIR/cdn_ws_enabled.txt"
CDN_WS_HOST_FILE="$DATA_DIR/cdn_ws_host.txt"
CDN_WS_SNI_FILE="$DATA_DIR/cdn_ws_sni.txt"
CDN_WS_PORT_FILE="$DATA_DIR/cdn_ws_port.txt"
CDN_WS_TAG_FILE="$DATA_DIR/cdn_ws_tag.txt"
CDN_WS_PATH_FILE="$DATA_DIR/cdn_ws_path.txt"
CDN_XHTTP_ENABLED_FILE="$DATA_DIR/cdn_xhttp_enabled.txt"
CDN_XHTTP_HOST_FILE="$DATA_DIR/cdn_xhttp_host.txt"
CDN_XHTTP_SNI_FILE="$DATA_DIR/cdn_xhttp_sni.txt"
CDN_XHTTP_PORT_FILE="$DATA_DIR/cdn_xhttp_port.txt"
CDN_XHTTP_TAG_FILE="$DATA_DIR/cdn_xhttp_tag.txt"
CDN_XHTTP_PUBLIC_PATH_FILE="$DATA_DIR/cdn_xhttp_public_path.txt"
TAG_WS_FILE="$DATA_DIR/tag_ws.txt"
TAG_XHTTP_FILE="$DATA_DIR/tag_xhttp.txt"
TAG_REALITY_FILE="$DATA_DIR/tag_reality.txt"
PEERS_FILE="$DATA_DIR/peers.txt"
NODES_FILE="$DATA_DIR/nodes.json"
JOIN_TOKEN_FILE="$DATA_DIR/join_token.txt"
UPSTREAM_API_URL_FILE="$DATA_DIR/upstream_api_url.txt"
UPSTREAM_API_TOKEN_FILE="$DATA_DIR/upstream_api_token.txt"
BACKUP_DIR="$DATA_DIR/backups"
UPDATE_URL_FILE="$DATA_DIR/update_url.txt"
AUTO_UPDATE_FILE="$DATA_DIR/auto_update.txt"
UPDATE_LAST_CHECK_FILE="$DATA_DIR/update_last_check.txt"
XRAY_BIN="$DATA_DIR/xray"
XRAY_STATS_PORT="${XRAY_STATS_PORT:-10085}"
XRAY_PID=""
API_PID=""
SUB_PID=""
USERS_STATE=""
CHECK_INTERVAL=300
LIMIT_CHECK_INTERVAL=60
FEDERATION_SYNC_INTERVAL=2
UPDATE_CHECK_INTERVAL=3600
LAST_UPDATE_CHECK=0
UPDATE_APPLIED=0
SERVER_MODE=0

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

    if [ ! -f "$NODES_FILE" ]; then
        echo "[]" > "$NODES_FILE"
    fi

    if [ ! -f "$DEVICES_FILE" ]; then
        echo "{}" > "$DEVICES_FILE"
    fi

    if [ ! -f "$TRAFFIC_FILE" ]; then
        echo "{}" > "$TRAFFIC_FILE"
    fi

    mkdir -p "$BACKUP_DIR" >/dev/null 2>&1

    if [ ! -f "$AUTO_UPDATE_FILE" ]; then
        echo "1" > "$AUTO_UPDATE_FILE"
    fi

    if [ ! -f "$TRANSPORT_FILE" ]; then
        echo "ws" > "$TRANSPORT_FILE"
    fi

    if [ ! -f "$XHTTP_PATH_FILE" ]; then
        echo "/api/v1/sync/" > "$XHTTP_PATH_FILE"
    fi

    if [ ! -f "$XHTTP_METHOD_FILE" ]; then
        echo "GET" > "$XHTTP_METHOD_FILE"
    fi

    if [ ! -f "$XHTTP_ALPN_FILE" ]; then
        echo "h2,http1" > "$XHTTP_ALPN_FILE"
    fi

    touch "$KEY_FILE" "$ACTION_LOG_FILE" >/dev/null 2>&1

    python3 - "$USERS_FILE" <<'PY' >/dev/null 2>&1
import json, sys, time
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        raw = f.read()
    data = json.loads(raw)
    if not isinstance(data, list):
        raise ValueError("users.json is not list")
except Exception:
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            raw = f.read()
    except Exception:
        raw = ""
    backup = f"{path}.bad.{int(time.time())}"
    with open(backup, "w", encoding="utf-8") as f:
        f.write(raw or "broken users.json backup\n")
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

    if is_reality_enabled; then
        ensure_reality_files || return 1
    fi

    return 0
}

normalize_domain() {
    DOMAIN_VALUE="$(printf '%s' "$1" | tr -d '[:space:]')"
    DOMAIN_VALUE="${DOMAIN_VALUE#http://}"
    DOMAIN_VALUE="${DOMAIN_VALUE#https://}"
    DOMAIN_VALUE="${DOMAIN_VALUE%%/*}"
    DOMAIN_VALUE="${DOMAIN_VALUE%%:*}"
    echo "$DOMAIN_VALUE"
}

ensure_domain() {
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
        return 0
    fi

    if [ -n "${DOMAIN:-}" ]; then
        INPUT_DOMAIN="$(normalize_domain "$DOMAIN")"
        if [ -z "$INPUT_DOMAIN" ]; then
            echo "domain is empty"
            return 1
        fi
        echo "$INPUT_DOMAIN" > "$DOMAIN_FILE"
        return 0
    fi

    blank
    echo "Enter domain connected in Pterodactyl Domains:"
    read -r INPUT_DOMAIN

    INPUT_DOMAIN="$(normalize_domain "$INPUT_DOMAIN")"

    if [ -z "$INPUT_DOMAIN" ]; then
        echo "domain is empty"
        return 1
    fi

    echo "$INPUT_DOMAIN" > "$DOMAIN_FILE"
    return 0
}

read_domain() {
    if [ -f "$DOMAIN_FILE" ] && [ -s "$DOMAIN_FILE" ]; then
        normalize_domain "$(head -n 1 "$DOMAIN_FILE")"
        return 0
    fi

    if [ -n "${DOMAIN:-}" ]; then
        normalize_domain "$DOMAIN"
        return 0
    fi

    echo "localhost"
    return 0
}

# Р’РѕР·РІСЂР°С‰Р°РµС‚ СЂРµР°Р»СЊРЅС‹Р№ IP СЃРµСЂРІРµСЂР° (Р° РЅРµ РґРѕРјРµРЅ Pterodactyl Domains).
# РќР° Pterodactyl env SERVER_IP РѕР±С‹С‡РЅРѕ СЃРѕРґРµСЂР¶РёС‚ IP Р°Р»Р»РѕРєР°С†РёРё вЂ” РЅРѕ СЌС‚Рѕ С‡Р°СЃС‚Рѕ
# 0.0.0.0 (РІРЅСѓС‚СЂРё РєРѕРЅС‚РµР№РЅРµСЂР°), РїРѕСЌС‚РѕРјСѓ РїСЂРѕР±СѓРµРј РїРѕ РѕС‡РµСЂРµРґРё:
#   1. env PUBLIC_IP / SERVER_IP (РµСЃР»Рё РѕРЅ РІР°Р»РёРґРЅС‹Р№, РЅРµ 0.0.0.0/127.x)
#   2. РєСЌС€ РІ public_ip.txt
#   3. curl РЅР° ifconfig.me / api.ipify.org (РѕРґРёРЅ СЂР°Р·, РїРѕС‚РѕРј СЃРѕС…СЂР°РЅРёС‚СЊ РІ РєСЌС€)
#   4. fallback вЂ” РґРѕРјРµРЅ РёР· domain.txt
read_public_ip() {
    local CANDIDATE=""

    if [ -n "${PUBLIC_IP:-}" ]; then
        CANDIDATE="$PUBLIC_IP"
    elif [ -n "${SERVER_IP:-}" ]; then
        CANDIDATE="$SERVER_IP"
    fi

    case "$CANDIDATE" in
        ""|0.0.0.0|127.*|::|::1) CANDIDATE="" ;;
    esac

    if [ -n "$CANDIDATE" ]; then
        echo "$CANDIDATE"
        return 0
    fi

    if [ -f "$PUBLIC_IP_FILE" ] && [ -s "$PUBLIC_IP_FILE" ]; then
        head -n 1 "$PUBLIC_IP_FILE"
        return 0
    fi

    for URL in "https://api.ipify.org" "https://ifconfig.me/ip" "https://ipv4.icanhazip.com"; do
        CANDIDATE="$(curl -fsS --max-time 4 "$URL" 2>/dev/null | tr -d '[:space:]')"
        if [ -n "$CANDIDATE" ]; then
            echo "$CANDIDATE" > "$PUBLIC_IP_FILE"
            echo "$CANDIDATE"
            return 0
        fi
    done

    DOMAIN_VALUE="$(read_domain)"
    if command -v getent >/dev/null 2>&1; then
        CANDIDATE="$(getent ahostsv4 "$DOMAIN_VALUE" 2>/dev/null | awk '{print $1; exit}' | tr -d '[:space:]')"
        if [ -n "$CANDIDATE" ]; then
            echo "$CANDIDATE" > "$PUBLIC_IP_FILE"
            echo "$CANDIDATE"
            return 0
        fi
    fi

    CANDIDATE="$(python3 - "$DOMAIN_VALUE" <<'PY' 2>/dev/null
import socket
import sys
try:
    print(socket.gethostbyname(sys.argv[1]))
except Exception:
    pass
PY
)"
    CANDIDATE="$(printf '%s' "$CANDIDATE" | head -n 1 | tr -d '[:space:]')"
    if [ -n "$CANDIDATE" ]; then
        echo "$CANDIDATE" > "$PUBLIC_IP_FILE"
        echo "$CANDIDATE"
        return 0
    fi

    read_domain
    return 0
}

read_subscription_host() {
    local HOST_VALUE

    HOST_VALUE="$(read_public_ip | head -n 1 | tr -d '[:space:]')"
    if [ -z "$HOST_VALUE" ]; then
        HOST_VALUE="$(read_domain)"
    fi

    case "$HOST_VALUE" in
        *:*)
            if printf '%s' "$HOST_VALUE" | grep -Eq '^[0-9A-Fa-f:]+$'; then
                echo "[$HOST_VALUE]"
                return 0
            fi
            ;;
    esac

    echo "$HOST_VALUE"
    return 0
}

read_reality_host() {
    local HOST_VALUE

    HOST_VALUE="$(read_domain | head -n 1 | tr -d '[:space:]')"
    if [ -z "$HOST_VALUE" ]; then
        HOST_VALUE="$(read_subscription_host)"
    fi

    echo "$HOST_VALUE"
    return 0
}

get_node_name() {
    if [ -n "${NODE_NAME:-${VPN_NODE_NAME:-}}" ]; then
        printf '%s\n' "${NODE_NAME:-${VPN_NODE_NAME:-}}"
        return 0
    fi

    if [ -f "$NODE_NAME_FILE" ] && [ -s "$NODE_NAME_FILE" ]; then
        head -n 1 "$NODE_NAME_FILE"
        return 0
    fi

    read_domain
    return 0
}

tag_file_for() {
    case "$1" in
        ws) echo "$TAG_WS_FILE" ;;
        xhttp) echo "$TAG_XHTTP_FILE" ;;
        reality) echo "$TAG_REALITY_FILE" ;;
        cdn-ws|ws-cdn) echo "$CDN_WS_TAG_FILE" ;;
        cdn-xhttp|xhttp-cdn|cdn) echo "$CDN_XHTTP_TAG_FILE" ;;
        *) echo "" ;;
    esac
}

default_tag_for() {
    case "$1" in
        ws) echo "WS" ;;
        xhttp) echo "XHTTP" ;;
        reality) echo "Reality" ;;
        cdn-ws|ws-cdn|cdn-xhttp|xhttp-cdn|cdn) echo "CDN" ;;
        *) echo "" ;;
    esac
}

get_link_tag() {
    local KIND="$1"
    local FILE DEFAULT_VALUE

    FILE="$(tag_file_for "$KIND")"
    DEFAULT_VALUE="$(default_tag_for "$KIND")"
    if [ -n "$FILE" ] && [ -f "$FILE" ] && [ -s "$FILE" ]; then
        head -n 1 "$FILE"
        return 0
    fi

    echo "$DEFAULT_VALUE"
    return 0
}

set_link_tag() {
    local KIND="$1"
    local VALUE="$2"
    local FILE

    FILE="$(tag_file_for "$KIND")"
    if [ -z "$FILE" ]; then
        return 1
    fi

    printf '%s\n' "$VALUE" > "$FILE"
    return 0
}

get_port() {
    local PORT_VALUE
    PORT_VALUE="${SERVER_PORT:-25565}"
    if validate_port "$PORT_VALUE"; then
        echo "$PORT_VALUE"
    else
        echo "25565"
    fi
}

get_public_port() {
    local PORT_VALUE
    PORT_VALUE="${PUBLIC_PORT:-${WS_PUBLIC_PORT:-}}"
    if [ -z "$PORT_VALUE" ]; then
        PORT_VALUE="$(get_port)"
    fi
    if validate_port "$PORT_VALUE"; then
        echo "$PORT_VALUE"
    else
        get_port
    fi
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

    candidate_port_after_base 1
    return $?
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
    return $?
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

    echo "proxy11.h1guro.ovh"
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

get_sub_name() {
    if [ -n "${SUB_NAME:-${VPN_SUB_NAME:-}}" ]; then
        printf '%s\n' "${SUB_NAME:-${VPN_SUB_NAME:-}}"
        return 0
    fi

    if [ -f "$SUB_NAME_FILE" ] && [ -s "$SUB_NAME_FILE" ]; then
        head -n 1 "$SUB_NAME_FILE"
        return 0
    fi

    echo ""
    return 0
}

append_sub_name_fragment() {
    local URL_VALUE="$1"
    local NAME_VALUE="$2"

    if [ -z "$URL_VALUE" ] || [ -z "$NAME_VALUE" ]; then
        echo "$URL_VALUE"
        return 0
    fi

    python3 - "$URL_VALUE" "$NAME_VALUE" <<'PY'
import sys
import urllib.parse

url = sys.argv[1]
name = sys.argv[2]
print(url.split("#", 1)[0] + "#" + urllib.parse.quote(name, safe=""))
PY
}

is_cdn_ws_enabled() {
    local VALUE HOST_VALUE

    VALUE="${CDN_WS_ENABLED:-${VPN_CDN_WS:-}}"
    if [ -n "$VALUE" ]; then
        if is_enabled_value "$VALUE"; then
            return 0
        fi
        if is_disabled_value "$VALUE"; then
            return 1
        fi
    fi

    if [ -f "$CDN_WS_ENABLED_FILE" ] && [ -s "$CDN_WS_ENABLED_FILE" ]; then
        VALUE="$(head -n 1 "$CDN_WS_ENABLED_FILE" 2>/dev/null)"
        if is_enabled_value "$VALUE"; then
            return 0
        fi
        if is_disabled_value "$VALUE"; then
            return 1
        fi
    fi

    HOST_VALUE="$(get_cdn_ws_host)"
    [ -n "$HOST_VALUE" ]
}

set_cdn_ws_enabled() {
    if [ "$1" = "1" ]; then
        echo "1" > "$CDN_WS_ENABLED_FILE"
    else
        echo "0" > "$CDN_WS_ENABLED_FILE"
    fi
    return 0
}

get_cdn_ws_host() {
    if [ -n "${CDN_WS_HOST:-${VPN_CDN_WS_HOST:-}}" ]; then
        normalize_domain "${CDN_WS_HOST:-${VPN_CDN_WS_HOST:-}}"
        return 0
    fi

    if [ -f "$CDN_WS_HOST_FILE" ] && [ -s "$CDN_WS_HOST_FILE" ]; then
        normalize_domain "$(head -n 1 "$CDN_WS_HOST_FILE" 2>/dev/null)"
        return 0
    fi

    echo ""
    return 0
}

get_cdn_ws_sni() {
    if [ -n "${CDN_WS_SNI:-${VPN_CDN_WS_SNI:-}}" ]; then
        normalize_domain "${CDN_WS_SNI:-${VPN_CDN_WS_SNI:-}}"
        return 0
    fi

    if [ -f "$CDN_WS_SNI_FILE" ] && [ -s "$CDN_WS_SNI_FILE" ]; then
        normalize_domain "$(head -n 1 "$CDN_WS_SNI_FILE" 2>/dev/null)"
        return 0
    fi

    get_cdn_ws_host
    return 0
}

get_cdn_ws_port() {
    local PORT_VALUE

    PORT_VALUE="${CDN_WS_PORT:-${VPN_CDN_WS_PORT:-}}"
    if validate_port "$PORT_VALUE"; then
        echo "$PORT_VALUE"
        return 0
    fi

    if [ -f "$CDN_WS_PORT_FILE" ] && [ -s "$CDN_WS_PORT_FILE" ]; then
        PORT_VALUE="$(head -n 1 "$CDN_WS_PORT_FILE" 2>/dev/null)"
        if validate_port "$PORT_VALUE"; then
            echo "$PORT_VALUE"
            return 0
        fi
    fi

    echo "443"
    return 0
}

get_cdn_ws_tag_suffix() {
    if [ -n "${CDN_WS_TAG:-${VPN_CDN_WS_TAG:-}}" ]; then
        printf '%s\n' "${CDN_WS_TAG:-${VPN_CDN_WS_TAG:-}}"
        return 0
    fi

    if [ -f "$CDN_WS_TAG_FILE" ] && [ -s "$CDN_WS_TAG_FILE" ]; then
        head -n 1 "$CDN_WS_TAG_FILE"
        return 0
    fi

    echo "CDN"
    return 0
}

get_cdn_ws_path() {
    local PATH_VALUE

    PATH_VALUE="${CDN_WS_PATH:-${VPN_CDN_WS_PATH:-}}"
    if [ -z "$PATH_VALUE" ] && [ -f "$CDN_WS_PATH_FILE" ] && [ -s "$CDN_WS_PATH_FILE" ]; then
        PATH_VALUE="$(head -n 1 "$CDN_WS_PATH_FILE" 2>/dev/null)"
    fi

    PATH_VALUE="$(strip_outer_quotes "$PATH_VALUE")"
    if [ -z "$PATH_VALUE" ]; then
        PATH_VALUE="/xray"
    fi

    case "$PATH_VALUE" in
        /*) ;;
        *) PATH_VALUE="/$PATH_VALUE" ;;
    esac

    printf '%s\n' "$PATH_VALUE"
    return 0
}

get_transport() {
    local VALUE

    VALUE="${TRANSPORT:-${VPN_TRANSPORT:-}}"
    if [ -z "$VALUE" ] && [ -f "$TRANSPORT_FILE" ] && [ -s "$TRANSPORT_FILE" ]; then
        VALUE="$(head -n 1 "$TRANSPORT_FILE" 2>/dev/null)"
    fi

    VALUE="$(printf '%s' "$VALUE" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    case "$VALUE" in
        xhttp)
            echo "xhttp"
            ;;
        *)
            echo "ws"
            ;;
    esac
    return 0
}

set_transport() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        xhttp)
            echo "xhttp" > "$TRANSPORT_FILE"
            ;;
        *)
            echo "ws" > "$TRANSPORT_FILE"
            ;;
    esac
    return 0
}

get_xhttp_path() {
    local PATH_VALUE

    PATH_VALUE="${XHTTP_PATH:-${VPN_XHTTP_PATH:-}}"
    if [ -z "$PATH_VALUE" ] && [ -f "$XHTTP_PATH_FILE" ] && [ -s "$XHTTP_PATH_FILE" ]; then
        PATH_VALUE="$(head -n 1 "$XHTTP_PATH_FILE" 2>/dev/null)"
    fi

    PATH_VALUE="$(strip_outer_quotes "$PATH_VALUE")"
    if [ -z "$PATH_VALUE" ]; then
        PATH_VALUE="/api/v1/sync/"
    fi

    case "$PATH_VALUE" in
        /*) ;;
        *) PATH_VALUE="/$PATH_VALUE" ;;
    esac
    case "$PATH_VALUE" in
        */) ;;
        *) PATH_VALUE="$PATH_VALUE/" ;;
    esac

    printf '%s\n' "$PATH_VALUE"
    return 0
}

get_xhttp_method() {
    local METHOD_VALUE

    METHOD_VALUE="${XHTTP_METHOD:-${VPN_XHTTP_METHOD:-}}"
    if [ -z "$METHOD_VALUE" ] && [ -f "$XHTTP_METHOD_FILE" ] && [ -s "$XHTTP_METHOD_FILE" ]; then
        METHOD_VALUE="$(head -n 1 "$XHTTP_METHOD_FILE" 2>/dev/null)"
    fi

    METHOD_VALUE="$(printf '%s' "$METHOD_VALUE" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')"
    case "$METHOD_VALUE" in
        GET|POST|PUT)
            echo "$METHOD_VALUE"
            ;;
        *)
            echo "GET"
            ;;
    esac
    return 0
}

normalize_xhttp_alpn() {
    local ALPN_VALUE

    ALPN_VALUE="$(strip_outer_quotes "${1:-}")"
    ALPN_VALUE="$(printf '%s' "$ALPN_VALUE" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    case "$ALPN_VALUE" in
        h2,http1|h2,http/1.1|h2,http1.1|h2,http2|h2,http/2|h2,http/1|h2,1|h2,1.1)
            echo "h2,http1"
            ;;
        h2|http2|2)
            echo "h2"
            ;;
        none|off|disable|disabled|auto|default)
            echo "none"
            ;;
        http1|http1.1|http/1.1|1|1.1|"")
            echo "h2,http1"
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

get_xhttp_alpn() {
    local ALPN_VALUE

    ALPN_VALUE="${XHTTP_ALPN:-${VPN_XHTTP_ALPN:-}}"
    if [ -z "$ALPN_VALUE" ] && [ -f "$XHTTP_ALPN_FILE" ] && [ -s "$XHTTP_ALPN_FILE" ]; then
        ALPN_VALUE="$(head -n 1 "$XHTTP_ALPN_FILE" 2>/dev/null)"
    fi

    normalize_xhttp_alpn "$ALPN_VALUE" || echo "h2,http1"
    return 0
}

set_xhttp_alpn() {
    local ALPN_VALUE

    ALPN_VALUE="$(normalize_xhttp_alpn "${1:-}")"
    if [ -z "$ALPN_VALUE" ]; then
        return 1
    fi

    echo "$ALPN_VALUE" > "$XHTTP_ALPN_FILE"
    return 0
}

is_mws_enabled() {
    local VALUE

    VALUE="${MWS_ENABLED:-${VPN_MWS_ENABLED:-}}"
    if [ -n "$VALUE" ]; then
        is_enabled_value "$VALUE" && return 0
        is_disabled_value "$VALUE" && return 1
    fi

    if [ -f "$MWS_ENABLED_FILE" ] && [ -s "$MWS_ENABLED_FILE" ]; then
        VALUE="$(head -n 1 "$MWS_ENABLED_FILE" 2>/dev/null)"
        is_enabled_value "$VALUE" && return 0
    fi

    return 1
}

get_mws_domain() {
    local VALUE

    VALUE="${MWS_DOMAIN:-${VPN_MWS_DOMAIN:-}}"
    if [ -z "$VALUE" ] && [ -f "$MWS_DOMAIN_FILE" ] && [ -s "$MWS_DOMAIN_FILE" ]; then
        VALUE="$(head -n 1 "$MWS_DOMAIN_FILE" 2>/dev/null)"
    fi
    if [ -z "$VALUE" ]; then
        VALUE="$(get_domain)"
    fi
    normalize_domain "$VALUE"
    return 0
}

get_mws_cert_file() {
    local VALUE DOMAIN_VALUE

    VALUE="${MWS_CERT_PATH:-${VPN_MWS_CERT_PATH:-}}"
    if [ -z "$VALUE" ] && [ -f "$MWS_CERT_FILE" ] && [ -s "$MWS_CERT_FILE" ]; then
        VALUE="$(head -n 1 "$MWS_CERT_FILE" 2>/dev/null)"
    fi
    if [ -z "$VALUE" ]; then
        DOMAIN_VALUE="$(get_mws_domain)"
        VALUE="/etc/letsencrypt/live/$DOMAIN_VALUE/fullchain.pem"
    fi
    strip_outer_quotes "$VALUE"
    return 0
}

get_mws_key_file() {
    local VALUE DOMAIN_VALUE

    VALUE="${MWS_KEY_PATH:-${VPN_MWS_KEY_PATH:-}}"
    if [ -z "$VALUE" ] && [ -f "$MWS_KEY_FILE" ] && [ -s "$MWS_KEY_FILE" ]; then
        VALUE="$(head -n 1 "$MWS_KEY_FILE" 2>/dev/null)"
    fi
    if [ -z "$VALUE" ]; then
        DOMAIN_VALUE="$(get_mws_domain)"
        VALUE="/etc/letsencrypt/live/$DOMAIN_VALUE/privkey.pem"
    fi
    strip_outer_quotes "$VALUE"
    return 0
}

get_xhttp_mode() {
    if is_mws_enabled; then
        echo "auto"
    else
        echo "packet-up"
    fi
    return 0
}

is_cdn_xhttp_enabled() {
    local VALUE HOST_VALUE

    VALUE="${CDN_XHTTP_ENABLED:-${VPN_CDN_XHTTP:-}}"
    if [ -n "$VALUE" ]; then
        if is_enabled_value "$VALUE"; then
            return 0
        fi
        if is_disabled_value "$VALUE"; then
            return 1
        fi
    fi

    if [ -f "$CDN_XHTTP_ENABLED_FILE" ] && [ -s "$CDN_XHTTP_ENABLED_FILE" ]; then
        VALUE="$(head -n 1 "$CDN_XHTTP_ENABLED_FILE" 2>/dev/null)"
        if is_enabled_value "$VALUE"; then
            return 0
        fi
        if is_disabled_value "$VALUE"; then
            return 1
        fi
    fi

    HOST_VALUE="$(get_cdn_xhttp_host)"
    [ -n "$HOST_VALUE" ]
}

set_cdn_xhttp_enabled() {
    if [ "$1" = "1" ]; then
        echo "1" > "$CDN_XHTTP_ENABLED_FILE"
    else
        echo "0" > "$CDN_XHTTP_ENABLED_FILE"
    fi
    return 0
}

get_cdn_xhttp_host() {
    if [ -n "${CDN_XHTTP_HOST:-${VPN_CDN_XHTTP_HOST:-}}" ]; then
        normalize_domain "${CDN_XHTTP_HOST:-${VPN_CDN_XHTTP_HOST:-}}"
        return 0
    fi

    if [ -f "$CDN_XHTTP_HOST_FILE" ] && [ -s "$CDN_XHTTP_HOST_FILE" ]; then
        normalize_domain "$(head -n 1 "$CDN_XHTTP_HOST_FILE" 2>/dev/null)"
        return 0
    fi

    echo ""
    return 0
}

get_cdn_xhttp_sni() {
    if [ -n "${CDN_XHTTP_SNI:-${VPN_CDN_XHTTP_SNI:-}}" ]; then
        normalize_domain "${CDN_XHTTP_SNI:-${VPN_CDN_XHTTP_SNI:-}}"
        return 0
    fi

    if [ -f "$CDN_XHTTP_SNI_FILE" ] && [ -s "$CDN_XHTTP_SNI_FILE" ]; then
        normalize_domain "$(head -n 1 "$CDN_XHTTP_SNI_FILE" 2>/dev/null)"
        return 0
    fi

    get_cdn_xhttp_host
    return 0
}

get_cdn_xhttp_port() {
    local PORT_VALUE

    PORT_VALUE="${CDN_XHTTP_PORT:-${VPN_CDN_XHTTP_PORT:-}}"
    if validate_port "$PORT_VALUE"; then
        echo "$PORT_VALUE"
        return 0
    fi

    if [ -f "$CDN_XHTTP_PORT_FILE" ] && [ -s "$CDN_XHTTP_PORT_FILE" ]; then
        PORT_VALUE="$(head -n 1 "$CDN_XHTTP_PORT_FILE" 2>/dev/null)"
        if validate_port "$PORT_VALUE"; then
            echo "$PORT_VALUE"
            return 0
        fi
    fi

    echo "443"
    return 0
}

get_cdn_xhttp_tag_suffix() {
    if [ -n "${CDN_XHTTP_TAG:-${VPN_CDN_XHTTP_TAG:-}}" ]; then
        printf '%s\n' "${CDN_XHTTP_TAG:-${VPN_CDN_XHTTP_TAG:-}}"
        return 0
    fi

    if [ -f "$CDN_XHTTP_TAG_FILE" ] && [ -s "$CDN_XHTTP_TAG_FILE" ]; then
        head -n 1 "$CDN_XHTTP_TAG_FILE"
        return 0
    fi

    echo "CDN"
    return 0
}

get_cdn_xhttp_public_path() {
    local PATH_VALUE

    PATH_VALUE="${CDN_XHTTP_PUBLIC_PATH:-${VPN_CDN_XHTTP_PUBLIC_PATH:-}}"
    if [ -z "$PATH_VALUE" ] && [ -f "$CDN_XHTTP_PUBLIC_PATH_FILE" ] && [ -s "$CDN_XHTTP_PUBLIC_PATH_FILE" ]; then
        PATH_VALUE="$(head -n 1 "$CDN_XHTTP_PUBLIC_PATH_FILE" 2>/dev/null)"
    fi

    PATH_VALUE="$(strip_outer_quotes "$PATH_VALUE")"
    if [ -z "$PATH_VALUE" ]; then
        PATH_VALUE="$(get_xhttp_path)"
    fi

    case "$PATH_VALUE" in
        /*) ;;
        *) PATH_VALUE="/$PATH_VALUE" ;;
    esac
    case "$PATH_VALUE" in
        */) ;;
        *) PATH_VALUE="$PATH_VALUE/" ;;
    esac

    printf '%s\n' "$PATH_VALUE"
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

strip_outer_quotes() {
    local VALUE="$*"

    VALUE="${VALUE#"${VALUE%%[![:space:]]*}"}"
    VALUE="${VALUE%"${VALUE##*[![:space:]]}"}"

    case "$VALUE" in
        \'*\')
            VALUE="${VALUE#\'}"
            VALUE="${VALUE%\'}"
            ;;
        \"*\")
            VALUE="${VALUE#\"}"
            VALUE="${VALUE%\"}"
            ;;
    esac

    printf '%s' "$VALUE"
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
    local PORT_VALUE="$1"

    if ! echo "$PORT_VALUE" | grep -Eq '^[0-9]+$'; then
        return 1
    fi

    if [ "$PORT_VALUE" -lt 1 ] || [ "$PORT_VALUE" -gt 65535 ]; then
        return 1
    fi

    return 0
}

is_enabled_value() {
    case "$1" in
        1|yes|YES|true|TRUE|on|ON|enable|enabled)
            return 0
            ;;
    esac
    return 1
}

is_disabled_value() {
    case "$1" in
        0|no|NO|false|FALSE|off|OFF|disable|disabled)
            return 0
            ;;
    esac
    return 1
}

is_reality_enabled() {
    local VALUE PORT_VALUE

    VALUE="${REALITY_ENABLED:-${VPN_REALITY:-}}"
    if [ -n "$VALUE" ]; then
        if is_enabled_value "$VALUE"; then
            return 0
        fi
        if is_disabled_value "$VALUE"; then
            return 1
        fi
    fi

    if [ -n "${REALITY_PORT:-}" ] && validate_port "$REALITY_PORT"; then
        return 0
    fi

    if [ -f "$REALITY_ENABLED_FILE" ] && [ -s "$REALITY_ENABLED_FILE" ]; then
        VALUE="$(head -n 1 "$REALITY_ENABLED_FILE" 2>/dev/null)"
        if is_enabled_value "$VALUE"; then
            return 0
        fi
        if is_disabled_value "$VALUE"; then
            return 1
        fi
    fi

    return 0
}

set_reality_enabled() {
    if [ "$1" = "1" ]; then
        echo "1" > "$REALITY_ENABLED_FILE"
    else
        echo "0" > "$REALITY_ENABLED_FILE"
    fi
    return 0
}

saved_api_port() {
    if [ -f "$API_PORT_FILE" ] && [ -s "$API_PORT_FILE" ]; then
        head -n 1 "$API_PORT_FILE"
    fi
}

saved_sub_port() {
    if [ -f "$SUB_PORT_FILE" ] && [ -s "$SUB_PORT_FILE" ]; then
        head -n 1 "$SUB_PORT_FILE"
    fi
}

candidate_port_after_base() {
    local OFFSET="$1"
    local BASE_PORT CANDIDATE

    BASE_PORT="$(get_port)"
    if validate_port "$BASE_PORT"; then
        CANDIDATE=$((BASE_PORT + OFFSET))
        if [ "$CANDIDATE" -le 65535 ]; then
            echo "$CANDIDATE"
            return 0
        fi
    fi

    CANDIDATE=$((30000 + OFFSET))
    if [ "$CANDIDATE" -le 65535 ]; then
        echo "$CANDIDATE"
        return 0
    fi

    return 1
}

auto_offset_port() {
    local SERVICE="$1"
    local START_OFFSET="$2"
    local OFFSET CANDIDATE

    OFFSET="$START_OFFSET"
    while [ "$OFFSET" -le 20 ]; do
        CANDIDATE="$(candidate_port_after_base "$OFFSET")"
        if validate_port "$CANDIDATE" && check_port_conflict "$CANDIDATE" "$SERVICE" >/dev/null 2>&1; then
            echo "$CANDIDATE"
            return 0
        fi
        OFFSET=$((OFFSET + 1))
    done

    candidate_port_after_base "$START_OFFSET"
}

auto_api_port() {
    local PORT_VALUE

    PORT_VALUE="$(saved_api_port)"
    if validate_port "$PORT_VALUE"; then
        echo "$PORT_VALUE"
        return 0
    fi

    PORT_VALUE="${API_PORT:-${VPN_API_PORT:-}}"
    if validate_port "$PORT_VALUE"; then
        echo "$PORT_VALUE"
        return 0
    fi

    auto_offset_port api 2
}

auto_sub_port() {
    local PORT_VALUE

    PORT_VALUE="$(saved_sub_port)"
    if validate_port "$PORT_VALUE"; then
        echo "$PORT_VALUE"
        return 0
    fi

    PORT_VALUE="${SUB_PORT:-${VPN_SUB_PORT:-}}"
    if validate_port "$PORT_VALUE"; then
        echo "$PORT_VALUE"
        return 0
    fi

    auto_offset_port sub 3
}

check_port_conflict() {
    local PORT_VALUE="$1"
    local SERVICE="$2"
    local WS_PORT REALITY_PORT_VALUE API_PORT_VALUE SUB_PORT_VALUE

    WS_PORT="$(get_port)"
    if [ "$SERVICE" != "ws" ] && [ "$PORT_VALUE" = "$WS_PORT" ]; then
        echo "port $PORT_VALUE is already used by ws/xray"
        return 1
    fi

    if [ "$SERVICE" != "reality" ] && is_reality_enabled; then
        REALITY_PORT_VALUE="$(get_reality_port)"
        if [ -n "$REALITY_PORT_VALUE" ] && [ "$PORT_VALUE" = "$REALITY_PORT_VALUE" ]; then
            echo "port $PORT_VALUE is already used by reality"
            return 1
        fi
    fi

    API_PORT_VALUE="$(saved_api_port)"
    if ! validate_port "$API_PORT_VALUE"; then
        API_PORT_VALUE="${API_PORT:-${VPN_API_PORT:-}}"
    fi
    if [ "$SERVICE" != "api" ] && validate_port "$API_PORT_VALUE"; then
        if [ "$PORT_VALUE" = "$API_PORT_VALUE" ]; then
            echo "port $PORT_VALUE is already used by api"
            return 1
        fi
    fi

    SUB_PORT_VALUE="$(saved_sub_port)"
    if ! validate_port "$SUB_PORT_VALUE"; then
        SUB_PORT_VALUE="${SUB_PORT:-${VPN_SUB_PORT:-}}"
    fi
    if [ "$SERVICE" != "sub" ] && validate_port "$SUB_PORT_VALUE"; then
        if [ "$PORT_VALUE" = "$SUB_PORT_VALUE" ]; then
            echo "port $PORT_VALUE is already used by subscription"
            return 1
        fi
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
    # Р’РђР–РќРћ: `-` РґРѕР»Р¶РµРЅ Р±С‹С‚СЊ РІ РљРћРќР¦Р• СЃРїРёСЃРєР°, РёРЅР°С‡Рµ GNU tr РїСЂРёРјРµС‚ РµРіРѕ Р·Р° С„Р»Р°Рі
    # Рё СѓРїР°РґС‘С‚ СЃ "tr: invalid option -- '['" вЂ” С‚РѕРєРµРЅ СЃС‚Р°РЅРµС‚ РїСѓСЃС‚С‹Рј,
    # Рё РІ С„Р°Р№Р»Рµ РѕРєР°Р¶РµС‚СЃСЏ РѕР±С‹С‡РЅС‹Р№ unix timestamp РІРјРµСЃС‚Рѕ РЅРѕСЂРјР°Р»СЊРЅРѕРіРѕ РєР»СЋС‡Р°.
    TOKEN="$(printf '%s' "$TOKEN" | tr -d '[:space:]-')"

    if [ -z "$TOKEN" ]; then
        TOKEN="$(date +%s)"
    fi

    echo "$TOKEN" > "$API_TOKEN_FILE"
    chmod 600 "$API_TOKEN_FILE" >/dev/null 2>&1
    echo "$TOKEN"
    return 0
}

get_join_token() {
    if [ -f "$JOIN_TOKEN_FILE" ] && [ -s "$JOIN_TOKEN_FILE" ]; then
        head -n 1 "$JOIN_TOKEN_FILE"
        return 0
    fi

    TOKEN="$(make_uuid)$(make_uuid)"
    TOKEN="$(printf '%s' "$TOKEN" | tr -d '[:space:]-')"

    if [ -z "$TOKEN" ]; then
        TOKEN="$(date +%s)"
    fi

    echo "$TOKEN" > "$JOIN_TOKEN_FILE"
    chmod 600 "$JOIN_TOKEN_FILE" >/dev/null 2>&1
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
    REALITY_PORT_VALUE="$(get_reality_port)"
    if ! validate_port "$REALITY_PORT_VALUE"; then
        echo "reality is disabled. enable it with: vpn reality PORT [PUBLIC_PORT] [SNI] [DEST]"
        return 1
    fi

    if [ -z "${REALITY_SNI:-}" ] && [ -f "$REALITY_SNI_FILE" ] && [ -s "$REALITY_SNI_FILE" ]; then
        CURRENT_SNI="$(head -n 1 "$REALITY_SNI_FILE" 2>/dev/null)"
        if [ "$CURRENT_SNI" = "www.microsoft.com" ]; then
            echo "proxy11.h1guro.ovh" > "$REALITY_SNI_FILE"
        fi
    fi

    if [ -z "${PUBLIC_REALITY_PORT:-}" ] && [ -f "$REALITY_PUBLIC_PORT_FILE" ] && [ -s "$REALITY_PUBLIC_PORT_FILE" ]; then
        CURRENT_PUBLIC_REALITY_PORT="$(head -n 1 "$REALITY_PUBLIC_PORT_FILE" 2>/dev/null)"
        if [ "$CURRENT_PUBLIC_REALITY_PORT" = "$REALITY_PORT_VALUE" ] || [ "$CURRENT_PUBLIC_REALITY_PORT" = "8443" ]; then
            echo "$REALITY_PORT_VALUE" > "$REALITY_PUBLIC_PORT_FILE"
        elif [ "$CURRENT_PUBLIC_REALITY_PORT" = "443" ]; then
            echo "$REALITY_PORT_VALUE" > "$REALITY_PUBLIC_PORT_FILE"
        fi
    fi

    if [ ! -f "$REALITY_SNI_FILE" ] || [ ! -s "$REALITY_SNI_FILE" ]; then
        echo "$(get_reality_sni)" > "$REALITY_SNI_FILE"
    fi

    if [ ! -f "$REALITY_DEST_FILE" ] || [ ! -s "$REALITY_DEST_FILE" ]; then
        echo "$(get_reality_dest)" > "$REALITY_DEST_FILE"
    fi

    if [ -z "${REALITY_DEST:-}" ] && [ -f "$REALITY_DEST_FILE" ] && [ -s "$REALITY_DEST_FILE" ]; then
        CURRENT_DEST="$(head -n 1 "$REALITY_DEST_FILE" 2>/dev/null)"
        if [ "$CURRENT_DEST" = "www.microsoft.com:443" ]; then
            echo "proxy11.h1guro.ovh:443" > "$REALITY_DEST_FILE"
        fi
    fi

    if [ ! -f "$REALITY_PORT_FILE" ] || [ ! -s "$REALITY_PORT_FILE" ]; then
        echo "$REALITY_PORT_VALUE" > "$REALITY_PORT_FILE"
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
    # РЎС‚Р°СЂС‹Р№ С„РѕСЂРјР°С‚: "Private key:" / "Public key:"
    # РќРѕРІС‹Р№ С„РѕСЂРјР°С‚ (xray v25.3.6+): "PrivateKey:" / "Password:" (Password = РїСѓР±Р»РёС‡РЅС‹Р№ РєР»СЋС‡)
    # СЃРј. XTLS/Xray-core#5159, #5160
    # РџРѕРґРґРµСЂР¶РёРІР°РµРј С„РѕСЂРјР°С‚С‹:
    #   "Private key: ..." / "Public key: ..."           (СЃС‚Р°СЂС‹Р№)
    #   "PrivateKey: ..."  / "Password: ..."              (v25.3.6+)
    #   "PrivateKey: ..."  / "Password (PublicKey): ..."  (РїРѕСЃР»Рµ PR XTLS/Xray-core#5759)
    PRIVATE_KEY="$(echo "$KEYS_OUTPUT" | sed -n -E 's/^[[:space:]]*Private[[:space:]]*[Kk]ey[[:space:]]*:[[:space:]]*//p' | head -n 1 | tr -d '[:space:]')"
    PUBLIC_KEY="$(echo "$KEYS_OUTPUT" | sed -n -E 's/^[[:space:]]*Public[[:space:]]*[Kk]ey[[:space:]]*:[[:space:]]*//p' | head -n 1 | tr -d '[:space:]')"
    if [ -z "$PUBLIC_KEY" ]; then
        # Р»РѕРІРёРј "Password:" Рё "Password (PublicKey):" Рё С‚.Рї.
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
    SUB_ID=""

    if [ -z "$SUB_PORT_VALUE" ]; then
        return 1
    fi

    if ! validate_port "$SUB_PORT_VALUE"; then
        return 1
    fi

    SUB_PUBLIC_HOST="$(read_subscription_host)"
    SUB_ID="$(python3 - "$USERS_FILE" "$NAME" <<'PY'
import json
import sys
import time
import urllib.parse

users_file, identifier = sys.argv[1], sys.argv[2]
now = int(time.time())

try:
    with open(users_file, "r", encoding="utf-8") as f:
        users = json.load(f)
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

for user in users:
    try:
        name = str(user.get("name", ""))
        client_id = str(user.get("uuid", ""))
        expires_at = int(user.get("expires_at", 0))
    except Exception:
        continue
    if user.get("banned") or user.get("disabled"):
        continue
    if expires_at > now and client_id and identifier in (name, client_id):
        print(urllib.parse.quote(client_id, safe=""))
        sys.exit(0)

sys.exit(1)
PY
)" || return 1

    if [ -z "$SUB_ID" ]; then
        return 1
    fi

    append_sub_name_fragment "http://$SUB_PUBLIC_HOST:$SUB_PORT_VALUE/sub/$SUB_ID" "$(get_sub_name)"
    return 0
}

sync_keys_file() {
    PUBLIC_DOMAIN="$(read_domain)"
    WS_PUBLIC_PORT_VALUE="$(get_public_port)"
    NODE_NAME_VALUE="$(get_node_name)"
    TRANSPORT_VALUE="$(get_transport)"
    XHTTP_PATH_VALUE="$(get_xhttp_path)"
    REALITY_ENABLED_VALUE="0"
    REALITY_PUBLIC_PORT_VALUE=""
    REALITY_PUBLIC_HOST_VALUE=""
    REALITY_SNI_VALUE=""
    REALITY_PUBLIC_KEY_VALUE=""
    REALITY_SHORT_ID_VALUE=""
    SUB_PORT_VALUE="$(get_sub_port)"
    SUB_TOKEN_VALUE=""
    SUB_PUBLIC_HOST_VALUE=""
    SUB_NAME_VALUE="$(get_sub_name)"
    CDN_WS_ENABLED_VALUE="0"
    CDN_WS_HOST_VALUE=""
    CDN_WS_SNI_VALUE=""
    CDN_WS_PORT_VALUE=""
    CDN_WS_TAG_VALUE=""
    CDN_WS_PATH_VALUE=""
    CDN_XHTTP_ENABLED_VALUE="0"
    CDN_XHTTP_HOST_VALUE=""
    CDN_XHTTP_SNI_VALUE=""
    CDN_XHTTP_PORT_VALUE=""
    CDN_XHTTP_TAG_VALUE=""
    CDN_XHTTP_PUBLIC_PATH_VALUE=""

    if is_reality_enabled && ensure_reality_files >/dev/null 2>&1; then
        REALITY_ENABLED_VALUE="1"
        REALITY_PUBLIC_PORT_VALUE="$(get_public_reality_port)"
        REALITY_PUBLIC_HOST_VALUE="$(read_reality_host)"
        REALITY_SNI_VALUE="$(get_reality_sni)"
        REALITY_PUBLIC_KEY_VALUE="$(read_reality_public_key)"
        REALITY_SHORT_ID_VALUE="$(read_reality_short_id)"
    fi

    if [ -n "$SUB_PORT_VALUE" ] && validate_port "$SUB_PORT_VALUE"; then
        SUB_PUBLIC_HOST_VALUE="$(read_subscription_host)"
    fi

    if is_cdn_ws_enabled; then
        CDN_WS_ENABLED_VALUE="1"
        CDN_WS_HOST_VALUE="$(get_cdn_ws_host)"
        CDN_WS_SNI_VALUE="$(get_cdn_ws_sni)"
        CDN_WS_PORT_VALUE="$(get_cdn_ws_port)"
        CDN_WS_TAG_VALUE="$(get_cdn_ws_tag_suffix)"
        CDN_WS_PATH_VALUE="$(get_cdn_ws_path)"
    fi

    if is_cdn_xhttp_enabled; then
        CDN_XHTTP_ENABLED_VALUE="1"
        CDN_XHTTP_HOST_VALUE="$(get_cdn_xhttp_host)"
        CDN_XHTTP_SNI_VALUE="$(get_cdn_xhttp_sni)"
        CDN_XHTTP_PORT_VALUE="$(get_cdn_xhttp_port)"
        CDN_XHTTP_TAG_VALUE="$(get_cdn_xhttp_tag_suffix)"
        CDN_XHTTP_PUBLIC_PATH_VALUE="$(get_cdn_xhttp_public_path)"
    fi

    python3 - "$USERS_FILE" "$KEY_FILE" "$PUBLIC_DOMAIN" "$WS_PUBLIC_PORT_VALUE" "$NODE_NAME_VALUE" "$REALITY_ENABLED_VALUE" "$REALITY_PUBLIC_PORT_VALUE" "$REALITY_PUBLIC_HOST_VALUE" "$REALITY_SNI_VALUE" "$REALITY_PUBLIC_KEY_VALUE" "$REALITY_SHORT_ID_VALUE" "$SUB_PORT_VALUE" "$SUB_TOKEN_VALUE" "$SUB_PUBLIC_HOST_VALUE" "$SUB_NAME_VALUE" "$CDN_WS_ENABLED_VALUE" "$CDN_WS_HOST_VALUE" "$CDN_WS_SNI_VALUE" "$CDN_WS_PORT_VALUE" "$CDN_WS_TAG_VALUE" "$CDN_WS_PATH_VALUE" "$TRAFFIC_FILE" "$TRANSPORT_VALUE" "$XHTTP_PATH_VALUE" "$XHTTP_METHOD_VALUE" "$CDN_XHTTP_ENABLED_VALUE" "$CDN_XHTTP_HOST_VALUE" "$CDN_XHTTP_SNI_VALUE" "$CDN_XHTTP_PORT_VALUE" "$CDN_XHTTP_TAG_VALUE" "$CDN_XHTTP_PUBLIC_PATH_VALUE" <<'PY'
import datetime
import json
import sys
import time
import urllib.parse

def read_tag_suffix(name, default):
    try:
        with open(name, "r", encoding="utf-8") as f:
            return f.readline().strip()
    except Exception:
        return default


def link_tag(base, suffix):
    base = str(base or "").strip()
    suffix = str(suffix or "").strip()
    if not suffix:
        return base
    if suffix[:1] in ("-", "_", "/", "#", "(", "["):
        return base + suffix
    return (base + " " + suffix).strip()

def xhttp_client_extra(method):
    method = (method or "GET").upper()
    if method not in ("GET", "POST", "PUT"):
        method = "GET"
    return {
        "xmux": {
            "cMaxReuseTimes": "48-96",
            "maxConcurrency": "4-8",
            "maxConnections": 0,
            "hKeepAlivePeriod": 0,
            "hMaxRequestTimes": "500-900",
            "hMaxReusableSecs": "300-900",
        },
        "seqKey": "page",
        "sessionKey": "X-Request-Id",
        "xPaddingKey": "_dc",
        "seqPlacement": "query",
        "uplinkDataKey": "X-Payload",
        "xPaddingBytes": "80-240",
        "xPaddingMethod": "tokenish",
        "uplinkChunkSize": "1024-2048",
        "sessionPlacement": "header",
        "uplinkHTTPMethod": method,
        "xPaddingObfsMode": True,
        "xPaddingPlacement": "query",
        "scMaxEachPostBytes": "4096-8192",
        "uplinkDataPlacement": "header",
    }


def xhttp_extra_param(method):
    extra = json.dumps(xhttp_client_extra(method), ensure_ascii=False, separators=(",", ":"))
    return urllib.parse.quote(extra, safe="")


def read_xhttp_alpn(default="h2,http1"):
    try:
        with open("xhttp_alpn.txt", "r", encoding="utf-8") as f:
            value = f.readline().strip().lower()
    except Exception:
        value = default
    aliases = {
        "h2,http1": "h2,http1",
        "h2,http/1.1": "h2,http1",
        "h2,http1.1": "h2,http1",
        "h2,http2": "h2,http1",
        "h2,1.1": "h2,http1",
        "h2": "h2",
        "http2": "h2",
        "2": "h2",
        "none": "none",
        "off": "none",
        "disabled": "none",
        "auto": "none",
        "default": "none",
        "http1": "http1",
        "http1.1": "http1",
        "http/1.1": "http1",
        "1": "http1",
        "1.1": "http1",
        "": default,
    }
    return aliases.get(value, default)


def xhttp_alpn_query():
    value = read_xhttp_alpn()
    if value == "h2,http1":
        return "&alpn=h2%2Chttp%2F1.1"
    if value == "h2":
        return "&alpn=h2"
    if value == "none":
        return ""
    return "&alpn=http%2F1.1"


def read_mws_enabled():
    try:
        with open("mws_enabled.txt", "r", encoding="utf-8") as f:
            value = f.readline().strip().lower()
        return value in ("1", "true", "yes", "on", "enabled")
    except Exception:
        return False


def normalize_xhttp_path_py(path):
    path = str(path or "/api/v1/sync/").strip()
    if not path.startswith("/"):
        path = "/" + path
    if not path.endswith("/"):
        path += "/"
    return path


def build_xhttp_vless(client_id, address, port, path, host_header, tag, security="none", sni="", method="GET"):
    path = urllib.parse.quote(normalize_xhttp_path_py(path), safe="")
    tag = urllib.parse.quote(tag, safe="")
    if read_mws_enabled():
        url = f"vless://{client_id}@{address}:{port}?encryption=none&type=xhttp&path={path}&host={host_header}&mode=auto"
    else:
        extra = xhttp_extra_param(method)
        url = f"vless://{client_id}@{address}:{port}?encryption=none&type=xhttp&path={path}&host={host_header}&mode=packet-up&extra={extra}"
    if security == "tls":
        url += f"&security=tls&sni={sni or host_header}&fp=chrome{xhttp_alpn_query()}"
    else:
        url += "&security=none"
    return url + f"#{tag}"

users_file = sys.argv[1]
key_file = sys.argv[2]
domain = sys.argv[3]
ws_port = sys.argv[4]
node_name = sys.argv[5].strip() or domain
reality_enabled = sys.argv[6] == "1"
reality_port = sys.argv[7]
reality_host = sys.argv[8]
reality_sni = sys.argv[9]
reality_public_key = sys.argv[10]
reality_short_id = sys.argv[11]
sub_port = sys.argv[12]
sub_token = sys.argv[13]
sub_public_host = sys.argv[14]
sub_name = sys.argv[15]
cdn_ws_enabled = sys.argv[16] == "1"
cdn_ws_host = sys.argv[17]
cdn_ws_sni = sys.argv[18] or cdn_ws_host
cdn_ws_port = sys.argv[19] or "443"
cdn_ws_tag_suffix = sys.argv[20] or "CDN"
cdn_ws_path = sys.argv[21] or "/xray"
traffic_file = sys.argv[22]
transport = sys.argv[23] if len(sys.argv) > 23 else "ws"
xhttp_path = sys.argv[24] if len(sys.argv) > 24 and sys.argv[24] else "/api/v1/sync/"
xhttp_method = (sys.argv[25] if len(sys.argv) > 25 and sys.argv[25] else "GET").upper()
cdn_xhttp_enabled = len(sys.argv) > 26 and sys.argv[26] == "1"
cdn_xhttp_host = sys.argv[27] if len(sys.argv) > 27 else ""
cdn_xhttp_sni = (sys.argv[28] if len(sys.argv) > 28 else "") or cdn_xhttp_host
cdn_xhttp_port = (sys.argv[29] if len(sys.argv) > 29 else "") or "443"
cdn_xhttp_tag_suffix = (sys.argv[30] if len(sys.argv) > 30 else "") or "CDN"
cdn_xhttp_public_path = (sys.argv[31] if len(sys.argv) > 31 else "") or xhttp_path
tag_ws = read_tag_suffix("tag_ws.txt", "WS")
tag_xhttp = read_tag_suffix("tag_xhttp.txt", "XHTTP")
tag_reality = read_tag_suffix("tag_reality.txt", "Reality")
if not xhttp_path.startswith("/"):
    xhttp_path = "/" + xhttp_path
if not xhttp_path.endswith("/"):
    xhttp_path += "/"
if xhttp_method not in ("GET", "POST", "PUT"):
    xhttp_method = "GET"
if not cdn_xhttp_public_path.startswith("/"):
    cdn_xhttp_public_path = "/" + cdn_xhttp_public_path
if not cdn_xhttp_public_path.endswith("/"):
    cdn_xhttp_public_path += "/"
now = int(time.time())

try:
    with open(users_file, "r", encoding="utf-8") as f:
        users = json.load(f)
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

try:
    with open(traffic_file, "r", encoding="utf-8") as f:
        traffic = json.load(f)
    if not isinstance(traffic, dict):
        traffic = {}
except Exception:
    traffic = {}

lines = []
generated = datetime.datetime.fromtimestamp(now).strftime("%Y-%m-%d %H:%M:%S")
lines.append(f"generated_at: {generated}")
lines.append(f"domain: {domain}")
lines.append(f"node_name: {node_name}")
lines.append(f"transport: {transport if transport == 'xhttp' else 'ws'}")
lines.append(f"ws_public_port: {ws_port}")
if transport == "xhttp":
    lines.append(f"xhttp_path: {xhttp_path}")
if reality_enabled:
    lines.append(f"reality_public_host: {reality_host}")
    lines.append(f"reality_public_port: {reality_port}")
    lines.append(f"reality_sni: {reality_sni}")
else:
    lines.append("reality: disabled")
if sub_port:
    lines.append(f"sub_public_port: {sub_port}")
    lines.append(f"sub_public_host: {sub_public_host}")
if sub_name:
    lines.append(f"sub_name: {sub_name}")
if cdn_ws_enabled:
    lines.append(f"cdn_ws: {cdn_ws_host}:{cdn_ws_port} sni={cdn_ws_sni} path={cdn_ws_path}")
if cdn_xhttp_enabled:
    lines.append(f"cdn_xhttp: {cdn_xhttp_host}:{cdn_xhttp_port} sni={cdn_xhttp_sni} path={cdn_xhttp_public_path}")
lines.append(" ")

def ws_link(name, uuid):
    tag = urllib.parse.quote(link_tag(node_name, tag_ws), safe="")
    if str(ws_port) == "443":
        return f"vless://{uuid}@{domain}:{ws_port}?type=ws&security=tls&sni={domain}&host={domain}&path=%2Fxray&encryption=none#{tag}"
    return f"vless://{uuid}@{domain}:{ws_port}?type=ws&security=none&host={domain}&path=%2Fxray&encryption=none#{tag}"

def xhttp_link(name, uuid):
    tag = link_tag(node_name, tag_xhttp)
    security = "tls" if str(ws_port) == "443" else "none"
    return build_xhttp_vless(uuid, domain, ws_port, xhttp_path, domain, tag, security=security, sni=domain, method=xhttp_method)

def cdn_ws_link(name, uuid):
    if not cdn_ws_enabled or not cdn_ws_host:
        return ""
    tag = urllib.parse.quote(link_tag(link_tag(node_name, tag_ws), cdn_ws_tag_suffix).replace(" ", "-"), safe="")
    return (
        f"vless://{uuid}@{cdn_ws_host}:{cdn_ws_port}"
        f"?security=tls&sni={cdn_ws_sni}&type=ws&path={urllib.parse.quote(cdn_ws_path, safe='')}"
        f"&host={cdn_ws_sni}&encryption=none#{tag}"
    )

def cdn_xhttp_link(name, uuid):
    if not cdn_xhttp_enabled or not cdn_xhttp_host:
        return ""
    tag = link_tag(node_name, cdn_xhttp_tag_suffix).replace(" ", "-")
    return build_xhttp_vless(uuid, cdn_xhttp_host, cdn_xhttp_port, cdn_xhttp_public_path, cdn_xhttp_sni, tag, security="tls", sni=cdn_xhttp_sni, method=xhttp_method)

def reality_link(name, uuid):
    tag = urllib.parse.quote(link_tag(node_name, tag_reality), safe="")
    return (
        f"vless://{uuid}@{reality_host}:{reality_port}"
        f"?type=tcp&security=reality&pbk={reality_public_key}&fp=chrome"
        f"&sni={reality_sni}&sid={reality_short_id}&spx=%2F"
        f"&flow=xtls-rprx-vision&encryption=none#{tag}"
    )

def subscription_url(name, uuid):
    if not sub_port or not uuid:
        return ""
    quoted_uuid = urllib.parse.quote(uuid, safe="")
    host = sub_public_host or domain
    url = f"http://{host}:{sub_port}/sub/{quoted_uuid}"
    if sub_name:
        url += "#" + urllib.parse.quote(sub_name, safe="")
    return url

def gb_text(value):
    try:
        return f"{int(value) / 1073741824:.2f}".rstrip("0").rstrip(".")
    except Exception:
        return "0"

def traffic_row(uuid):
    row = traffic.get(uuid, {})
    return row if isinstance(row, dict) else {}

active_count = 0
listed_count = 0
for u in users:
    try:
        name = str(u["name"])
        uuid = str(u["uuid"])
        exp = int(u["expires_at"])
    except Exception:
        continue

    if exp <= now or not uuid:
        continue

    listed_count += 1

    if u.get("banned") or u.get("disabled"):
        lines.append(f"{name} | uuid: {uuid} | status: banned")
        if u.get("ban_reason"):
            lines.append(f"reason: {u.get('ban_reason')}")
        lines.append(" ")
        continue

    left = max(0, exp - now)
    days_left = left // 86400
    hours_left = (left % 86400) // 3600
    date = datetime.datetime.fromtimestamp(exp).strftime("%Y-%m-%d %H:%M")

    active_count += 1
    lines.append(f"{name} | uuid: {uuid} | expires: {date} | left: {days_left}d {hours_left}h")
    limit_bytes = int(u.get("traffic_limit_bytes", 0) or 0)
    device_limit = int(u.get("device_limit", 0) or 0)
    traffic_used = int(traffic_row(uuid).get("used_bytes", 0) or 0)
    if limit_bytes or device_limit:
        parts = []
        if limit_bytes:
            parts.append(f"traffic: {gb_text(traffic_used)}GB/{gb_text(limit_bytes)}GB")
        if device_limit:
            parts.append(f"devices: max {device_limit}")
        lines.append("limits: " + " | ".join(parts))
    if transport == "xhttp":
        lines.append("xhttp:")
        lines.append(xhttp_link(name, uuid))
    else:
        lines.append("ws:")
        lines.append(ws_link(name, uuid))
    if cdn_ws_enabled:
        cdn_link = cdn_ws_link(name, uuid)
        if cdn_link:
            lines.append("ws-cdn:")
            lines.append(cdn_link)
    if cdn_xhttp_enabled:
        cdn_link = cdn_xhttp_link(name, uuid)
        if cdn_link:
            lines.append("xhttp-cdn:")
            lines.append(cdn_link)
    if reality_enabled:
        lines.append("reality:")
        lines.append(reality_link(name, uuid))
    sub = subscription_url(name, uuid)
    if sub:
        lines.append("subscription:")
        lines.append(sub)
    lines.append(" ")

if listed_count == 0:
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
    TRANSPORT_VALUE="$(get_transport)"
    XHTTP_PATH_VALUE="$(get_xhttp_path)"
    XHTTP_METHOD_VALUE="$(get_xhttp_method)"
    REALITY_ENABLED_VALUE="0"
    REALITY_LOCAL_PORT=""
    REALITY_SNI_VALUE=""
    REALITY_DEST_VALUE=""
    REALITY_PRIVATE_KEY_VALUE=""
    REALITY_SHORT_ID_VALUE=""
    MWS_ENABLED_VALUE="0"
    MWS_DOMAIN_VALUE=""
    MWS_CERT_VALUE=""
    MWS_KEY_VALUE=""

    prune_expired >/dev/null 2>&1

    if is_reality_enabled; then
        REALITY_LOCAL_PORT="$(get_reality_port)"
        if ! validate_port "$REALITY_LOCAL_PORT"; then
            echo "reality is enabled but port is not configured"
            echo "use: vpn reality PORT [PUBLIC_PORT] [SNI] [DEST]"
            return 1
        fi

        if [ "$LOCAL_PORT" = "$REALITY_LOCAL_PORT" ]; then
            echo "ws port and reality port must be different"
            return 1
        fi

        ensure_reality_files || return 1
        REALITY_ENABLED_VALUE="1"
        REALITY_SNI_VALUE="$(get_reality_sni)"
        REALITY_DEST_VALUE="$(get_reality_dest)"
        REALITY_PRIVATE_KEY_VALUE="$(read_reality_private_key)"
        REALITY_SHORT_ID_VALUE="$(read_reality_short_id)"
    fi

    if is_mws_enabled; then
        MWS_ENABLED_VALUE="1"
        MWS_DOMAIN_VALUE="$(get_mws_domain)"
        MWS_CERT_VALUE="$(get_mws_cert_file)"
        MWS_KEY_VALUE="$(get_mws_key_file)"
    fi

    python3 - "$USERS_FILE" "$CONFIG_FILE" "$LOCAL_PORT" "$REALITY_ENABLED_VALUE" "$REALITY_LOCAL_PORT" "$REALITY_SNI_VALUE" "$REALITY_DEST_VALUE" "$REALITY_PRIVATE_KEY_VALUE" "$REALITY_SHORT_ID_VALUE" "$XRAY_STATS_PORT" "$TRANSPORT_VALUE" "$XHTTP_PATH_VALUE" "$XHTTP_METHOD_VALUE" "$MWS_ENABLED_VALUE" "$MWS_DOMAIN_VALUE" "$MWS_CERT_VALUE" "$MWS_KEY_VALUE" <<'PY'
import json, sys

users_file = sys.argv[1]
config_file = sys.argv[2]

try:
    port = int(sys.argv[3])
except Exception:
    port = 25565

reality_enabled = sys.argv[4] == "1"
reality_port = 0
if reality_enabled:
    try:
        reality_port = int(sys.argv[5])
    except Exception:
        reality_enabled = False

reality_sni = sys.argv[6]
reality_dest = sys.argv[7]
reality_private_key = sys.argv[8]
reality_short_id = sys.argv[9]
stats_port = int(sys.argv[10])
transport = sys.argv[11] if len(sys.argv) > 11 else "ws"
xhttp_path = sys.argv[12] if len(sys.argv) > 12 and sys.argv[12] else "/api/v1/sync/"
xhttp_method = (sys.argv[13] if len(sys.argv) > 13 and sys.argv[13] else "GET").upper()
mws_enabled = len(sys.argv) > 14 and sys.argv[14] == "1"
mws_domain = sys.argv[15] if len(sys.argv) > 15 else ""
mws_cert = sys.argv[16] if len(sys.argv) > 16 else ""
mws_key = sys.argv[17] if len(sys.argv) > 17 else ""
if not xhttp_path.startswith("/"):
    xhttp_path = "/" + xhttp_path
if not xhttp_path.endswith("/"):
    xhttp_path += "/"
if xhttp_method not in ("GET", "POST", "PUT"):
    xhttp_method = "GET"

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

    if u.get("banned") or u.get("disabled"):
        continue

    clients.append({
        "id": uuid,
        "email": name
    })
    if reality_enabled:
        reality_clients.append({
            "id": uuid,
            "email": name + "-reality",
            "flow": "xtls-rprx-vision"
        })

main_inbound = {
    "port": port,
    "tag": "xhttp-in" if transport == "xhttp" else "ws-in",
    "listen": "0.0.0.0",
    "protocol": "vless",
    "settings": {
        "clients": clients,
        "decryption": "none"
    },
    "sniffing": {
        "enabled": True,
        "destOverride": ["http", "tls", "quic"]
    }
}

if transport == "xhttp" and mws_enabled:
    main_inbound["tag"] = "XHTTP_mws"
    main_inbound["streamSettings"] = {
        "network": "xhttp",
        "security": "tls",
        "tlsSettings": {
            "minVersion": "1.2",
            "certificates": [
                {
                    "certificateFile": mws_cert,
                    "keyFile": mws_key
                }
            ]
        },
        "xhttpSettings": {
            "mode": "auto",
            "path": xhttp_path
        }
    }
elif transport == "xhttp":
    main_inbound["streamSettings"] = {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": {
            "mode": "packet-up",
            "path": xhttp_path,
            "extra": {
                "seqKey": "page",
                "sessionKey": "X-Request-Id",
                "noSSEHeader": False,
                "xPaddingKey": "_dc",
                "seqPlacement": "query",
                "uplinkDataKey": "X-Payload",
                "xPaddingBytes": "80-240",
                "xPaddingMethod": "tokenish",
                "uplinkChunkSize": "1024-2048",
                "sessionPlacement": "header",
                "uplinkHTTPMethod": xhttp_method,
                "xPaddingObfsMode": True,
                "xPaddingPlacement": "query",
                "scMaxBufferedPosts": 30,
                "scMaxEachPostBytes": "4096-8192",
                "uplinkDataPlacement": "header",
                "serverMaxHeaderBytes": 32768
            }
        }
    }
else:
    main_inbound["streamSettings"] = {
        "network": "ws",
        "wsSettings": {
            "path": "/xray"
        }
    }

config = {
    "log": {
        "loglevel": "warning"
    },
    "stats": {},
    "api": {
        "tag": "api",
        "services": ["HandlerService", "LoggerService", "StatsService"]
    },
    "policy": {
        "levels": {
            "0": {
                "statsUserUplink": True,
                "statsUserDownlink": True
            }
        },
        "system": {
            "statsInboundUplink": True,
            "statsInboundDownlink": True
        }
    },
    "inbounds": [
        main_inbound,
        {
            "tag": "api",
            "listen": "127.0.0.1",
            "port": stats_port,
            "protocol": "dokodemo-door",
            "settings": {
                "address": "127.0.0.1"
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "freedom",
            "tag": "api"
        }
    ],
    "routing": {
        "rules": [
            {
                "type": "field",
                "inboundTag": ["api"],
                "outboundTag": "api"
            }
        ]
    }
}

if reality_enabled:
    config["inbounds"].append({
            "port": reality_port,
            "tag": "reality-in",
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
        })

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
    NODE_NAME_VALUE="$(get_node_name)"
    TRANSPORT_VALUE="$(get_transport)"
    XHTTP_PATH_VALUE="$(get_xhttp_path)"
    REALITY_ENABLED_VALUE="0"
    REALITY_PUBLIC_PORT_VALUE=""
    REALITY_PUBLIC_HOST_VALUE=""
    REALITY_SNI_VALUE=""
    REALITY_PUBLIC_KEY_VALUE=""
    REALITY_SHORT_ID_VALUE=""
    SUB_URL_VALUE="$(make_subscription_url "$NAME" 2>/dev/null || true)"
    CDN_WS_ENABLED_VALUE="0"
    CDN_WS_HOST_VALUE=""
    CDN_WS_SNI_VALUE=""
    CDN_WS_PORT_VALUE=""
    CDN_WS_TAG_VALUE=""
    CDN_WS_PATH_VALUE=""
    CDN_XHTTP_ENABLED_VALUE="0"
    CDN_XHTTP_HOST_VALUE=""
    CDN_XHTTP_SNI_VALUE=""
    CDN_XHTTP_PORT_VALUE=""
    CDN_XHTTP_TAG_VALUE=""
    CDN_XHTTP_PUBLIC_PATH_VALUE=""

    if is_reality_enabled && ensure_reality_files >/dev/null 2>&1; then
        REALITY_ENABLED_VALUE="1"
        REALITY_PUBLIC_PORT_VALUE="$(get_public_reality_port)"
        REALITY_PUBLIC_HOST_VALUE="$(read_reality_host)"
        REALITY_SNI_VALUE="$(get_reality_sni)"
        REALITY_PUBLIC_KEY_VALUE="$(read_reality_public_key)"
        REALITY_SHORT_ID_VALUE="$(read_reality_short_id)"
    fi

    if is_cdn_ws_enabled; then
        CDN_WS_ENABLED_VALUE="1"
        CDN_WS_HOST_VALUE="$(get_cdn_ws_host)"
        CDN_WS_SNI_VALUE="$(get_cdn_ws_sni)"
        CDN_WS_PORT_VALUE="$(get_cdn_ws_port)"
        CDN_WS_TAG_VALUE="$(get_cdn_ws_tag_suffix)"
        CDN_WS_PATH_VALUE="$(get_cdn_ws_path)"
    fi

    if is_cdn_xhttp_enabled; then
        CDN_XHTTP_ENABLED_VALUE="1"
        CDN_XHTTP_HOST_VALUE="$(get_cdn_xhttp_host)"
        CDN_XHTTP_SNI_VALUE="$(get_cdn_xhttp_sni)"
        CDN_XHTTP_PORT_VALUE="$(get_cdn_xhttp_port)"
        CDN_XHTTP_TAG_VALUE="$(get_cdn_xhttp_tag_suffix)"
        CDN_XHTTP_PUBLIC_PATH_VALUE="$(get_cdn_xhttp_public_path)"
    fi

    python3 - "$USERS_FILE" "$NAME" "$PUBLIC_DOMAIN" "$WS_PUBLIC_PORT_VALUE" "$NODE_NAME_VALUE" "$REALITY_ENABLED_VALUE" "$REALITY_PUBLIC_PORT_VALUE" "$REALITY_PUBLIC_HOST_VALUE" "$REALITY_SNI_VALUE" "$REALITY_PUBLIC_KEY_VALUE" "$REALITY_SHORT_ID_VALUE" "$SUB_URL_VALUE" "$CDN_WS_ENABLED_VALUE" "$CDN_WS_HOST_VALUE" "$CDN_WS_SNI_VALUE" "$CDN_WS_PORT_VALUE" "$CDN_WS_TAG_VALUE" "$CDN_WS_PATH_VALUE" "$TRANSPORT_VALUE" "$XHTTP_PATH_VALUE" "$(get_xhttp_method)" "$CDN_XHTTP_ENABLED_VALUE" "$CDN_XHTTP_HOST_VALUE" "$CDN_XHTTP_SNI_VALUE" "$CDN_XHTTP_PORT_VALUE" "$CDN_XHTTP_TAG_VALUE" "$CDN_XHTTP_PUBLIC_PATH_VALUE" <<'PY'
import json, sys
import urllib.parse

def read_tag_suffix(name, default):
    try:
        with open(name, "r", encoding="utf-8") as f:
            return f.readline().strip()
    except Exception:
        return default


def link_tag(base, suffix):
    base = str(base or "").strip()
    suffix = str(suffix or "").strip()
    if not suffix:
        return base
    if suffix[:1] in ("-", "_", "/", "#", "(", "["):
        return base + suffix
    return (base + " " + suffix).strip()

def xhttp_client_extra(method):
    method = (method or "GET").upper()
    if method not in ("GET", "POST", "PUT"):
        method = "GET"
    return {
        "xmux": {
            "cMaxReuseTimes": "48-96",
            "maxConcurrency": "4-8",
            "maxConnections": 0,
            "hKeepAlivePeriod": 0,
            "hMaxRequestTimes": "500-900",
            "hMaxReusableSecs": "300-900",
        },
        "seqKey": "page",
        "sessionKey": "X-Request-Id",
        "xPaddingKey": "_dc",
        "seqPlacement": "query",
        "uplinkDataKey": "X-Payload",
        "xPaddingBytes": "80-240",
        "xPaddingMethod": "tokenish",
        "uplinkChunkSize": "1024-2048",
        "sessionPlacement": "header",
        "uplinkHTTPMethod": method,
        "xPaddingObfsMode": True,
        "xPaddingPlacement": "query",
        "scMaxEachPostBytes": "4096-8192",
        "uplinkDataPlacement": "header",
    }


def xhttp_extra_param(method):
    extra = json.dumps(xhttp_client_extra(method), ensure_ascii=False, separators=(",", ":"))
    return urllib.parse.quote(extra, safe="")


def read_xhttp_alpn(default="h2,http1"):
    try:
        with open("xhttp_alpn.txt", "r", encoding="utf-8") as f:
            value = f.readline().strip().lower()
    except Exception:
        value = default
    aliases = {
        "h2,http1": "h2,http1",
        "h2,http/1.1": "h2,http1",
        "h2,http1.1": "h2,http1",
        "h2,http2": "h2,http1",
        "h2,1.1": "h2,http1",
        "h2": "h2",
        "http2": "h2",
        "2": "h2",
        "none": "none",
        "off": "none",
        "disabled": "none",
        "auto": "none",
        "default": "none",
        "http1": "http1",
        "http1.1": "http1",
        "http/1.1": "http1",
        "1": "http1",
        "1.1": "http1",
        "": default,
    }
    return aliases.get(value, default)


def xhttp_alpn_query():
    value = read_xhttp_alpn()
    if value == "h2,http1":
        return "&alpn=h2%2Chttp%2F1.1"
    if value == "h2":
        return "&alpn=h2"
    if value == "none":
        return ""
    return "&alpn=http%2F1.1"


def read_mws_enabled():
    try:
        with open("mws_enabled.txt", "r", encoding="utf-8") as f:
            value = f.readline().strip().lower()
        return value in ("1", "true", "yes", "on", "enabled")
    except Exception:
        return False


def normalize_xhttp_path_py(path):
    path = str(path or "/api/v1/sync/").strip()
    if not path.startswith("/"):
        path = "/" + path
    if not path.endswith("/"):
        path += "/"
    return path


def build_xhttp_vless(client_id, address, port, path, host_header, tag, security="none", sni="", method="GET"):
    path = urllib.parse.quote(normalize_xhttp_path_py(path), safe="")
    tag = urllib.parse.quote(tag, safe="")
    if read_mws_enabled():
        url = f"vless://{client_id}@{address}:{port}?encryption=none&type=xhttp&path={path}&host={host_header}&mode=auto"
    else:
        extra = xhttp_extra_param(method)
        url = f"vless://{client_id}@{address}:{port}?encryption=none&type=xhttp&path={path}&host={host_header}&mode=packet-up&extra={extra}"
    if security == "tls":
        url += f"&security=tls&sni={sni or host_header}&fp=chrome{xhttp_alpn_query()}"
    else:
        url += "&security=none"
    return url + f"#{tag}"

users_file = sys.argv[1]
name = sys.argv[2]
domain = sys.argv[3]
ws_port = sys.argv[4]
node_name = sys.argv[5].strip() or domain
reality_enabled = sys.argv[6] == "1"
reality_port = sys.argv[7]
reality_host = sys.argv[8]
reality_sni = sys.argv[9]
reality_public_key = sys.argv[10]
reality_short_id = sys.argv[11]
sub_url = sys.argv[12]
cdn_ws_enabled = sys.argv[13] == "1"
cdn_ws_host = sys.argv[14]
cdn_ws_sni = sys.argv[15] or cdn_ws_host
cdn_ws_port = sys.argv[16] or "443"
cdn_ws_tag_suffix = sys.argv[17] or "CDN"
cdn_ws_path = sys.argv[18] or "/xray"
transport = sys.argv[19] if len(sys.argv) > 19 else "ws"
xhttp_path = sys.argv[20] if len(sys.argv) > 20 and sys.argv[20] else "/api/v1/sync/"
xhttp_method = (sys.argv[21] if len(sys.argv) > 21 and sys.argv[21] else "GET").upper()
cdn_xhttp_enabled = len(sys.argv) > 22 and sys.argv[22] == "1"
cdn_xhttp_host = sys.argv[23] if len(sys.argv) > 23 else ""
cdn_xhttp_sni = (sys.argv[24] if len(sys.argv) > 24 else "") or cdn_xhttp_host
cdn_xhttp_port = (sys.argv[25] if len(sys.argv) > 25 else "") or "443"
cdn_xhttp_tag_suffix = (sys.argv[26] if len(sys.argv) > 26 else "") or "CDN"
cdn_xhttp_public_path = (sys.argv[27] if len(sys.argv) > 27 else "") or xhttp_path
tag_ws = read_tag_suffix("tag_ws.txt", "WS")
tag_xhttp = read_tag_suffix("tag_xhttp.txt", "XHTTP")
tag_reality = read_tag_suffix("tag_reality.txt", "Reality")
if not xhttp_path.startswith("/"):
    xhttp_path = "/" + xhttp_path
if not xhttp_path.endswith("/"):
    xhttp_path += "/"
if xhttp_method not in ("GET", "POST", "PUT"):
    xhttp_method = "GET"
if not cdn_xhttp_public_path.startswith("/"):
    cdn_xhttp_public_path = "/" + cdn_xhttp_public_path
if not cdn_xhttp_public_path.endswith("/"):
    cdn_xhttp_public_path += "/"

try:
    with open(users_file, "r", encoding="utf-8") as f:
        users = json.load(f)
except Exception:
    users = []

for u in users:
    if u.get("name") == name:
        if u.get("banned") or u.get("disabled"):
            print("user is banned")
            sys.exit(2)
        uuid = u.get("uuid")
        ws_tag = urllib.parse.quote(link_tag(node_name, tag_ws), safe="")
        if str(ws_port) == "443":
            ws_link = f"vless://{uuid}@{domain}:{ws_port}?type=ws&security=tls&sni={domain}&host={domain}&path=%2Fxray&encryption=none#{ws_tag}"
        else:
            ws_link = f"vless://{uuid}@{domain}:{ws_port}?type=ws&security=none&host={domain}&path=%2Fxray&encryption=none#{ws_tag}"
        if transport == "xhttp":
            security = "tls" if str(ws_port) == "443" else "none"
            xhttp_link = build_xhttp_vless(uuid, domain, ws_port, xhttp_path, domain, link_tag(node_name, tag_xhttp), security=security, sni=domain, method=xhttp_method)
            print("xhttp:")
            print(xhttp_link)
        else:
            print("ws:")
            print(ws_link)
        if cdn_ws_enabled and cdn_ws_host:
            cdn_tag = urllib.parse.quote(link_tag(link_tag(node_name, tag_ws), cdn_ws_tag_suffix).replace(" ", "-"), safe="")
            cdn_link = (
                f"vless://{uuid}@{cdn_ws_host}:{cdn_ws_port}"
                f"?security=tls&sni={cdn_ws_sni}&type=ws&path={urllib.parse.quote(cdn_ws_path, safe='')}"
                f"&host={cdn_ws_sni}&encryption=none#{cdn_tag}"
            )
            print("ws-cdn:")
            print(cdn_link)
        if cdn_xhttp_enabled and cdn_xhttp_host:
            cdn_link = build_xhttp_vless(uuid, cdn_xhttp_host, cdn_xhttp_port, cdn_xhttp_public_path, cdn_xhttp_sni, link_tag(node_name, cdn_xhttp_tag_suffix).replace(" ", "-"), security="tls", sni=cdn_xhttp_sni, method=xhttp_method)
            print("xhttp-cdn:")
            print(cdn_link)
        if reality_enabled:
            reality_tag = urllib.parse.quote(link_tag(node_name, tag_reality), safe="")
            reality_link = (
                f"vless://{uuid}@{reality_host}:{reality_port}"
                f"?type=tcp&security=reality&pbk={reality_public_key}&fp=chrome"
                f"&sni={reality_sni}&sid={reality_short_id}&spx=%2F"
                f"&flow=xtls-rprx-vision&encryption=none#{reality_tag}"
            )
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
    echo "vpn add NAME DAYS GB DEV   add user with traffic/device limits"
    echo "vpn del NAME               delete user"
    echo "vpn ban NAME [REASON]      disable user without deleting"
    echo "vpn unban NAME             enable banned user"
    echo "vpn list                   show users"
    echo "vpn info NAME              show user info"
    echo "vpn link NAME              show user link"
    echo "vpn limit NAME ...         set traffic GB and device limits"
    echo "vpn keys                   show all keys and recent logs"
    echo "vpn logs [COUNT]           show action logs"
    echo "vpn node NAME              set node/location name for link tags"
    echo "vpn tag status             show link name suffixes"
    echo "vpn tag ws|xhttp|reality VALUE"
    echo "vpn tag cdn|cdn-ws|cdn-xhttp VALUE"
    echo "vpn cdn HOST SNI [PORT]    add WS-CDN links for all clients"
    echo "vpn cdn HOST SNI PORT TAG PATH"
    echo "vpn cdn xhttp HOST SNI PORT TAG PATH"
    echo "vpn cdn off/status         manage generated CDN links"
    echo "vpn xhttp on/off/status    switch main inbound between XHTTP and WS"
    echo "vpn xhttp alpn h2,http1|h2|http1|none"
    echo "vpn mws on DOMAIN [PATH]   enable direct MWS XHTTP+TLS inbound"
    echo "vpn mws off/status         manage direct MWS mode"
    echo "vpn transport ws|xhttp     transport alias"
    echo "vpn join-token             show token for node auto-registration"
    echo "vpn join MASTER TOKEN NAME auto-register this node on master"
    echo "vpn peer add NAME URL      add remote node raw subscription URL"
    echo "vpn federation ...         sync users from master API"
    echo "vpn backup ...             create/list/restore backups"
    echo "vpn stats                  show xray traffic counters"
    echo "vpn update ...             update this script from URL"
    echo "vpn version                show script version/update status"
    echo "vpn doctor [fix]           check config and service health"
    echo "vpn renew NAME DAYS        extend user by DAYS"
    echo "vpn domain DOMAIN          set public domain"
    echo "vpn ports                  show port/allocation status"
    echo "vpn reality status         show Reality status"
    echo "vpn reality PORT [PUBLIC]  enable Reality on allocated port"
    echo "vpn reality off            disable Reality"
    echo "vpn api PORT               start API on 0.0.0.0:PORT"
    echo "vpn api stop               stop API"
    echo "vpn api status             show API status"
    echo "vpn api token              show API token"
    echo "vpn sub PORT               start subscription on 0.0.0.0:PORT"
    echo "vpn sub name NAME          set subscription display name"
    echo "vpn sub stop/status/token  manage subscription server"
    echo "vpn restart                restart xray"
    echo "vpn stop                   stop server"
    print_line
    echo "examples:"
    echo "vpn add test 30"
    echo "vpn add test 30 100 3"
    echo "vpn link test"
    echo "vpn limit test 100 3"
    echo "vpn limit test traffic 50"
    echo "vpn limit test devices 2"
    echo "vpn ban test abuse"
    echo "vpn unban test"
    echo "vpn node Germany"
    echo "vpn cdn cdn.gateway.h1cloud.su top2355543541.mwscdn.ru 443 CDN /h1cdn/nl1/xray"
    echo "vpn xhttp on"
    echo "vpn cdn xhttp proxy.h1cloud.su proxy.h1cloud.su 443 CDN /api/v1/ch1/sync"
    echo "vpn sub name Germany-VPN"
    echo "vpn join-token"
    echo "vpn join http://MASTER:PORT/api JOIN_TOKEN Germany"
    echo "vpn peer add de http://IP:PORT/sub/{uuid}/local"
    echo "vpn federation upstream http://MASTER:PORT/api TOKEN"
    echo "vpn renew test 15"
    echo "vpn del test"
    echo "vpn domain vpn.example.com"
    echo "vpn ports"
    echo "vpn reality 30001 proxy11.h1guro.ovh"
    echo "vpn api 25626"
    echo "vpn sub 25627"
    echo "vpn update url https://raw.githubusercontent.com/h1gurodev/h1cloud-vless/refs/heads/main/main.sh"
    echo "vpn update auto on"
    print_line
}

cmd_add() {
    NAME="$1"
    DAYS="$2"
    LIMIT_GB="${3:-}"
    DEVICE_LIMIT_VALUE="${4:-}"

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

    if upstream_configured; then
        EXISTING_UUID="$(local_user_uuid "$NAME" 2>/dev/null)"
        echo "federation upstream enabled: creating user on master..."
        if forward_client_to_upstream create "$NAME" "$DAYS" "$EXISTING_UUID" "$LIMIT_GB" "$DEVICE_LIMIT_VALUE"; then
            sync_after_upstream_client_write "$NAME" link
        else
            echo "upstream create failed"
            sync_after_upstream_client_write "$NAME" link
        fi
        return 0
    fi

    UUID="$(make_uuid)"

    if [ -z "$UUID" ]; then
        echo "cannot generate uuid"
        return 0
    fi

    python3 - "$USERS_FILE" "$NAME" "$DAYS" "$UUID" "$LIMIT_GB" "$DEVICE_LIMIT_VALUE" <<'PY'
import json, sys, time
from decimal import Decimal, InvalidOperation

path = sys.argv[1]
name = sys.argv[2]
days = int(sys.argv[3])
uuid = sys.argv[4]
limit_gb = sys.argv[5].strip()
device_limit_raw = sys.argv[6].strip()

def parse_limit_gb(value):
    text = str(value or "").strip().lower()
    if not text or text in ("0", "off", "none", "unlimited", "no"):
        return 0
    try:
        gb = Decimal(text.replace(",", "."))
    except InvalidOperation:
        print("bad GB limit")
        sys.exit(2)
    if gb < 0:
        print("bad GB limit")
        sys.exit(2)
    return int(gb * Decimal(1073741824))

def parse_device_limit(value):
    text = str(value or "").strip().lower()
    if not text or text in ("0", "off", "none", "unlimited", "no"):
        return 0
    try:
        number = int(text)
    except Exception:
        print("bad device limit")
        sys.exit(2)
    if number < 0:
        print("bad device limit")
        sys.exit(2)
    return number

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

traffic_limit_bytes = parse_limit_gb(limit_gb)
device_limit = parse_device_limit(device_limit_raw)

user = {
    "name": name,
    "uuid": uuid,
    "created_at": now,
    "expires_at": expires_at,
    "banned": False
}
if traffic_limit_bytes:
    user["traffic_limit_bytes"] = traffic_limit_bytes
    user["traffic_reset_pending"] = True
if device_limit:
    user["device_limit"] = device_limit

users.append(user)

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

    if upstream_configured; then
        echo "federation upstream enabled: deleting user on master..."
        if forward_client_to_upstream delete "$NAME"; then
            sync_after_upstream_client_write "$NAME"
        else
            echo "upstream delete failed"
        fi
        return 0
    fi

    python3 - "$USERS_FILE" "$DEVICES_FILE" "$TRAFFIC_FILE" "$NAME" <<'PY'
import json, os, sys

path = sys.argv[1]
devices_file = sys.argv[2]
traffic_file = sys.argv[3]
name = sys.argv[4]

try:
    with open(path, "r", encoding="utf-8") as f:
        users = json.load(f)
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

removed_ids = [str(u.get("uuid", "")) for u in users if u.get("name") == name]
new_users = [u for u in users if u.get("name") != name]

if len(new_users) == len(users):
    print("user not found")
    sys.exit(2)

with open(path, "w", encoding="utf-8") as f:
    json.dump(new_users, f, ensure_ascii=False, indent=2)

def cleanup_json_map(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            data = {}
    except Exception:
        data = {}
    changed = False
    for client_id in removed_ids:
        if client_id in data:
            data.pop(client_id, None)
            changed = True
    if changed:
        tmp = f"{path}.tmp.{os.getpid()}"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        os.replace(tmp, path)

cleanup_json_map(devices_file)
cleanup_json_map(traffic_file)

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

cmd_ban() {
    NAME="$1"
    shift 2>/dev/null || true
    REASON="$*"

    if ! validate_name "$NAME"; then
        echo "usage: vpn ban NAME [REASON]"
        return 0
    fi

    if upstream_configured; then
        echo "federation upstream enabled: banning user on master..."
        if forward_client_to_upstream ban "$NAME" "$REASON"; then
            sync_after_upstream_client_write "$NAME"
        else
            echo "upstream ban failed"
        fi
        return 0
    fi

    python3 - "$USERS_FILE" "$NAME" "$REASON" <<'PY'
import json, sys, time

path = sys.argv[1]
name = sys.argv[2]
reason = sys.argv[3].strip()

try:
    with open(path, "r", encoding="utf-8") as f:
        users = json.load(f)
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

found = False
now = int(time.time())
for user in users:
    if user.get("name") == name:
        user["banned"] = True
        user["banned_at"] = now
        user["ban_reason"] = reason
        found = True
        break

if not found:
    print("user not found")
    sys.exit(2)

with open(path, "w", encoding="utf-8") as f:
    json.dump(users, f, ensure_ascii=False, indent=2)

print("user banned")
PY

    RC="$?"

    if [ "$RC" -eq 0 ]; then
        restart_xray >/dev/null 2>&1
        sync_keys_file >/dev/null 2>&1
        remember_users_state
        restart_api_if_running
        restart_sub_if_running
        log_action "client_ban" "$NAME $REASON"
    fi

    return 0
}

cmd_unban() {
    NAME="$1"

    if ! validate_name "$NAME"; then
        echo "usage: vpn unban NAME"
        return 0
    fi

    if upstream_configured; then
        echo "federation upstream enabled: unbanning user on master..."
        if forward_client_to_upstream unban "$NAME"; then
            sync_after_upstream_client_write "$NAME"
        else
            echo "upstream unban failed"
        fi
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

found = False
for user in users:
    if user.get("name") == name:
        user["banned"] = False
        user.pop("disabled", None)
        user.pop("banned_at", None)
        user.pop("ban_reason", None)
        found = True
        break

if not found:
    print("user not found")
    sys.exit(2)

with open(path, "w", encoding="utf-8") as f:
    json.dump(users, f, ensure_ascii=False, indent=2)

print("user unbanned")
PY

    RC="$?"

    if [ "$RC" -eq 0 ]; then
        restart_xray >/dev/null 2>&1
        sync_keys_file >/dev/null 2>&1
        remember_users_state
        restart_api_if_running
        restart_sub_if_running
        log_action "client_unban" "$NAME"
    fi

    return 0
}

cmd_list() {
    prune_expired >/dev/null 2>&1

    python3 - "$USERS_FILE" "$TRAFFIC_FILE" "$DEVICES_FILE" <<'PY'
import json, sys, time, datetime

path = sys.argv[1]
traffic_file = sys.argv[2]
devices_file = sys.argv[3]
now = int(time.time())

try:
    with open(path, "r", encoding="utf-8") as f:
        users = json.load(f)
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

try:
    with open(traffic_file, "r", encoding="utf-8") as f:
        traffic = json.load(f)
    if not isinstance(traffic, dict):
        traffic = {}
except Exception:
    traffic = {}

try:
    with open(devices_file, "r", encoding="utf-8") as f:
        devices = json.load(f)
    if not isinstance(devices, dict):
        devices = {}
except Exception:
    devices = {}

def gb_text(value):
    try:
        return f"{int(value) / 1073741824:.2f}".rstrip("0").rstrip(".")
    except Exception:
        return "0"

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
        status = "banned" if u.get("banned") or u.get("disabled") else "active"
        uuid = str(u.get("uuid", ""))
        used = int((traffic.get(uuid, {}) or {}).get("used_bytes", 0) or 0)
        traffic_limit = int(u.get("traffic_limit_bytes", 0) or 0)
        device_limit = int(u.get("device_limit", 0) or 0)
        device_count = len(devices.get(uuid, []) if isinstance(devices.get(uuid, []), list) else [])
        limits = []
        if traffic_limit:
            limits.append(f"traffic {gb_text(used)}/{gb_text(traffic_limit)}GB")
        if device_limit:
            limits.append(f"devices {device_count}/{device_limit}")
        suffix = " | " + " | ".join(limits) if limits else ""
        print(f"{u['name']} | uuid: {uuid} | status: {status} | expires: {date} | left: {days_left}d {hours_left}h{suffix}")
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

    python3 - "$USERS_FILE" "$TRAFFIC_FILE" "$DEVICES_FILE" "$NAME" <<'PY'
import datetime
import json
import sys
import time

path = sys.argv[1]
traffic_file = sys.argv[2]
devices_file = sys.argv[3]
name = sys.argv[4]
now = int(time.time())

try:
    with open(path, "r", encoding="utf-8") as f:
        users = json.load(f)
    if not isinstance(users, list):
        users = []
except Exception:
    users = []

try:
    with open(traffic_file, "r", encoding="utf-8") as f:
        traffic = json.load(f)
    if not isinstance(traffic, dict):
        traffic = {}
except Exception:
    traffic = {}

try:
    with open(devices_file, "r", encoding="utf-8") as f:
        devices = json.load(f)
    if not isinstance(devices, dict):
        devices = {}
except Exception:
    devices = {}

def gb_text(value):
    try:
        return f"{int(value) / 1073741824:.2f}".rstrip("0").rstrip(".")
    except Exception:
        return "0"

for u in users:
    if u.get("name") == name:
        exp = int(u.get("expires_at", 0))
        left = max(0, exp - now)
        days_left = left // 86400
        hours_left = (left % 86400) // 3600
        date = datetime.datetime.fromtimestamp(exp).strftime("%Y-%m-%d %H:%M")
        status = "banned" if u.get("banned") or u.get("disabled") else "active"
        print(f"name: {u.get('name')}")
        print(f"uuid: {u.get('uuid')}")
        print(f"status: {status}")
        if status == "banned" and u.get("ban_reason"):
            print(f"ban_reason: {u.get('ban_reason')}")
        uuid = str(u.get("uuid", ""))
        traffic_row = traffic.get(uuid, {}) if isinstance(traffic.get(uuid, {}), dict) else {}
        device_rows = devices.get(uuid, []) if isinstance(devices.get(uuid, []), list) else []
        traffic_limit = int(u.get("traffic_limit_bytes", 0) or 0)
        device_limit = int(u.get("device_limit", 0) or 0)
        used = int(traffic_row.get("used_bytes", 0) or 0)
        print(f"traffic: {gb_text(used)}GB / {gb_text(traffic_limit)}GB" if traffic_limit else f"traffic: {gb_text(used)}GB / unlimited")
        print(f"devices: {len(device_rows)} / {device_limit}" if device_limit else f"devices: {len(device_rows)} / unlimited")
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

    if upstream_configured; then
        echo "federation upstream enabled: renewing user on master..."
        if forward_client_to_upstream renew "$NAME" "$DAYS"; then
            sync_after_upstream_client_write "$NAME"
        else
            echo "upstream renew failed"
        fi
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

cmd_limit() {
    local NAME="$1"
    local ACTION="${2:-status}"
    local VALUE="${3:-}"
    local VALUE2="${4:-}"

    if ! validate_name "$NAME"; then
        echo "usage: vpn limit NAME [GB DEVICES|traffic GB|devices COUNT|off|reset-traffic|reset-devices|status]"
        return 0
    fi

    if upstream_configured; then
        case "$ACTION" in
            status|show|reset-traffic|traffic-reset|reset|reset-devices|devices-reset|clear-devices|"")
                ;;
            *)
                echo "federation upstream enabled: updating limits on master..."
                if forward_client_to_upstream limit "$NAME" "$ACTION" "$VALUE" "$VALUE2"; then
                    sync_after_upstream_client_write "$NAME"
                else
                    echo "upstream limit update failed"
                fi
                return 0
                ;;
        esac
    fi

    python3 - "$USERS_FILE" "$DEVICES_FILE" "$TRAFFIC_FILE" "$NAME" "$ACTION" "$VALUE" "$VALUE2" <<'PY'
import json
import os
import sys
import time
from decimal import Decimal, InvalidOperation

users_file, devices_file, traffic_file, name, action, value, value2 = sys.argv[1:8]
action = (action or "status").strip().lower()

def load_json(path, default):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, type(default)) else default
    except Exception:
        return default

def save_json(path, data):
    tmp = f"{path}.tmp.{os.getpid()}"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)

def parse_limit_gb(raw):
    text = str(raw or "").strip().lower()
    if text in ("", "0", "off", "none", "unlimited", "no"):
        return 0
    try:
        gb = Decimal(text.replace(",", "."))
    except InvalidOperation:
        raise ValueError("bad traffic GB limit")
    if gb < 0:
        raise ValueError("bad traffic GB limit")
    return int(gb * Decimal(1073741824))

def parse_device_limit(raw):
    text = str(raw or "").strip().lower()
    if text in ("", "0", "off", "none", "unlimited", "no"):
        return 0
    try:
        count = int(text)
    except Exception:
        raise ValueError("bad device limit")
    if count < 0:
        raise ValueError("bad device limit")
    return count

def gb_text(bytes_value):
    try:
        return f"{int(bytes_value) / 1073741824:.2f}".rstrip("0").rstrip(".")
    except Exception:
        return "0"

users = load_json(users_file, [])
target = None
for user in users:
    if isinstance(user, dict) and user.get("name") == name:
        target = user
        break

if target is None:
    print("user not found")
    sys.exit(2)

devices = load_json(devices_file, {})
traffic = load_json(traffic_file, {})
client_id = str(target.get("uuid", ""))
traffic_row = traffic.get(client_id, {}) if isinstance(traffic.get(client_id, {}), dict) else {}
devices_list = devices.get(client_id, []) if isinstance(devices.get(client_id, []), list) else []
changed_users = False
changed_devices = False
changed_traffic = False

try:
    if action in ("status", "show", ""):
        pass
    elif action in ("off", "disable", "clear", "none"):
        target.pop("traffic_limit_bytes", None)
        target.pop("traffic_reset_pending", None)
        target.pop("device_limit", None)
        target.pop("quota_exceeded_at", None)
        changed_users = True
    elif action in ("traffic", "gb", "quota"):
        target["traffic_limit_bytes"] = parse_limit_gb(value)
        target["traffic_reset_pending"] = True
        target.pop("quota_exceeded_at", None)
        changed_users = True
    elif action in ("devices", "device", "hwid"):
        target["device_limit"] = parse_device_limit(value)
        changed_users = True
    elif action in ("reset-traffic", "traffic-reset", "reset"):
        traffic[client_id] = {"used_bytes": 0, "last_counter_bytes": int(traffic_row.get("last_counter_bytes", 0) or 0), "reset_pending": True, "updated_at": int(time.time())}
        target["traffic_reset_pending"] = True
        target.pop("quota_exceeded_at", None)
        changed_users = True
        changed_traffic = True
    elif action in ("reset-devices", "devices-reset", "clear-devices"):
        devices.pop(client_id, None)
        changed_devices = True
    else:
        target["traffic_limit_bytes"] = parse_limit_gb(action)
        target["device_limit"] = parse_device_limit(value)
        target["traffic_reset_pending"] = True
        target.pop("quota_exceeded_at", None)
        changed_users = True
except ValueError as exc:
    print(str(exc))
    sys.exit(2)

if changed_users:
    save_json(users_file, users)
if changed_devices:
    save_json(devices_file, devices)
if changed_traffic:
    save_json(traffic_file, traffic)

traffic_row = traffic.get(client_id, {}) if isinstance(traffic.get(client_id, {}), dict) else {}
devices_list = devices.get(client_id, []) if isinstance(devices.get(client_id, []), list) else []
limit_bytes = int(target.get("traffic_limit_bytes", 0) or 0)
device_limit = int(target.get("device_limit", 0) or 0)
used = int(traffic_row.get("used_bytes", 0) or 0)

print(f"name: {name}")
print(f"traffic: {gb_text(used)}GB / {gb_text(limit_bytes)}GB" if limit_bytes else f"traffic: {gb_text(used)}GB / unlimited")
print(f"devices: {len(devices_list)} / {device_limit}" if device_limit else f"devices: {len(devices_list)} / unlimited")
if devices_list:
    for item in devices_list:
        if isinstance(item, dict):
            label = item.get("label") or item.get("id", "")
            last_seen = item.get("last_seen", 0)
            print(f"- {label} last_seen={last_seen}")
if changed_users or changed_devices or changed_traffic:
    print("limits saved")
PY

    RC="$?"
    if [ "$RC" -eq 0 ]; then
        sync_keys_file >/dev/null 2>&1
        remember_users_state
        restart_api_if_running
        restart_sub_if_running
        log_action "client_limit" "$NAME $ACTION $VALUE $VALUE2"
    fi

    return 0
}

cmd_domain() {
    NEW_DOMAIN="$(normalize_domain "$1")"

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

cmd_tag() {
    local ACTION="${1:-status}"
    local VALUE FILE

    case "$ACTION" in
        status|"")
            print_line
            echo "Link tag suffixes"
            print_line
            echo "ws: $(get_link_tag ws)"
            echo "xhttp: $(get_link_tag xhttp)"
            echo "reality: $(get_link_tag reality)"
            echo "cdn-ws: $(get_link_tag cdn-ws)"
            echo "cdn-xhttp: $(get_link_tag cdn-xhttp)"
            print_line
            echo "examples:"
            echo "vpn tag xhttp Fast"
            echo "vpn tag ws \"\""
            echo "vpn tag reality REAL"
            echo "vpn tag cdn Budget"
            print_line
            ;;
        reset|defaults)
            rm -f "$TAG_WS_FILE" "$TAG_XHTTP_FILE" "$TAG_REALITY_FILE" >/dev/null 2>&1
            rm -f "$CDN_WS_TAG_FILE" "$CDN_XHTTP_TAG_FILE" >/dev/null 2>&1
            sync_keys_file >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
            remember_users_state
            log_action "tag_reset" ""
            echo "tag suffixes reset"
            ;;
        ws|xhttp|reality|cdn-ws|ws-cdn|cdn-xhttp|xhttp-cdn)
            shift
            VALUE="$(strip_outer_quotes "$*")"
            if ! set_link_tag "$ACTION" "$VALUE"; then
                echo "unknown tag kind: $ACTION"
                return 0
            fi
            sync_keys_file >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
            remember_users_state
            log_action "tag_set" "$ACTION=$VALUE"
            echo "tag saved: $ACTION = $VALUE"
            ;;
        cdn)
            shift
            VALUE="$(strip_outer_quotes "$*")"
            echo "$VALUE" > "$CDN_WS_TAG_FILE"
            echo "$VALUE" > "$CDN_XHTTP_TAG_FILE"
            sync_keys_file >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
            remember_users_state
            log_action "tag_set" "cdn=$VALUE"
            echo "tag saved: cdn-ws/cdn-xhttp = $VALUE"
            ;;
        help|*)
            echo "vpn tag status"
            echo "vpn tag ws VALUE"
            echo "vpn tag xhttp VALUE"
            echo "vpn tag reality VALUE"
            echo "vpn tag cdn VALUE              set both CDN suffixes"
            echo "vpn tag cdn-ws VALUE"
            echo "vpn tag cdn-xhttp VALUE"
            echo "vpn tag reset"
            ;;
    esac

    return 0
}

cmd_reality() {
    ACTION="${1:-}"

    case "$ACTION" in
        status|"")
            print_line
            echo "Reality settings"
            print_line
            if is_reality_enabled; then
                ensure_reality_files >/dev/null 2>&1
                echo "status: enabled"
                echo "local port: $(get_reality_port)"
                echo "public port: $(get_public_reality_port)"
                echo "sni: $(get_reality_sni)"
                echo "dest: $(get_reality_dest)"
                echo "public key: $(read_reality_public_key)"
                echo "short id: $(read_reality_short_id)"
            else
                echo "status: disabled"
                echo "enable: vpn reality PORT [PUBLIC_PORT] [SNI] [DEST]"
            fi
            print_line
            ;;
        off|disable|disabled|stop)
            set_reality_enabled 0
            rm -f "$REALITY_PORT_FILE" "$REALITY_PUBLIC_PORT_FILE" >/dev/null 2>&1
            restart_xray >/dev/null 2>&1
            sync_keys_file >/dev/null 2>&1
            remember_users_state
            restart_api_if_running
            restart_sub_if_running
            log_action "reality_disable" ""
            echo "reality disabled"
            ;;
        *)
            if ! validate_port "$ACTION"; then
                echo "usage: vpn reality PORT [PUBLIC_PORT] [SNI] [DEST]"
                echo "example: vpn reality 30001 proxy11.h1guro.ovh"
                return 0
            fi

            LOCAL_REALITY_PORT="$ACTION"
            if ! check_port_conflict "$LOCAL_REALITY_PORT" "reality"; then
                return 0
            fi

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
            set_reality_enabled 1

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

cmd_xhttp() {
    local ACTION="${1:-status}"
    local PATH_VALUE METHOD_VALUE ALPN_VALUE

    case "$ACTION" in
        status|"")
            print_line
            echo "Transport"
            print_line
            echo "mode: $(get_transport)"
            echo "ws path: /xray"
            echo "xhttp path: $(get_xhttp_path)"
            echo "xhttp uplink method: $(get_xhttp_method)"
            echo "xhttp alpn: $(get_xhttp_alpn)"
            if is_mws_enabled; then
                echo "mws direct: enabled domain=$(get_mws_domain) mode=auto tls=yes"
            else
                echo "mws direct: disabled"
            fi
            print_line
            ;;
        on|enable|enabled|xhttp)
            PATH_VALUE="$(strip_outer_quotes "${2:-}")"
            METHOD_VALUE="$(strip_outer_quotes "${3:-}")"
            if [ -n "$PATH_VALUE" ]; then
                case "$PATH_VALUE" in
                    /*) ;;
                    *) PATH_VALUE="/$PATH_VALUE" ;;
                esac
                case "$PATH_VALUE" in
                    */) ;;
                    *) PATH_VALUE="$PATH_VALUE/" ;;
                esac
                echo "$PATH_VALUE" > "$XHTTP_PATH_FILE"
            fi
            if [ -n "$METHOD_VALUE" ]; then
                METHOD_VALUE="$(printf '%s' "$METHOD_VALUE" | tr '[:lower:]' '[:upper:]')"
                case "$METHOD_VALUE" in
                    GET|POST|PUT)
                        echo "$METHOD_VALUE" > "$XHTTP_METHOD_FILE"
                        ;;
                    *)
                        echo "bad method. use GET, POST or PUT"
                        return 0
                        ;;
                esac
            fi
            set_transport xhttp
            restart_xray >/dev/null 2>&1
            sync_keys_file >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
            log_action "transport_set" "xhttp path=$(get_xhttp_path) method=$(get_xhttp_method)"
            echo "xhttp enabled"
            echo "local path: $(get_xhttp_path)"
            echo "uplink method: $(get_xhttp_method)"
            echo "alpn: $(get_xhttp_alpn)"
            ;;
        off|disable|disabled|ws)
            set_transport ws
            restart_xray >/dev/null 2>&1
            sync_keys_file >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
            log_action "transport_set" "ws"
            echo "ws enabled"
            echo "path: /xray"
            ;;
        path)
            PATH_VALUE="$(strip_outer_quotes "${2:-}")"
            if [ -z "$PATH_VALUE" ]; then
                echo "usage: vpn xhttp path /api/v1/sync/"
                return 0
            fi
            case "$PATH_VALUE" in
                /*) ;;
                *) PATH_VALUE="/$PATH_VALUE" ;;
            esac
            case "$PATH_VALUE" in
                */) ;;
                *) PATH_VALUE="$PATH_VALUE/" ;;
            esac
            echo "$PATH_VALUE" > "$XHTTP_PATH_FILE"
            if [ "$(get_transport)" = "xhttp" ]; then
                restart_xray >/dev/null 2>&1
            fi
            sync_keys_file >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
            log_action "xhttp_path_set" "$PATH_VALUE"
            echo "xhttp path saved: $PATH_VALUE"
            ;;
        method)
            METHOD_VALUE="$(printf '%s' "${2:-}" | tr '[:lower:]' '[:upper:]')"
            case "$METHOD_VALUE" in
                GET|POST|PUT)
                    echo "$METHOD_VALUE" > "$XHTTP_METHOD_FILE"
                    if [ "$(get_transport)" = "xhttp" ]; then
                        restart_xray >/dev/null 2>&1
                    fi
                    restart_api_if_running
                    log_action "xhttp_method_set" "$METHOD_VALUE"
                    echo "xhttp method saved: $METHOD_VALUE"
                    ;;
                *)
                    echo "usage: vpn xhttp method GET"
                    ;;
            esac
            ;;
        alpn)
            ALPN_VALUE="$(strip_outer_quotes "${2:-}")"
            if ! set_xhttp_alpn "$ALPN_VALUE"; then
                echo "usage: vpn xhttp alpn h2,http1|h2|http1|none"
                return 0
            fi
            sync_keys_file >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
            log_action "xhttp_alpn_set" "$(get_xhttp_alpn)"
            echo "xhttp alpn saved: $(get_xhttp_alpn)"
            ;;
        *)
            echo "usage: vpn xhttp on [PATH/] [GET|POST|PUT]"
            echo "       vpn xhttp off"
            echo "       vpn xhttp alpn h2,http1|h2|http1|none"
            echo "       vpn xhttp status"
            ;;
    esac

    return 0
}

cmd_mws() {
    local ACTION="${1:-status}"
    local DOMAIN_VALUE PATH_VALUE CERT_VALUE KEY_VALUE

    case "$ACTION" in
        status|"")
            print_line
            echo "MWS XHTTP"
            print_line
            if is_mws_enabled; then
                echo "status: enabled"
            else
                echo "status: disabled"
            fi
            echo "domain: $(get_mws_domain)"
            echo "xhttp path: $(get_xhttp_path)"
            echo "cert: $(get_mws_cert_file)"
            echo "key: $(get_mws_key_file)"
            echo "origin for MWS: https://$(read_public_ip):$(get_public_port)"
            echo "host header: $(get_mws_domain)"
            print_line
            ;;
        on|enable|enabled)
            DOMAIN_VALUE="$(normalize_domain "${2:-}")"
            PATH_VALUE="$(strip_outer_quotes "${3:-/xhttppath}")"
            CERT_VALUE="$(strip_outer_quotes "${4:-}")"
            KEY_VALUE="$(strip_outer_quotes "${5:-}")"
            if [ -z "$DOMAIN_VALUE" ]; then
                echo "usage: vpn mws on DOMAIN [PATH] [CERT_FILE] [KEY_FILE]"
                return 0
            fi
            case "$PATH_VALUE" in
                /*) ;;
                *) PATH_VALUE="/$PATH_VALUE" ;;
            esac
            echo "1" > "$MWS_ENABLED_FILE"
            echo "$DOMAIN_VALUE" > "$MWS_DOMAIN_FILE"
            echo "$PATH_VALUE" > "$XHTTP_PATH_FILE"
            echo "GET" > "$XHTTP_METHOD_FILE"
            echo "h2" > "$XHTTP_ALPN_FILE"
            if [ -n "$CERT_VALUE" ]; then
                echo "$CERT_VALUE" > "$MWS_CERT_FILE"
            else
                echo "/etc/letsencrypt/live/$DOMAIN_VALUE/fullchain.pem" > "$MWS_CERT_FILE"
            fi
            if [ -n "$KEY_VALUE" ]; then
                echo "$KEY_VALUE" > "$MWS_KEY_FILE"
            else
                echo "/etc/letsencrypt/live/$DOMAIN_VALUE/privkey.pem" > "$MWS_KEY_FILE"
            fi
            set_transport xhttp
            build_config >/dev/null 2>&1
            restart_xray >/dev/null 2>&1
            sync_keys_file >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
            log_action "mws_enabled" "$DOMAIN_VALUE path=$PATH_VALUE"
            echo "mws xhttp enabled"
            echo "MWS origin: https://$(read_public_ip):$(get_public_port)"
            echo "MWS Host header: $DOMAIN_VALUE"
            echo "MWS WebSocket: off"
            ;;
        off|disable|disabled)
            echo "0" > "$MWS_ENABLED_FILE"
            build_config >/dev/null 2>&1
            restart_xray >/dev/null 2>&1
            sync_keys_file >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
            log_action "mws_disabled" ""
            echo "mws xhttp disabled"
            ;;
        *)
            echo "usage: vpn mws on DOMAIN [PATH] [CERT_FILE] [KEY_FILE]"
            echo "       vpn mws off"
            echo "       vpn mws status"
            ;;
    esac
}

cmd_transport() {
    case "${1:-status}" in
        xhttp)
            shift
            cmd_xhttp on "$@"
            ;;
        ws)
            cmd_xhttp off
            ;;
        status|"")
            cmd_xhttp status
            ;;
        *)
            echo "usage: vpn transport ws|xhttp"
            ;;
    esac
    return 0
}

cmd_cdn() {
    local ACTION="${1:-status}"
    local CDN_HOST_VALUE SNI_HOST_VALUE PORT_VALUE TAG_VALUE PATH_VALUE

    case "$ACTION" in
        status|"")
            print_line
            echo "WS-CDN"
            print_line
            if is_cdn_ws_enabled; then
                echo "status: enabled"
                echo "cdn address: $(get_cdn_ws_host)"
                echo "sni/host: $(get_cdn_ws_sni)"
                echo "port: $(get_cdn_ws_port)"
                echo "tag suffix: $(get_cdn_ws_tag_suffix)"
                echo "path: $(get_cdn_ws_path)"
                echo "origin remains: $(read_domain):$(get_public_port) /xray"
            else
                echo "status: disabled"
                echo "enable: vpn cdn CDN_HOST SNI_HOST [PORT] [TAG_SUFFIX] [PATH]"
            fi
            print_line
            echo "XHTTP-CDN"
            print_line
            if is_cdn_xhttp_enabled; then
                echo "status: enabled"
                echo "cdn address: $(get_cdn_xhttp_host)"
                echo "sni/host: $(get_cdn_xhttp_sni)"
                echo "port: $(get_cdn_xhttp_port)"
                echo "tag suffix: $(get_cdn_xhttp_tag_suffix)"
                echo "public path: $(get_cdn_xhttp_public_path)"
                echo "origin remains: $(read_domain):$(get_public_port) $(get_xhttp_path)"
            else
                echo "status: disabled"
                echo "enable: vpn cdn xhttp CDN_HOST SNI_HOST [PORT] [TAG_SUFFIX] [PUBLIC_PATH/]"
            fi
            print_line
            ;;
        off|disable|disabled|stop)
            set_cdn_ws_enabled 0
            set_cdn_xhttp_enabled 0
            sync_keys_file >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
            log_action "cdn_disable" "all"
            echo "cdn links disabled"
            ;;
        xhttp)
            if [ "${2:-}" = "off" ] || [ "${2:-}" = "disable" ]; then
                set_cdn_xhttp_enabled 0
                sync_keys_file >/dev/null 2>&1
                restart_api_if_running
                restart_sub_if_running
                log_action "cdn_xhttp_disable" ""
                echo "xhttp-cdn disabled"
                return 0
            fi
            CDN_HOST_VALUE="$(normalize_domain "${2:-}")"
            SNI_HOST_VALUE="$(normalize_domain "${3:-}")"
            PORT_VALUE="${4:-443}"
            TAG_VALUE="$(strip_outer_quotes "${5:-CDN}")"
            PATH_VALUE="$(strip_outer_quotes "${6:-}")"
            if [ -z "$PATH_VALUE" ]; then
                case "$TAG_VALUE" in
                    /*)
                        PATH_VALUE="$TAG_VALUE"
                        TAG_VALUE="CDN"
                        ;;
                esac
            fi
            if [ -z "$PATH_VALUE" ]; then
                PATH_VALUE="$(get_xhttp_path)"
            fi
            case "$PATH_VALUE" in
                /*) ;;
                *) PATH_VALUE="/$PATH_VALUE" ;;
            esac
            if [ -z "$CDN_HOST_VALUE" ] || [ -z "$SNI_HOST_VALUE" ] || ! validate_port "$PORT_VALUE"; then
                echo "usage: vpn cdn xhttp CDN_HOST SNI_HOST [PORT] [TAG_SUFFIX] [PUBLIC_PATH/]"
                return 0
            fi
            echo "$CDN_HOST_VALUE" > "$CDN_XHTTP_HOST_FILE"
            echo "$SNI_HOST_VALUE" > "$CDN_XHTTP_SNI_FILE"
            echo "$PORT_VALUE" > "$CDN_XHTTP_PORT_FILE"
            echo "${TAG_VALUE:-CDN}" > "$CDN_XHTTP_TAG_FILE"
            echo "$PATH_VALUE" > "$CDN_XHTTP_PUBLIC_PATH_FILE"
            set_cdn_xhttp_enabled 1
            sync_keys_file >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
            log_action "cdn_xhttp_set" "cdn=$CDN_HOST_VALUE sni=$SNI_HOST_VALUE port=$PORT_VALUE tag=${TAG_VALUE:-CDN} path=$PATH_VALUE"
            echo "xhttp-cdn saved"
            echo "current and future clients will include xhttp-cdn links"
            ;;
        on|enable|add|ws)
            CDN_HOST_VALUE="$(normalize_domain "${2:-}")"
            SNI_HOST_VALUE="$(normalize_domain "${3:-}")"
            PORT_VALUE="${4:-443}"
            TAG_VALUE="$(strip_outer_quotes "${5:-CDN}")"
            PATH_VALUE="$(strip_outer_quotes "${6:-}")"
            if [ -z "$PATH_VALUE" ]; then
                case "$TAG_VALUE" in
                    /*)
                        PATH_VALUE="$TAG_VALUE"
                        TAG_VALUE="CDN"
                        ;;
                esac
            fi
            if [ -z "$PATH_VALUE" ]; then
                PATH_VALUE="/xray"
            fi
            case "$PATH_VALUE" in
                /*) ;;
                *) PATH_VALUE="/$PATH_VALUE" ;;
            esac
            if [ -z "$CDN_HOST_VALUE" ] || [ -z "$SNI_HOST_VALUE" ] || ! validate_port "$PORT_VALUE"; then
                echo "usage: vpn cdn CDN_HOST SNI_HOST [PORT] [TAG_SUFFIX] [PATH]"
                echo "or:    vpn cdn ws CDN_HOST SNI_HOST [PORT] [TAG_SUFFIX] [PATH]"
                return 0
            fi
            echo "$CDN_HOST_VALUE" > "$CDN_WS_HOST_FILE"
            echo "$SNI_HOST_VALUE" > "$CDN_WS_SNI_FILE"
            echo "$PORT_VALUE" > "$CDN_WS_PORT_FILE"
            echo "${TAG_VALUE:-CDN}" > "$CDN_WS_TAG_FILE"
            echo "$PATH_VALUE" > "$CDN_WS_PATH_FILE"
            set_cdn_ws_enabled 1
            sync_keys_file >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
            log_action "cdn_ws_set" "cdn=$CDN_HOST_VALUE sni=$SNI_HOST_VALUE port=$PORT_VALUE tag=${TAG_VALUE:-CDN} path=$PATH_VALUE"
            echo "ws-cdn saved"
            echo "current and future clients will include ws-cdn links"
            ;;
        *)
            CDN_HOST_VALUE="$(normalize_domain "$ACTION")"
            SNI_HOST_VALUE="$(normalize_domain "${2:-}")"
            PORT_VALUE="${3:-443}"
            TAG_VALUE="$(strip_outer_quotes "${4:-CDN}")"
            PATH_VALUE="$(strip_outer_quotes "${5:-}")"
            if [ -z "$PATH_VALUE" ]; then
                case "$TAG_VALUE" in
                    /*)
                        PATH_VALUE="$TAG_VALUE"
                        TAG_VALUE="CDN"
                        ;;
                esac
            fi
            if [ -z "$PATH_VALUE" ]; then
                PATH_VALUE="/xray"
            fi
            case "$PATH_VALUE" in
                /*) ;;
                *) PATH_VALUE="/$PATH_VALUE" ;;
            esac
            if [ -z "$CDN_HOST_VALUE" ] || [ -z "$SNI_HOST_VALUE" ] || ! validate_port "$PORT_VALUE"; then
                echo "usage: vpn cdn CDN_HOST SNI_HOST [PORT] [TAG_SUFFIX] [PATH]"
                return 0
            fi
            echo "$CDN_HOST_VALUE" > "$CDN_WS_HOST_FILE"
            echo "$SNI_HOST_VALUE" > "$CDN_WS_SNI_FILE"
            echo "$PORT_VALUE" > "$CDN_WS_PORT_FILE"
            echo "${TAG_VALUE:-CDN}" > "$CDN_WS_TAG_FILE"
            echo "$PATH_VALUE" > "$CDN_WS_PATH_FILE"
            set_cdn_ws_enabled 1
            sync_keys_file >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
            log_action "cdn_ws_set" "cdn=$CDN_HOST_VALUE sni=$SNI_HOST_VALUE port=$PORT_VALUE tag=${TAG_VALUE:-CDN} path=$PATH_VALUE"
            echo "ws-cdn saved"
            echo "current and future clients will include ws-cdn links"
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
    # Р’РЎР• РїРµСЂРµРјРµРЅРЅС‹Рµ С„СѓРЅРєС†РёРё вЂ” local, РёРЅР°С‡Рµ РѕРЅРё РєРѕРЅС„Р»РёРєС‚СѓСЋС‚ СЃ С‚Р°РєРёРјРё Р¶Рµ
    # РёРјРµРЅР°РјРё РІ start_sub_process/restart_api_if_running/keep_api_alive
    # (Р±С‹РІР°Р»Рѕ, С‡С‚Рѕ api РїСЂРё СЃС‚Р°СЂС‚Рµ РїРµС‡Р°С‚Р°Р» С‡СѓР¶РѕР№ РїРѕСЂС‚).
    local API_BIND_PORT="$1"
    local TOKEN LOCAL_PORT PUBLIC_PORT_VALUE NODE_NAME_VALUE
    local REALITY_ENABLED_VALUE REALITY_LOCAL_PORT_VALUE REALITY_PUBLIC_PORT_VALUE REALITY_PUBLIC_HOST_VALUE
    local REALITY_SNI_VALUE REALITY_DEST_VALUE
    local REALITY_PRIVATE_KEY_VALUE REALITY_PUBLIC_KEY_VALUE REALITY_SHORT_ID_VALUE
    local SUB_PORT_VALUE SUB_TOKEN_VALUE SUB_PUBLIC_HOST_VALUE RUNNING_PORT
    local API_PUBLIC_HOST_VALUE JOIN_TOKEN_VALUE
    local SUB_NAME_VALUE CDN_WS_ENABLED_VALUE CDN_WS_HOST_VALUE CDN_WS_SNI_VALUE CDN_WS_PORT_VALUE CDN_WS_TAG_VALUE CDN_WS_PATH_VALUE
    local TRANSPORT_VALUE XHTTP_PATH_VALUE XHTTP_METHOD_VALUE
    local CDN_XHTTP_ENABLED_VALUE CDN_XHTTP_HOST_VALUE CDN_XHTTP_SNI_VALUE CDN_XHTTP_PORT_VALUE CDN_XHTTP_TAG_VALUE CDN_XHTTP_PUBLIC_PATH_VALUE

    if ! validate_port "$API_BIND_PORT"; then
        echo "usage: vpn api PORT"
        echo "port must be 1-65535"
        return 0
    fi

    if ! check_port_conflict "$API_BIND_PORT" "api"; then
        return 0
    fi

    if api_is_running; then
        RUNNING_PORT="$(cat "$API_PORT_FILE" 2>/dev/null)"
        echo "api already running: 0.0.0.0:${RUNNING_PORT:-unknown}"
        echo "token: $(get_api_token)"
        return 0
    fi

    TOKEN="$(get_api_token)"
    JOIN_TOKEN_VALUE="$(get_join_token)"
    LOCAL_PORT="$(get_port)"
    PUBLIC_PORT_VALUE="$(get_public_port)"
    API_PUBLIC_HOST_VALUE="$(read_subscription_host)"
    NODE_NAME_VALUE="$(get_node_name)"
    REALITY_ENABLED_VALUE="0"
    REALITY_LOCAL_PORT_VALUE=""
    REALITY_PUBLIC_PORT_VALUE=""
    REALITY_PUBLIC_HOST_VALUE=""
    REALITY_SNI_VALUE=""
    REALITY_DEST_VALUE=""
    REALITY_PRIVATE_KEY_VALUE=""
    REALITY_PUBLIC_KEY_VALUE=""
    REALITY_SHORT_ID_VALUE=""
    if is_reality_enabled && ensure_reality_files >/dev/null 2>&1; then
        REALITY_ENABLED_VALUE="1"
        REALITY_LOCAL_PORT_VALUE="$(get_reality_port)"
        REALITY_PUBLIC_PORT_VALUE="$(get_public_reality_port)"
        REALITY_PUBLIC_HOST_VALUE="$(read_reality_host)"
        REALITY_SNI_VALUE="$(get_reality_sni)"
        REALITY_DEST_VALUE="$(get_reality_dest)"
        REALITY_PRIVATE_KEY_VALUE="$(read_reality_private_key)"
        REALITY_PUBLIC_KEY_VALUE="$(read_reality_public_key)"
        REALITY_SHORT_ID_VALUE="$(read_reality_short_id)"
    fi
    SUB_PORT_VALUE="$(get_sub_port)"
    SUB_TOKEN_VALUE=""
    SUB_PUBLIC_HOST_VALUE=""
    SUB_NAME_VALUE="$(get_sub_name)"
    CDN_WS_ENABLED_VALUE="0"
    CDN_WS_HOST_VALUE=""
    CDN_WS_SNI_VALUE=""
    CDN_WS_PORT_VALUE=""
    CDN_WS_TAG_VALUE=""
    CDN_WS_PATH_VALUE=""
    TRANSPORT_VALUE="$(get_transport)"
    XHTTP_PATH_VALUE="$(get_xhttp_path)"
    XHTTP_METHOD_VALUE="$(get_xhttp_method)"
    CDN_XHTTP_ENABLED_VALUE="0"
    CDN_XHTTP_HOST_VALUE=""
    CDN_XHTTP_SNI_VALUE=""
    CDN_XHTTP_PORT_VALUE=""
    CDN_XHTTP_TAG_VALUE=""
    CDN_XHTTP_PUBLIC_PATH_VALUE=""

    if [ -n "$SUB_PORT_VALUE" ] && validate_port "$SUB_PORT_VALUE"; then
        SUB_TOKEN_VALUE="$(get_sub_token)"
        SUB_PUBLIC_HOST_VALUE="$(read_subscription_host)"
    fi

    if is_cdn_ws_enabled; then
        CDN_WS_ENABLED_VALUE="1"
        CDN_WS_HOST_VALUE="$(get_cdn_ws_host)"
        CDN_WS_SNI_VALUE="$(get_cdn_ws_sni)"
        CDN_WS_PORT_VALUE="$(get_cdn_ws_port)"
        CDN_WS_TAG_VALUE="$(get_cdn_ws_tag_suffix)"
        CDN_WS_PATH_VALUE="$(get_cdn_ws_path)"
    fi

    if is_cdn_xhttp_enabled; then
        CDN_XHTTP_ENABLED_VALUE="1"
        CDN_XHTTP_HOST_VALUE="$(get_cdn_xhttp_host)"
        CDN_XHTTP_SNI_VALUE="$(get_cdn_xhttp_sni)"
        CDN_XHTTP_PORT_VALUE="$(get_cdn_xhttp_port)"
        CDN_XHTTP_TAG_VALUE="$(get_cdn_xhttp_tag_suffix)"
        CDN_XHTTP_PUBLIC_PATH_VALUE="$(get_cdn_xhttp_public_path)"
    fi

    python3 -u - "$USERS_FILE" "$KEY_FILE" "$CONFIG_FILE" "$DOMAIN_FILE" "$API_TOKEN_FILE" "$ACTION_LOG_FILE" "$API_BIND_PORT" "$LOCAL_PORT" "$PUBLIC_PORT_VALUE" "$NODE_NAME_VALUE" "$REALITY_ENABLED_VALUE" "$REALITY_LOCAL_PORT_VALUE" "$REALITY_PUBLIC_PORT_VALUE" "$REALITY_PUBLIC_HOST_VALUE" "$REALITY_SNI_VALUE" "$REALITY_DEST_VALUE" "$REALITY_PRIVATE_KEY_VALUE" "$REALITY_PUBLIC_KEY_VALUE" "$REALITY_SHORT_ID_VALUE" "$SUB_PORT_VALUE" "$SUB_TOKEN_VALUE" "$SUB_PUBLIC_HOST_VALUE" "$NODE_NAME_FILE" "$PEERS_FILE" "$UPSTREAM_API_URL_FILE" "$UPSTREAM_API_TOKEN_FILE" "$NODES_FILE" "$JOIN_TOKEN_FILE" "$BACKUP_DIR" "$API_PUBLIC_HOST_VALUE" "$XRAY_STATS_PORT" "$XRAY_BIN" "$UPDATE_URL_FILE" "$AUTO_UPDATE_FILE" "$SUB_NAME_VALUE" "$CDN_WS_ENABLED_VALUE" "$CDN_WS_HOST_VALUE" "$CDN_WS_SNI_VALUE" "$CDN_WS_PORT_VALUE" "$CDN_WS_TAG_VALUE" "$CDN_WS_PATH_VALUE" "$SUB_TOKEN_FILE" "$REALITY_ENABLED_FILE" "$REALITY_PRIVATE_KEY_FILE" "$REALITY_PUBLIC_KEY_FILE" "$REALITY_SHORT_ID_FILE" "$REALITY_SNI_FILE" "$REALITY_DEST_FILE" "$REALITY_PORT_FILE" "$REALITY_PUBLIC_PORT_FILE" "$PUBLIC_IP_FILE" "$SUB_NAME_FILE" "$CDN_WS_ENABLED_FILE" "$CDN_WS_HOST_FILE" "$CDN_WS_SNI_FILE" "$CDN_WS_PORT_FILE" "$CDN_WS_TAG_FILE" "$CDN_WS_PATH_FILE" "$DEVICES_FILE" "$TRAFFIC_FILE" "$TRANSPORT_VALUE" "$XHTTP_PATH_VALUE" "$XHTTP_METHOD_VALUE" "$CDN_XHTTP_ENABLED_VALUE" "$CDN_XHTTP_HOST_VALUE" "$CDN_XHTTP_SNI_VALUE" "$CDN_XHTTP_PORT_VALUE" "$CDN_XHTTP_TAG_VALUE" "$CDN_XHTTP_PUBLIC_PATH_VALUE" "$TRANSPORT_FILE" "$XHTTP_PATH_FILE" "$XHTTP_METHOD_FILE" "$CDN_XHTTP_ENABLED_FILE" "$CDN_XHTTP_HOST_FILE" "$CDN_XHTTP_SNI_FILE" "$CDN_XHTTP_PORT_FILE" "$CDN_XHTTP_TAG_FILE" "$CDN_XHTTP_PUBLIC_PATH_FILE" <<'PY' &
import datetime
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
import zipfile

def read_tag_suffix(name, default):
    try:
        with open(name, "r", encoding="utf-8") as f:
            return f.readline().strip()
    except Exception:
        return default


def link_tag(base, suffix):
    base = str(base or "").strip()
    suffix = str(suffix or "").strip()
    if not suffix:
        return base
    if suffix[:1] in ("-", "_", "/", "#", "(", "["):
        return base + suffix
    return (base + " " + suffix).strip()

def xhttp_client_extra(method):
    method = (method or "GET").upper()
    if method not in ("GET", "POST", "PUT"):
        method = "GET"
    return {
        "xmux": {
            "cMaxReuseTimes": "48-96",
            "maxConcurrency": "4-8",
            "maxConnections": 0,
            "hKeepAlivePeriod": 0,
            "hMaxRequestTimes": "500-900",
            "hMaxReusableSecs": "300-900",
        },
        "seqKey": "page",
        "sessionKey": "X-Request-Id",
        "xPaddingKey": "_dc",
        "seqPlacement": "query",
        "uplinkDataKey": "X-Payload",
        "xPaddingBytes": "80-240",
        "xPaddingMethod": "tokenish",
        "uplinkChunkSize": "1024-2048",
        "sessionPlacement": "header",
        "uplinkHTTPMethod": method,
        "xPaddingObfsMode": True,
        "xPaddingPlacement": "query",
        "scMaxEachPostBytes": "4096-8192",
        "uplinkDataPlacement": "header",
    }


def xhttp_extra_param(method):
    extra = json.dumps(xhttp_client_extra(method), ensure_ascii=False, separators=(",", ":"))
    return urllib.parse.quote(extra, safe="")


def read_xhttp_alpn(default="h2,http1"):
    try:
        with open("xhttp_alpn.txt", "r", encoding="utf-8") as f:
            value = f.readline().strip().lower()
    except Exception:
        value = default
    aliases = {
        "h2,http1": "h2,http1",
        "h2,http/1.1": "h2,http1",
        "h2,http1.1": "h2,http1",
        "h2,http2": "h2,http1",
        "h2,1.1": "h2,http1",
        "h2": "h2",
        "http2": "h2",
        "2": "h2",
        "none": "none",
        "off": "none",
        "disabled": "none",
        "auto": "none",
        "default": "none",
        "http1": "http1",
        "http1.1": "http1",
        "http/1.1": "http1",
        "1": "http1",
        "1.1": "http1",
        "": default,
    }
    return aliases.get(value, default)


def xhttp_alpn_query():
    value = read_xhttp_alpn()
    if value == "h2,http1":
        return "&alpn=h2%2Chttp%2F1.1"
    if value == "h2":
        return "&alpn=h2"
    if value == "none":
        return ""
    return "&alpn=http%2F1.1"


def read_mws_enabled():
    try:
        with open("mws_enabled.txt", "r", encoding="utf-8") as f:
            value = f.readline().strip().lower()
        return value in ("1", "true", "yes", "on", "enabled")
    except Exception:
        return False


def normalize_xhttp_path_py(path):
    path = str(path or "/api/v1/sync/").strip()
    if not path.startswith("/"):
        path = "/" + path
    if not path.endswith("/"):
        path += "/"
    return path


def build_xhttp_vless(client_id, address, port, path, host_header, tag, security="none", sni="", method="GET"):
    path = urllib.parse.quote(normalize_xhttp_path_py(path), safe="")
    tag = urllib.parse.quote(tag, safe="")
    if read_mws_enabled():
        url = f"vless://{client_id}@{address}:{port}?encryption=none&type=xhttp&path={path}&host={host_header}&mode=auto"
    else:
        extra = xhttp_extra_param(method)
        url = f"vless://{client_id}@{address}:{port}?encryption=none&type=xhttp&path={path}&host={host_header}&mode=packet-up&extra={extra}"
    if security == "tls":
        url += f"&security=tls&sni={sni or host_header}&fp=chrome{xhttp_alpn_query()}"
    else:
        url += "&security=none"
    return url + f"#{tag}"

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
NODE_NAME = sys.argv[10].strip()
REALITY_ENABLED = sys.argv[11] == "1"
REALITY_PORT = 0
if REALITY_ENABLED:
    try:
        REALITY_PORT = int(sys.argv[12])
    except Exception:
        REALITY_ENABLED = False
PUBLIC_REALITY_PORT = sys.argv[13]
REALITY_PUBLIC_HOST = sys.argv[14]
REALITY_SNI = sys.argv[15]
REALITY_DEST = sys.argv[16]
REALITY_PRIVATE_KEY = sys.argv[17]
REALITY_PUBLIC_KEY = sys.argv[18]
REALITY_SHORT_ID = sys.argv[19]
SUB_PORT = sys.argv[20]
SUB_TOKEN = sys.argv[21]
SUB_PUBLIC_HOST = sys.argv[22]
NODE_NAME_FILE = sys.argv[23]
PEERS_FILE = sys.argv[24]
UPSTREAM_API_URL_FILE = sys.argv[25]
UPSTREAM_API_TOKEN_FILE = sys.argv[26]
NODES_FILE = sys.argv[27]
JOIN_TOKEN_FILE = sys.argv[28]
BACKUP_DIR = sys.argv[29]
API_PUBLIC_HOST = sys.argv[30]
XRAY_STATS_PORT = int(sys.argv[31])
XRAY_BIN = sys.argv[32]
UPDATE_URL_FILE = sys.argv[33]
AUTO_UPDATE_FILE = sys.argv[34]
SUB_NAME = sys.argv[35].strip()
CDN_WS_ENABLED = sys.argv[36] == "1"
CDN_WS_HOST = sys.argv[37]
CDN_WS_SNI = sys.argv[38] or CDN_WS_HOST
CDN_WS_PORT = sys.argv[39] or "443"
CDN_WS_TAG = sys.argv[40] or "CDN"
CDN_WS_PATH = sys.argv[41] or "/xray"
API_TOKEN_FILE = TOKEN_FILE
SUB_TOKEN_FILE = sys.argv[42]
REALITY_ENABLED_FILE = sys.argv[43]
REALITY_PRIVATE_KEY_FILE = sys.argv[44]
REALITY_PUBLIC_KEY_FILE = sys.argv[45]
REALITY_SHORT_ID_FILE = sys.argv[46]
REALITY_SNI_FILE = sys.argv[47]
REALITY_DEST_FILE = sys.argv[48]
REALITY_PORT_FILE = sys.argv[49]
REALITY_PUBLIC_PORT_FILE = sys.argv[50]
PUBLIC_IP_FILE = sys.argv[51]
SUB_NAME_FILE = sys.argv[52]
CDN_WS_ENABLED_FILE = sys.argv[53]
CDN_WS_HOST_FILE = sys.argv[54]
CDN_WS_SNI_FILE = sys.argv[55]
CDN_WS_PORT_FILE = sys.argv[56]
CDN_WS_TAG_FILE = sys.argv[57]
CDN_WS_PATH_FILE = sys.argv[58]
DEVICES_FILE = sys.argv[59]
TRAFFIC_FILE = sys.argv[60]
TRANSPORT = sys.argv[61] if len(sys.argv) > 61 else "ws"
XHTTP_PATH = sys.argv[62] if len(sys.argv) > 62 and sys.argv[62] else "/api/v1/sync/"
XHTTP_METHOD = (sys.argv[63] if len(sys.argv) > 63 and sys.argv[63] else "GET").upper()
CDN_XHTTP_ENABLED = len(sys.argv) > 64 and sys.argv[64] == "1"
CDN_XHTTP_HOST = sys.argv[65] if len(sys.argv) > 65 else ""
CDN_XHTTP_SNI = (sys.argv[66] if len(sys.argv) > 66 else "") or CDN_XHTTP_HOST
CDN_XHTTP_PORT = (sys.argv[67] if len(sys.argv) > 67 else "") or "443"
CDN_XHTTP_TAG = (sys.argv[68] if len(sys.argv) > 68 else "") or "CDN"
CDN_XHTTP_PUBLIC_PATH = (sys.argv[69] if len(sys.argv) > 69 and sys.argv[69] else "") or XHTTP_PATH
TRANSPORT_FILE = sys.argv[70] if len(sys.argv) > 70 else ""
XHTTP_PATH_FILE = sys.argv[71] if len(sys.argv) > 71 else ""
XHTTP_METHOD_FILE = sys.argv[72] if len(sys.argv) > 72 else ""
CDN_XHTTP_ENABLED_FILE = sys.argv[73] if len(sys.argv) > 73 else ""
CDN_XHTTP_HOST_FILE = sys.argv[74] if len(sys.argv) > 74 else ""
CDN_XHTTP_SNI_FILE = sys.argv[75] if len(sys.argv) > 75 else ""
CDN_XHTTP_PORT_FILE = sys.argv[76] if len(sys.argv) > 76 else ""
CDN_XHTTP_TAG_FILE = sys.argv[77] if len(sys.argv) > 77 else ""
CDN_XHTTP_PUBLIC_PATH_FILE = sys.argv[78] if len(sys.argv) > 78 else ""
if TRANSPORT != "xhttp":
    TRANSPORT = "ws"
if not XHTTP_PATH.startswith("/"):
    XHTTP_PATH = "/" + XHTTP_PATH
if not XHTTP_PATH.endswith("/"):
    XHTTP_PATH += "/"
if XHTTP_METHOD not in ("GET", "POST", "PUT"):
    XHTTP_METHOD = "GET"
if not CDN_XHTTP_PUBLIC_PATH.startswith("/"):
    CDN_XHTTP_PUBLIC_PATH = "/" + CDN_XHTTP_PUBLIC_PATH
if not CDN_XHTTP_PUBLIC_PATH.endswith("/"):
    CDN_XHTTP_PUBLIC_PATH += "/"

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


def read_first_line(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.readline().strip()
    except Exception:
        return ""


def enabled_from_file(path):
    return read_first_line(path).strip().lower() in ("1", "true", "yes", "on", "enabled")


def read_node_name():
    value = read_first_line(NODE_NAME_FILE)
    if value:
        return value
    return NODE_NAME or read_domain()


def validate_label(value, max_len=80):
    text = str(value or "").strip()
    if not text or len(text) > max_len:
        return False
    return not any(ch in text for ch in "\r\n\t")


def strip_outer_quotes(value):
    text = str(value or "").strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in ("'", '"'):
        return text[1:-1].strip()
    return text


def slugify_label(value):
    text = strip_outer_quotes(value).lower()
    table = {
        "Р°": "a", "Р±": "b", "РІ": "v", "Рі": "g", "Рґ": "d", "Рµ": "e", "С‘": "e",
        "Р¶": "zh", "Р·": "z", "Рё": "i", "Р№": "y", "Рє": "k", "Р»": "l", "Рј": "m",
        "РЅ": "n", "Рѕ": "o", "Рї": "p", "СЂ": "r", "СЃ": "s", "С‚": "t", "Сѓ": "u",
        "С„": "f", "С…": "h", "С†": "c", "С‡": "ch", "С€": "sh", "С‰": "sch",
        "СЉ": "", "С‹": "y", "СЊ": "", "СЌ": "e", "СЋ": "yu", "СЏ": "ya",
    }
    result = []
    for ch in text:
        if ch in table:
            result.append(table[ch])
        elif ch.isascii() and (ch.isalnum() or ch in "._-"):
            result.append(ch)
        elif ch.isspace() or ch in "/\\:;,+()[]{}":
            result.append("-")
    slug = re.sub(r"[-_.]{2,}", "-", "".join(result)).strip("-_.")
    if not slug:
        slug = "node-" + hashlib.sha1(text.encode("utf-8", "ignore")).hexdigest()[:8]
    return slug[:48].strip("-_.") or "node"


def load_peers():
    peers = []
    try:
        with open(PEERS_FILE, "r", encoding="utf-8") as f:
            rows = [line.rstrip("\n") for line in f]
    except Exception:
        rows = []

    for row in rows:
        if not row.strip() or "|" not in row:
            continue
        name, url = row.split("|", 1)
        name = strip_outer_quotes(name)
        url = strip_outer_quotes(url)
        if validate_name(name) and url:
            peers.append({"name": name, "url": url})
    return peers


def save_peers(peers):
    rows = []
    for peer in peers:
        name = strip_outer_quotes(peer.get("name", ""))
        url = strip_outer_quotes(peer.get("url", ""))
        if validate_name(name) and url:
            rows.append(f"{name}|{url}")
    atomic_text(PEERS_FILE, "\n".join(rows).rstrip() + ("\n" if rows else ""))


def load_nodes():
    try:
        with open(NODES_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, list) else []
    except Exception:
        return []


def save_nodes(nodes):
    atomic_json(NODES_FILE, nodes)


def load_devices():
    try:
        with open(DEVICES_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def save_devices(devices):
    atomic_json(DEVICES_FILE, devices)


def load_traffic():
    try:
        with open(TRAFFIC_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def save_traffic(traffic):
    atomic_json(TRAFFIC_FILE, traffic)


def gb_from_bytes(value):
    try:
        return round(int(value) / 1073741824, 3)
    except Exception:
        return 0


def parse_limit_bytes(value):
    text = str(value or "").strip().lower()
    if text in ("", "0", "off", "none", "unlimited", "no"):
        return 0
    try:
        gb = float(text.replace(",", "."))
    except Exception:
        raise ValueError("bad_traffic_limit")
    if gb < 0:
        raise ValueError("bad_traffic_limit")
    return int(gb * 1073741824)


def parse_device_limit_value(value):
    text = str(value or "").strip().lower()
    if text in ("", "0", "off", "none", "unlimited", "no"):
        return 0
    try:
        count = int(text)
    except Exception:
        raise ValueError("bad_device_limit")
    if count < 0:
        raise ValueError("bad_device_limit")
    return count


def read_join_token():
    return read_first_line(JOIN_TOKEN_FILE)


def public_api_url():
    host = API_PUBLIC_HOST or read_domain()
    return f"http://{host}:{API_PORT}/api"


def node_health_from_url(url):
    clean = strip_outer_quotes(url)
    try:
        parsed = urllib.parse.urlparse(clean)
        if not parsed.scheme or not parsed.netloc:
            return {"ok": False, "error": "bad_url"}
        health_url = urllib.parse.urlunparse((parsed.scheme, parsed.netloc, "/health", "", "", ""))
        started = time.time()
        req = urllib.request.Request(health_url, headers={"User-Agent": "H1CloudVPNHealth/1.0"})
        with urllib.request.urlopen(req, timeout=3) as resp:
            body = resp.read(8192).decode("utf-8", "ignore")
        latency_ms = int((time.time() - started) * 1000)
        payload = {}
        try:
            payload = json.loads(body)
        except Exception:
            pass
        return {"ok": True, "url": health_url, "latency_ms": latency_ms, "payload": payload}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


def nodes_with_health():
    peers = load_peers()
    nodes = load_nodes()
    by_name = {str(node.get("name", "")): dict(node) for node in nodes if isinstance(node, dict)}
    result = []
    for peer in peers:
        name = peer.get("name", "")
        node = by_name.get(name, {"name": name})
        node["sub_url"] = peer.get("url", node.get("sub_url", ""))
        node["health"] = node_health_from_url(node["sub_url"])
        result.append(node)
    return result


def backup_targets():
    names = [
        USERS_FILE, DEVICES_FILE, TRAFFIC_FILE, DOMAIN_FILE, CONFIG_FILE, KEY_FILE, NODE_NAME_FILE, ACTION_LOG_FILE,
        API_TOKEN_FILE, SUB_TOKEN_FILE, PEERS_FILE, NODES_FILE, JOIN_TOKEN_FILE,
        UPSTREAM_API_URL_FILE, UPSTREAM_API_TOKEN_FILE, UPDATE_URL_FILE, AUTO_UPDATE_FILE,
        SUB_NAME_FILE, TRANSPORT_FILE, XHTTP_PATH_FILE, XHTTP_METHOD_FILE,
        CDN_WS_ENABLED_FILE, CDN_WS_HOST_FILE, CDN_WS_SNI_FILE,
        CDN_WS_PORT_FILE, CDN_WS_TAG_FILE, CDN_WS_PATH_FILE,
        CDN_XHTTP_ENABLED_FILE, CDN_XHTTP_HOST_FILE, CDN_XHTTP_SNI_FILE,
        CDN_XHTTP_PORT_FILE, CDN_XHTTP_TAG_FILE, CDN_XHTTP_PUBLIC_PATH_FILE,
        REALITY_ENABLED_FILE, REALITY_PRIVATE_KEY_FILE, REALITY_PUBLIC_KEY_FILE,
        REALITY_SHORT_ID_FILE, REALITY_SNI_FILE, REALITY_DEST_FILE,
        REALITY_PORT_FILE, REALITY_PUBLIC_PORT_FILE, PUBLIC_IP_FILE,
    ]
    return [path for path in names if path and os.path.exists(path) and os.path.isfile(path)]


def list_backups():
    try:
        rows = []
        for name in os.listdir(BACKUP_DIR):
            if not name.endswith(".zip"):
                continue
            path = os.path.join(BACKUP_DIR, name)
            rows.append({
                "name": name,
                "path": path,
                "size": os.path.getsize(path),
                "created_at": int(os.path.getmtime(path)),
            })
        return sorted(rows, key=lambda item: item["created_at"], reverse=True)
    except Exception:
        return []


def create_backup():
    os.makedirs(BACKUP_DIR, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    path = os.path.join(BACKUP_DIR, f"backup-{stamp}.zip")
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for src in backup_targets():
            zf.write(src, arcname=os.path.basename(src))
    log_action("backup_create", path)
    return path


def federation_payload():
    upstream_url = read_first_line(UPSTREAM_API_URL_FILE)
    return {
        "enabled": bool(upstream_url and read_first_line(UPSTREAM_API_TOKEN_FILE)),
        "upstream_url": upstream_url,
    }


def upstream_config():
    api_url = strip_outer_quotes(read_first_line(UPSTREAM_API_URL_FILE)).rstrip("/")
    token = strip_outer_quotes(read_first_line(UPSTREAM_API_TOKEN_FILE))
    if not api_url or not token:
        return "", ""
    return api_url, token


def upstream_enabled():
    api_url, token = upstream_config()
    return bool(api_url and token)


def upstream_request(method, path, payload=None):
    api_url, token = upstream_config()
    if not api_url or not token:
        raise ValueError("upstream_disabled")

    body = None
    headers = {
        "Authorization": f"Bearer {token}",
        "User-Agent": "H1CloudVPNAPIProxy/1.0",
    }
    if payload is not None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"

    if not path.startswith("/"):
        path = "/" + path

    req = urllib.request.Request(api_url + path, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            text = resp.read(1024 * 1024).decode("utf-8", "ignore")
    except urllib.error.HTTPError as exc:
        text = exc.read().decode("utf-8", "ignore")
        try:
            detail = json.loads(text).get("error") or text
        except Exception:
            detail = text or exc.reason
        raise ValueError(f"upstream_http_{exc.code}: {detail}")

    try:
        data = json.loads(text) if text else {}
    except Exception:
        data = {}

    if data and data.get("ok") is False:
        raise ValueError(str(data.get("error", "upstream_failed")))
    return data


def sync_users_from_upstream():
    data = upstream_request("GET", "/clients")
    clients = data.get("clients", [])
    if not isinstance(clients, list):
        raise ValueError("bad_upstream_clients")

    users = []
    for item in clients:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name", "")).strip()
        client_id = str(item.get("uuid", "")).strip()
        try:
            created_at = int(item.get("created_at", 0))
            expires_at = int(item.get("expires_at", 0))
        except Exception:
            continue
        if not name or not client_id or expires_at <= 0:
            continue
        row = {
            "name": name,
            "uuid": client_id,
            "created_at": created_at,
            "expires_at": expires_at,
            "banned": bool(item.get("banned") or item.get("disabled")),
            "banned_at": int(item.get("banned_at", 0) or 0),
            "ban_reason": str(item.get("ban_reason", "") or ""),
        }
        row["traffic_limit_bytes"] = int(item.get("traffic_limit_bytes", 0) or 0)
        row["device_limit"] = int(item.get("device_limit", 0) or 0)
        if item.get("traffic_reset_pending"):
            row["traffic_reset_pending"] = True
        users.append(row)

    save_users(users)
    log_action("api_upstream_sync", f"users={len(users)}")
    return users


def find_user_by_name(users, name):
    for user in users:
        if user.get("name") == name:
            return user
    return None


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
    tag = urllib.parse.quote(link_tag(read_node_name() or domain, read_tag_suffix("tag_ws.txt", "WS")), safe="")
    if str(PUBLIC_PORT) == "443":
        return (
            f"vless://{client_id}@{domain}:{PUBLIC_PORT}"
            f"?type=ws&security=tls&sni={domain}&host={domain}&path=%2Fxray&encryption=none#{tag}"
        )
    return (
        f"vless://{client_id}@{domain}:{PUBLIC_PORT}"
        f"?type=ws&security=none&host={domain}&path=%2Fxray&encryption=none#{tag}"
    )


def make_xhttp_link(user):
    client_id = str(user.get("uuid", ""))
    domain = read_domain()
    security = "tls" if str(PUBLIC_PORT) == "443" else "none"
    return build_xhttp_vless(client_id, domain, PUBLIC_PORT, XHTTP_PATH, domain, link_tag(read_node_name() or domain, read_tag_suffix("tag_xhttp.txt", "XHTTP")), security=security, sni=domain, method=XHTTP_METHOD)


def make_cdn_ws_link(user):
    if not CDN_WS_ENABLED or not CDN_WS_HOST:
        return ""
    client_id = str(user.get("uuid", ""))
    tag = urllib.parse.quote(link_tag(link_tag(read_node_name() or read_domain(), read_tag_suffix("tag_ws.txt", "WS")), CDN_WS_TAG).replace(" ", "-"), safe="")
    return (
        f"vless://{client_id}@{CDN_WS_HOST}:{CDN_WS_PORT}"
        f"?security=tls&sni={CDN_WS_SNI}&type=ws&path={urllib.parse.quote(CDN_WS_PATH, safe='')}"
        f"&host={CDN_WS_SNI}&encryption=none#{tag}"
    )


def make_cdn_xhttp_link(user):
    if not CDN_XHTTP_ENABLED or not CDN_XHTTP_HOST:
        return ""
    client_id = str(user.get("uuid", ""))
    tag = link_tag(read_node_name() or read_domain(), CDN_XHTTP_TAG).replace(" ", "-")
    return build_xhttp_vless(client_id, CDN_XHTTP_HOST, CDN_XHTTP_PORT, CDN_XHTTP_PUBLIC_PATH, CDN_XHTTP_SNI, tag, security="tls", sni=CDN_XHTTP_SNI, method=XHTTP_METHOD)


def make_reality_link(user):
    if not REALITY_ENABLED:
        return ""
    name = str(user.get("name", ""))
    client_id = str(user.get("uuid", ""))
    host = REALITY_PUBLIC_HOST or read_domain()
    tag = urllib.parse.quote(link_tag(read_node_name() or read_domain(), read_tag_suffix("tag_reality.txt", "Reality")), safe="")
    return (
        f"vless://{client_id}@{host}:{PUBLIC_REALITY_PORT}"
        f"?type=tcp&security=reality&pbk={REALITY_PUBLIC_KEY}&fp=chrome"
        f"&sni={REALITY_SNI}&sid={REALITY_SHORT_ID}&spx=%2F"
        f"&flow=xtls-rprx-vision&encryption=none#{tag}"
    )


def make_links(user):
    links = {}
    if TRANSPORT == "xhttp":
        links["xhttp"] = make_xhttp_link(user)
    else:
        links["ws"] = make_ws_link(user)
    cdn_link = make_cdn_ws_link(user)
    if cdn_link:
        links["ws_cdn"] = cdn_link
    cdn_link = make_cdn_xhttp_link(user)
    if cdn_link:
        links["xhttp_cdn"] = cdn_link
    if REALITY_ENABLED:
        links["reality"] = make_reality_link(user)
    return links


def make_subscription_url(user):
    if not SUB_PORT:
        return ""
    client_id = urllib.parse.quote(str(user.get("uuid", "")), safe="")
    if not client_id:
        return ""
    host = SUB_PUBLIC_HOST or read_domain()
    url = f"http://{host}:{SUB_PORT}/sub/{client_id}"
    if SUB_NAME:
        url += "#" + urllib.parse.quote(SUB_NAME, safe="")
    return url


def client_payload(user):
    current = now_ts()
    expires_at = int(user.get("expires_at", 0))
    left = max(0, expires_at - current)
    banned = bool(user.get("banned") or user.get("disabled"))
    links = {} if banned else make_links(user)
    subscription_url = "" if banned else make_subscription_url(user)
    client_id = str(user.get("uuid", ""))
    devices = load_devices().get(client_id, [])
    if not isinstance(devices, list):
        devices = []
    traffic_row = load_traffic().get(client_id, {})
    if not isinstance(traffic_row, dict):
        traffic_row = {}
    traffic_used = int(traffic_row.get("used_bytes", 0) or 0)
    traffic_limit = int(user.get("traffic_limit_bytes", 0) or 0)
    device_limit = int(user.get("device_limit", 0) or 0)
    return {
        "name": user.get("name"),
        "uuid": client_id,
        "status": "banned" if banned else "active",
        "banned": banned,
        "banned_at": int(user.get("banned_at", 0) or 0),
        "ban_reason": user.get("ban_reason", ""),
        "created_at": int(user.get("created_at", 0)),
        "expires_at": expires_at,
        "left_seconds": left,
        "left_days": left // 86400,
        "link": links.get("ws") or links.get("xhttp") or "",
        "links": links,
        "subscription_url": subscription_url,
        "traffic_used_bytes": traffic_used,
        "traffic_used_gb": gb_from_bytes(traffic_used),
        "traffic_limit_bytes": traffic_limit,
        "traffic_limit_gb": gb_from_bytes(traffic_limit),
        "traffic_left_bytes": max(0, traffic_limit - traffic_used) if traffic_limit else None,
        "device_limit": device_limit,
        "devices_count": len(devices),
        "devices": devices,
    }


def status_payload(users):
    current = now_ts()
    active = []
    expired = []
    banned = []
    for user in users:
        try:
            if user.get("banned") or user.get("disabled"):
                banned.append(user)
            elif int(user.get("expires_at", 0)) > current:
                active.append(user)
            else:
                expired.append(user)
        except Exception:
            expired.append(user)

    return {
        "ok": True,
        "service": "vpn-api",
        "node_name": read_node_name(),
        "domain": read_domain(),
        "api": {
            "port": API_PORT,
        },
        "ws": {
            "local_port": XRAY_PORT,
            "public_port": PUBLIC_PORT,
            "path": "/xray",
        },
        "transport": {
            "mode": TRANSPORT,
            "xhttp_path": XHTTP_PATH,
            "xhttp_uplink_method": XHTTP_METHOD,
        },
        "cdn_ws": {
            "enabled": bool(CDN_WS_ENABLED and CDN_WS_HOST),
            "host": CDN_WS_HOST,
            "sni": CDN_WS_SNI,
            "port": CDN_WS_PORT,
            "tag_suffix": CDN_WS_TAG,
            "path": CDN_WS_PATH,
        },
        "cdn_xhttp": {
            "enabled": bool(CDN_XHTTP_ENABLED and CDN_XHTTP_HOST),
            "host": CDN_XHTTP_HOST,
            "sni": CDN_XHTTP_SNI,
            "port": CDN_XHTTP_PORT,
            "tag_suffix": CDN_XHTTP_TAG,
            "public_path": CDN_XHTTP_PUBLIC_PATH,
            "origin_path": XHTTP_PATH,
        },
        "reality": {
            "enabled": REALITY_ENABLED,
            "local_port": REALITY_PORT if REALITY_ENABLED else None,
            "public_host": REALITY_PUBLIC_HOST if REALITY_ENABLED else "",
            "public_port": PUBLIC_REALITY_PORT if REALITY_ENABLED else "",
            "sni": REALITY_SNI if REALITY_ENABLED else "",
            "dest": REALITY_DEST if REALITY_ENABLED else "",
        },
        "subscription": {
            "enabled": bool(SUB_PORT),
            "public_host": SUB_PUBLIC_HOST,
            "port": SUB_PORT,
            "name": SUB_NAME,
            "auth": "uuid_path",
            "legacy_token_enabled": bool(SUB_TOKEN),
        },
        "clients": {
            "total": len(users),
            "active": len(active),
            "expired": len(expired),
            "banned": len(banned),
        },
        "peers": load_peers(),
        "nodes": load_nodes(),
        "federation": federation_payload(),
        "join": {
            "enabled": bool(read_join_token()),
            "token_file": os.path.basename(JOIN_TOKEN_FILE),
        },
        "traffic": {
            "enabled": True,
            "stats_port": XRAY_STATS_PORT,
            "note": "Use vpn stats for live Xray counters.",
        },
        "backups": list_backups()[:5],
    }


def write_config(users):
    clients = []
    reality_clients = []
    for user in users:
        if user.get("banned") or user.get("disabled"):
            continue
        try:
            clients.append({"id": str(user["uuid"]), "email": str(user["name"])})
            if REALITY_ENABLED:
                reality_clients.append({
                    "id": str(user["uuid"]),
                    "email": f"{user['name']}-reality",
                    "flow": "xtls-rprx-vision",
                })
        except Exception:
            pass

    main_inbound = {
        "port": XRAY_PORT,
        "tag": "xhttp-in" if TRANSPORT == "xhttp" else "ws-in",
        "listen": "0.0.0.0",
        "protocol": "vless",
        "settings": {"clients": clients, "decryption": "none"},
        "sniffing": {"enabled": True, "destOverride": ["http", "tls", "quic"]},
    }
    mws_enabled = enabled_from_file("mws_enabled.txt")
    mws_domain = read_first_line("mws_domain.txt") or read_domain()
    mws_cert = read_first_line("mws_cert_file.txt") or f"/etc/letsencrypt/live/{mws_domain}/fullchain.pem"
    mws_key = read_first_line("mws_key_file.txt") or f"/etc/letsencrypt/live/{mws_domain}/privkey.pem"

    if TRANSPORT == "xhttp" and mws_enabled:
        main_inbound["tag"] = "XHTTP_mws"
        main_inbound["streamSettings"] = {
            "network": "xhttp",
            "security": "tls",
            "tlsSettings": {
                "minVersion": "1.2",
                "certificates": [
                    {
                        "certificateFile": mws_cert,
                        "keyFile": mws_key,
                    }
                ],
            },
            "xhttpSettings": {
                "mode": "auto",
                "path": XHTTP_PATH,
            },
        }
    elif TRANSPORT == "xhttp":
        main_inbound["streamSettings"] = {
            "network": "xhttp",
            "security": "none",
            "xhttpSettings": {
                "mode": "packet-up",
                "path": XHTTP_PATH,
                "extra": {
                    "seqKey": "page",
                    "sessionKey": "X-Request-Id",
                    "noSSEHeader": False,
                    "xPaddingKey": "_dc",
                    "seqPlacement": "query",
                    "uplinkDataKey": "X-Payload",
                    "xPaddingBytes": "80-240",
                    "xPaddingMethod": "tokenish",
                    "uplinkChunkSize": "1024-2048",
                    "sessionPlacement": "header",
                    "uplinkHTTPMethod": XHTTP_METHOD,
                    "xPaddingObfsMode": True,
                    "xPaddingPlacement": "query",
                    "scMaxBufferedPosts": 30,
                    "scMaxEachPostBytes": "4096-8192",
                    "uplinkDataPlacement": "header",
                    "serverMaxHeaderBytes": 32768,
                },
            },
        }
    else:
        main_inbound["streamSettings"] = {"network": "ws", "wsSettings": {"path": "/xray"}}

    config = {
        "log": {"loglevel": "warning"},
        "stats": {},
        "api": {"tag": "api", "services": ["HandlerService", "LoggerService", "StatsService"]},
        "policy": {
            "levels": {"0": {"statsUserUplink": True, "statsUserDownlink": True}},
            "system": {"statsInboundUplink": True, "statsInboundDownlink": True},
        },
        "inbounds": [
            main_inbound,
            {
                "tag": "api",
                "listen": "127.0.0.1",
                "port": XRAY_STATS_PORT,
                "protocol": "dokodemo-door",
                "settings": {"address": "127.0.0.1"},
            }
        ],
        "outbounds": [
            {"protocol": "freedom", "tag": "direct"},
            {"protocol": "freedom", "tag": "api"},
        ],
        "routing": {
            "rules": [{"type": "field", "inboundTag": ["api"], "outboundTag": "api"}],
        },
    }
    if REALITY_ENABLED:
        config["inbounds"].append({
            "port": REALITY_PORT,
            "tag": "reality-in",
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
        })
    atomic_json(CONFIG_FILE, config)


def write_keys(users):
    current = now_ts()
    generated = datetime.datetime.fromtimestamp(current).strftime("%Y-%m-%d %H:%M:%S")
    traffic = load_traffic()
    devices = load_devices()
    lines = [
        f"generated_at: {generated}",
        f"domain: {read_domain()}",
        f"node_name: {read_node_name() or read_domain()}",
        f"transport: {TRANSPORT}",
        f"ws_public_port: {PUBLIC_PORT}",
    ]
    if TRANSPORT == "xhttp":
        lines.append(f"xhttp_path: {XHTTP_PATH}")
    if REALITY_ENABLED:
        lines.append(f"reality_public_host: {REALITY_PUBLIC_HOST}")
        lines.append(f"reality_public_port: {PUBLIC_REALITY_PORT}")
        lines.append(f"reality_sni: {REALITY_SNI}")
    else:
        lines.append("reality: disabled")
    if SUB_PORT:
        lines.append(f"sub_public_port: {SUB_PORT}")
        lines.append(f"sub_public_host: {SUB_PUBLIC_HOST}")
    if SUB_NAME:
        lines.append(f"sub_name: {SUB_NAME}")
    if CDN_WS_ENABLED and CDN_WS_HOST:
        lines.append(f"cdn_ws: {CDN_WS_HOST}:{CDN_WS_PORT} sni={CDN_WS_SNI} path={CDN_WS_PATH}")
    if CDN_XHTTP_ENABLED and CDN_XHTTP_HOST:
        lines.append(f"cdn_xhttp: {CDN_XHTTP_HOST}:{CDN_XHTTP_PORT} sni={CDN_XHTTP_SNI} path={CDN_XHTTP_PUBLIC_PATH}")
    lines.append(" ")

    active_count = 0
    listed_count = 0
    for user in users:
        try:
            expires_at = int(user["expires_at"])
            if expires_at <= current:
                continue
            listed_count += 1
            if user.get("banned") or user.get("disabled"):
                lines.append(f"{user['name']} | uuid: {user['uuid']} | status: banned")
                if user.get("ban_reason"):
                    lines.append(f"reason: {user.get('ban_reason')}")
                lines.append(" ")
                continue
            left = max(0, expires_at - current)
            date = datetime.datetime.fromtimestamp(expires_at).strftime("%Y-%m-%d %H:%M")
            active_count += 1
            lines.append(
                f"{user['name']} | uuid: {user['uuid']} | expires: {date} | "
                f"left: {left // 86400}d {(left % 86400) // 3600}h"
            )
            client_id = str(user.get("uuid", ""))
            traffic_limit = int(user.get("traffic_limit_bytes", 0) or 0)
            device_limit = int(user.get("device_limit", 0) or 0)
            traffic_row = traffic.get(client_id, {}) if isinstance(traffic.get(client_id, {}), dict) else {}
            device_rows = devices.get(client_id, []) if isinstance(devices.get(client_id, []), list) else []
            if traffic_limit or device_limit:
                parts = []
                if traffic_limit:
                    parts.append(f"traffic: {gb_from_bytes(int(traffic_row.get('used_bytes', 0) or 0))}GB/{gb_from_bytes(traffic_limit)}GB")
                if device_limit:
                    parts.append(f"devices: {len(device_rows)}/{device_limit}")
                lines.append("limits: " + " | ".join(parts))
            if TRANSPORT == "xhttp":
                lines.append("xhttp:")
                lines.append(make_xhttp_link(user))
            else:
                lines.append("ws:")
                lines.append(make_ws_link(user))
            cdn_link = make_cdn_ws_link(user)
            if cdn_link:
                lines.append("ws-cdn:")
                lines.append(cdn_link)
            cdn_link = make_cdn_xhttp_link(user)
            if cdn_link:
                lines.append("xhttp-cdn:")
                lines.append(cdn_link)
            if REALITY_ENABLED:
                lines.append("reality:")
                lines.append(make_reality_link(user))
            sub_url = make_subscription_url(user)
            if sub_url:
                lines.append("subscription:")
                lines.append(sub_url)
            lines.append(" ")
        except Exception:
            pass

    if listed_count == 0:
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


def embedded_panel_html():
    return """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>H1Cloud VLESS Panel</title>
  <style>
    :root { color-scheme: dark; --bg:#07090d; --panel:#111720; --line:#263140; --text:#e7ecf3; --muted:#8f9aac; --ok:#43e189; --cyan:#26d6e5; --red:#f87171; --warn:#fb923c; }
    * { box-sizing: border-box; }
    body { margin: 0; background: var(--bg); color: var(--text); font: 14px/1.45 Inter, system-ui, -apple-system, Segoe UI, Arial, sans-serif; }
    main { width: min(1180px, calc(100% - 28px)); margin: 0 auto; padding: 26px 0 50px; }
    header, section { border-bottom: 1px solid rgba(255,255,255,.08); padding: 18px 0; }
    h1, h2, h3 { margin: 0 0 8px; }
    p, small { color: var(--muted); }
    .bar, .grid, form, .links, .actions { display: flex; gap: 10px; flex-wrap: wrap; align-items: end; }
    .card, table { border: 1px solid var(--line); border-radius: 10px; background: var(--panel); }
    .card { padding: 16px; margin: 12px 0; }
    label { display: grid; gap: 6px; color: var(--muted); font-size: 12px; font-weight: 700; text-transform: uppercase; }
    input, textarea { min-width: 210px; padding: 0 12px; border: 1px solid var(--line); border-radius: 8px; background: #090d13; color: var(--text); }
    input { height: 42px; }
    textarea { min-height: 92px; padding: 10px 12px; resize: vertical; }
    button { min-height: 38px; border: 1px solid var(--line); border-radius: 8px; padding: 0 12px; background: #121923; color: var(--text); cursor: pointer; font-weight: 700; }
    button.primary { border: 0; color: #061018; background: linear-gradient(135deg, var(--ok), var(--cyan)); }
    button.danger { color: var(--red); }
    table { width: 100%; border-collapse: collapse; overflow: hidden; }
    th, td { padding: 12px; border-bottom: 1px solid rgba(255,255,255,.08); text-align: left; vertical-align: top; }
    th { color: var(--muted); font-size: 12px; text-transform: uppercase; }
    code { overflow-wrap: anywhere; color: #dfe7f3; }
    .pill { display: inline-flex; min-height: 26px; align-items: center; border-radius: 999px; padding: 0 9px; border: 1px solid var(--line); font-weight: 800; font-size: 12px; }
    .ok { color: var(--ok); } .warn { color: var(--warn); } .bad { color: var(--red); }
    .links button { min-height: 30px; font-size: 12px; }
    .manual-grid { display: grid; grid-template-columns: minmax(180px,1fr) minmax(220px,1.1fr) 100px minmax(120px,.7fr); gap: 10px; width: 100%; }
    pre { margin: 0; white-space: pre-wrap; color: var(--muted); }
    @media (max-width: 760px) { input, textarea { min-width: 100%; } .manual-grid { grid-template-columns: 1fr; } th:nth-child(3), td:nth-child(3) { min-width: 240px; } }
  </style>
</head>
<body>
<main>
  <header>
    <h1>H1Cloud VLESS Panel</h1>
    <p id="line">API: <code id="apiBase"></code></p>
    <div class="bar">
      <label>API Token <input id="token" type="password" autocomplete="off" /></label>
      <button class="primary" id="connect">Connect</button>
      <button id="refresh">Refresh</button>
    </div>
  </header>

  <section>
    <h2>Overview</h2>
    <div class="grid" id="stats"></div>
  </section>

  <section>
    <h2>Clients</h2>
    <form id="createForm" class="card">
      <label>Name <input id="name" autocomplete="off" placeholder="lol123" /></label>
      <label>Days <input id="days" type="number" min="1" step="1" value="30" /></label>
      <label>GB <input id="trafficGb" type="number" min="0" step="0.1" placeholder="0 = unlimited" /></label>
      <label>Devices <input id="deviceLimit" type="number" min="0" step="1" placeholder="0 = unlimited" /></label>
      <button class="primary" type="submit">Create</button>
    </form>
    <table>
      <thead><tr><th>Client</th><th>Status</th><th>Links</th><th>Actions</th></tr></thead>
      <tbody id="clients"><tr><td colspan="4">No data.</td></tr></tbody>
    </table>
  </section>

  <section>
    <h2>Manual add</h2>
    <form id="manualForm" class="card">
      <label style="width: 100%;">Original VLESS <textarea id="manualSource" placeholder="vless://uuid@de.safetunn.shop:25629?type=ws&path=/xray&host=de.safetunn.shop#Germany WS"></textarea></label>
      <div class="manual-grid">
        <label>CDN address <input id="manualCdn" placeholder="cdn.de.h1cloud.su" /></label>
        <label>SNI / Host <input id="manualHost" placeholder="top2355543541.mwscdn.ru" /></label>
        <label>Port <input id="manualPort" type="number" min="1" max="65535" value="443" /></label>
        <label>Tag suffix <input id="manualSuffix" value="CDN" /></label>
      </div>
      <button class="primary" type="submit">Build</button>
      <button id="manualCopy" type="button" disabled>Copy</button>
    </form>
    <div class="card"><pre id="manualOutput">CDN link will appear here.</pre></div>
  </section>

  <section>
    <h2>Logs</h2>
    <div class="card"><pre id="logs">No logs.</pre></div>
  </section>
</main>
<script>
const apiBase = location.origin + "/api";
const $ = (id) => document.getElementById(id);
$("apiBase").textContent = apiBase;
$("token").value = localStorage.getItem("h1cloud.inline.token") || "";

function esc(value) {
  return String(value ?? "").replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");
}

async function api(path, options = {}) {
  const headers = { Authorization: `Bearer ${$("token").value.trim()}`, ...(options.headers || {}) };
  if (options.body) headers["Content-Type"] = "application/json";
  const response = await fetch(apiBase + path, { ...options, headers, body: options.body ? JSON.stringify(options.body) : undefined });
  const text = await response.text();
  let payload = {};
  try { payload = text ? JSON.parse(text) : {}; } catch { payload = { ok: false, error: text || response.statusText }; }
  if (!response.ok || payload.ok === false) throw new Error(payload.error || response.statusText || "request_failed");
  return payload;
}

function copyButton(label, value) {
  if (!value) return `<button disabled>${label}</button>`;
  return `<button data-copy="${esc(value)}">${label}</button>`;
}

function renderStats(status) {
  const cdn = status.cdn_ws || {};
  const xcdn = status.cdn_xhttp || {};
  const transport = status.transport || {};
  const sub = status.subscription || {};
  const items = [
    ["Node", status.node_name || status.domain || "-"],
    ["Clients", `${status.clients?.active || 0} active / ${status.clients?.total || 0} total`],
    ["Transport", transport.mode || "ws"],
    ["WS", `:${status.ws?.public_port || "-"}`],
    ["XHTTP", transport.mode === "xhttp" ? (transport.xhttp_path || "/api/v1/sync/") : "off"],
    ["WS-CDN", cdn.enabled ? `${cdn.host}:${cdn.port || 443} ${cdn.path || "/xray"}` : "off"],
    ["XHTTP-CDN", xcdn.enabled ? `${xcdn.host}:${xcdn.port || 443} ${xcdn.public_path || ""}` : "off"],
    ["Reality", status.reality?.enabled ? `:${status.reality.public_port}` : "off"],
    ["Subscription", sub.enabled ? (sub.name || `:${sub.port}`) : "off"],
    ["Federation", status.federation?.enabled ? "on" : "off"],
  ];
  $("stats").innerHTML = items.map(([k, v]) => `<div class="card"><small>${esc(k)}</small><h3>${esc(v)}</h3></div>`).join("");
}

function renderClients(clients) {
  if (!clients.length) {
    $("clients").innerHTML = `<tr><td colspan="4">No clients.</td></tr>`;
    return;
  }
  $("clients").innerHTML = clients.map((client) => {
    const banned = Boolean(client.banned || client.status === "banned");
    const links = client.links || {};
    const name = esc(client.name);
    const trafficLimit = Number(client.traffic_limit_gb || 0);
    const trafficUsed = Number(client.traffic_used_gb || 0);
    const deviceLimit = Number(client.device_limit || 0);
    const deviceCount = Number(client.devices_count || 0);
    const limitText = [
      trafficLimit ? `${trafficUsed.toFixed(2).replace(/\\.?0+$/, "")}/${trafficLimit.toFixed(2).replace(/\\.?0+$/, "")} GB` : "",
      deviceLimit ? `${deviceCount}/${deviceLimit} devices` : "",
    ].filter(Boolean).join(" В· ");
    return `<tr>
      <td><strong>${name}</strong><br><code>${esc(client.uuid)}</code></td>
      <td><span class="pill ${banned ? "bad" : "ok"}">${banned ? "banned" : `${client.left_days || 0} days`}</span><br><small>${esc(limitText || client.ban_reason || "")}</small></td>
      <td><div class="links">${copyButton("WS", links.ws)}${copyButton("XHTTP", links.xhttp)}${copyButton("WS-CDN", links.ws_cdn)}${copyButton("XHTTP-CDN", links.xhttp_cdn)}${copyButton("Reality", links.reality)}${links.ws || links.xhttp || client.link ? `<button data-manual-link="${esc(links.ws || links.xhttp || client.link)}">Manual add</button>` : ""}${copyButton("Sub", client.subscription_url)}</div></td>
      <td><div class="actions"><button data-renew="${name}" data-days="30">+30</button>${banned ? `<button data-unban="${name}">Unban</button>` : `<button class="danger" data-ban="${name}">Ban</button>`}<button class="danger" data-delete="${name}">Delete</button></div></td>
    </tr>`;
  }).join("");
}

function cleanHost(value) {
  const raw = String(value || "").trim();
  if (!raw) return "";
  try { return new URL(raw.includes("://") ? raw : `https://${raw}`).hostname.trim(); }
  catch { return raw.replace(/^https?:\\/\\//i, "").split("/")[0].split(":")[0].trim(); }
}

function encodeQueryValue(value) {
  return encodeURIComponent(String(value)).replaceAll("%2F", "/");
}

function convertVlessToCdn(sourceLink) {
  const source = String(sourceLink || "").trim();
  const cdnHost = cleanHost($("manualCdn").value);
  const edgeHost = cleanHost($("manualHost").value) || cdnHost;
  const port = String($("manualPort").value || "443").trim();
  if (!source.startsWith("vless://")) throw new Error("Paste VLESS link");
  if (!cdnHost) throw new Error("Set CDN address");
  if (!edgeHost) throw new Error("Set SNI / Host");
  const parsed = new URL(source);
  const uuid = decodeURIComponent(parsed.username || "");
  if (!uuid) throw new Error("UUID missing");
  const params = new URLSearchParams(parsed.search);
  params.set("security", "tls");
  params.set("sni", edgeHost);
  params.set("type", params.get("type") || "ws");
  params.set("path", params.get("path") || "/xray");
  params.set("host", edgeHost);
  params.set("encryption", params.get("encryption") || "none");
  const ordered = ["security", "sni", "type", "path", "host", "encryption"];
  const used = new Set();
  const pairs = [];
  for (const key of ordered) {
    if (params.has(key)) { used.add(key); pairs.push([key, params.get(key) || ""]); }
  }
  params.forEach((value, key) => { if (!used.has(key)) pairs.push([key, value]); });
  const query = pairs.map(([key, value]) => `${encodeURIComponent(key)}=${encodeQueryValue(value)}`).join("&");
  const oldTag = decodeURIComponent(parsed.hash.replace(/^#/, "")) || "WS";
  const suffix = String($("manualSuffix").value || "").trim();
  const tag = (suffix ? `${oldTag} ${suffix}` : oldTag).trim().replace(/\\s+/g, "-");
  return `vless://${encodeURIComponent(uuid)}@${cdnHost}:${port}?${query}#${encodeURIComponent(tag)}`;
}

function fillManual(link) {
  $("manualSource").value = link || "";
  $("manualSource").focus();
}

async function loadAll() {
  localStorage.setItem("h1cloud.inline.token", $("token").value.trim());
  $("line").innerHTML = `Connecting to <code>${esc(apiBase)}</code>...`;
  const [status, clients, logs] = await Promise.all([api("/status"), api("/clients"), api("/logs?count=80")]);
  renderStats(status);
  renderClients(clients.clients || []);
  $("logs").textContent = (logs.logs || []).join("\\n") || "No logs.";
  $("line").innerHTML = `Connected: <code>${esc(status.node_name || status.domain || apiBase)}</code>`;
}

$("connect").onclick = () => loadAll().catch((error) => $("line").textContent = "Error: " + error.message);
$("refresh").onclick = $("connect").onclick;
$("createForm").onsubmit = async (event) => {
  event.preventDefault();
  const body = { name: $("name").value.trim(), days: Number($("days").value || 30) };
  const trafficGb = Number($("trafficGb").value || 0);
  const deviceLimit = Number($("deviceLimit").value || 0);
  if (trafficGb > 0) body.traffic_limit_gb = trafficGb;
  if (deviceLimit > 0) body.device_limit = deviceLimit;
  await api("/clients", { method: "POST", body });
  $("name").value = "";
  $("trafficGb").value = "";
  $("deviceLimit").value = "";
  await loadAll();
};
$("manualForm").onsubmit = async (event) => {
  event.preventDefault();
  try {
    $("manualOutput").textContent = convertVlessToCdn($("manualSource").value);
    $("manualCopy").disabled = false;
  } catch (error) {
    $("line").textContent = "Error: " + error.message;
  }
};
$("manualCopy").onclick = () => navigator.clipboard.writeText($("manualOutput").textContent);
document.addEventListener("click", async (event) => {
  const button = event.target.closest("button");
  if (!button) return;
  try {
    if (button.dataset.copy) await navigator.clipboard.writeText(button.dataset.copy);
    if (button.dataset.renew) await api(`/clients/${encodeURIComponent(button.dataset.renew)}`, { method: "PATCH", body: { days: Number(button.dataset.days || 30) } });
    if (button.dataset.ban) await api(`/clients/${encodeURIComponent(button.dataset.ban)}/ban`, { method: "PATCH", body: { reason: prompt("Reason", "") || "" } });
    if (button.dataset.unban) await api(`/clients/${encodeURIComponent(button.dataset.unban)}/unban`, { method: "PATCH", body: {} });
    if (button.dataset.delete && confirm(`Delete ${button.dataset.delete}?`)) await api(`/clients/${encodeURIComponent(button.dataset.delete)}`, { method: "DELETE" });
    if (button.dataset.manualLink) fillManual(button.dataset.manualLink);
    if (!button.dataset.copy && !button.dataset.manualLink) await loadAll();
  } catch (error) {
    $("line").textContent = "Error: " + error.message;
  }
});
</script>
</body>
</html>"""


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

    def send_text(self, status, text, content_type="text/plain; charset=utf-8"):
        body = text.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
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

        if method == "GET" and parts and parts[0] in ("panel", "panel.html"):
            self.send_text(200, embedded_panel_html(), "text/html; charset=utf-8")
            return

        if method == "GET" and path in ("", "health"):
            payload = {
                "ok": True,
                "service": "vpn-api",
                "api_port": API_PORT,
                "endpoints": [
                    "GET /clients",
                    "GET /status",
                    "GET/PATCH /node",
                    "GET/POST/DELETE /peers",
                    "GET/PATCH/DELETE /federation",
                    "GET /info?name=NAME",
                    "POST /create",
                    "PATCH /edit",
                    "PATCH /clients/NAME/ban",
                    "PATCH /clients/NAME/unban",
                    "DELETE /clients/NAME",
                    "GET /panel",
                    "GET /keys",
                    "GET /logs",
                ],
                "auth": "Authorization: Bearer TOKEN or X-API-Key: TOKEN",
            }
            self.send_json(200, payload)
            return

        if method == "POST" and parts == ["nodes", "join"]:
            data = {}
            for key, values in params.items():
                data[key] = values[0] if values else ""
            data.update(self.read_body())
            self.join_node(data)
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

        if method == "GET" and parts and parts[0] in ("status", "system", "dashboard"):
            self.send_json(200, status_payload(users))
            return

        if parts and parts[0] == "node":
            if method == "GET":
                self.send_json(200, {"ok": True, "node_name": read_node_name()})
                return
            if method in ("POST", "PUT", "PATCH"):
                self.set_node_name(users, data)
                return

        if parts and parts[0] == "peers":
            if method == "GET":
                self.send_json(200, {"ok": True, "peers": load_peers()})
                return
            if method == "POST":
                self.save_peer(data)
                return
            if method == "DELETE" and len(parts) == 2:
                self.delete_peer(parts[1])
                return

        if parts and parts[0] == "nodes":
            if method == "GET":
                if len(parts) > 1 and parts[1] == "health":
                    self.send_json(200, {"ok": True, "nodes": nodes_with_health()})
                else:
                    self.send_json(200, {"ok": True, "nodes": load_nodes(), "peers": load_peers()})
                return

        if parts and parts[0] == "backups":
            if method == "GET":
                self.send_json(200, {"ok": True, "backups": list_backups()})
                return
            if method == "POST":
                path = create_backup()
                self.send_json(201, {"ok": True, "backup": {"path": path, "name": os.path.basename(path)}})
                return

        if parts and parts[0] in ("traffic", "stats"):
            self.send_json(200, {
                "ok": True,
                "traffic": {
                    "enabled": True,
                    "stats_port": XRAY_STATS_PORT,
                    "message": "Live counters are available from the server console via vpn stats.",
                },
            })
            return

        if parts and parts[0] == "federation":
            if method == "GET":
                self.send_json(200, {"ok": True, "federation": federation_payload()})
                return
            if method in ("POST", "PUT", "PATCH"):
                self.set_federation(data)
                return
            if method == "DELETE":
                self.disable_federation()
                return

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

        if method in ("POST", "PUT", "PATCH") and parts and parts[0] in ("ban", "unban"):
            name = first_value(data, "name")
            if parts[0] == "ban":
                self.ban_client(users, name, data)
            else:
                self.unban_client(users, name)
            return

        if method in ("POST", "PUT", "PATCH") and parts and parts[0] in ("clients", "users") and len(parts) == 3 and parts[2] in ("ban", "unban"):
            if parts[2] == "ban":
                self.ban_client(users, parts[1], data)
            else:
                self.unban_client(users, parts[1])
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

    def join_node(self, data):
        token = strip_outer_quotes(first_value(data, "join_token", "token"))
        expected = read_join_token()
        if not expected or token != expected:
            self.send_json(401, {"ok": False, "error": "bad_join_token"})
            return

        display_name = strip_outer_quotes(first_value(data, "node_name", "display_name", "label", "name"))
        peer_name = strip_outer_quotes(first_value(data, "peer_name", "code"))
        sub_url = strip_outer_quotes(first_value(data, "sub_url", "subscription_url"))
        api_url = strip_outer_quotes(first_value(data, "api_url", "node_api_url"))

        if not validate_label(display_name):
            self.send_json(400, {"ok": False, "error": "bad_node_name"})
            return
        if not validate_name(peer_name):
            peer_name = slugify_label(display_name)
        if not validate_name(peer_name):
            self.send_json(400, {"ok": False, "error": "bad_peer_name"})
            return
        if not sub_url.startswith(("http://", "https://")):
            self.send_json(400, {"ok": False, "error": "bad_sub_url"})
            return

        now = now_ts()
        nodes = [node for node in load_nodes() if isinstance(node, dict) and node.get("name") != peer_name]
        nodes.append({
            "name": peer_name,
            "display_name": display_name,
            "sub_url": sub_url,
            "api_url": api_url,
            "joined_at": now,
            "last_seen_at": now,
        })
        save_nodes(nodes)

        peers = [peer for peer in load_peers() if peer.get("name") != peer_name]
        peers.append({"name": peer_name, "url": sub_url})
        save_peers(peers)

        log_action("node_join", f"{peer_name} {display_name} {sub_url}")
        self.send_json(200, {
            "ok": True,
            "node": nodes[-1],
            "upstream_url": public_api_url(),
            "api_token": API_TOKEN,
        })

    def set_node_name(self, users, data):
        global NODE_NAME

        value = str(first_value(data, "name", "node_name")).strip()
        if not validate_label(value):
            self.send_json(400, {"ok": False, "error": "bad_node_name"})
            return

        NODE_NAME = value
        atomic_text(NODE_NAME_FILE, value + "\n")
        write_keys(users)
        log_action("api_node_set", value)
        self.send_json(200, {"ok": True, "node_name": read_node_name()})

    def save_peer(self, data):
        name = strip_outer_quotes(first_value(data, "name"))
        url = strip_outer_quotes(first_value(data, "url"))

        if not validate_name(name):
            self.send_json(400, {"ok": False, "error": "bad_peer_name"})
            return
        if not url.startswith(("http://", "https://")):
            self.send_json(400, {"ok": False, "error": "bad_peer_url"})
            return

        peers = [peer for peer in load_peers() if peer.get("name") != name]
        peers.append({"name": name, "url": url})
        save_peers(peers)
        log_action("api_peer_save", name)
        self.send_json(200, {"ok": True, "peers": peers})

    def delete_peer(self, name):
        if not validate_name(name):
            self.send_json(400, {"ok": False, "error": "bad_peer_name"})
            return

        peers = load_peers()
        new_peers = [peer for peer in peers if peer.get("name") != name]
        if len(new_peers) == len(peers):
            self.send_json(404, {"ok": False, "error": "peer_not_found"})
            return

        save_peers(new_peers)
        log_action("api_peer_delete", name)
        self.send_json(200, {"ok": True, "peers": new_peers})

    def set_federation(self, data):
        api_url = strip_outer_quotes(first_value(data, "api_url", "url", "upstream_url")).rstrip("/")
        token = strip_outer_quotes(first_value(data, "token", "api_token", "upstream_token"))

        if not api_url.startswith(("http://", "https://")):
            self.send_json(400, {"ok": False, "error": "bad_upstream_url"})
            return
        if not token:
            self.send_json(400, {"ok": False, "error": "bad_upstream_token"})
            return

        atomic_text(UPSTREAM_API_URL_FILE, api_url + "\n")
        atomic_text(UPSTREAM_API_TOKEN_FILE, token + "\n")
        try:
            os.chmod(UPSTREAM_API_TOKEN_FILE, 0o600)
        except Exception:
            pass
        log_action("api_federation_set", api_url)
        self.send_json(200, {"ok": True, "federation": federation_payload()})

    def disable_federation(self):
        for path in (UPSTREAM_API_URL_FILE, UPSTREAM_API_TOKEN_FILE):
            try:
                os.remove(path)
            except FileNotFoundError:
                pass
            except Exception:
                pass
        log_action("api_federation_off", "")
        self.send_json(200, {"ok": True, "federation": federation_payload()})

    def create_client(self, users, data):
        name = str(first_value(data, "name")).strip()
        days = parse_int(first_value(data, "days"), None)
        try:
            traffic_limit = parse_limit_bytes(first_value(data, "traffic_limit_gb", "traffic_gb", "gb", "limit_gb"))
            device_limit = parse_device_limit_value(first_value(data, "device_limit", "devices", "device_count", "max_devices"))
        except ValueError as exc:
            self.send_json(400, {"ok": False, "error": str(exc)})
            return

        if not validate_name(name):
            self.send_json(400, {"ok": False, "error": "bad_name"})
            return
        if days is None or days <= 0:
            self.send_json(400, {"ok": False, "error": "bad_days"})
            return

        requested_uuid = str(first_value(data, "uuid", "client_id")).strip()
        if requested_uuid:
            try:
                client_uuid = str(uuid.UUID(requested_uuid))
            except Exception:
                self.send_json(400, {"ok": False, "error": "bad_uuid"})
                return
        else:
            client_uuid = str(uuid.uuid4())

        if upstream_enabled():
            payload = {"name": name, "days": days}
            if requested_uuid:
                payload["uuid"] = client_uuid
            if traffic_limit:
                payload["traffic_limit_gb"] = gb_from_bytes(traffic_limit)
            if device_limit:
                payload["device_limit"] = device_limit
            try:
                upstream_request("POST", "/clients", payload)
                synced = sync_users_from_upstream()
                user = find_user_by_name(synced, name)
                log_action("api_client_create_upstream", f"{name} days={days}")
                self.send_json(201, {"ok": True, "proxied": True, "client": client_payload(user) if user else None})
            except Exception as exc:
                log_action("api_upstream_create_failed", f"{name} {exc}")
                self.send_json(502, {"ok": False, "error": str(exc)})
            return

        if any(user.get("name") == name for user in users):
            self.send_json(409, {"ok": False, "error": "user_already_exists"})
            return
        if any(str(user.get("uuid")) == client_uuid for user in users):
            self.send_json(409, {"ok": False, "error": "uuid_already_exists"})
            return

        current = now_ts()
        user = {
            "name": name,
            "uuid": client_uuid,
            "created_at": current,
            "expires_at": current + days * 86400,
            "banned": False,
        }
        if traffic_limit:
            user["traffic_limit_bytes"] = traffic_limit
            user["traffic_reset_pending"] = True
        if device_limit:
            user["device_limit"] = device_limit
        users.append(user)
        save_users(users)
        log_action("api_client_create", f"{name} days={days}")
        self.send_json(201, {"ok": True, "client": client_payload(user)})

    def edit_client(self, users, name, data):
        if not validate_name(name):
            self.send_json(400, {"ok": False, "error": "bad_name"})
            return

        if upstream_enabled():
            payload = {}
            for key in ("new_name", "days", "set_days", "expires_at", "traffic_limit_gb", "traffic_gb", "gb", "limit_gb", "device_limit", "devices", "device_count", "max_devices"):
                value = first_value(data, key)
                if value != "":
                    payload[key] = value
            if not payload:
                self.send_json(400, {"ok": False, "error": "nothing_to_edit"})
                return
            try:
                upstream_request("PATCH", "/clients/" + urllib.parse.quote(name, safe=""), payload)
                synced = sync_users_from_upstream()
                target_name = str(payload.get("new_name") or name)
                target = find_user_by_name(synced, target_name)
                log_action("api_client_edit_upstream", f"{name} {payload}")
                self.send_json(200, {"ok": True, "proxied": True, "client": client_payload(target) if target else None})
            except Exception as exc:
                log_action("api_upstream_edit_failed", f"{name} {exc}")
                self.send_json(502, {"ok": False, "error": str(exc)})
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

        traffic_value = first_value(data, "traffic_limit_gb", "traffic_gb", "gb", "limit_gb")
        if traffic_value != "":
            try:
                traffic_limit = parse_limit_bytes(traffic_value)
            except ValueError as exc:
                self.send_json(400, {"ok": False, "error": str(exc)})
                return
            target["traffic_limit_bytes"] = traffic_limit
            target["traffic_reset_pending"] = True
            target.pop("quota_exceeded_at", None)
            changed.append(f"traffic_limit_gb={gb_from_bytes(traffic_limit)}")

        device_value = first_value(data, "device_limit", "devices", "device_count", "max_devices")
        if device_value != "":
            try:
                device_limit = parse_device_limit_value(device_value)
            except ValueError as exc:
                self.send_json(400, {"ok": False, "error": str(exc)})
                return
            target["device_limit"] = device_limit
            changed.append(f"device_limit={device_limit}")

        if not changed:
            self.send_json(400, {"ok": False, "error": "nothing_to_edit"})
            return

        save_users(users)
        log_action("api_client_edit", f"{name} {' '.join(changed)}")
        self.send_json(200, {"ok": True, "client": client_payload(target)})

    def ban_client(self, users, name, data):
        if not validate_name(name):
            self.send_json(400, {"ok": False, "error": "bad_name"})
            return

        if upstream_enabled():
            reason = str(first_value(data, "reason", "ban_reason")).strip()
            try:
                upstream_request("PATCH", "/clients/" + urllib.parse.quote(name, safe="") + "/ban", {"reason": reason})
                synced = sync_users_from_upstream()
                target = find_user_by_name(synced, name)
                log_action("api_client_ban_upstream", f"{name} {reason}")
                self.send_json(200, {"ok": True, "proxied": True, "client": client_payload(target) if target else None})
            except Exception as exc:
                log_action("api_upstream_ban_failed", f"{name} {exc}")
                self.send_json(502, {"ok": False, "error": str(exc)})
            return

        target = None
        for user in users:
            if user.get("name") == name:
                target = user
                break

        if target is None:
            self.send_json(404, {"ok": False, "error": "user_not_found"})
            return

        reason = str(first_value(data, "reason", "ban_reason")).strip()
        target["banned"] = True
        target["banned_at"] = now_ts()
        target["ban_reason"] = reason
        save_users(users)
        log_action("api_client_ban", f"{name} {reason}")
        self.send_json(200, {"ok": True, "client": client_payload(target)})

    def unban_client(self, users, name):
        if not validate_name(name):
            self.send_json(400, {"ok": False, "error": "bad_name"})
            return

        if upstream_enabled():
            try:
                upstream_request("PATCH", "/clients/" + urllib.parse.quote(name, safe="") + "/unban", {})
                synced = sync_users_from_upstream()
                target = find_user_by_name(synced, name)
                log_action("api_client_unban_upstream", name)
                self.send_json(200, {"ok": True, "proxied": True, "client": client_payload(target) if target else None})
            except Exception as exc:
                log_action("api_upstream_unban_failed", f"{name} {exc}")
                self.send_json(502, {"ok": False, "error": str(exc)})
            return

        target = None
        for user in users:
            if user.get("name") == name:
                target = user
                break

        if target is None:
            self.send_json(404, {"ok": False, "error": "user_not_found"})
            return

        target["banned"] = False
        target.pop("disabled", None)
        target.pop("banned_at", None)
        target.pop("ban_reason", None)
        save_users(users)
        log_action("api_client_unban", name)
        self.send_json(200, {"ok": True, "client": client_payload(target)})

    def delete_client(self, users, name):
        if not validate_name(name):
            self.send_json(400, {"ok": False, "error": "bad_name"})
            return

        if upstream_enabled():
            try:
                upstream_request("DELETE", "/clients/" + urllib.parse.quote(name, safe=""))
                sync_users_from_upstream()
                log_action("api_client_delete_upstream", name)
                self.send_json(200, {"ok": True, "proxied": True, "deleted": name})
            except Exception as exc:
                log_action("api_upstream_delete_failed", f"{name} {exc}")
                self.send_json(502, {"ok": False, "error": str(exc)})
            return

        new_users = [user for user in users if user.get("name") != name]
        if len(new_users) == len(users):
            self.send_json(404, {"ok": False, "error": "user_not_found"})
            return

        removed_ids = [str(user.get("uuid", "")) for user in users if user.get("name") == name]
        save_users(new_users)
        if removed_ids:
            devices = load_devices()
            traffic = load_traffic()
            for client_id in removed_ids:
                devices.pop(client_id, None)
                traffic.pop(client_id, None)
            save_devices(devices)
            save_traffic(traffic)
        log_action("api_client_delete", name)
        self.send_json(200, {"ok": True, "deleted": name})


class ReuseServer(ThreadingHTTPServer):
    allow_reuse_address = True


log_action("api_start", f"0.0.0.0:{API_PORT}")
try:
    server = ReuseServer(("0.0.0.0", API_PORT), Handler)
except OSError as exc:
    if exc.errno == 98:
        sys.stderr.write(
            f"port {API_PORT} is already in use.\n"
            "on Pterodactyl: РёСЃРїРѕР»СЊР·СѓР№ РїРѕСЂС‚, РєРѕС‚РѕСЂС‹Р№ СЂРµР°Р»СЊРЅРѕ РІС‹РґРµР»РµРЅ СЌС‚РѕРјСѓ СЃРµСЂРІРµСЂСѓ\n"
            "(Configuration -> Allocations РІ РїР°РЅРµР»Рё). docker-proxy РѕС‚ wings СѓР¶Рµ СЃРёРґРёС‚\n"
            "РЅР° РЅРµ-РІС‹РґРµР»РµРЅРЅС‹С… РїРѕСЂС‚Р°С… РІРЅСѓС‚СЂРё netns, РїРѕСЌС‚РѕРјСѓ bind() РїР°РґР°РµС‚.\n"
        )
    else:
        sys.stderr.write(f"api bind failed on port {API_PORT}: {exc}\n")
    sys.exit(1)
server.serve_forever()
PY

    API_PID="$!"
    echo "$API_PID" > "$API_PID_FILE"
    echo "$API_BIND_PORT" > "$API_PORT_FILE"

    sleep 1

    if kill -0 "$API_PID" >/dev/null 2>&1; then
        echo "api started: 0.0.0.0:$API_BIND_PORT"
        echo "url: http://$(read_public_ip):$API_BIND_PORT"
        echo "token: $TOKEN"
        echo "auth: Authorization: Bearer $TOKEN"
        log_action "api_start" "0.0.0.0:$API_BIND_PORT pid=$API_PID"
        return 0
    fi

    echo "api failed to start"
    rm -f "$API_PID_FILE" "$API_PORT_FILE" >/dev/null 2>&1
    API_PID=""
    return 0
}

cmd_api() {
    local ACTION="${1:-}"
    local RESTART_PORT

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
            RESTART_PORT="${2:-}"
            if [ -z "$RESTART_PORT" ] && [ -f "$API_PORT_FILE" ]; then
                RESTART_PORT="$(cat "$API_PORT_FILE" 2>/dev/null)"
            fi
            stop_api_process keep
            start_api_process "$RESTART_PORT"
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
        ban)
            shift
            cmd_ban "$@"
            ;;
        unban)
            cmd_unban "${2:-}"
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
            echo "vpn api ban NAME [REASON]    disable client"
            echo "vpn api unban NAME           enable client"
            print_line
            echo "HTTP examples:"
            echo "GET    /clients"
            echo "GET    /info?name=NAME"
            echo "POST   /create {\"name\":\"test\",\"days\":30}"
            echo "PATCH  /edit {\"name\":\"test\",\"days\":15}"
            echo "PATCH  /clients/test/ban {\"reason\":\"chargeback\"}"
            echo "PATCH  /clients/test/unban"
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
    local SUB_BIND_PORT="$1"
    local TOKEN WS_PUBLIC_PORT_VALUE RUNNING_PORT REALITY_ENABLED_VALUE REALITY_PUBLIC_HOST_VALUE NODE_NAME_VALUE
    local SUB_NAME_VALUE CDN_WS_ENABLED_VALUE CDN_WS_HOST_VALUE CDN_WS_SNI_VALUE CDN_WS_PORT_VALUE CDN_WS_TAG_VALUE CDN_WS_PATH_VALUE
    local TRANSPORT_VALUE XHTTP_PATH_VALUE
    local CDN_XHTTP_ENABLED_VALUE CDN_XHTTP_HOST_VALUE CDN_XHTTP_SNI_VALUE CDN_XHTTP_PORT_VALUE CDN_XHTTP_TAG_VALUE CDN_XHTTP_PUBLIC_PATH_VALUE

    if ! validate_port "$SUB_BIND_PORT"; then
        echo "usage: vpn sub PORT"
        echo "port must be 1-65535"
        return 0
    fi

    if ! check_port_conflict "$SUB_BIND_PORT" "sub"; then
        return 0
    fi

    if sub_is_running; then
        RUNNING_PORT="$(cat "$SUB_PORT_FILE" 2>/dev/null)"
        echo "subscription already running: 0.0.0.0:${RUNNING_PORT:-unknown}"
        echo "url format: http://$(read_subscription_host):${RUNNING_PORT:-PORT}/sub/CLIENT_UUID"
        return 0
    fi

    REALITY_ENABLED_VALUE="0"
    REALITY_PUBLIC_HOST_VALUE=""
    if is_reality_enabled && ensure_reality_files >/dev/null 2>&1; then
        REALITY_ENABLED_VALUE="1"
        REALITY_PUBLIC_HOST_VALUE="$(read_reality_host)"
    fi
    TOKEN="$(get_sub_token)"
    WS_PUBLIC_PORT_VALUE="$(get_public_port)"
    NODE_NAME_VALUE="$(get_node_name)"
    SUB_NAME_VALUE="$(get_sub_name)"
    CDN_WS_ENABLED_VALUE="0"
    CDN_WS_HOST_VALUE=""
    CDN_WS_SNI_VALUE=""
    CDN_WS_PORT_VALUE=""
    CDN_WS_TAG_VALUE=""
    CDN_WS_PATH_VALUE=""
    TRANSPORT_VALUE="$(get_transport)"
    XHTTP_PATH_VALUE="$(get_xhttp_path)"
    XHTTP_METHOD_VALUE="$(get_xhttp_method)"
    CDN_XHTTP_ENABLED_VALUE="0"
    CDN_XHTTP_HOST_VALUE=""
    CDN_XHTTP_SNI_VALUE=""
    CDN_XHTTP_PORT_VALUE=""
    CDN_XHTTP_TAG_VALUE=""
    CDN_XHTTP_PUBLIC_PATH_VALUE=""
    if is_cdn_ws_enabled; then
        CDN_WS_ENABLED_VALUE="1"
        CDN_WS_HOST_VALUE="$(get_cdn_ws_host)"
        CDN_WS_SNI_VALUE="$(get_cdn_ws_sni)"
        CDN_WS_PORT_VALUE="$(get_cdn_ws_port)"
        CDN_WS_TAG_VALUE="$(get_cdn_ws_tag_suffix)"
        CDN_WS_PATH_VALUE="$(get_cdn_ws_path)"
    fi
    if is_cdn_xhttp_enabled; then
        CDN_XHTTP_ENABLED_VALUE="1"
        CDN_XHTTP_HOST_VALUE="$(get_cdn_xhttp_host)"
        CDN_XHTTP_SNI_VALUE="$(get_cdn_xhttp_sni)"
        CDN_XHTTP_PORT_VALUE="$(get_cdn_xhttp_port)"
        CDN_XHTTP_TAG_VALUE="$(get_cdn_xhttp_tag_suffix)"
        CDN_XHTTP_PUBLIC_PATH_VALUE="$(get_cdn_xhttp_public_path)"
    fi
    echo "$SUB_BIND_PORT" > "$SUB_PORT_FILE"

    python3 -u - "$USERS_FILE" "$DOMAIN_FILE" "$REALITY_PUBLIC_KEY_FILE" "$REALITY_SHORT_ID_FILE" "$REALITY_SNI_FILE" "$REALITY_PUBLIC_PORT_FILE" "$SUB_TOKEN_FILE" "$SUB_BIND_PORT" "$WS_PUBLIC_PORT_VALUE" "$NODE_NAME_VALUE" "$REALITY_ENABLED_VALUE" "$REALITY_PUBLIC_HOST_VALUE" "$PEERS_FILE" "$UPSTREAM_API_URL_FILE" "$UPSTREAM_API_TOKEN_FILE" "$SUB_NAME_VALUE" "$CDN_WS_ENABLED_VALUE" "$CDN_WS_HOST_VALUE" "$CDN_WS_SNI_VALUE" "$CDN_WS_PORT_VALUE" "$CDN_WS_TAG_VALUE" "$CDN_WS_PATH_VALUE" "$DEVICES_FILE" "$TRANSPORT_VALUE" "$XHTTP_PATH_VALUE" "$XHTTP_METHOD_VALUE" "$CDN_XHTTP_ENABLED_VALUE" "$CDN_XHTTP_HOST_VALUE" "$CDN_XHTTP_SNI_VALUE" "$CDN_XHTTP_PORT_VALUE" "$CDN_XHTTP_TAG_VALUE" "$CDN_XHTTP_PUBLIC_PATH_VALUE" <<'PY' &
import base64
import datetime
import hashlib
import html
import json
import binascii
import os
import sys
import time
import urllib.parse
import urllib.request

def read_tag_suffix(name, default):
    try:
        with open(name, "r", encoding="utf-8") as f:
            return f.readline().strip()
    except Exception:
        return default


def link_tag(base, suffix):
    base = str(base or "").strip()
    suffix = str(suffix or "").strip()
    if not suffix:
        return base
    if suffix[:1] in ("-", "_", "/", "#", "(", "["):
        return base + suffix
    return (base + " " + suffix).strip()

def xhttp_client_extra(method):
    method = (method or "GET").upper()
    if method not in ("GET", "POST", "PUT"):
        method = "GET"
    return {
        "xmux": {
            "cMaxReuseTimes": "48-96",
            "maxConcurrency": "4-8",
            "maxConnections": 0,
            "hKeepAlivePeriod": 0,
            "hMaxRequestTimes": "500-900",
            "hMaxReusableSecs": "300-900",
        },
        "seqKey": "page",
        "sessionKey": "X-Request-Id",
        "xPaddingKey": "_dc",
        "seqPlacement": "query",
        "uplinkDataKey": "X-Payload",
        "xPaddingBytes": "80-240",
        "xPaddingMethod": "tokenish",
        "uplinkChunkSize": "1024-2048",
        "sessionPlacement": "header",
        "uplinkHTTPMethod": method,
        "xPaddingObfsMode": True,
        "xPaddingPlacement": "query",
        "scMaxEachPostBytes": "4096-8192",
        "uplinkDataPlacement": "header",
    }


def xhttp_extra_param(method):
    extra = json.dumps(xhttp_client_extra(method), ensure_ascii=False, separators=(",", ":"))
    return urllib.parse.quote(extra, safe="")


def read_xhttp_alpn(default="h2,http1"):
    try:
        with open("xhttp_alpn.txt", "r", encoding="utf-8") as f:
            value = f.readline().strip().lower()
    except Exception:
        value = default
    aliases = {
        "h2,http1": "h2,http1",
        "h2,http/1.1": "h2,http1",
        "h2,http1.1": "h2,http1",
        "h2,http2": "h2,http1",
        "h2,1.1": "h2,http1",
        "h2": "h2",
        "http2": "h2",
        "2": "h2",
        "none": "none",
        "off": "none",
        "disabled": "none",
        "auto": "none",
        "default": "none",
        "http1": "http1",
        "http1.1": "http1",
        "http/1.1": "http1",
        "1": "http1",
        "1.1": "http1",
        "": default,
    }
    return aliases.get(value, default)


def xhttp_alpn_query():
    value = read_xhttp_alpn()
    if value == "h2,http1":
        return "&alpn=h2%2Chttp%2F1.1"
    if value == "h2":
        return "&alpn=h2"
    if value == "none":
        return ""
    return "&alpn=http%2F1.1"


def read_mws_enabled():
    try:
        with open("mws_enabled.txt", "r", encoding="utf-8") as f:
            value = f.readline().strip().lower()
        return value in ("1", "true", "yes", "on", "enabled")
    except Exception:
        return False


def normalize_xhttp_path_py(path):
    path = str(path or "/api/v1/sync/").strip()
    if not path.startswith("/"):
        path = "/" + path
    if not path.endswith("/"):
        path += "/"
    return path


def build_xhttp_vless(client_id, address, port, path, host_header, tag, security="none", sni="", method="GET"):
    path = urllib.parse.quote(normalize_xhttp_path_py(path), safe="")
    tag = urllib.parse.quote(tag, safe="")
    if read_mws_enabled():
        url = f"vless://{client_id}@{address}:{port}?encryption=none&type=xhttp&path={path}&host={host_header}&mode=auto"
    else:
        extra = xhttp_extra_param(method)
        url = f"vless://{client_id}@{address}:{port}?encryption=none&type=xhttp&path={path}&host={host_header}&mode=packet-up&extra={extra}"
    if security == "tls":
        url += f"&security=tls&sni={sni or host_header}&fp=chrome{xhttp_alpn_query()}"
    else:
        url += "&security=none"
    return url + f"#{tag}"

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
NODE_NAME = sys.argv[10].strip()
REALITY_ENABLED = sys.argv[11] == "1"
REALITY_PUBLIC_HOST = sys.argv[12]
PEERS_FILE = sys.argv[13]
UPSTREAM_API_URL_FILE = sys.argv[14]
UPSTREAM_API_TOKEN_FILE = sys.argv[15]
SUB_NAME = sys.argv[16].strip()
CDN_WS_ENABLED = sys.argv[17] == "1"
CDN_WS_HOST = sys.argv[18]
CDN_WS_SNI = sys.argv[19] or CDN_WS_HOST
CDN_WS_PORT = sys.argv[20] or "443"
CDN_WS_TAG = sys.argv[21] or "CDN"
CDN_WS_PATH = sys.argv[22] or "/xray"
DEVICES_FILE = sys.argv[23]
TRANSPORT = sys.argv[24] if len(sys.argv) > 24 else "ws"
XHTTP_PATH = sys.argv[25] if len(sys.argv) > 25 and sys.argv[25] else "/api/v1/sync/"
XHTTP_METHOD = (sys.argv[26] if len(sys.argv) > 26 and sys.argv[26] else "GET").upper()
CDN_XHTTP_ENABLED = len(sys.argv) > 27 and sys.argv[27] == "1"
CDN_XHTTP_HOST = sys.argv[28] if len(sys.argv) > 28 else ""
CDN_XHTTP_SNI = (sys.argv[29] if len(sys.argv) > 29 else "") or CDN_XHTTP_HOST
CDN_XHTTP_PORT = (sys.argv[30] if len(sys.argv) > 30 else "") or "443"
CDN_XHTTP_TAG = (sys.argv[31] if len(sys.argv) > 31 else "") or "CDN"
CDN_XHTTP_PUBLIC_PATH = (sys.argv[32] if len(sys.argv) > 32 and sys.argv[32] else "") or XHTTP_PATH
if TRANSPORT != "xhttp":
    TRANSPORT = "ws"
if not XHTTP_PATH.startswith("/"):
    XHTTP_PATH = "/" + XHTTP_PATH
if not XHTTP_PATH.endswith("/"):
    XHTTP_PATH += "/"
if XHTTP_METHOD not in ("GET", "POST", "PUT"):
    XHTTP_METHOD = "GET"
if not CDN_XHTTP_PUBLIC_PATH.startswith("/"):
    CDN_XHTTP_PUBLIC_PATH = "/" + CDN_XHTTP_PUBLIC_PATH
if not CDN_XHTTP_PUBLIC_PATH.endswith("/"):
    CDN_XHTTP_PUBLIC_PATH += "/"
LAST_ON_DEMAND_SYNC = 0


def read_first(path, default=""):
    try:
        with open(path, "r", encoding="utf-8") as f:
            value = f.readline().strip()
            return value or default
    except Exception:
        return default


def read_domain():
    return read_first(DOMAIN_FILE, "localhost")


def strip_outer_quotes(value):
    text = str(value or "").strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in ("'", '"'):
        return text[1:-1].strip()
    return text


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


def atomic_json(path, data):
    tmp = f"{path}.tmp.{os.getpid()}"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def load_devices():
    try:
        with open(DEVICES_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def save_devices(devices):
    atomic_json(DEVICES_FILE, devices)


def upstream_config():
    api_url = strip_outer_quotes(read_first(UPSTREAM_API_URL_FILE, "")).rstrip("/")
    token = strip_outer_quotes(read_first(UPSTREAM_API_TOKEN_FILE, ""))
    if not api_url or not token:
        return "", ""
    return api_url, token


def sync_upstream_now(force=False):
    global LAST_ON_DEMAND_SYNC

    now = int(time.time())
    if not force and now - LAST_ON_DEMAND_SYNC < 2:
        return False

    api_url, token = upstream_config()
    if not api_url or not token:
        return False

    url = api_url if api_url.endswith("/clients") else api_url + "/clients"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
        "User-Agent": "H1CloudVPNSubSync/1.0",
    })

    with urllib.request.urlopen(req, timeout=6) as resp:
        payload = json.loads(resp.read(1024 * 1024).decode("utf-8"))

    clients = payload.get("clients", [])
    if not isinstance(clients, list):
        return False

    users = []
    for item in clients:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name", "")).strip()
        client_id = str(item.get("uuid", "")).strip()
        try:
            created_at = int(item.get("created_at", 0))
            expires_at = int(item.get("expires_at", 0))
        except Exception:
            continue
        if not name or not client_id or expires_at <= 0:
            continue
        row = {
            "name": name,
            "uuid": client_id,
            "created_at": created_at,
            "expires_at": expires_at,
            "banned": bool(item.get("banned") or item.get("disabled")),
            "banned_at": int(item.get("banned_at", 0) or 0),
            "ban_reason": str(item.get("ban_reason", "") or ""),
        }
        row["traffic_limit_bytes"] = int(item.get("traffic_limit_bytes", 0) or 0)
        row["device_limit"] = int(item.get("device_limit", 0) or 0)
        if item.get("traffic_reset_pending"):
            row["traffic_reset_pending"] = True
        users.append(row)

    before = json.dumps(load_users(), ensure_ascii=False, sort_keys=True)
    after = json.dumps(users, ensure_ascii=False, sort_keys=True)
    if before != after:
        atomic_json(USERS_FILE, users)

    LAST_ON_DEMAND_SYNC = now
    return before != after


def find_user(identifier):
    now = int(time.time())
    for user in load_users():
        try:
            name = str(user.get("name", ""))
            client_id = str(user.get("uuid", ""))
            if user.get("banned") or user.get("disabled"):
                continue
            if identifier in (name, client_id) and int(user.get("expires_at", 0)) > now:
                return user
        except Exception:
            pass
    return None


def first_param(params, *names):
    for name in names:
        values = params.get(name)
        if values:
            value = str(values[0]).strip()
            if value:
                return value
    return ""


def first_header(headers, *names):
    lower = {str(key).lower(): str(value).strip() for key, value in headers.items()}
    for name in names:
        value = lower.get(name.lower(), "")
        if value:
            return value
    return ""


def request_device_id(headers, params, client_ip):
    explicit = first_param(
        params,
        "hwid", "happ_hwid", "device_id", "device", "deviceId", "client_id", "clientId", "sid",
    )
    source = "query"
    if not explicit:
        explicit = first_header(
            headers,
            "X-HWID", "HWID", "X-Happ-HWID", "X-Device-ID", "Device-ID",
            "X-Device-Id", "X-Client-Device-ID", "X-Client-ID", "Client-ID",
            "X-Client-Identifier", "X-Sub-ID",
        )
        source = "header"
    if explicit:
        return "hwid:" + hashlib.sha256(explicit.encode("utf-8", "ignore")).hexdigest(), source, explicit[:80]

    user_agent = first_header(headers, "User-Agent")
    fallback = f"{client_ip}|{user_agent or 'unknown'}"
    return "fallback:" + hashlib.sha256(fallback.encode("utf-8", "ignore")).hexdigest(), "fallback", (user_agent or client_ip)[:80]


def register_device(user, headers, params, client_ip):
    try:
        limit = int(user.get("device_limit", 0) or 0)
    except Exception:
        limit = 0
    if limit <= 0:
        return True, None

    client_id = str(user.get("uuid", ""))
    if not client_id:
        return True, None

    device_id, source, label = request_device_id(headers, params, client_ip)
    now = int(time.time())
    devices = load_devices()
    rows = devices.get(client_id, [])
    if not isinstance(rows, list):
        rows = []

    for row in rows:
        if isinstance(row, dict) and row.get("id") == device_id:
            row["last_seen"] = now
            row["ip"] = client_ip
            row["user_agent"] = first_header(headers, "User-Agent")
            save_devices(devices)
            return True, None

    if len(rows) >= limit:
        return False, {
            "ok": False,
            "error": "device_limit_exceeded",
            "limit": limit,
            "used": len(rows),
        }

    rows.append({
        "id": device_id,
        "source": source,
        "label": label,
        "first_seen": now,
        "last_seen": now,
        "ip": client_ip,
        "user_agent": first_header(headers, "User-Agent"),
    })
    devices[client_id] = rows
    save_devices(devices)
    return True, None


def node_name():
    return NODE_NAME or read_domain()


def load_peers():
    peers = []
    try:
        with open(PEERS_FILE, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except Exception:
        return peers

    for line in lines:
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "|" in line:
            name, template = line.split("|", 1)
        else:
            name, template = "", line
        name = strip_outer_quotes(name)
        template = strip_outer_quotes(template)
        if template:
            peers.append({"name": name, "template": template})
    return peers


def decode_peer_body(text):
    lines = [line.strip() for line in text.splitlines() if line.strip()]
    if any(line.startswith("vless://") for line in lines):
        return lines
    compact = "".join(lines)
    if not compact:
        return []
    try:
        decoded = base64.b64decode(compact + "=" * (-len(compact) % 4), validate=False)
        return [line.strip() for line in decoded.decode("utf-8", "ignore").splitlines() if line.strip()]
    except (binascii.Error, ValueError, UnicodeDecodeError):
        return []


def fetch_peer_links(user):
    result = []
    name = str(user.get("name", ""))
    client_id = str(user.get("uuid", ""))
    quoted_name = urllib.parse.quote(name, safe="")
    quoted_uuid = urllib.parse.quote(client_id, safe="")
    for peer in load_peers():
        template = peer["template"]
        url = (
            template
            .replace("{name}", quoted_name)
            .replace("{uuid}", quoted_uuid)
            .replace("{id}", quoted_uuid)
            .replace("{mode}", "raw")
        )
        if "scope=" not in url:
            url += ("&" if "?" in url else "?") + "scope=local"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "H1CloudVPNSub/1.0"})
            with urllib.request.urlopen(req, timeout=6) as resp:
                text = resp.read(1024 * 512).decode("utf-8", "ignore")
        except Exception:
            continue
        for link in decode_peer_body(text):
            if link.startswith("vless://"):
                result.append(link)
    return result


def merge_links(*groups):
    seen = set()
    result = []
    for group in groups:
        for link in group:
            if link and link not in seen:
                seen.add(link)
                result.append(link)
    return result


def make_links(user):
    name = str(user.get("name", ""))
    client_id = str(user.get("uuid", ""))
    domain = read_domain()
    reality_host = REALITY_PUBLIC_HOST or domain
    reality_public_key = read_first(REALITY_PUBLIC_KEY_FILE)
    reality_short_id = read_first(REALITY_SHORT_ID_FILE)
    reality_sni = read_first(REALITY_SNI_FILE, "proxy11.h1guro.ovh")
    reality_public_port = read_first(REALITY_PUBLIC_PORT_FILE, "443")
    tag_ws = read_tag_suffix("tag_ws.txt", "WS")
    tag_xhttp = read_tag_suffix("tag_xhttp.txt", "XHTTP")
    tag_reality = read_tag_suffix("tag_reality.txt", "Reality")
    ws_tag = urllib.parse.quote(link_tag(node_name(), tag_ws), safe="")
    xhttp_tag = urllib.parse.quote(link_tag(node_name(), tag_xhttp), safe="")

    if str(WS_PUBLIC_PORT) == "443":
        ws = (
            f"vless://{client_id}@{domain}:{WS_PUBLIC_PORT}"
            f"?type=ws&security=tls&sni={domain}&host={domain}&path=%2Fxray&encryption=none#{ws_tag}"
        )
    else:
        ws = (
            f"vless://{client_id}@{domain}:{WS_PUBLIC_PORT}"
            f"?type=ws&security=none&host={domain}&path=%2Fxray&encryption=none#{ws_tag}"
        )
    security = "tls" if str(WS_PUBLIC_PORT) == "443" else "none"
    xhttp = build_xhttp_vless(client_id, domain, WS_PUBLIC_PORT, XHTTP_PATH, domain, link_tag(node_name(), tag_xhttp), security=security, sni=domain, method=XHTTP_METHOD)
    links = [xhttp if TRANSPORT == "xhttp" else ws]
    if CDN_WS_ENABLED and CDN_WS_HOST:
        cdn_tag = urllib.parse.quote(link_tag(link_tag(node_name(), tag_ws), CDN_WS_TAG).replace(" ", "-"), safe="")
        links.append(
            f"vless://{client_id}@{CDN_WS_HOST}:{CDN_WS_PORT}"
            f"?security=tls&sni={CDN_WS_SNI}&type=ws&path={urllib.parse.quote(CDN_WS_PATH, safe='')}"
            f"&host={CDN_WS_SNI}&encryption=none#{cdn_tag}"
        )
    if CDN_XHTTP_ENABLED and CDN_XHTTP_HOST:
        cdn_tag = link_tag(node_name(), CDN_XHTTP_TAG).replace(" ", "-")
        links.append(build_xhttp_vless(client_id, CDN_XHTTP_HOST, CDN_XHTTP_PORT, CDN_XHTTP_PUBLIC_PATH, CDN_XHTTP_SNI, cdn_tag, security="tls", sni=CDN_XHTTP_SNI, method=XHTTP_METHOD))
    if REALITY_ENABLED:
        reality_tag = urllib.parse.quote(link_tag(node_name(), tag_reality), safe="")
        reality = (
            f"vless://{client_id}@{reality_host}:{reality_public_port}"
            f"?type=tcp&security=reality&pbk={reality_public_key}&fp=chrome"
            f"&sni={reality_sni}&sid={reality_short_id}&spx=%2F"
            f"&flow=xtls-rprx-vision&encryption=none#{reality_tag}"
        )
        links.append(reality)
    return links


def current_subscription_url(identifier, request_host="", include_name=True):
    quoted = urllib.parse.quote(identifier, safe="")
    host = request_host or f"{read_domain()}:{SUB_PORT}"
    url = f"http://{host}/sub/{quoted}"
    if include_name and SUB_NAME:
        url += "#" + urllib.parse.quote(SUB_NAME, safe="")
    return url


def link_name(parsed, params):
    fragment = urllib.parse.unquote(parsed.fragment or "")
    return fragment or parsed.hostname or "proxy"


def yaml_quote(value):
    return json.dumps(str(value), ensure_ascii=False)


def clash_proxy_from_link(link):
    parsed = urllib.parse.urlparse(link)
    params = urllib.parse.parse_qs(parsed.query)
    query = {key: values[0] if values else "" for key, values in params.items()}
    name = link_name(parsed, query)
    port = parsed.port or 443
    host = parsed.hostname or ""
    uuid = parsed.username or ""
    security = query.get("security", "none")
    network = query.get("type", "tcp")
    lines = [
        f"  - name: {yaml_quote(name)}",
        "    type: vless",
        f"    server: {yaml_quote(host)}",
        f"    port: {port}",
        f"    uuid: {yaml_quote(uuid)}",
        "    udp: true",
        f"    tls: {'true' if security in ('tls', 'reality') else 'false'}",
        f"    network: {yaml_quote(network)}",
    ]
    if query.get("flow"):
        lines.append(f"    flow: {yaml_quote(query.get('flow'))}")
    if query.get("sni"):
        lines.append(f"    servername: {yaml_quote(query.get('sni'))}")
    if network == "ws":
        lines.append("    ws-opts:")
        lines.append(f"      path: {yaml_quote(urllib.parse.unquote(query.get('path', '/')))}")
        if query.get("host"):
            lines.append("      headers:")
            lines.append(f"        Host: {yaml_quote(query.get('host'))}")
    if security == "reality":
        lines.append("    reality-opts:")
        lines.append(f"      public-key: {yaml_quote(query.get('pbk', ''))}")
        lines.append(f"      short-id: {yaml_quote(query.get('sid', ''))}")
        lines.append(f"    client-fingerprint: {yaml_quote(query.get('fp', 'chrome'))}")
    return "\n".join(lines)


def render_clash_config(links):
    names = [link_name(urllib.parse.urlparse(link), {}) for link in links]
    proxies = "\n".join(clash_proxy_from_link(link) for link in links)
    name_rows = "\n".join(f"      - {yaml_quote(name)}" for name in names)
    return (
        "mixed-port: 7890\n"
        "allow-lan: false\n"
        "mode: rule\n"
        "log-level: warning\n"
        "proxies:\n"
        f"{proxies}\n"
        "proxy-groups:\n"
        "  - name: H1Cloud\n"
        "    type: select\n"
        "    proxies:\n"
        f"{name_rows}\n"
        "rules:\n"
        "  - MATCH,H1Cloud\n"
    )


def sing_box_outbound_from_link(link):
    parsed = urllib.parse.urlparse(link)
    params = urllib.parse.parse_qs(parsed.query)
    query = {key: values[0] if values else "" for key, values in params.items()}
    outbound = {
        "type": "vless",
        "tag": link_name(parsed, query),
        "server": parsed.hostname or "",
        "server_port": parsed.port or 443,
        "uuid": parsed.username or "",
        "packet_encoding": "xudp",
    }
    network = query.get("type", "tcp")
    security = query.get("security", "none")
    if query.get("flow"):
        outbound["flow"] = query.get("flow")
    if network == "ws":
        outbound["transport"] = {
            "type": "ws",
            "path": urllib.parse.unquote(query.get("path", "/")),
            "headers": {"Host": query.get("host", parsed.hostname or "")},
        }
    if security in ("tls", "reality"):
        outbound["tls"] = {
            "enabled": True,
            "server_name": query.get("sni", parsed.hostname or ""),
            "utls": {"enabled": True, "fingerprint": query.get("fp", "chrome")},
        }
    if security == "reality":
        outbound.setdefault("tls", {"enabled": True})
        outbound["tls"]["reality"] = {
            "enabled": True,
            "public_key": query.get("pbk", ""),
            "short_id": query.get("sid", ""),
        }
    return outbound


def render_sing_box_config(links):
    outbounds = [sing_box_outbound_from_link(link) for link in links]
    outbounds.append({"type": "direct", "tag": "direct"})
    return json.dumps({
        "log": {"level": "warn"},
        "inbounds": [{
            "type": "mixed",
            "tag": "mixed-in",
            "listen": "127.0.0.1",
            "listen_port": 2080,
        }],
        "outbounds": outbounds,
        "route": {"final": outbounds[0]["tag"] if outbounds else "direct"},
    }, ensure_ascii=False, indent=2)


def render_client_page(user, links, request_host=""):
    identifier = str(user.get("uuid", ""))
    base_url = current_subscription_url(identifier, request_host, include_name=False)
    sub_url = current_subscription_url(identifier, request_host, include_name=True)
    raw_url = base_url + "/raw"
    clash_url = base_url + "/clash"
    sing_url = base_url + "/sing-box"
    qr_src = "https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=" + urllib.parse.quote(sub_url, safe="")
    rows = "\n".join(
        f"<li><button data-copy=\"{html.escape(link, quote=True)}\">Copy</button><code>{html.escape(link)}</code></li>"
        for link in links
    )
    return f"""<!doctype html>
<html lang="ru">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>H1Cloud Client</title>
  <style>
    body {{ margin: 0; min-height: 100vh; background: #07090d; color: #e7ecf3; font-family: Inter, Arial, sans-serif; }}
    main {{ width: min(920px, calc(100% - 28px)); margin: 0 auto; padding: 28px 0; }}
    section {{ border: 1px solid rgba(255,255,255,.1); border-radius: 14px; background: #131821; padding: 18px; margin: 14px 0; }}
    h1 {{ margin: 0 0 6px; }} p {{ color: #8a96a6; }}
    a, button {{ color: #061018; background: linear-gradient(135deg,#4ade80,#22d3ee); border: 0; border-radius: 9px; padding: 10px 12px; font-weight: 700; text-decoration: none; cursor: pointer; }}
    .actions {{ display: flex; flex-wrap: wrap; gap: 10px; }}
    code {{ display: block; overflow-wrap: anywhere; color: #e7ecf3; background: #0a0d13; border: 1px solid rgba(255,255,255,.1); border-radius: 9px; padding: 10px; }}
    li {{ display: grid; grid-template-columns: auto 1fr; gap: 10px; align-items: start; margin: 10px 0; }}
    img {{ border-radius: 10px; background: white; padding: 8px; }}
  </style>
</head>
<body>
<main>
  <section>
    <h1>{html.escape(str(user.get("name", "")))}</h1>
    <p>РџРѕРґРїРёСЃРєР° H1Cloud. РЎСЃС‹Р»РєР° Р±РµР· token: <code>{html.escape(sub_url)}</code></p>
    <div class="actions">
      <button data-copy="{html.escape(sub_url, quote=True)}">Copy subscription</button>
      <a href="{html.escape(raw_url, quote=True)}">Raw</a>
      <a href="{html.escape(clash_url, quote=True)}">Clash Meta</a>
      <a href="{html.escape(sing_url, quote=True)}">sing-box</a>
    </div>
  </section>
  <section>
    <h2>QR</h2>
    <img alt="Subscription QR" src="{html.escape(qr_src, quote=True)}" />
  </section>
  <section>
    <h2>VLESS links</h2>
    <ul>{rows}</ul>
  </section>
</main>
<script>
document.addEventListener('click', async (event) => {{
  const button = event.target.closest('[data-copy]');
  if (!button) return;
  await navigator.clipboard.writeText(button.dataset.copy);
  button.textContent = 'Copied';
}});
</script>
</body>
</html>"""


class Handler(BaseHTTPRequestHandler):
    server_version = "H1CloudVPNSub/1.0"

    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "authorization,content-type")
        self.send_header("Access-Control-Allow-Methods", "GET,OPTIONS")
        if SUB_NAME:
            encoded_name = base64.b64encode(SUB_NAME.encode("utf-8")).decode("ascii")
            self.send_header("profile-title", "base64:" + encoded_name)
            self.send_header("Profile-Title", "base64:" + encoded_name)
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

        if parts[0] == "sub":
            if len(parts) < 2:
                self.send_json(400, {"ok": False, "error": "uuid_required"})
                return
            identifier = parts[1]
            mode = parts[2] if len(parts) > 2 else "base64"
        else:
            identifier = parts[0]
            mode = parts[1] if len(parts) > 1 else "base64"

        user = find_user(identifier)
        if not user:
            try:
                sync_upstream_now(force=True)
            except Exception:
                pass
            user = find_user(identifier)

        if not user:
            self.send_json(404, {"ok": False, "error": "user_not_found"})
            return

        token = ""
        auth = self.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            token = auth.split(" ", 1)[1].strip()
        if not token:
            token = params.get("token", [""])[0]

        # New public subscription format: /sub/<client_uuid>.
        # Legacy /sub/<name>?token=... remains supported for old links.
        matched_uuid = str(user.get("uuid", "")) == identifier
        legacy_token = read_token()
        if not matched_uuid and (not legacy_token or token != legacy_token):
            self.send_json(401, {"ok": False, "error": "unauthorized"})
            return

        ok_device, device_error = register_device(user, self.headers, params, self.client_address[0])
        if not ok_device:
            self.send_json(403, device_error)
            return

        scope = params.get("scope", ["all"])[0]
        local_links = make_links(user)
        peer_links = [] if scope == "local" or mode == "local" else fetch_peer_links(user)
        links = merge_links(local_links, peer_links)
        raw = "\n".join(links) + "\n"

        if mode in ("raw", "local"):
            self.send_text(200, raw)
            return

        if mode in ("clash", "clash-meta", "yaml", "yml"):
            self.send_text(200, render_clash_config(links), "text/yaml; charset=utf-8")
            return

        if mode in ("sing-box", "singbox"):
            self.send_text(200, render_sing_box_config(links), "application/json; charset=utf-8")
            return

        if mode in ("page", "client", "cabinet", "qr"):
            self.send_text(200, render_client_page(user, links, self.headers.get("Host", "")), "text/html; charset=utf-8")
            return

        if mode == "json":
            expires_at = int(user.get("expires_at", 0))
            reality_links = [link for link in local_links if "security=reality" in link]
            ws_links = [link for link in local_links if "type=ws" in link and "security=reality" not in link]
            xhttp_links = [link for link in local_links if "type=xhttp" in link]
            cdn_ws_links = [link for link in local_links if CDN_WS_ENABLED and CDN_WS_HOST and f"@{CDN_WS_HOST}:" in link]
            cdn_xhttp_links = [link for link in local_links if CDN_XHTTP_ENABLED and CDN_XHTTP_HOST and f"@{CDN_XHTTP_HOST}:" in link]
            self.send_json(200, {
                "ok": True,
                "name": user.get("name"),
                "subscription_name": SUB_NAME,
                "expires_at": expires_at,
                "expires": datetime.datetime.fromtimestamp(expires_at).strftime("%Y-%m-%d %H:%M"),
                "links": {
                    "local": local_links,
                    "peers": peer_links,
                    "all": links,
                    **({"ws": ws_links[0]} if ws_links else {}),
                    **({"xhttp": xhttp_links[0]} if xhttp_links else {}),
                    **({"ws_cdn": cdn_ws_links[0]} if cdn_ws_links else {}),
                    **({"xhttp_cdn": cdn_xhttp_links[0]} if cdn_xhttp_links else {}),
                    **({"reality": reality_links[0]} if reality_links else {}),
                },
            })
            return

        encoded = base64.b64encode(raw.encode("utf-8")).decode("ascii")
        self.send_text(200, encoded + "\n")


class ReuseServer(ThreadingHTTPServer):
    allow_reuse_address = True


try:
    server = ReuseServer(("0.0.0.0", SUB_PORT), Handler)
except OSError as exc:
    if exc.errno == 98:
        sys.stderr.write(
            f"port {SUB_PORT} is already in use.\n"
            "on Pterodactyl РёСЃРїРѕР»СЊР·СѓР№ С‚РѕР»СЊРєРѕ РїРѕСЂС‚, РєРѕС‚РѕСЂС‹Р№ РІС‹РґРµР»РµРЅ СЃРµСЂРІРµСЂСѓ РІ РїР°РЅРµР»Рё.\n"
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
        echo "subscription started: 0.0.0.0:$SUB_BIND_PORT"
        echo "url format: http://$(read_subscription_host):$SUB_BIND_PORT/sub/CLIENT_UUID"
        log_action "sub_start" "0.0.0.0:$SUB_BIND_PORT pid=$SUB_PID"
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
    local ACTION="${1:-}"
    local RESTART_PORT NAME_VALUE

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
            RESTART_PORT="${2:-}"
            if [ -z "$RESTART_PORT" ] && [ -f "$SUB_PORT_FILE" ]; then
                RESTART_PORT="$(cat "$SUB_PORT_FILE" 2>/dev/null)"
            fi
            stop_sub_process keep
            start_sub_process "$RESTART_PORT"
            ;;
        status)
            if sub_is_running; then
                RUNNING_PORT="$(cat "$SUB_PORT_FILE" 2>/dev/null)"
                echo "subscription running: 0.0.0.0:${RUNNING_PORT:-unknown}"
                echo "pid: $SUB_PID"
                echo "url format: http://$(read_subscription_host):${RUNNING_PORT:-PORT}/sub/CLIENT_UUID"
            else
                echo "subscription stopped"
            fi
            NAME_VALUE="$(get_sub_name)"
            echo "display name: ${NAME_VALUE:-not set}"
            ;;
        name|title|rename)
            shift
            NAME_VALUE="$(strip_outer_quotes "$*")"
            case "$NAME_VALUE" in
                ""|off|disable|disabled|none|clear)
                    rm -f "$SUB_NAME_FILE" >/dev/null 2>&1
                    sync_keys_file >/dev/null 2>&1
                    restart_api_if_running
                    restart_sub_if_running
                    log_action "sub_name_clear" ""
                    echo "subscription display name cleared"
                    ;;
                *)
                    printf '%s\n' "$NAME_VALUE" > "$SUB_NAME_FILE"
                    sync_keys_file >/dev/null 2>&1
                    restart_api_if_running
                    restart_sub_if_running
                    log_action "sub_name_set" "$NAME_VALUE"
                    echo "subscription display name saved: $NAME_VALUE"
                    ;;
            esac
            ;;
        token)
            echo "legacy token for old /sub/NAME?token=... links:"
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
            echo "vpn sub name NAME       set profile/subscription display name"
            echo "vpn sub name off        clear profile/subscription display name"
            echo "vpn sub token           show legacy subscription token"
            echo "vpn sub url NAME        show subscription URL"
            print_line
            echo "subscription URL: http://IP:PORT/sub/CLIENT_UUID"
            echo "raw links:        http://IP:PORT/sub/CLIENT_UUID/raw"
            echo "local links:      http://IP:PORT/sub/CLIENT_UUID/local"
            echo "json:             http://IP:PORT/sub/CLIENT_UUID/json"
            echo "legacy still works: http://IP:PORT/sub/NAME?token=TOKEN"
            print_line
            ;;
        *)
            echo "unknown sub command: $ACTION"
            echo "type: vpn sub help"
            ;;
    esac

    return 0
}

cmd_node() {
    local VALUE="$*"

    VALUE="$(strip_outer_quotes "$VALUE")"

    if [ -z "$VALUE" ] || [ "$VALUE" = "status" ]; then
        print_line
        echo "Node"
        print_line
        echo "name: $(get_node_name)"
        echo "set: vpn node NAME"
        print_line
        return 0
    fi

    echo "$VALUE" > "$NODE_NAME_FILE"
    sync_keys_file >/dev/null 2>&1
    restart_api_if_running
    restart_sub_if_running
    log_action "node_set" "$VALUE"
    echo "node name saved: $VALUE"
    return 0
}

cmd_peer() {
    local ACTION="${1:-list}"
    local NAME="${2:-}"
    local URL="${3:-}"

    case "$ACTION" in
        list|status|"")
            if [ -f "$PEERS_FILE" ] && [ -s "$PEERS_FILE" ]; then
                python3 - "$PEERS_FILE" <<'PY'
import sys

path = sys.argv[1]

def strip_outer_quotes(value):
    text = str(value or "").strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in ("'", '"'):
        return text[1:-1].strip()
    return text

try:
    with open(path, "r", encoding="utf-8") as f:
        rows = [line.rstrip("\n") for line in f]
except Exception:
    rows = []

for row in rows:
    if not row.strip():
        continue
    if "|" in row:
        name, url = row.split("|", 1)
        print(f"{strip_outer_quotes(name)}|{strip_outer_quotes(url)}")
    else:
        print(strip_outer_quotes(row))
PY
            else
                echo "no peers"
            fi
            ;;
        add)
            NAME="$(strip_outer_quotes "$NAME")"
            URL="$(strip_outer_quotes "$URL")"
            if ! validate_name "$NAME" || [ -z "$URL" ]; then
                echo "usage: vpn peer add NAME http://IP:PORT/sub/{uuid}/local"
                return 0
            fi
            python3 - "$PEERS_FILE" "$NAME" "$URL" <<'PY'
import os, sys
path, name, url = sys.argv[1], sys.argv[2], sys.argv[3]

def strip_outer_quotes(value):
    text = str(value or "").strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in ("'", '"'):
        return text[1:-1].strip()
    return text

name = strip_outer_quotes(name)
url = strip_outer_quotes(url)
rows = []
try:
    with open(path, "r", encoding="utf-8") as f:
        rows = [line.rstrip("\n") for line in f]
except Exception:
    rows = []
rows = [row for row in rows if not row.startswith(name + "|")]
rows.append(f"{name}|{url}")
tmp = f"{path}.tmp.{os.getpid()}"
with open(tmp, "w", encoding="utf-8") as f:
    for row in rows:
        if row.strip():
            f.write(row + "\n")
os.replace(tmp, path)
PY
            restart_sub_if_running
            log_action "peer_add" "$NAME $URL"
            echo "peer saved: $NAME"
            ;;
        del|delete|remove)
            NAME="$(strip_outer_quotes "$NAME")"
            if [ -z "$NAME" ]; then
                echo "usage: vpn peer del NAME_OR_URL"
                return 0
            fi
            python3 - "$PEERS_FILE" "$NAME" <<'PY'
import os, sys
path, target = sys.argv[1], sys.argv[2]

def strip_outer_quotes(value):
    text = str(value or "").strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in ("'", '"'):
        return text[1:-1].strip()
    return text

target = strip_outer_quotes(target)
try:
    with open(path, "r", encoding="utf-8") as f:
        rows = [line.rstrip("\n") for line in f]
except Exception:
    rows = []
kept = []
for row in rows:
    if "|" in row:
        name, url = row.split("|", 1)
        if strip_outer_quotes(name) == target or strip_outer_quotes(url) == target:
            continue
    elif strip_outer_quotes(row) == target:
        continue
    kept.append(row)
tmp = f"{path}.tmp.{os.getpid()}"
with open(tmp, "w", encoding="utf-8") as f:
    for row in kept:
        if row.strip():
            f.write(row + "\n")
os.replace(tmp, path)
PY
            restart_sub_if_running
            log_action "peer_del" "$NAME"
            echo "peer deleted: $NAME"
            ;;
        help|*)
            echo "vpn peer list"
            echo "vpn peer add NAME http://IP:PORT/sub/{uuid}/local"
            echo "vpn peer del NAME_OR_URL"
            ;;
    esac

    return 0
}

upstream_configured() {
    [ -f "$UPSTREAM_API_URL_FILE" ] && [ -s "$UPSTREAM_API_URL_FILE" ] && [ -f "$UPSTREAM_API_TOKEN_FILE" ] && [ -s "$UPSTREAM_API_TOKEN_FILE" ]
}

local_user_uuid() {
    local NAME="$1"
    python3 - "$USERS_FILE" "$NAME" <<'PY'
import json
import sys

path, name = sys.argv[1], sys.argv[2]
try:
    with open(path, "r", encoding="utf-8") as f:
        users = json.load(f)
except Exception:
    users = []

for user in users if isinstance(users, list) else []:
    if isinstance(user, dict) and user.get("name") == name and user.get("uuid"):
        print(str(user.get("uuid")))
        break
PY
}

forward_client_to_upstream() {
    local ACTION="$1"
    shift

    if ! upstream_configured; then
        return 1
    fi

    python3 - "$UPSTREAM_API_URL_FILE" "$UPSTREAM_API_TOKEN_FILE" "$ACTION" "$@" <<'PY'
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

url_file, token_file, action = sys.argv[1:4]
args = sys.argv[4:]

def read_first(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.readline().strip()
    except Exception:
        return ""

base_url = read_first(url_file).rstrip("/")
token = read_first(token_file)
if not base_url or not token:
    raise SystemExit("upstream is not configured")

method = "GET"
path = "/clients"
payload = None

if action == "create":
    if len(args) < 2:
        raise SystemExit("create requires NAME DAYS")
    method = "POST"
    payload = {"name": args[0], "days": int(args[1])}
    if len(args) > 2 and args[2]:
        payload["uuid"] = args[2]
    if len(args) > 3 and args[3]:
        payload["traffic_limit_gb"] = args[3]
    if len(args) > 4 and args[4]:
        payload["device_limit"] = args[4]
elif action == "renew":
    if len(args) < 2:
        raise SystemExit("renew requires NAME DAYS")
    method = "PATCH"
    path = "/clients/" + urllib.parse.quote(args[0], safe="")
    payload = {"days": int(args[1])}
elif action == "delete":
    if len(args) < 1:
        raise SystemExit("delete requires NAME")
    method = "DELETE"
    path = "/clients/" + urllib.parse.quote(args[0], safe="")
elif action == "ban":
    if len(args) < 1:
        raise SystemExit("ban requires NAME")
    method = "PATCH"
    path = "/clients/" + urllib.parse.quote(args[0], safe="") + "/ban"
    payload = {"reason": args[1] if len(args) > 1 else ""}
elif action == "unban":
    if len(args) < 1:
        raise SystemExit("unban requires NAME")
    method = "PATCH"
    path = "/clients/" + urllib.parse.quote(args[0], safe="") + "/unban"
    payload = {}
elif action == "limit":
    if len(args) < 2:
        raise SystemExit("limit requires NAME ACTION")
    method = "PATCH"
    path = "/clients/" + urllib.parse.quote(args[0], safe="")
    subaction = (args[1] or "status").lower()
    payload = {}
    if subaction in ("traffic", "gb", "quota"):
        payload["traffic_limit_gb"] = args[2] if len(args) > 2 else "0"
    elif subaction in ("devices", "device", "hwid"):
        payload["device_limit"] = args[2] if len(args) > 2 else "0"
    elif subaction in ("off", "disable", "clear", "none"):
        payload["traffic_limit_gb"] = "0"
        payload["device_limit"] = "0"
    elif subaction not in ("status", "show", ""):
        payload["traffic_limit_gb"] = args[1]
        payload["device_limit"] = args[2] if len(args) > 2 else "0"
    if not payload:
        raise SystemExit("nothing_to_edit")
else:
    raise SystemExit(f"unknown upstream action: {action}")

body = None if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
req = urllib.request.Request(
    base_url + path,
    data=body,
    method=method,
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "User-Agent": "H1CloudVPNUpstreamWrite/1.0",
    },
)

try:
    with urllib.request.urlopen(req, timeout=12) as resp:
        text = resp.read(1024 * 1024).decode("utf-8", "ignore")
except urllib.error.HTTPError as exc:
    text = exc.read().decode("utf-8", "ignore")
    try:
        detail = json.loads(text).get("error") or text
    except Exception:
        detail = text or exc.reason
    raise SystemExit(f"HTTP {exc.code}: {detail}")

try:
    data = json.loads(text) if text else {}
except Exception:
    data = {}

if data and data.get("ok") is False:
    raise SystemExit(data.get("error", "upstream_failed"))

print(f"upstream {action} ok")
PY
}

sync_after_upstream_client_write() {
    local NAME="$1"
    local SHOW_LINK="${2:-}"

    sync_upstream_tick manual
    sync_keys_file >/dev/null 2>&1
    restart_api_if_running
    restart_sub_if_running

    if [ "$SHOW_LINK" = "link" ]; then
        echo "link:"
        make_link "$NAME" || true
    fi

    return 0
}

push_local_users_to_upstream() {
    if ! upstream_configured; then
        return 1
    fi

    python3 - "$USERS_FILE" "$UPSTREAM_API_URL_FILE" "$UPSTREAM_API_TOKEN_FILE" <<'PY'
import json
import math
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

users_file, url_file, token_file = sys.argv[1:4]

def read_first(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.readline().strip()
    except Exception:
        return ""

def load_local_users():
    try:
        with open(users_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, list) else []
    except Exception:
        return []

base_url = read_first(url_file).rstrip("/")
token = read_first(token_file)
if not base_url or not token:
    raise SystemExit(1)

def request(method, path, payload=None):
    body = None if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
    headers = {
        "Authorization": f"Bearer {token}",
        "User-Agent": "H1CloudVPNLocalUserPush/1.0",
    }
    if body is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(base_url + path, data=body, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=10) as resp:
        text = resp.read(1024 * 1024).decode("utf-8", "ignore")
    return json.loads(text) if text else {}

try:
    payload = request("GET", "/clients")
except Exception as exc:
    raise SystemExit(f"upstream read failed: {exc}")

upstream_clients = payload.get("clients", [])
if not isinstance(upstream_clients, list):
    raise SystemExit("bad upstream response")

upstream_names = {str(item.get("name", "")) for item in upstream_clients if isinstance(item, dict)}
upstream_uuids = {str(item.get("uuid", "")) for item in upstream_clients if isinstance(item, dict)}
now = int(time.time())
pushed = []

for user in load_local_users():
    if not isinstance(user, dict):
        continue
    name = str(user.get("name", "")).strip()
    client_id = str(user.get("uuid", "")).strip()
    try:
        expires_at = int(user.get("expires_at", 0))
    except Exception:
        continue
    if not name or not client_id or expires_at <= now:
        continue
    if name in upstream_names or client_id in upstream_uuids:
        continue
    days = max(1, int(math.ceil((expires_at - now) / 86400)))
    body = {"name": name, "days": days, "uuid": client_id}
    if int(user.get("traffic_limit_bytes", 0) or 0):
        body["traffic_limit_gb"] = round(int(user.get("traffic_limit_bytes", 0) or 0) / 1073741824, 3)
    if int(user.get("device_limit", 0) or 0):
        body["device_limit"] = int(user.get("device_limit", 0) or 0)
    try:
        request("POST", "/clients", body)
        pushed.append(name)
        upstream_names.add(name)
        upstream_uuids.add(client_id)
    except urllib.error.HTTPError as exc:
        if exc.code != 409:
            detail = exc.read().decode("utf-8", "ignore")
            print(f"push failed for {name}: HTTP {exc.code} {detail}")
    except Exception as exc:
        print(f"push failed for {name}: {exc}")

if pushed:
    print("local users pushed to upstream: " + ", ".join(pushed))
PY
}

sync_upstream_users() {
    local UPSTREAM_URL UPSTREAM_TOKEN

    if ! upstream_configured; then
        return 1
    fi

    UPSTREAM_URL="$(head -n 1 "$UPSTREAM_API_URL_FILE" 2>/dev/null)"
    UPSTREAM_TOKEN="$(head -n 1 "$UPSTREAM_API_TOKEN_FILE" 2>/dev/null)"

    python3 - "$USERS_FILE" "$UPSTREAM_URL" "$UPSTREAM_TOKEN" <<'PY'
import json
import os
import sys
import urllib.request

users_file, base_url, token = sys.argv[1], sys.argv[2].rstrip("/"), sys.argv[3]
url = base_url if base_url.endswith("/clients") else base_url + "/clients"
req = urllib.request.Request(url, headers={
    "Authorization": f"Bearer {token}",
    "User-Agent": "H1CloudVPNFederation/1.0",
})
with urllib.request.urlopen(req, timeout=10) as resp:
    payload = json.loads(resp.read().decode("utf-8"))

clients = payload.get("clients", [])
if not isinstance(clients, list):
    raise SystemExit("bad upstream response")

users = []
for item in clients:
    if not isinstance(item, dict):
        continue
    name = str(item.get("name", "")).strip()
    client_id = str(item.get("uuid", "")).strip()
    try:
        expires_at = int(item.get("expires_at", 0))
        created_at = int(item.get("created_at", 0))
    except Exception:
        continue
    if not name or not client_id or expires_at <= 0:
        continue
    row = {
        "name": name,
        "uuid": client_id,
        "created_at": created_at,
        "expires_at": expires_at,
        "banned": bool(item.get("banned") or item.get("disabled")),
        "banned_at": int(item.get("banned_at", 0) or 0),
        "ban_reason": str(item.get("ban_reason", "") or ""),
    }
    row["traffic_limit_bytes"] = int(item.get("traffic_limit_bytes", 0) or 0)
    row["device_limit"] = int(item.get("device_limit", 0) or 0)
    if item.get("traffic_reset_pending"):
        row["traffic_reset_pending"] = True
    users.append(row)

tmp = f"{users_file}.tmp.{os.getpid()}"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(users, f, ensure_ascii=False, indent=2)
os.replace(tmp, users_file)
print(f"upstream users synced: {len(users)}")
PY
}

sync_upstream_tick() {
    local MODE="${1:-}" BEFORE AFTER OUT PUSH_OUT RC

    if ! upstream_configured; then
        if [ "$MODE" = "manual" ]; then
            echo "federation sync skipped: upstream disabled"
        fi
        return 0
    fi

    PUSH_OUT="$(push_local_users_to_upstream 2>&1)"
    if [ -n "$PUSH_OUT" ]; then
        log_action "federation_push_local" "$PUSH_OUT"
        if [ "$MODE" = "manual" ] || echo "$PUSH_OUT" | grep -q "local users pushed"; then
            echo "$PUSH_OUT"
        fi
    fi

    BEFORE="$(cat "$USERS_FILE" 2>/dev/null || echo "[]")"
    OUT="$(sync_upstream_users 2>&1)"
    RC="$?"
    if [ "$RC" -ne 0 ]; then
        log_action "federation_sync_failed" "$OUT"
        if [ "$MODE" = "manual" ]; then
            echo "federation sync failed:"
            echo "$OUT"
        fi
        return 0
    fi

    AFTER="$(cat "$USERS_FILE" 2>/dev/null || echo "[]")"
    if [ "$BEFORE" != "$AFTER" ]; then
        sync_keys_file >/dev/null 2>&1
        remember_users_state
        if [ "$MODE" != "norestart" ]; then
            restart_xray >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
        fi
        log_action "federation_sync" "$OUT"
        echo "$OUT"
    elif [ "$MODE" = "manual" ]; then
        echo "federation sync: no changes"
    fi

    return 0
}

cmd_federation() {
    local ACTION="${1:-status}"
    local API_URL_VALUE API_TOKEN_VALUE

    case "$ACTION" in
        status|"")
            if upstream_configured; then
                echo "upstream: $(head -n 1 "$UPSTREAM_API_URL_FILE" 2>/dev/null)"
            else
                echo "upstream: disabled"
            fi
            ;;
        upstream)
            if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
                echo "usage: vpn federation upstream API_URL API_TOKEN"
                return 0
            fi
            API_URL_VALUE="$(strip_outer_quotes "$2")"
            API_TOKEN_VALUE="$(strip_outer_quotes "$3")"
            echo "$API_URL_VALUE" > "$UPSTREAM_API_URL_FILE"
            echo "$API_TOKEN_VALUE" > "$UPSTREAM_API_TOKEN_FILE"
            chmod 600 "$UPSTREAM_API_TOKEN_FILE" >/dev/null 2>&1
            log_action "federation_upstream_set" "$API_URL_VALUE"
            sync_upstream_tick manual
            echo "upstream saved"
            ;;
        sync)
            sync_upstream_tick manual
            ;;
        off|disable)
            rm -f "$UPSTREAM_API_URL_FILE" "$UPSTREAM_API_TOKEN_FILE" >/dev/null 2>&1
            log_action "federation_upstream_off" ""
            echo "upstream disabled"
            ;;
        help|*)
            echo "vpn federation status"
            echo "vpn federation upstream API_URL API_TOKEN"
            echo "vpn federation sync"
            echo "vpn federation off"
            ;;
    esac

    return 0
}

cmd_join_token() {
    echo "$(get_join_token)"
    return 0
}

cmd_join() {
    local MASTER_URL="$1"
    local JOIN_TOKEN_VALUE="$2"
    local NODE_VALUE="$3"
    local SUB_PORT_VALUE API_PORT_VALUE SUB_URL_VALUE API_URL_VALUE OUT

    MASTER_URL="$(strip_outer_quotes "$MASTER_URL")"
    JOIN_TOKEN_VALUE="$(strip_outer_quotes "$JOIN_TOKEN_VALUE")"
    NODE_VALUE="$(strip_outer_quotes "$NODE_VALUE")"

    if [ -z "$MASTER_URL" ] || [ -z "$JOIN_TOKEN_VALUE" ] || [ -z "$NODE_VALUE" ]; then
        echo "usage: vpn join http://MASTER_IP:API_PORT/api JOIN_TOKEN NODE_NAME"
        return 0
    fi

    echo "$NODE_VALUE" > "$NODE_NAME_FILE"
    SUB_PORT_VALUE="$(get_sub_port)"
    API_PORT_VALUE="$(saved_api_port)"
    if ! validate_port "$API_PORT_VALUE"; then
        API_PORT_VALUE="$(auto_api_port)"
    fi

    if ! validate_port "$SUB_PORT_VALUE"; then
        echo "subscription port is not configured"
        echo "run: vpn sub PORT"
        return 0
    fi

    SUB_URL_VALUE="http://$(read_subscription_host):$SUB_PORT_VALUE/sub/{uuid}/local"
    API_URL_VALUE=""
    if validate_port "$API_PORT_VALUE"; then
        API_URL_VALUE="http://$(read_subscription_host):$API_PORT_VALUE/api"
    fi

    OUT="$(python3 - "$MASTER_URL" "$JOIN_TOKEN_VALUE" "$NODE_VALUE" "$SUB_URL_VALUE" "$API_URL_VALUE" "$UPSTREAM_API_URL_FILE" "$UPSTREAM_API_TOKEN_FILE" <<'PY'
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

master_url, token, node_name, sub_url, api_url, upstream_file, token_file = sys.argv[1:8]
master_url = master_url.rstrip("/")
join_url = master_url + "/nodes/join"
payload = json.dumps({
    "join_token": token,
    "node_name": node_name,
    "sub_url": sub_url,
    "api_url": api_url,
}).encode("utf-8")

req = urllib.request.Request(join_url, data=payload, method="POST", headers={
    "Content-Type": "application/json",
    "User-Agent": "H1CloudVPNJoin/1.0",
})

try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read().decode("utf-8"))
except urllib.error.HTTPError as exc:
    body = exc.read().decode("utf-8", "ignore")
    try:
        payload = json.loads(body)
        detail = payload.get("error") or body
    except Exception:
        detail = body or exc.reason
    raise SystemExit(f"HTTP {exc.code}: {detail}")

if not data.get("ok"):
    raise SystemExit(data.get("error", "join_failed"))

upstream_url = str(data.get("upstream_url") or master_url).rstrip("/")
api_token = str(data.get("api_token") or "")
if not api_token:
    raise SystemExit("master did not return api_token")

def atomic_text(path, text):
    tmp = f"{path}.tmp.{os.getpid()}"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)

atomic_text(upstream_file, upstream_url + "\n")
atomic_text(token_file, api_token + "\n")
try:
    os.chmod(token_file, 0o600)
except Exception:
    pass

print(f"joined master: {upstream_url}")
print(f"peer url sent: {sub_url}")
PY
)"
    if [ "$?" -ne 0 ]; then
        echo "join failed:"
        echo "$OUT"
        return 0
    fi

    echo "$OUT"
    sync_upstream_tick manual
    sync_keys_file >/dev/null 2>&1
    restart_api_if_running
    restart_sub_if_running
    log_action "node_join_master" "$MASTER_URL $NODE_VALUE"
    return 0
}

cmd_backup() {
    local ACTION="${1:-create}"
    local TARGET="$2"

    case "$ACTION" in
        create|"")
            mkdir -p "$BACKUP_DIR" >/dev/null 2>&1
            python3 - "$BACKUP_DIR" "$USERS_FILE" "$DEVICES_FILE" "$TRAFFIC_FILE" "$DOMAIN_FILE" "$CONFIG_FILE" "$KEY_FILE" "$NODE_NAME_FILE" "$ACTION_LOG_FILE" "$API_TOKEN_FILE" "$SUB_TOKEN_FILE" "$SUB_NAME_FILE" "$TRANSPORT_FILE" "$XHTTP_PATH_FILE" "$XHTTP_METHOD_FILE" "$XHTTP_ALPN_FILE" "$MWS_ENABLED_FILE" "$MWS_DOMAIN_FILE" "$MWS_CERT_FILE" "$MWS_KEY_FILE" "$PEERS_FILE" "$NODES_FILE" "$JOIN_TOKEN_FILE" "$UPSTREAM_API_URL_FILE" "$UPSTREAM_API_TOKEN_FILE" "$UPDATE_URL_FILE" "$AUTO_UPDATE_FILE" "$CDN_WS_ENABLED_FILE" "$CDN_WS_HOST_FILE" "$CDN_WS_SNI_FILE" "$CDN_WS_PORT_FILE" "$CDN_WS_TAG_FILE" "$CDN_WS_PATH_FILE" "$CDN_XHTTP_ENABLED_FILE" "$CDN_XHTTP_HOST_FILE" "$CDN_XHTTP_SNI_FILE" "$CDN_XHTTP_PORT_FILE" "$CDN_XHTTP_TAG_FILE" "$CDN_XHTTP_PUBLIC_PATH_FILE" "$TAG_WS_FILE" "$TAG_XHTTP_FILE" "$TAG_REALITY_FILE" "$REALITY_ENABLED_FILE" "$REALITY_PRIVATE_KEY_FILE" "$REALITY_PUBLIC_KEY_FILE" "$REALITY_SHORT_ID_FILE" "$REALITY_SNI_FILE" "$REALITY_DEST_FILE" "$REALITY_PORT_FILE" "$REALITY_PUBLIC_PORT_FILE" "$PUBLIC_IP_FILE" <<'PY'
import datetime
import os
import sys
import zipfile

backup_dir = sys.argv[1]
paths = sys.argv[2:]
os.makedirs(backup_dir, exist_ok=True)
stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
target = os.path.join(backup_dir, f"backup-{stamp}.zip")
with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as zf:
    for path in paths:
        if path and os.path.isfile(path):
            zf.write(path, arcname=os.path.basename(path))
print(target)
PY
            log_action "backup_create" "$BACKUP_DIR"
            ;;
        list)
            if [ -d "$BACKUP_DIR" ]; then
                ls -1 "$BACKUP_DIR" 2>/dev/null | sed 's#^#backups/#'
            else
                echo "no backups"
            fi
            ;;
        restore)
            TARGET="$(strip_outer_quotes "$TARGET")"
            if [ -z "$TARGET" ]; then
                echo "usage: vpn backup restore backups/backup-YYYYMMDD-HHMMSS.zip"
                return 0
            fi
            if [ ! -f "$TARGET" ]; then
                echo "backup not found: $TARGET"
                return 0
            fi
            python3 - "$TARGET" "$DATA_DIR" <<'PY'
import os
import sys
import zipfile

backup, data_dir = sys.argv[1], sys.argv[2]
allowed = {
    "users.json", "devices.json", "traffic.json", "domain.txt", "config.json", "key.txt", "node_name.txt", "logs.txt",
    "api_token.txt", "sub_token.txt", "sub_name.txt", "transport.txt", "xhttp_path.txt", "xhttp_method.txt", "xhttp_alpn.txt",
    "mws_enabled.txt", "mws_domain.txt", "mws_cert_file.txt", "mws_key_file.txt",
    "peers.txt", "nodes.json", "join_token.txt",
    "upstream_api_url.txt", "upstream_api_token.txt", "update_url.txt", "auto_update.txt",
    "cdn_ws_enabled.txt", "cdn_ws_host.txt", "cdn_ws_sni.txt", "cdn_ws_port.txt", "cdn_ws_tag.txt", "cdn_ws_path.txt",
    "cdn_xhttp_enabled.txt", "cdn_xhttp_host.txt", "cdn_xhttp_sni.txt", "cdn_xhttp_port.txt", "cdn_xhttp_tag.txt", "cdn_xhttp_public_path.txt",
    "tag_ws.txt", "tag_xhttp.txt", "tag_reality.txt",
    "reality_enabled.txt", "reality_private_key.txt", "reality_public_key.txt",
    "reality_short_id.txt", "reality_sni.txt", "reality_dest.txt",
    "reality_port.txt", "reality_public_port.txt", "public_ip.txt",
}
with zipfile.ZipFile(backup, "r") as zf:
    for info in zf.infolist():
        name = os.path.basename(info.filename)
        if name in allowed:
            zf.extract(info, data_dir)
            src = os.path.join(data_dir, info.filename)
            dst = os.path.join(data_dir, name)
            if src != dst and os.path.exists(src):
                os.replace(src, dst)
print("backup restored")
PY
            build_config >/dev/null 2>&1
            sync_keys_file >/dev/null 2>&1
            restart_xray >/dev/null 2>&1
            restart_api_if_running
            restart_sub_if_running
            log_action "backup_restore" "$TARGET"
            ;;
        help|*)
            echo "vpn backup create"
            echo "vpn backup list"
            echo "vpn backup restore backups/backup-YYYYMMDD-HHMMSS.zip"
            ;;
    esac
}

cmd_stats() {
    if [ ! -x "$XRAY_BIN" ]; then
        echo "xray binary is missing"
        return 0
    fi
    "$XRAY_BIN" api statsquery --server="127.0.0.1:$XRAY_STATS_PORT" 2>/dev/null || {
        echo "stats unavailable"
        echo "xray stats api may still be starting or unsupported by this xray build"
    }
}

enforce_traffic_limits() {
    local OUT RC

    if [ ! -x "$XRAY_BIN" ]; then
        return 0
    fi

    OUT="$(python3 - "$USERS_FILE" "$TRAFFIC_FILE" "$XRAY_BIN" "$XRAY_STATS_PORT" <<'PY'
import json
import os
import re
import subprocess
import sys
import time

users_file, traffic_file, xray_bin, stats_port = sys.argv[1:5]

def load_json(path, default):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, type(default)) else default
    except Exception:
        return default

def save_json(path, data):
    tmp = f"{path}.tmp.{os.getpid()}"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)

try:
    proc = subprocess.run(
        [xray_bin, "api", "statsquery", f"--server=127.0.0.1:{stats_port}"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        timeout=6,
        check=False,
    )
except Exception:
    raise SystemExit(0)

raw = proc.stdout or ""
if not raw.strip():
    raise SystemExit(0)

stats = {}
for name, value in re.findall(r'name:\s*"([^"]+)"[\s\S]*?value:\s*([0-9]+)', raw):
    if not name.startswith("user>>>") or ">>>traffic>>>" not in name:
        continue
    parts = name.split(">>>")
    if len(parts) < 5:
        continue
    email = parts[1]
    direction = parts[-1]
    try:
        stats[(email, direction)] = stats.get((email, direction), 0) + int(value)
    except Exception:
        pass

if not stats:
    raise SystemExit(0)

users = load_json(users_file, [])
traffic = load_json(traffic_file, {})
if not isinstance(users, list):
    raise SystemExit(0)

now = int(time.time())
changed_traffic = False
changed_users = False
limited = []

for user in users:
    if not isinstance(user, dict):
        continue
    name = str(user.get("name", ""))
    client_id = str(user.get("uuid", ""))
    if not name or not client_id:
        continue

    counter = 0
    for email in (name, name + "-reality"):
        counter += int(stats.get((email, "uplink"), 0) or 0)
        counter += int(stats.get((email, "downlink"), 0) or 0)

    row = traffic.get(client_id, {})
    if not isinstance(row, dict):
        row = {}
    used = int(row.get("used_bytes", 0) or 0)
    last_counter = int(row.get("last_counter_bytes", 0) or 0)

    if user.pop("traffic_reset_pending", False) or row.pop("reset_pending", False):
        used = 0
        last_counter = counter
        changed_users = True
    else:
        delta = counter - last_counter if counter >= last_counter else counter
        if delta > 0:
            used += delta
            last_counter = counter

    new_row = {
        "used_bytes": used,
        "last_counter_bytes": last_counter,
        "updated_at": now,
    }
    if traffic.get(client_id) != new_row:
        traffic[client_id] = new_row
        changed_traffic = True

    limit_bytes = int(user.get("traffic_limit_bytes", 0) or 0)
    if limit_bytes > 0 and used >= limit_bytes and not (user.get("banned") or user.get("disabled")):
        user["banned"] = True
        user["banned_at"] = now
        user["ban_reason"] = f"traffic_quota_exceeded {used / 1073741824:.2f}/{limit_bytes / 1073741824:.2f}GB"
        user["quota_exceeded_at"] = now
        changed_users = True
        limited.append(name)

if changed_traffic:
    save_json(traffic_file, traffic)
if changed_users:
    save_json(users_file, users)
if limited:
    print("quota_exceeded:" + ",".join(limited))
PY
)"
    RC="$?"

    if [ "$RC" -ne 0 ]; then
        return 0
    fi

    if echo "$OUT" | grep -q '^quota_exceeded:'; then
        echo "$OUT"
        restart_xray >/dev/null 2>&1
        sync_keys_file >/dev/null 2>&1
        remember_users_state
        restart_api_if_running
        restart_sub_if_running
        log_action "traffic_quota_exceeded" "$OUT"
    fi

    return 0
}

script_path() {
    local TARGET RESOLVED
    TARGET="${BASH_SOURCE[0]:-$0}"

    if command -v readlink >/dev/null 2>&1; then
        RESOLVED="$(readlink -f "$TARGET" 2>/dev/null)"
        if [ -n "$RESOLVED" ]; then
            echo "$RESOLVED"
            return 0
        fi
    fi

    case "$TARGET" in
        /*) echo "$TARGET" ;;
        *) echo "$(pwd)/$TARGET" ;;
    esac
}

get_update_url() {
    if [ -n "${UPDATE_URL:-}" ]; then
        printf '%s\n' "$UPDATE_URL" | tr -d '\r' | head -n 1
        return 0
    fi

    if [ -f "$UPDATE_URL_FILE" ] && [ -s "$UPDATE_URL_FILE" ]; then
        head -n 1 "$UPDATE_URL_FILE" 2>/dev/null | tr -d '\r'
        return 0
    fi

    echo "$DEFAULT_UPDATE_URL"
}

auto_update_enabled() {
    local VALUE
    if [ ! -f "$AUTO_UPDATE_FILE" ]; then
        return 0
    fi

    VALUE="$(head -n 1 "$AUTO_UPDATE_FILE" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
    case "$VALUE" in
        0|off|false|no|disabled)
            return 1
            ;;
    esac
    return 0
}

set_auto_update() {
    local VALUE="$1"
    case "$VALUE" in
        1|on|true|yes|enable|enabled)
            echo "1" > "$AUTO_UPDATE_FILE"
            echo "auto update: on"
            ;;
        0|off|false|no|disable|disabled)
            echo "0" > "$AUTO_UPDATE_FILE"
            echo "auto update: off"
            ;;
        *)
            echo "usage: vpn update auto on|off|status"
            ;;
    esac
}

file_sha256() {
    local PATH_VALUE="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$PATH_VALUE" 2>/dev/null | awk '{print $1}'
        return 0
    fi
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$PATH_VALUE" 2>/dev/null | awk '{print $1}'
        return 0
    fi
    if command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$PATH_VALUE" 2>/dev/null | awk '{print $NF}'
        return 0
    fi
    echo ""
}

perform_update() {
    local MODE="$1"
    local URL CURRENT TMP BACKUP STAMP OLD_SHA NEW_SHA

    UPDATE_APPLIED=0
    URL="$(get_update_url)"
    URL="$(strip_outer_quotes "$URL")"

    if [ -z "$URL" ]; then
        if [ "$MODE" != "auto" ]; then
            echo "update url is empty"
            echo "set it: vpn update url https://example.com/main.sh"
        fi
        return 1
    fi

    CURRENT="$(script_path)"
    if [ ! -f "$CURRENT" ]; then
        if [ "$MODE" != "auto" ]; then
            echo "cannot find current script: $CURRENT"
        fi
        return 1
    fi

    TMP="$DATA_DIR/.main.sh.update.$$"
    rm -f "$TMP" >/dev/null 2>&1

    if ! curl -fsSL --max-time 30 -o "$TMP" "$URL"; then
        rm -f "$TMP" >/dev/null 2>&1
        if [ "$MODE" != "auto" ]; then
            echo "update download failed: $URL"
        fi
        return 1
    fi

    if ! bash -n "$TMP" >/dev/null 2>&1; then
        rm -f "$TMP" >/dev/null 2>&1
        if [ "$MODE" != "auto" ]; then
            echo "downloaded script is not valid bash"
        fi
        return 1
    fi

    if cmp -s "$CURRENT" "$TMP"; then
        rm -f "$TMP" >/dev/null 2>&1
        echo "$(date +%s)" > "$UPDATE_LAST_CHECK_FILE"
        if [ "$MODE" != "auto" ]; then
            echo "already latest: $SCRIPT_VERSION"
        fi
        return 0
    fi

    mkdir -p "$BACKUP_DIR" >/dev/null 2>&1
    STAMP="$(date +%Y%m%d-%H%M%S)"
    BACKUP="$BACKUP_DIR/main.sh.$STAMP.bak"
    cp -p "$CURRENT" "$BACKUP" 2>/dev/null || cp "$CURRENT" "$BACKUP" 2>/dev/null

    OLD_SHA="$(file_sha256 "$CURRENT")"
    NEW_SHA="$(file_sha256 "$TMP")"

    if ! mv -f "$TMP" "$CURRENT"; then
        rm -f "$TMP" >/dev/null 2>&1
        if [ "$MODE" != "auto" ]; then
            echo "cannot replace script"
        fi
        return 1
    fi

    chmod +x "$CURRENT" >/dev/null 2>&1
    echo "$URL" > "$UPDATE_URL_FILE"
    echo "$(date +%s)" > "$UPDATE_LAST_CHECK_FILE"
    UPDATE_APPLIED=1
    log_action "script_update" "url=$URL old=$OLD_SHA new=$NEW_SHA backup=$BACKUP"

    echo "script updated"
    echo "backup: $BACKUP"
    if [ -n "$OLD_SHA" ] && [ -n "$NEW_SHA" ]; then
        echo "sha256: $OLD_SHA -> $NEW_SHA"
    fi

    return 0
}

cmd_version() {
    local CURRENT URL AUTO LAST SHA

    CURRENT="$(script_path)"
    URL="$(get_update_url)"
    SHA="$(file_sha256 "$CURRENT")"
    AUTO="off"
    if auto_update_enabled; then
        AUTO="on"
    fi
    LAST="never"
    if [ -f "$UPDATE_LAST_CHECK_FILE" ] && [ -s "$UPDATE_LAST_CHECK_FILE" ]; then
        LAST="$(cat "$UPDATE_LAST_CHECK_FILE" 2>/dev/null)"
    fi

    print_line
    echo "H1Cloud VLESS version"
    print_line
    echo "version: $SCRIPT_VERSION"
    echo "script: $CURRENT"
    if [ -n "$SHA" ]; then
        echo "sha256: $SHA"
    fi
    echo "update_url: $URL"
    echo "auto_update: $AUTO"
    echo "last_update_check: $LAST"
    print_line
}

cmd_update() {
    local ACTION="${1:-run}"
    local VALUE="${2:-}"

    case "$ACTION" in
        run|now|check|"")
            perform_update manual
            if [ "$UPDATE_APPLIED" = "1" ] && [ "${SERVER_MODE:-0}" = "1" ]; then
                echo "update applied, restarting..."
                stop_api_process keep
                stop_sub_process keep
                stop_xray_process
                exec /bin/bash "$(script_path)"
            fi
            ;;
        url|source)
            VALUE="$(strip_outer_quotes "$VALUE")"
            if [ -z "$VALUE" ] || ! echo "$VALUE" | grep -Eq '^https?://'; then
                echo "usage: vpn update url https://example.com/main.sh"
                return 0
            fi
            echo "$VALUE" > "$UPDATE_URL_FILE"
            echo "1" > "$AUTO_UPDATE_FILE"
            echo "update url saved: $VALUE"
            echo "auto update: on"
            ;;
        auto)
            case "$VALUE" in
                status|"")
                    if auto_update_enabled; then
                        echo "auto update: on"
                    else
                        echo "auto update: off"
                    fi
                    echo "interval: ${UPDATE_CHECK_INTERVAL}s"
                    echo "url: $(get_update_url)"
                    ;;
                *)
                    set_auto_update "$VALUE"
                    ;;
            esac
            ;;
        status)
            cmd_version
            ;;
        help|*)
            echo "vpn update                 check URL and replace script if changed"
            echo "vpn update url URL         save update URL and enable auto update"
            echo "vpn update auto on|off     enable/disable hourly auto update"
            echo "vpn update auto status     show auto update status"
            echo "vpn version                show current script version"
            ;;
    esac

    return 0
}

cmd_doctor() {
    local ACTION="${1:-status}"
    local OK=1
    local API_PORT_VALUE SUB_PORT_VALUE

    print_line
    echo "H1Cloud doctor"
    print_line

    for BIN in bash curl python3; do
        if command -v "$BIN" >/dev/null 2>&1; then
            echo "ok: $BIN"
        else
            echo "missing: $BIN"
            OK=0
        fi
    done

    if [ -x "$XRAY_BIN" ]; then
        echo "ok: xray binary"
    else
        echo "missing: xray binary"
        OK=0
    fi

    echo "version: $SCRIPT_VERSION"
    echo "script: $(script_path)"
    echo "update_url: $(get_update_url)"
    if auto_update_enabled; then
        echo "auto_update: on"
    else
        echo "auto_update: off"
    fi
    echo "domain: $(read_domain)"
    echo "node: $(get_node_name)"
    echo "ws: local=$(get_port) public=$(get_public_port)"
    if is_reality_enabled; then
        echo "reality: local=$(get_reality_port) public=$(get_public_reality_port) sni=$(get_reality_sni)"
    else
        echo "reality: disabled"
    fi

    API_PORT_VALUE="$(saved_api_port)"
    SUB_PORT_VALUE="$(saved_sub_port)"
    if api_is_running; then
        echo "api: running on ${API_PORT_VALUE:-unknown}"
    else
        echo "api: stopped"
    fi
    if sub_is_running; then
        echo "subscription: running on ${SUB_PORT_VALUE:-unknown}"
    else
        echo "subscription: stopped"
    fi

    if [ "$ACTION" = "fix" ]; then
        echo "fix: rebuilding config and restarting live services"
        build_config >/dev/null 2>&1
        sync_keys_file >/dev/null 2>&1
        restart_xray >/dev/null 2>&1
        restart_api_if_running
        restart_sub_if_running
        remember_users_state
        log_action "doctor_fix" "config/services refreshed"
    fi

    if [ "$OK" -eq 1 ]; then
        echo "doctor: ok"
    else
        echo "doctor: problems found"
    fi
    print_line
    return 0
}

auto_update_tick() {
    local NOW LAST URL

    if ! auto_update_enabled; then
        return 0
    fi

    URL="$(get_update_url)"
    if [ -z "$URL" ]; then
        return 0
    fi

    NOW="$(date +%s)"
    LAST="$LAST_UPDATE_CHECK"
    if [ -f "$UPDATE_LAST_CHECK_FILE" ] && [ -s "$UPDATE_LAST_CHECK_FILE" ]; then
        LAST="$(cat "$UPDATE_LAST_CHECK_FILE" 2>/dev/null)"
    fi
    if ! echo "$LAST" | grep -Eq '^[0-9]+$'; then
        LAST=0
    fi

    if [ $((NOW - LAST)) -lt "$UPDATE_CHECK_INTERVAL" ]; then
        return 0
    fi

    LAST_UPDATE_CHECK="$NOW"
    echo "$NOW" > "$UPDATE_LAST_CHECK_FILE"

    if perform_update auto && [ "$UPDATE_APPLIED" = "1" ]; then
        echo "auto update applied, restarting..."
        stop_api_process keep
        stop_sub_process keep
        stop_xray_process
        exec /bin/bash "$(script_path)"
    fi

    return 0
}

cmd_ports() {
    local WS_PORT_VALUE WS_PUBLIC_PORT_VALUE REALITY_PORT_VALUE REALITY_PUBLIC_PORT_VALUE
    local API_PORT_VALUE SUB_PORT_VALUE REQUIRED
    local API_STATUS SUB_STATUS

    WS_PORT_VALUE="$(get_port)"
    WS_PUBLIC_PORT_VALUE="$(get_public_port)"
    API_PORT_VALUE="$(saved_api_port)"
    SUB_PORT_VALUE="$(saved_sub_port)"
    API_STATUS="saved"
    SUB_STATUS="saved"
    if ! validate_port "$API_PORT_VALUE"; then
        API_PORT_VALUE="$(auto_api_port)"
        API_STATUS="auto"
    fi
    if ! validate_port "$SUB_PORT_VALUE"; then
        SUB_PORT_VALUE="$(auto_sub_port)"
        SUB_STATUS="auto"
    fi
    REQUIRED=1

    print_line
    echo "Port / allocation status"
    print_line
    echo "ws/xray: local=$WS_PORT_VALUE public=$WS_PUBLIC_PORT_VALUE required=yes"

    if is_reality_enabled; then
        REALITY_PORT_VALUE="$(get_reality_port)"
        REALITY_PUBLIC_PORT_VALUE="$(get_public_reality_port)"
        REQUIRED=$((REQUIRED + 1))
        echo "reality: local=$REALITY_PORT_VALUE public=$REALITY_PUBLIC_PORT_VALUE required=yes"
    else
        echo "reality: disabled required=no"
    fi

    if validate_port "$API_PORT_VALUE"; then
        REQUIRED=$((REQUIRED + 1))
        if api_is_running; then
            echo "api: local=$API_PORT_VALUE status=running required=yes"
        else
            echo "api: local=$API_PORT_VALUE status=$API_STATUS required=yes"
        fi
    else
        echo "api: skipped required=no"
    fi

    if validate_port "$SUB_PORT_VALUE"; then
        REQUIRED=$((REQUIRED + 1))
        if sub_is_running; then
            echo "subscription: local=$SUB_PORT_VALUE status=running required=yes"
        else
            echo "subscription: local=$SUB_PORT_VALUE status=$SUB_STATUS required=yes"
        fi
    else
        echo "subscription: skipped required=no"
    fi

    print_line
    echo "minimum allocations for this config: $REQUIRED"
    echo "fresh default autostarts ws/reality/api/sub."
    print_line
    return 0
}

cmd_status() {
    print_line
    echo "H1Cloud VPN status"
    print_line
    echo "version: $SCRIPT_VERSION"
    echo "node: $(get_node_name)"
    echo "domain: $(read_domain)"
    echo "transport: $(get_transport)"
    if [ "$(get_transport)" = "xhttp" ]; then
        echo "xhttp_path: $(get_xhttp_path)"
        echo "xhttp_method: $(get_xhttp_method)"
    else
        echo "ws_path: /xray"
    fi
    if is_cdn_xhttp_enabled; then
        echo "cdn_xhttp: $(get_cdn_xhttp_host):$(get_cdn_xhttp_port) sni=$(get_cdn_xhttp_sni) path=$(get_cdn_xhttp_public_path)"
    else
        echo "cdn_xhttp: off"
    fi
    if is_cdn_ws_enabled; then
        echo "cdn_ws: $(get_cdn_ws_host):$(get_cdn_ws_port) sni=$(get_cdn_ws_sni) path=$(get_cdn_ws_path)"
    else
        echo "cdn_ws: off"
    fi
    if is_reality_enabled; then
        echo "reality: local=$(get_reality_port) public=$(get_public_reality_port) sni=$(get_reality_sni)"
    else
        echo "reality: off"
    fi
    if api_is_running; then
        echo "api: running port=$(saved_api_port)"
    else
        echo "api: stopped saved_port=$(saved_api_port)"
    fi
    if sub_is_running; then
        echo "subscription: running port=$(saved_sub_port)"
    else
        echo "subscription: stopped saved_port=$(saved_sub_port)"
    fi
    print_line
    cmd_ports
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
    local SAVED_PORT
    if [ -n "$API_PID" ] && ! kill -0 "$API_PID" >/dev/null 2>&1; then
        SAVED_PORT="$(cat "$API_PORT_FILE" 2>/dev/null)"
        API_PID=""
        if validate_port "$SAVED_PORT"; then
            echo "api stopped, trying to restart..."
            start_api_process "$SAVED_PORT" >/dev/null 2>&1
        fi
    fi

    return 0
}

keep_sub_alive() {
    local SAVED_PORT
    if [ -n "$SUB_PID" ] && ! kill -0 "$SUB_PID" >/dev/null 2>&1; then
        SAVED_PORT="$(cat "$SUB_PORT_FILE" 2>/dev/null)"
        SUB_PID=""
        if validate_port "$SAVED_PORT"; then
            echo "subscription stopped, trying to restart..."
            start_sub_process "$SAVED_PORT" >/dev/null 2>&1
        fi
    fi

    return 0
}

restart_api_if_running() {
    local SAVED_PORT
    if api_is_running; then
        SAVED_PORT="$(cat "$API_PORT_FILE" 2>/dev/null)"
        stop_api_process keep
        if validate_port "$SAVED_PORT"; then
            start_api_process "$SAVED_PORT" >/dev/null 2>&1
        fi
    fi
    return 0
}

restart_sub_if_running() {
    local SAVED_PORT
    if sub_is_running; then
        SAVED_PORT="$(cat "$SUB_PORT_FILE" 2>/dev/null)"
        stop_sub_process keep
        if validate_port "$SAVED_PORT"; then
            start_sub_process "$SAVED_PORT" >/dev/null 2>&1
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
            cmd_add "${2:-}" "${3:-}" "${4:-}" "${5:-}"
            ;;
        del|delete|remove)
            cmd_del "${2:-}"
            ;;
        ban|block|disable)
            shift
            cmd_ban "$@"
            ;;
        unban|unblock|enable)
            cmd_unban "${2:-}"
            ;;
        list|users)
            cmd_list
            ;;
        info)
            cmd_info "${2:-}"
            ;;
        status)
            cmd_status
            ;;
        link)
            make_link "${2:-}" || true
            ;;
        limit|limits|quota)
            cmd_limit "${2:-}" "${3:-}" "${4:-}" "${5:-}"
            ;;
        keys)
            cmd_keys
            ;;
        logs)
            cmd_logs "${2:-}"
            ;;
        node)
            shift
            cmd_node "$*"
            ;;
        tag|tags|label|labels)
            shift
            cmd_tag "$@"
            ;;
        cdn|ws-cdn|manual)
            shift
            cmd_cdn "$@"
            ;;
        xhttp)
            shift
            cmd_xhttp "$@"
            ;;
        mws|mwscdn)
            shift
            cmd_mws "$@"
            ;;
        transport)
            shift
            cmd_transport "$@"
            ;;
        join-token)
            cmd_join_token
            ;;
        join)
            cmd_join "${2:-}" "${3:-}" "${4:-}"
            ;;
        peer|peers)
            shift
            cmd_peer "$@"
            ;;
        federation|fed)
            shift
            cmd_federation "$@"
            ;;
        backup|backups)
            cmd_backup "${2:-}" "${3:-}"
            ;;
        stats|traffic)
            cmd_stats
            ;;
        update|upgrade)
            cmd_update "${2:-}" "${3:-}"
            ;;
        version|ver)
            cmd_version
            ;;
        doctor|diag|diagnose)
            cmd_doctor "${2:-}"
            ;;
        renew)
            cmd_renew "${2:-}" "${3:-}"
            ;;
        domain)
            cmd_domain "${2:-}"
            ;;
        ports)
            cmd_ports
            ;;
        reality)
            cmd_reality "${2:-}" "${3:-}" "${4:-}" "${5:-}"
            ;;
        api)
            cmd_api "${2:-}" "${3:-}" "${4:-}"
            ;;
        sub|subscription)
            shift
            cmd_sub "$@"
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
    SERVER_MODE=1

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

    sync_upstream_tick norestart >/dev/null 2>&1

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
    echo "node: $(get_node_name)"
    echo "local port: $(get_port)"
    echo "domain: $(read_domain)"
    echo "public port: $(get_public_port)"
    if is_reality_enabled; then
        echo "reality local port: $(get_reality_port)"
        echo "reality public port: $(get_public_reality_port)"
        echo "reality sni: $(get_reality_sni)"
    else
        echo "reality: disabled (vpn reality PORT to enable)"
    fi
    echo "allocations needed: see vpn ports"
    echo "type: vpn help"
    print_line
    blank
    echo "https://h1cloud.su - Р»СѓС‡С€РёР№ С…РѕСЃС‚РёРЅРі"
    echo "https://t.me/h1cloudbot"
    echo "РџСЂРѕРіСЂР°РјРјРёСЃС‚ - https://h1guro.ovh"
    print_line

    start_xray_process
    if [ "$?" -ne 0 ]; then
        echo "xray start failed, console will stay alive"
    fi

    AUTO_API_PORT="$(auto_api_port)"
    if validate_port "$AUTO_API_PORT"; then
        start_api_process "$AUTO_API_PORT" >/dev/null 2>&1
    else
        echo "api autostart skipped: cannot choose port"
    fi

    AUTO_SUB_PORT="$(auto_sub_port)"
    if validate_port "$AUTO_SUB_PORT"; then
        start_sub_process "$AUTO_SUB_PORT" >/dev/null 2>&1
    else
        echo "subscription autostart skipped: cannot choose port"
    fi

    LAST_CHECK=0
    LAST_FEDERATION_SYNC=0
    LAST_LIMIT_CHECK=0

    while true; do
        sync_external_user_changes

        if IFS= read -r -t 1 LINE; then
            handle_cmd "$LINE"
        fi

        sync_external_user_changes

        NOW="$(date +%s)"
        if [ $((NOW - LAST_CHECK)) -ge "$CHECK_INTERVAL" ]; then
            check_expired_loop_tick
            LAST_CHECK="$NOW"
        fi

        if [ $((NOW - LAST_FEDERATION_SYNC)) -ge "$FEDERATION_SYNC_INTERVAL" ]; then
            sync_upstream_tick
            LAST_FEDERATION_SYNC="$NOW"
        fi

        if [ $((NOW - LAST_LIMIT_CHECK)) -ge "$LIMIT_CHECK_INTERVAL" ]; then
            enforce_traffic_limits
            LAST_LIMIT_CHECK="$NOW"
        fi

        auto_update_tick
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
