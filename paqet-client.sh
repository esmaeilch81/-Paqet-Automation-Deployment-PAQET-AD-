#!/bin/bash
# Developer: Esmaeil (@Esmaeilch81)
# Description: Paqet Client Automation Deployment

# Professional UI Colors
INFO='\033[0;34m'
SUCCESS='\033[0;32m'
WARNING='\033[0;33m'
ERROR='\033[0;31m'
NC='\033[0m'

echo -e "${INFO}========================================${NC}"
echo -e "${INFO}   PAQET CLIENT AUTOMATION DEPLOYMENT   ${NC}"
echo -e "${SUCCESS}      Developed by: @Esmaeilch81        ${NC}"
echo -e "${INFO}========================================${NC}"

# 1. Dependency Check
echo -e "${INFO}[1/6] Checking system dependencies...${NC}"
sudo apt update -qq
sudo apt install -y curl wget libpcap-dev net-tools -qq 

# 2. Binary Installation
if [ ! -f "/usr/local/bin/paqet" ]; then
    echo -e "${INFO}[2/6] Installing Paqet binary...${NC}"
    VERSION="v1.0.0-alpha.13"
    wget -q https://github.com/hanselime/paqet/releases/download/$VERSION/paqet-linux-amd64-$VERSION.tar.gz 
    tar -xzf paqet-linux-amd64-$VERSION.tar.gz 
    sudo mv paqet_linux_amd64 /usr/local/bin/paqet 
    sudo chmod +x /usr/local/bin/paqet 
    sudo ln -sf /usr/lib/x86_64-linux-gnu/libpcap.so /usr/lib/x86_64-linux-gnu/libpcap.so.0.8 
else
    echo -e "${SUCCESS}Paqet binary already installed.${NC}"
fi
# 3. User Input for Connection
echo -e "${INFO}[3/6] Configuration Input...${NC}"
read -p "Enter Remote Server IP: " REMOTE_IP
read -p "Enter Remote Server Port (Default 443): " REMOTE_PORT
REMOTE_PORT=${REMOTE_PORT:-443}
read -p "Enter Secret (from Server): " SECRET

# 4. Intelligent Network Discovery
echo -e "${INFO}[4/6] Detecting local network topology...${NC}"
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1) 
LOCAL_IP=$(ip addr show $INTERFACE | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -n1) 
GATEWAY_IP=$(ip route | grep default | awk '{print $3}' | head -n1) 

# Refresh ARP cache for Gateway MAC
ping -c 2 $GATEWAY_IP > /dev/null
GATEWAY_MAC=$(arp -n $GATEWAY_IP | grep $GATEWAY_IP | awk '{print $3}') 

if [ -z "$GATEWAY_MAC" ]; then
    echo -e "${ERROR}Critical Error: Could not resolve Gateway MAC address.${NC}"
    exit 1
fi

# 5. Config File Generation
echo -e "${INFO}[5/6] Generating client.yaml...${NC}"
cat <<EOF > client.yaml
secret: "$SECRET"
destination: "$REMOTE_IP:$REMOTE_PORT"
listen: "127.0.0.1:1080"
interface: "$INTERFACE"
local_ip: "$LOCAL_IP"
gateway_ip: "$GATEWAY_IP"
gateway_mac: "$GATEWAY_MAC"
EOF

# 6. Optimized Routing/Iptables for Client
echo -e "${INFO}[6/6] Applying network optimizations...${NC}"
# Flush previous rules to prevent conflicts
sudo iptables -t raw -F 
sudo iptables -t mangle -F 

# Apply NOTRACK for tunnel performance
sudo iptables -t raw -A PREROUTING -p tcp --dport $REMOTE_PORT -j NOTRACK 
sudo iptables -t raw -A OUTPUT -p tcp --sport $REMOTE_PORT -j NOTRACK 
# Prevent local kernel from interfering with tunnel packets
sudo iptables -t mangle -A OUTPUT -p tcp --sport $REMOTE_PORT --tcp-flags RST RST -j DROP 

echo -e "${SUCCESS}========================================${NC}"
echo -e "${SUCCESS}   SETUP COMPLETE - READY TO RUN        ${NC}"
echo -e "${SUCCESS}========================================${NC}"
echo -e "To start the client, run:"
echo -e "${WARNING}sudo paqet run -c client.yaml${NC}"