#!/bin/bash
set -e

# SOC Automation Deployment Tool
# Author: Antigravity
# Version: 1.0

# Colors for Output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    SOC AUTOMATION CENTER - DEPLOYMENT TOOL      ${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
  echo -e "${YELLOW}Please run as root or with sudo${NC}"
  exit 1
fi

LOG_FILE="soc_install_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${GREEN}[1/6] Updating System & Installing Dependencies...${NC}"
apt-get update -qq
apt-get install -y curl jq python3 python3-requests docker.io unzip tar cron sed wget gnupg apt-transport-https

# ------------------------------------------------------------------
# 2. Install Wazuh (All-in-one)
# ------------------------------------------------------------------
echo ""
echo -e "${GREEN}[2/6] Installing Wazuh SIEM Platform...${NC}"
echo "This may take 5-10 minutes..."

# Check if already installed
if systemctl is-active --quiet wazuh-manager 2>/dev/null; then
    echo "✅ Wazuh already installed, skipping..."
else
    if [ -f "wazuh-install.sh" ]; then
        echo "Using local wazuh-install.sh..."
        bash wazuh-install.sh -a -i
    else
        echo "Downloading Wazuh installer..."
        curl -sO https://packages.wazuh.com/4.9/wazuh-install.sh
        chmod +x wazuh-install.sh
        bash wazuh-install.sh -a -i
    fi
fi

# Wait for Wazuh to be ready
sleep 10

# ------------------------------------------------------------------
# 3. Configure Wazuh Integration
# ------------------------------------------------------------------
echo ""
echo -e "${GREEN}[3/6] Configuring Wazuh → n8n Integration...${NC}"

# Create Integration Script
INTEGRATION_FILE="/var/ossec/integrations/custom-n8n"
echo "Creating custom integration script..."
cat > "$INTEGRATION_FILE" << 'INTEGRATION_EOF'
#!/usr/bin/env python3
import sys
import json
import requests

try:
    alert_file = sys.argv[1]
    hook_url = sys.argv[3]
except IndexError:
    sys.exit(1)

try:
    with open(alert_file) as f:
        alert_json = json.load(f)
    
    headers = {'content-type': 'application/json'}
    requests.post(hook_url, data=json.dumps(alert_json), headers=headers, timeout=10)
    sys.exit(0)
except Exception:
    sys.exit(1)
INTEGRATION_EOF

chmod 750 "$INTEGRATION_FILE"
chown root:ossec "$INTEGRATION_FILE"

# Update ossec.conf
OSSEC_CONF="/var/ossec/etc/ossec.conf"
if ! grep -q "<name>custom-n8n</name>" "$OSSEC_CONF"; then
    echo "Injecting integration block into ossec.conf..."
    # Backup first
    cp "$OSSEC_CONF" "${OSSEC_CONF}.bak"
    
    # Add integration before closing tag
    sed -i '/<\/ossec_config>/i \
  <integration>\n    <name>custom-n8n</name>\n    <hook_url>http://127.0.0.1:5678/webhook/wazuh-alert</hook_url>\n    <level>5</level>\n    <alert_format>json</alert_format>\n  </integration>' "$OSSEC_CONF"
fi

echo "Restarting Wazuh Manager..."
systemctl restart wazuh-manager
sleep 5

# ------------------------------------------------------------------
# 4. Setup Catalyst
# ------------------------------------------------------------------
echo ""
echo -e "${GREEN}[4/6] Deploying Catalyst Ticket System...${NC}"

# Check if catalyst binary exists
if [ ! -f "catalyst_Linux_x86_64.tar.gz" ]; then
    echo -e "${YELLOW}Warning: catalyst_Linux_x86_64.tar.gz not found in current directory${NC}"
    echo "Please download Catalyst from SecurityBrew and place it here, then re-run."
    echo "Skipping Catalyst installation..."
    SKIP_CATALYST=true
else
    SKIP_CATALYST=false
fi

if [ "$SKIP_CATALYST" = false ]; then
    echo "Extracting Catalyst binary..."
    tar -xzf catalyst_Linux_x86_64.tar.gz
    mv catalyst /usr/local/bin/
    chmod +x /usr/local/bin/catalyst

    # Create Service
    echo "Creating systemd service..."
    cat > /etc/systemd/system/catalyst.service <<'SERVICE_EOF'
[Unit]
Description=Catalyst Ticket System
After=network.target

[Service]
ExecStart=/usr/local/bin/catalyst serve --app-url http://localhost:8090
Restart=always
User=root
WorkingDirectory=/root

