#!/bin/bash

# ==========================================
ALLOWED_IPS=("185.218.137.132")
# ==========================================

echo "Проверка прав доступа..."
CURRENT_IP=$(curl -s ifconfig.me)

MATCH=false
for ip in "${ALLOWED_IPS[@]}"; do
    if [ "$ip" == "$CURRENT_IP" ]; then
        MATCH=true
        break
    fi
done

# Если совпадений нет, выдаем ошибку и выходим
if [ "$MATCH" = false ]; then
    clear
    echo "❌ Ошибка доступа: Ваш IP-адрес ($CURRENT_IP) не находится в белом списке."
    echo "Скрипт предназначен только для авторизованных серверов."
    exit 1
fi

# Если IP разрешен, идем дальше
clear
echo "================================================================"
echo "🚀 Автоматическая настройка Xray (VLESS + WS)"
echo "👨‍💻 Разработчик решения: h1guro.ovh"
echo "💎 Спонсор установки — хостинг h1cloud:"
echo "🌐 Сайт: h1cloud.su | 🤖 Бот: t.me/h1cloudbot"
echo "================================================================"
echo ""

# Спрашиваем домен у пользователя
read -p "Введите ваш привязанный домен (например, lololol.free.h1cloud.ru): " DOMAIN

# Порт сервера
PORT=${SERVER_PORT:-25587}

# Генерируем случайный UUID
UUID=$(cat /proc/sys/kernel/random/uuid)

echo "=> Создаем config.json..."

# Записываем конфигурацию в файл
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

# Даем права на исполнение и запускаем
chmod +x ./xray
./xray run -config config.json
