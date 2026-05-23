#!/bin/bash

# ==========================================
# БЕЛЫЙ СПИСОК IP (Оставь нужные или удали блок, если бесит)
ALLOWED_IPS=("185.218.137.132" "ТВОЙ_ВТОРОЙ_IP")
CURRENT_IP=$(curl -s ifconfig.me)
MATCH=false
for ip in "${ALLOWED_IPS[@]}"; do
    if [ "$ip" == "$CURRENT_IP" ]; then MATCH=true; break; fi
done
if [ "$MATCH" = false ]; then
    clear; echo "❌ Ошибка: IP-адрес ($CURRENT_IP) не в белом списке."; exit 1
fi
# ==========================================

clear
echo "================================================================"
echo "🚀 Автоматическая настройка Xray (VLESS + WS)"
echo "👨‍💻 Разработчик решения: h1guro.ovh"
echo "💎 Спонсор установки — хостинг h1cloud:"
echo "🌐 Сайт: h1cloud.su | 🤖 Бот: t.me/h1cloudbot"
echo "================================================================"
echo ""

# Создаем папку и качаем ядро молча
mkdir -p $HOME/xray
cd $HOME/xray

if [ ! -f "./xray" ]; then
    echo "=> Скачивание ядра Xray..."
    wget -qO xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
    
    if command -v unzip &> /dev/null; then unzip -q xray.zip
    elif command -v python3 &> /dev/null; then python3 -m zipfile -e xray.zip .
    elif command -v busybox &> /dev/null; then busybox unzip -q xray.zip
    else echo "❌ Ошибка: Не могу распаковать архив."; exit 1; fi
    rm xray.zip
fi

# Генерация данных
PORT=${SERVER_PORT:-25587}
UUID=$(cat /proc/sys/kernel/random/uuid)

# Пробуем подхватить домен из переменных среды панели, если его нет — ставим заглушку
DOMAIN=${DOMAIN:-"СЮДА_ВПИСАТЬ_ПРИВЯЗАННЫЙ_ДОМЕН"}

echo "=> Создаем конфигурацию..."

cat <<EOF > config.json
{
  "log": {"loglevel": "warning"},
  "inbounds": [{
    "port": $PORT,
    "listen": "0.0.0.0",
    "protocol": "vless",
    "settings": {"clients": [{"id": "$UUID", "level": 0, "email": "user"}], "decryption": "none"},
    "streamSettings": {"network": "ws", "wsSettings": {"path": "/xray"}}
  }],
  "outbounds": [{"protocol": "freedom"}]
}
EOF

echo "=> Готово!"
echo ""
echo "================================================================"
echo "🎉 ВАША ССЫЛКА ДЛЯ ПОДКЛЮЧЕНИЯ (СКОПИРУЙТЕ ЕЁ):"
echo "vless://${UUID}@${DOMAIN}:443?type=ws&security=tls&path=%2Fxray&sni=${DOMAIN}&encryption=none#h1cloudVPN"
echo "================================================================"
echo "⚠️ ВАЖНО: При добавлении в приложение замените '$DOMAIN' на домен, который вы привязали в панели!"
echo "================================================================"
echo "🔥 Заказывайте мощные серверы: h1cloud.su | t.me/h1cloudbot"
echo "================================================================"
echo ""
echo "=> Xray запущен и работает. Консоль можно закрывать."

chmod +x ./xray
./xray run -config config.json
