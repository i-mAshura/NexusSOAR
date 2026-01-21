# 🛠️ SOC Automation Deployment Tool (`deploy_soc.sh`)

**Version:** 1.0  
**Author:** Antigravity  
**Objective:** End-to-end automated deployment of a fully integrated SOC (Security Operations Center).

---

## 🚀 Overview
This script transforms a fresh Linux server (Ubuntu/Debian recommended) into a production-ready SOC. It installs, configures, and interconnects **Wazuh** (SIEM), **Catalyst** (Ticketing), and **n8n** (Automation) without requiring manual intervention.

### ✨ Key Features
*   **Zero-Touch Selection**: Automatically detects IP addresses and configures bindings.
*   **Auto-Authentication**: Registers the Catalyst admin account and programmatically retrieves the API Bearer Token.
*   **Workflow Injection**: Automatically imports the "V10 SOC Edition" workflow and necessary credentials into n8n.
*   **Persistence**: Sets up systemd services and Docker restart policies to survive reboots.

---

## 📋 Step-by-Step Execution Flow

When you run `./deploy_soc.sh`, the following actions occur linearly:

### 1. 🏗️ System Preparation
*   Checks for `root` privileges.
*   Updates `apt` repositories.
*   Installs dependencies: `docker.io`, `python3`, `curl`, `jq`, `unzip`, `cron`.

### 2. 🛡️ Wazuh SIEM Deployment
*   Downloads the official Wazuh installation script.
*   Executes an **Unattended Installation** (All-in-one architecture).
*   Starts the Wazuh Manager, API, and Dashboard.

### 3. 🔌 Integration Configuration
*   **Script Creation**: Generates the `/var/ossec/integrations/custom-n8n` Python script to forward alerts.
*   **Config Injection**: Modifies `/var/ossec/etc/ossec.conf` to add the `<integration>` block pointing to `http://127.0.0.1:5678`.
*   **Restart**: Reloads Wazuh to apply changes.

### 4. 🎫 Catalyst Ticketing Setup
*   **Binary Deployment**: Extracts `catalyst` to `/usr/local/bin`.
*   **Service Creation**: Creates a `systemd` service (`catalyst.service`) ensuring it starts at boot on port **8090**.
*   **DNS Magic**: Configures a cron job to keep the `catalystip` host alias synced with the server's current IP.
*   **Auto-Registration**:
    *   Calls the API to register `admin@catalyst.local`.
    *   Calls the API to **Login** and extract the live **JWT Bearer Token** for use in n8n.

### 5. ⚙️ n8n Orchestration Setup
*   **Docker Launch**: Spins up the `n8n` container on port **5678** (with secure cookies disabled for local dev).
*   **Credential construction**: dynamically builds a credentials JSON file using the **Telegram Token** and the **Catalyst Token** retrieved in Step 4.
*   **Workflow Import**: Injects `n8n_v10_final.json` (The Premium SOC Workflow) directly into the running instance.

### 6. ✅ Final Summary
*   The script concludes by printing a **Dashboard Access Card**:
    *   **Wazuh URL**: `https://<PUBLIC_IP>`
    *   **Catalyst URL**: `http://<PUBLIC_IP>:8090` (Configured with `admin123`)
    *   **n8n URL**: `http://<PUBLIC_IP>:5678`

---

## 💻 Usage

1.  **Transfer the tool**:
    ```bash
    # Assuming you have the zip or files
    chmod +x deploy_soc.sh
    ```

2.  **Run**:
    ```bash
    sudo ./deploy_soc.sh
    ```

3.  **Wait**: Approx 5-10 minutes depending on internet speed.

4.  **Login**: Use the credentials provided in the final output.
