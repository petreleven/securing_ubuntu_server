#!/usr/bin/env bash
set -euo pipefail

# Configuration
SSH_PORT=2220
SFTP_PORT=2222
SSH_USER="peter"
REQUIRED_PKGS=(ufw curl)

# 1) Update & upgrade
echo "→ Updating package lists..."
sudo apt update -y
echo "→ Upgrading installed packages..."
sudo apt upgrade -y

# 2) Install prerequisites
echo "→ Installing: ${REQUIRED_PKGS[*]}"
sudo apt-get install -y "${REQUIRED_PKGS[@]}"

# 3) Create user if missing
if id "${SSH_USER}" &>/dev/null; then
  echo "→ User '${SSH_USER}' already exists, skipping creation."
else
  echo "→ Creating user '${SSH_USER}'..."
  sudo adduser --gecos "" "${SSH_USER}"
  sudo usermod -aG sudo "${SSH_USER}"
fi

# 4) Firewall setup
echo "→ Configuring UFW firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow "${SSH_PORT}/tcp"
sudo ufw allow "${SFTP_PORT}/tcp"
sudo ufw --force enable
echo "→ UFW status:"
sudo ufw status verbose

# 5) Prompt for SSH key reminder
echo
echo "⚠️  Make sure to set up your SSH key locally:"
echo "   ssh-keygen -t rsa -b 4096"
echo "   ssh-copy-id -p ${SSH_PORT} ${SSH_USER}@\$(curl -s ifconfig.me)"
echo

# 6) Backup & patch sshd_config
SSHD_CONF="/etc/ssh/sshd_config"
BACKUP="${SSHD_CONF}.bak_$(date +%F_%T)"
echo "→ Backing up SSH config to ${BACKUP}"
sudo cp "${SSHD_CONF}" "${BACKUP}"

# Helper to idempotently add or update a setting
upsert_sshd() {
  local key="$1" val="$2"
  if sudo grep -Eq "^\s*${key}\s+" "${SSHD_CONF}"; then
    sudo sed -ri "s|^\s*${key}\s+.*|${key} ${val}|g" "${SSHD_CONF}"
  else
    echo "${key} ${val}" | sudo tee -a "${SSHD_CONF}" >/dev/null
  fi
}

echo "→ Updating SSHD configuration..."
upsert_sshd "PermitRootLogin" "no"
upsert_sshd "Port" "${SSH_PORT}"
upsert_sshd "AllowUsers" "${SSH_USER}"

# 7) Restart SSH
echo "→ Restarting SSH daemon..."
sudo systemctl restart ssh

echo "✅ Server setup complete! You can now SSH in with:"
echo "   ssh -p ${SSH_PORT} ${SSH_USER}@\$(curl -s ifconfig.me)"
