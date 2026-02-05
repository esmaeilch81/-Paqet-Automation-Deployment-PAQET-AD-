#!/bin/bash
# Developer: Esmaeil (@Esmaeilch81)
# Description: Paqet Server Auto-Installer

# Standard colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Starting Paqet Auto-Installer...     ${NC}"
echo -e "${GREEN}      Developed by: @Esmaeilch81        ${NC}"
echo -e "${GREEN}========================================${NC}"

# 1. Update and Install Dependencies 
echo "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install curl wget git nano htop net-tools unzip zip software-properties-common libpcap-dev iptables-persistent -y 

# 2. Download and Install Paqet 
echo "Downloading Paqet binary..."
VERSION="v1.0.0-alpha.13"
wget https://github.com/hanselime/paqet/releases/download/$VERSION/paqet-linux-amd64-$VERSION.tar.gz 
tar -xvf paqet-linux-amd64-$VERSION.tar.gz 
sudo mv paqet_linux_amd64 /usr/local/bin/paqet 
sudo chmod +x /usr/local/bin/paqet 

# Fix libpcap shared library 
sudo ln -sf /usr/lib/x86_64-linux-gnu/libpcap.so /usr/lib/x86_64-linux-gnu/libpcap.so.0.8 
sudo ldconfig 

# 3. Port Configuration & Conflict Check
DEFAULT_PORT=443
while true; do
    read -p "Enter desired port (Default: 443): " PORT
    PORT=${PORT:-$DEFAULT_PORT}
    
    if sudo netstat -tuln | grep -q ":$PORT "; then
        echo -e "${RED}Error: Port $PORT is already in use!${NC}"
        read -p "Do you want to try another port? (y/n): " retry
        if [[ $retry != "y" ]]; then exit 1; fi
    else
        echo -e "${GREEN}Port $PORT is available.${NC}"
        break
    fi
done

# 4. Smart Network Discovery [cite: 1, 2]
echo "Extracting network information..."
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1) [cite: 1, 2]
LOCAL_IP=$(ip addr show $INTERFACE | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -n1)
GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -n1) [cite: 2]

# Get Gateway MAC (Ping first to ensure it's in ARP cache) 
ping -c 2 $GATEWAY_IP > /dev/null
GATEWAY_MAC=$(arp -n $GATEWAY_IP | grep $GATEWAY_IP | awk '{print $3}') 

# Generate Secret 
SECRET=$(paqet secret) 

echo -e "Detected Interface: ${GREEN}$INTERFACE${NC}"
echo -e "Detected Gateway MAC: ${GREEN}$GATEWAY_MAC${NC}"

# 5. Create server.yaml 
sudo mkdir -p /etc/paqet 
cat <<EOF | sudo tee /etc/paqet/server.yaml
secret: "$SECRET"
destination: "127.0.0.1:80"
listen: ":$PORT"
interface: "$INTERFACE"
local_ip: "$LOCAL_IP"
gateway_ip: "$GATEWAY_IP"
gateway_mac: "$GATEWAY_MAC"
EOF

# 6. Firewall & Iptables Optimization 
echo "Applying Iptables rules..."
sudo ufw allow $PORT/tcp 
sudo iptables -t raw -F 
sudo iptables -t mangle -F 
sudo iptables -t raw -A PREROUTING -p tcp --dport $PORT -j NOTRACK 
sudo iptables -t raw -A OUTPUT -p tcp --sport $PORT -j NOTRACK 
sudo iptables -t mangle -A OUTPUT -p tcp --sport $PORT --tcp-flags RST RST -j DROP 
sudo netfilter-persistent save 

# 7. Systemd Service Creation 
echo "Creating systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/paqet.service
[Unit]
Description=paqet Server
After=network.target

[Service]
ExecStart=/usr/local/bin/paqet run -c /etc/paqet/server.yaml
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 8. Start Service 
sudo systemctl daemon-reload 
sudo systemctl enable paqet 
sudo systemctl start paqet 

echo -e "${GREEN}Installation complete! Service is running.${NC}"
sudo systemctl status paqet