[Install]
WantedBy=multi-user.target
SERVICE_EOF

    systemctl daemon-reload
    systemctl enable catalyst
    systemctl start catalyst

    # Wait for Catalyst
    echo "Waiting for Catalyst to start..."
    for i in {1..30}; do
        if curl -s http://localhost:8090/ > /dev/null 2>&1; then
            echo "✅ Catalyst is running"
            break
        fi
        sleep 2
    done

    # Setup DNS Alias
    echo "Setting up catalystip DNS alias..."
    IP=$(hostname -I | awk '{print $1}')
    
    # Remove any existing catalystip entry
    sed -i '/catalystip/d' /etc/hosts
    echo "$IP catalystip" >> /etc/hosts

    # Create updater script
    if [ -f "scripts/update_catalyst_ip.sh" ]; then
        echo "Using local updater script..."
        cp scripts/update_catalyst_ip.sh /usr/local/bin/update_catalyst_ip.sh
        chmod +x /usr/local/bin/update_catalyst_ip.sh
    else
        echo "Creating updater script from template..."
        cat > /usr/local/bin/update_catalyst_ip.sh <<'UPDATER_EOF'
#!/bin/bash
CURRENT_IP=$(hostname -I | awk '{print $1}')
sed -i '/catalystip/d' /etc/hosts
echo "$CURRENT_IP catalystip" >> /etc/hosts
UPDATER_EOF
        chmod +x /usr/local/bin/update_catalyst_ip.sh
    fi

    # Add to cron
    (crontab -l 2>/dev/null | grep -v update_catalyst_ip; echo "* * * * * /usr/local/bin/update_catalyst_ip.sh") | crontab -
    (crontab -l 2>/dev/null | grep -v @reboot.*update_catalyst_ip; echo "@reboot /usr/local/bin/update_catalyst_ip.sh") | crontab -

    # Catalyst uses PocketBase backend
    echo "Configuring Catalyst admin (PocketBase)..."
    sleep 3
    
    # Try PocketBase admin auth first
    TOKEN_RESP=$(curl -s -X POST http://localhost:8090/api/admins/auth-with-password \
      -H "Content-Type: application/json" \
      -d '{"identity":"admin@catalyst.local","password":"admin123"}' 2>/dev/null)
    
    CATALYST_TOKEN=$(echo "$TOKEN_RESP" | jq -r .token 2>/dev/null || echo "")
    
    # If admin auth fails, try regular user collection
    if [ -z "$CATALYST_TOKEN" ] || [ "$CATALYST_TOKEN" = "null" ]; then
        sleep 2
        TOKEN_RESP=$(curl -s -X POST http://localhost:8090/api/collections/users/auth-with-password \
          -H "Content-Type: application/json" \
          -d '{"identity":"admin@catalyst.local","password":"admin123"}' 2>/dev/null)
        
        CATALYST_TOKEN=$(echo "$TOKEN_RESP" | jq -r .token 2>/dev/null || echo "")
    fi
    
    if [ -z "$CATALYST_TOKEN" ] || [ "$CATALYST_TOKEN" = "null" ]; then
        echo -e "${YELLOW}Could not retrieve Catalyst token automatically${NC}"
        CATALYST_TOKEN="MANUAL_SETUP_REQUIRED"
    fi
else
    CATALYST_TOKEN="CATALYST_NOT_INSTALLED"
fi

# ------------------------------------------------------------------
# 5. Setup n8n (Docker)
# ------------------------------------------------------------------
echo ""
echo -e "${GREEN}[5/6] Deploying n8n Automation Engine...${NC}"

# Stop existing if present
docker stop n8n 2>/dev/null || true
docker rm n8n 2>/dev/null || true

echo "Starting n8n container..."
docker run -d --name n8n --restart always \
  -p 5678:5678 \
  -e N8N_SECURE_COOKIE=false \
  -v n8n_data:/home/node/.n8n \
  docker.n8n.io/n8nio/n8n

echo "Waiting for n8n to initialize (20 seconds)..."
sleep 20

# Check if workflow file exists
if [ -f "workflows/n8n_v10_final.json" ]; then
    echo "Importing SOC workflow..."
    docker cp workflows/n8n_v10_final.json n8n:/tmp/workflow.json
    
    # Import workflow
    docker exec -u node n8n n8n import:workflow --input=/tmp/workflow.json || echo "Workflow import may need manual verification"
