# 🐛 Troubleshooting Guide - SOC Automation Tool

## Common Issues and Solutions

---

## 1️⃣ Installation Failures

### ❌ "Permission denied"
**Symptom**: Script fails immediately with permission error.

**Solution**:
```bash
# Ensure you're running as root
sudo ./deploy_soc.sh

# Or switch to root
sudo su -
./deploy_soc.sh
```

### ❌ "apt-get: command not found"
**Symptom**: Package manager not recognized.

**Solution**: This tool requires Ubuntu/Debian. For RHEL/CentOS, you'll need to modify the script to use `yum` or `dnf`.

---

## 2️⃣ Wazuh Issues

### ❌ Wazuh Manager Won't Start
**Check Status**:
```bash
sudo systemctl status wazuh-manager
```

**View Logs**:
```bash
sudo tail -f /var/ossec/logs/ossec.log
```

**Common Fix**:
```bash
sudo systemctl restart wazuh-manager
```

### ❌ Wazuh Dashboard Not Accessible
**Symptom**: Can't access `https://YOUR_IP`

**Check**:
```bash
sudo systemctl status wazuh-dashboard
sudo netstat -tuln | grep 443
```

**Solution**:
```bash
# Restart dashboard
sudo systemctl restart wazuh-dashboard

# Check firewall
sudo ufw allow 443/tcp
```

### ❌ Alerts Not Forwarding to n8n
**Check Integration**:
```bash
sudo cat /var/ossec/etc/ossec.conf | grep -A 10 integration
```

**Verify Script**:
```bash
ls -l /var/ossec/integrations/custom-n8n
sudo test -x /var/ossec/integrations/custom-n8n && echo "Executable" || echo "Not executable"
```

**Test Manually**:
```bash
# Generate test alert
logger "TEST_ALERT_LEVEL_12"

# Check Wazuh alert log
sudo tail -f /var/ossec/logs/alerts/alerts.json
```

---

## 3️⃣ Catalyst Issues

### ❌ Catalyst Not Starting
**Check Service**:
```bash
sudo systemctl status catalyst
```

**View Logs**:
```bash
sudo journalctl -u catalyst -f
```

**Restart**:
```bash
sudo systemctl restart catalyst
```

### ❌ "401 Unauthorized" When Creating Tickets
**Symptom**: n8n shows authentication errors.

**Solution**: Token expired. Regenerate:
```bash
curl -X POST http://localhost:8090/auth/local/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@catalyst.local","password":"admin123"}'
```

**Update n8n**:
1. Copy the new `token` value
2. Open n8n: `http://YOUR_IP:5678`
3. Go to **Credentials** → **Bearer Auth account**
4. Paste new token → **Save**

### ❌ Catalyst IP Changes After Reboot
**Symptom**: Tickets stop being created.

**Check DNS Alias**:
```bash
grep catalystip /etc/hosts
```

**Force Update**:
```bash
sudo /usr/local/bin/update_catalyst_ip.sh
```

**Verify Cron**:
```bash
crontab -l | grep update_catalyst
```

---

## 4️⃣ n8n Issues

### ❌ n8n Container Not Running
**Check Docker**:
```bash
docker ps | grep n8n
```

**View Logs**:
```bash
docker logs n8n
```

**Restart**:
```bash
docker restart n8n
```

### ❌ Workflow Not Imported
**Check Workflows**:
1. Open `http://YOUR_IP:5678`
2. Click **Workflows** menu
3. Look for "Wazuh -> AbuseIPDB -> Catalyst -> Telegram"

**Manual Import**:
```bash
# Copy JSON into container
docker cp n8n_v10_final.json n8n:/tmp/workflow.json

# Import
docker exec -u node n8n n8n import:workflow --input=/tmp/workflow.json
```

### ❌ Webhook Returns 404
**Symptom**: Wazuh alerts don't trigger the workflow.

**Check Workflow is Active**:
1. Open n8n UI
2. Open the workflow
3. Click **Active** toggle (should be green)

**Test Webhook**:
```bash
curl -X POST http://localhost:5678/webhook/wazuh-alert \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

### ❌ Telegram Notifications Not Sending
**Check Credentials**:
1. Open n8n → **Credentials**
2. Verify **Telegram account 2** has correct bot token

**Test Bot**:
```bash
# Send test message
curl https://api.telegram.org/bot<YOUR_BOT_TOKEN>/sendMessage \
  -d chat_id=<YOUR_CHAT_ID> \
  -d text="Test from SOC"
```

---

## 5️⃣ Network & Connectivity

### ❌ Can't Access Services from Browser
**Check Firewall**:
```bash
sudo ufw status
```

**Open Ports**:
```bash
sudo ufw allow 443/tcp   # Wazuh
sudo ufw allow 8090/tcp  # Catalyst
sudo ufw allow 5678/tcp  # n8n
```

### ❌ DNS Resolution Fails
**Symptom**: n8n can't reach `catalystip`.

**Test**:
```bash
ping catalystip
```

**Fix**:
```bash
# Get current IP
ip addr show | grep "inet " | grep -v 127.0.0.1

# Update hosts file manually
sudo nano /etc/hosts
# Add: 192.168.1.X catalystip
```

---

## 6️⃣ Performance Issues

### ⚠️ High Memory Usage
**Check**:
```bash
free -h
htop
```

**Solutions**:
- Increase server RAM (minimum 8GB, recommended 16GB)
- Limit Wazuh indexer memory in `/etc/wazuh-indexer/jvm.options`
- Restart services to clear cache

### ⚠️ Slow Alert Processing
**Check n8n Queue**:
```bash
docker exec n8n n8n list:workflow --active
```

**Optimize**:
- Increase Wazuh alert level threshold to reduce volume
- Add filtering in n8n workflow

---

## 7️⃣ Complete Reset

### 🔄 Start Fresh
**If all else fails**, remove everything and re-run:

```bash
# Stop services
sudo systemctl stop wazuh-manager wazuh-indexer wazuh-dashboard catalyst
docker stop n8n && docker rm n8n

# Remove packages (CAREFUL!)
sudo apt-get purge wazuh* -y

# Remove data
sudo rm -rf /var/ossec /usr/local/bin/catalyst /etc/systemd/system/catalyst.service

# Re-run deployment
sudo ./deploy_soc.sh
```

---

## 📞 Getting Help

If issues persist:
1. Check logs in `/var/log/syslog`
2. Review individual component documentation
3. Open an issue on GitHub with:
   - OS version: `lsb_release -a`
   - Error messages from logs
   - Steps to reproduce

---

**Most issues resolve with a simple service restart!** 🔄
