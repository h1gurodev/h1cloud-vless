#!/bin/bash

# ==========================================
# БЕЛЫЙ СПИСОК IP
ALLOWED_IPS=("185.218.137.132")
# ==========================================

# Проверка IP
CURRENT_IP=$(curl -s ifconfig.me)
MATCH=false
for ip in "${ALLOWED_IPS[@]}"; do
    if [ "$ip" == "$CURRENT_IP" ]; then
        MATCH=true
        break
    fi
done

if [ "$MATCH" = false ]; then
    clear
    echo "❌ Ошибка: IP-адрес ($CURRENT_IP) не в белом списке."
    exit 1
fi

# Берем домен из аргумента команды
DOMAIN=$1

# Если домен не передали, ругаемся и показываем, как надо
if [ -z "$DOMAIN" ]; then
    clear
    echo "❌ Ошибка: Вы не указали домен при запуске!"
    echo "================================================================"
    echo "Правильная команда для запуска:"
    echo "curl -s https://raw.githubusercontent.com/h1gurodev/h1cloud-vless/refs/heads/main/install.sh | bash -s -- твойдомен.ru"
    echo "================================================================"
    exit 1
fi

clear
echo "================================================================"
echo "🚀 Автоматическая настройка Xray (VLESS + WS)"
echo "👨‍💻 Разработчик решения: h1guro.ovh"
echo "💎 Спонсор установки — хостинг h1cloud:"
echo "🌐 Сайт: h1cloud.su | 🤖 Бот: t.me/h1cloudbot"
echo "================================================================"
echo ""
echo "=> Используем домен: $DOMAIN"

# Порт сервера
PORT=${SERVER_PORT:-25587}
UUID=$(cat /proc/sys/kernel/random/uuid)

# Ищем папку xray и переходим в нее
if [ -d "$HOME/xray" ]; then
    cd "$HOME/xray"
elif [ -d "./xray" ]; then
    cd "./xray"
fi

echo "=> Создаем config.json в папке $(pwd)..."

cat <<EOF > config.json
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
            "id": "$UUID",
            "level": 0,
            "email": "user"
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

echo "=> Конфиг успешно создан!"
echo ""
echo "================================================================"
echo "🎉 ВАША ССЫЛКА ДЛЯ ПОДКЛЮЧЕНИЯ (СКОПИРУЙТЕ ЕЁ):"
echo "vless://${UUID}@${DOMAIN}:443?type=ws&security=tls&path=%2Fxray&sni=${DOMAIN}&encryption=none#h1cloudVPN"
echo "================================================================"
echo "🔥 Спасибо, что выбираете h1cloud!"
echo "💻 Заказывайте мощные серверы: h1cloud.su | t.me/h1cloudbot"
echo "👨‍💻 Cайт разработчика: h1guro.ovh"
echo "================================================================"
echo ""
echo "=> Запускаем сервер Xray..."

chmod +x ./xray
./xray run -config config.json