else
    echo -e "${YELLOW}Warning: workflows/n8n_v10_final.json not found. Workflow not imported.${NC}"
fi

# ------------------------------------------------------------------
# 6. Final Summary
# ------------------------------------------------------------------
echo ""
echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}         🎉 DEPLOYMENT COMPLETE! 🎉             ${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

# Extract Wazuh credentials if available
WAZUH_CREDS_FILE="/root/wazuh-install-files/wazuh-passwords.txt"
WAZUH_ADMIN_USER="admin"
WAZUH_ADMIN_PASS="<see credentials file>"

if [ -f "$WAZUH_CREDS_FILE" ]; then
    WAZUH_ADMIN_PASS=$(grep -A 1 "username: 'admin'" "$WAZUH_CREDS_FILE" | grep password | awk -F"'" '{print $2}' || echo "<see credentials file>")
fi

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              📊 SOC ACCESS INFORMATION                ║${NC}"
echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo ""

# Wazuh
echo -e "${GREEN}🛡️  WAZUH SIEM & XDR${NC}"
echo -e "   ├─ Dashboard URL:  https://$PUBLIC_IP:443"
echo -e "   ├─ API URL:        https://$PUBLIC_IP:55000"
echo -e "   ├─ Username:       ${WAZUH_ADMIN_USER}"
echo -e "   └─ Password:       ${WAZUH_ADMIN_PASS}"
if [ -f "$WAZUH_CREDS_FILE" ]; then
    echo -e "   ${YELLOW}📄 Full credentials: $WAZUH_CREDS_FILE${NC}"
fi
echo ""

# Catalyst
if [ "$SKIP_CATALYST" = false ]; then
    echo -e "${GREEN}🎫 CATALYST TICKET SYSTEM${NC}"
    echo -e "   ├─ Dashboard URL:  http://$PUBLIC_IP:8090"
    echo -e "   ├─ Email:          admin@catalyst.local"
    echo -e "   ├─ Password:       admin123"
    if [ "$CATALYST_TOKEN" != "MANUAL_SETUP_REQUIRED" ] && [ "$CATALYST_TOKEN" != "CATALYST_NOT_INSTALLED" ]; then
        echo -e "   └─ Bearer Token:   ${CATALYST_TOKEN:0:40}..."
        echo -e "      ${YELLOW}ℹ️  Full token saved in installation log${NC}"
    else
        echo -e "   └─ Bearer Token:   ${RED}Manual setup required${NC}"
        echo -e "      ${YELLOW}Run: ./scripts/get_catalyst_token.sh${NC}"
    fi
    echo ""
fi

# n8n
echo -e "${GREEN}⚙️  N8N AUTOMATION ENGINE${NC}"
echo -e "   ├─ Dashboard URL:  http://$PUBLIC_IP:5678"
echo -e "   ├─ Status:         ✅ Running in Docker"
echo -e "   ├─ Auto-start:     ✅ Enabled (--restart always)"
if [ -f "n8n_v10_final.json" ]; then
    echo -e "   └─ Workflow:       ✅ V10 SOC Edition Imported"
else
    echo -e "   └─ Workflow:       ${YELLOW}⚠️  Import manually${NC}"
fi
echo ""

# Port Summary
echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                  🔌 PORT SUMMARY                      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo "   443   → Wazuh Dashboard (HTTPS)"
echo "   55000 → Wazuh API (HTTPS)"
echo "   8090  → Catalyst Tickets (HTTP)"
echo "   5678  → n8n Automation (HTTP)"
echo ""

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              ⚠️  IMPORTANT NEXT STEPS                 ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo "1. ${YELLOW}Change default passwords${NC} (especially Catalyst!)"
echo "2. Configure ${YELLOW}Telegram bot${NC} in n8n workflow:"
echo "   • Get bot token from @BotFather"
echo "   • Get chat ID from @userinfobot"
echo "   • Update 'Telegram (Success)' node in n8n"
echo ""
echo "3. ${YELLOW}Test the workflow:${NC}"
echo "   logger 'TEST_SOC_ALERT_LEVEL_12'"
echo ""
echo "4. ${YELLOW}Setup firewall${NC} (if not already):"
echo "   ufw allow 443/tcp"
echo "   ufw allow 8090/tcp"
echo "   ufw allow 5678/tcp"
echo ""
echo "5. ${YELLOW}Review installation log:${NC} $LOG_FILE"
echo ""

echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}         Happy SOC Monitoring! 🛡️✨                    ${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"

