#!/bin/bash
set -euo pipefail

# Оновлення системи та встановлення python3-pip
apt-get update -yq
apt-get install python3-pip -yq

# Створюємо каталог для додатку
mkdir -p /app

# Клонування репозиторію з GitHub
# Замість YOUR_GITHUB_USERNAME підставте vhurna
git clone https://github.com/vhurna/azure_task_12_deploy_app_with_vm_extention.git || exit 1
cd azure_task_12_deploy_app_with_vm_extention

# Копіюємо файли додатку у /app
cp -r app/* /app

# Налаштування системного сервісу, якщо файл існує
if [[ -f /app/todoapp.service ]]; then
    mv /app/todoapp.service /etc/systemd/system/
    chmod 755 /etc/systemd/system/todoapp.service
    systemctl daemon-reload
    systemctl enable todoapp
    systemctl start todoapp
else
    echo "Warning: /app/todoapp.service не знайдено, пропускаємо налаштування systemd"
fi
