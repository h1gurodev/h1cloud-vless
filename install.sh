#!/bin/bash

# ==========================================
# БЕЛЫЙ СПИСОК IP
ALLOWED_IPS=("185.218.137.132" "ТВОЙ_ВТОРОЙ_IP")
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

# Переходим в рабочую папку
mkdir -p $HOME/xray
cd $HOME/xray

# СКАЧИВАНИЕ И РАСПАКОВКА XRAY
if [ ! -f "./xray" ]; then
    echo "=> Ядро Xray не найдено. Начинаю загрузку с GitHub..."
    wget -qO xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    
    echo "=> Распаковка архива..."
    # Так как команды unzip на сервере нет, используем Python или Busybox
    if command -v unzip &> /dev/null; then
        unzip -q xray.zip
    elif command -v python3 &> /dev/null; then
        python3 -m zipfile -e xray.zip .
    elif command -v busybox &> /dev/null; then
        busybox unzip -q xray.zip
    else
        echo "❌ Ошибка: Не могу распаковать архив. На сервере нет утилит unzip или python3."
        exit 1
    fi
    # Удаляем мусор
    rm xray.zip
else
    echo "=> Ядро Xray уже скачано, пропускаем загрузку."
fi

# Порт сервера
PORT=${SERVER_PORT:-25587}
UUID=$(cat /proc/sys/kernel/random/uuid)

echo "=> Создаем config.json..."

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
