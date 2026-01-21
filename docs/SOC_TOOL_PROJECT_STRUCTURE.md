# SOC Automation Tool - Project Structure

## 📁 Repository Layout for GitHub

```
soc-automation-tool/
│
├── 📄 README.md                        # Main project documentation (SOC_TOOL_README.md)
├── 📄 LICENSE                          # MIT License
├── 📄 DEPLOYMENT_GUIDE.md              # Technical deployment details (SOC_DEPLOYMENT_TOOL.md)
│
├── 🚀 deploy_soc.sh                    # Main deployment script (executable)
├── 🔄 update_catalyst_ip.sh            # DNS alias updater (executable)
│
├── 📋 workflows/
│   └── n8n_v10_final.json              # Pre-configured n8n workflow
│
├── 🛠️ configs/
│   └── (Optional: place config templates here)
│
└── 📚 docs/
    ├── TROUBLESHOOTING.md              # Common issues and fixes
    └── CUSTOMIZATION.md                # How to customize the deployment
```

---

## 📝 File Descriptions

### Core Files
- **`deploy_soc.sh`**: The master installation script. Run this to deploy everything.
- **`update_catalyst_ip.sh`**: Auto-updates the `catalystip` DNS alias. Runs via cron.
- **`n8n_v10_final.json`**: The V10 SOC Edition workflow (AbuseIPDB + Catalyst + Telegram).

### Documentation
- **`README.md`**: Main project landing page with quick start guide.
- **`DEPLOYMENT_GUIDE.md`**: Step-by-step technical breakdown of what the script does.
- **`LICENSE`**: MIT License for open-source distribution.

---

## 🔧 Required Files for Distribution

To create a complete GitHub repo, ensure you have:

1. ✅ `deploy_soc.sh` (from your current system)
2. ✅ `update_catalyst_ip.sh` (from your current system)
3. ✅ `n8n_v10_final.json` (your working workflow)
4. ✅ `README.md` (use `SOC_TOOL_README.md`)
5. ✅ `DEPLOYMENT_GUIDE.md` (use `SOC_DEPLOYMENT_TOOL.md`)
6. ✅ `LICENSE` (use `SOC_TOOL_LICENSE`)

### Additional Files Needed
You'll also need to bundle:
- **`catalyst_Linux_x86_64.tar.gz`**: The Catalyst binary (users can download separately if large)
- **`.gitignore`**: To exclude logs and sensitive data

---

## 📦 Creating the Distributable Package

### Option 1: GitHub Repository
```bash
# On your local machine
mkdir soc-automation-tool
cd soc-automation-tool

# Copy files
cp /home/socadmin/deploy_soc.sh ./
cp /home/socadmin/update_catalyst_ip.sh ./
cp /home/socadmin/n8n_v10_final.json ./workflows/
cp /home/socadmin/SOC_TOOL_README.md ./README.md
cp /home/socadmin/SOC_DEPLOYMENT_TOOL.md ./DEPLOYMENT_GUIDE.md
cp /home/socadmin/SOC_TOOL_LICENSE ./LICENSE

# Initialize git
git init
git add .
git commit -m "Initial commit: SOC Automation Tool v1.0"

# Push to GitHub
git remote add origin https://github.com/yourusername/soc-automation-tool.git
git push -u origin main
```

### Option 2: Standalone .tar.gz
```bash
tar -czf soc-automation-tool_v1.0.tar.gz \
  deploy_soc.sh \
  update_catalyst_ip.sh \
  n8n_v10_final.json \
  README.md \
  DEPLOYMENT_GUIDE.md \
  LICENSE
```

---

## 🌐 User Workflow (After Distribution)

1. **Clone/Download**:
   ```bash
   git clone https://github.com/yourusername/soc-automation-tool.git
   cd soc-automation-tool
   ```

2. **Run**:
   ```bash
   sudo ./deploy_soc.sh
   ```

3. **Access**:
   - Wazuh: `https://<SERVER_IP>`
   - Catalyst: `http://<SERVER_IP>:8090`
   - n8n: `http://<SERVER_IP>:5678`

---

## 🔐 Security Notes

- **DO NOT** commit sensitive credentials to GitHub
- **DO** include a `.env.example` if you plan to make variables configurable
- **DO** add clear warnings in README about changing default passwords

---

## ✅ Pre-Release Checklist

- [ ] Test `deploy_soc.sh` on fresh Ubuntu 22.04 VM
- [ ] Test `deploy_soc.sh` on fresh Debian 12 VM
- [ ] Verify all URLs in README are correct
- [ ] Check that Catalyst binary is accessible (or provide download link)
- [ ] Add screenshots to README for visual appeal
- [ ] Create GitHub releases with version tags
