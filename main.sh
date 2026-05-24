#!/bin/bash
set -e

echo "========================================"
echo "starting xray for pterodactyl"
echo "========================================"

if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required"
    exit 1
fi

if [ ! -f "./xray" ]; then
    echo "downloading xray..."

    curl -L -o xray.zip "https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip"

    if command -v unzip >/dev/null 2>&1; then
        unzip -o -q xray.zip
    elif command -v python3 >/dev/null 2>&1; then
        python3 -m zipfile -e xray.zip .
    else
        echo "unzip or python3 is required"
        exit 1
    fi

    rm -f xray.zip
    chmod +x ./xray
fi

PORT="${SERVER_PORT:-25565}"
DOMAIN="${DOMAIN:-${XRAY_DOMAIN:-${SERVER_IP:-localhost}}}"

if [ ! -f uuid.txt ]; then
    if [ -f /proc/sys/kernel/random/uuid ]; then
        cat /proc/sys/kernel/random/uuid > uuid.txt
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import uuid; print(uuid.uuid4())" > uuid.txt
    else
        echo "cannot generate uuid"
        exit 1
    fi
fi

UUID="$(cat uuid.txt)"

cat > config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": $PORT,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID"
          }
        ],
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
EOF

echo "========================================"
echo "xray is ready"
echo "domain: $DOMAIN"
echo "port: $PORT"
echo "uuid: $UUID"
echo "link (and at file key.txt):"
echo "vless://${UUID}@${DOMAIN}:${PORT}?type=ws&path=%2Fxray&encryption=none#Pterodactyl-Xray"
echo "========================================"
echo ""
echo "🚀 h1cloud.su - лучший хостинг"
echo "🚀 t.me/h1cloudbot"
echo "🚀 Программист - h1guro.ovh"
echo "========================================"
echo "all done. gl!!!!"
cat > key.txt <<EOF
vless://${UUID}@${DOMAIN}:${PORT}?type=ws&path=%2Fxray&encryption=none#H1CLOUD
EOF
exec ./xray run -config config.json
