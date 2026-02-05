#!/bin/bash

echo "🚀 شروع آپلود پروژه به GitHub..."

# 1. نصب git اگر نصب نیست
if ! command -v git &> /dev/null; then
    echo "📦 در حال نصب git..."
    sudo apt update
    sudo apt install -y git
fi

# 2. تنظیم اطلاعات
echo "👤 تنظیم اطلاعات کاربری..."
git config --global user.name "@Esmaeilch81"
git config --global user.email "Esich81@gmail.com"

# 3. ساختار پروژه ایجاد کن
echo "📁 ایجاد ساختار پروژه..."
mkdir -p paqet-automation/{server,client,docs}
cp paqet-server.sh paqet-automation/server/install.sh
cp paqet-client.sh paqet-automation/client/install.sh

# 4. ایجاد فایل README
cat > paqet-automation/README.md << 'EOF'
# Paqet Automation Deployment 🚀

## Quick Installation

### Server:
```bash
curl -sSL https://raw.githubusercontent.com/esmaeilch81/paqet-automation/main/server/install.sh | sudo bash
