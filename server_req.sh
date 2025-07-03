#!/bin/bash

# Enhanced system setup script for Ubuntu game server hosting only
set -euo pipefail

# Configuration
LOG_FILE="/tmp/log/gameserver-setup.log"
BASE_PATH="/srv"
REQUIRED_PACKAGES=("python3" "python3-pip" "acl" "curl" "wget" "htop" "ufw" "git")
mkdir -p /tmp/log
touch "$LOG_FILE"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
	local level=$1
	shift
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	echo -e "${timestamp} [${level}] $*" | tee -a "$LOG_FILE"
}
log_info() {
	log "INFO" "$*"
	echo -e "${GREEN}[INFO]${NC} $*"
}
log_warn() {
	log "WARN" "$*"
	echo -e "${YELLOW}[WARN]${NC} $*"
}
log_error() {
	log "ERROR" "$*"
	echo -e "${RED}[ERROR]${NC} $*"
}

# Ensure cleanup logs errors
cleanup() {
	if [[ $? -ne 0 ]]; then
		log_error "Script failed. Check logs at $LOG_FILE"
	fi
}
trap cleanup EXIT

# Detect OS and enforce Ubuntu
detect_os() {
	if [[ -f /etc/os-release ]]; then
		. /etc/os-release
		if [[ "$ID" != "ubuntu" ]]; then
			log_error "Unsupported OS: $NAME. This script only supports Ubuntu."
			exit 1
		fi
	else
		log_error "Cannot detect OS version"
		exit 1
	fi

	log_info "Detected Ubuntu $VERSION_ID"
	PKG_MANAGER="apt"
	PKG_UPDATE="apt-get update -y && apt-get upgrade -y"
	PKG_INSTALL="apt-get install -y"
}

# System update
update_system() {
	log_info "Updating system packages..."
	eval "$PKG_UPDATE"
	log_info "System update completed"
}

install_packages() {
	log_info "Installing required packages..."
	eval "$PKG_INSTALL ${REQUIRED_PACKAGES[*]}"

	# If Docker is already installed, skip the rest
	if command -v docker &>/dev/null; then
		log_info "Docker already installed (version: $(docker --version)). Skipping."
		return
	fi

	log_info "Installing Docker prerequisites..."
	# Remove any old upstream packages if present (errors OK)
	apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
	apt-get update -y
	apt-get install -y ca-certificates curl gnupg lsb-release

	log_info "Adding Docker GPG key and repo..."
	mkdir -p /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
		gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	chmod a+r /etc/apt/keyrings/docker.gpg

	echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" |
		tee /etc/apt/sources.list.d/docker.list >/dev/null

	log_info "Updating apt and installing Docker CE..."
	apt-get update -y
	apt-get install -y docker-ce docker-ce-cli containerd.io \
		docker-buildx-plugin docker-compose-plugin docker-compose

	log_info "Installing Python packages via pip3..."
	pip3 install --break-system-packages pyyaml docker-compose

	log_info "Docker installation complete (version: $(docker --version))."
}

# Setup Docker service
setup_docker() {
	log_info "Enabling and starting Docker..."
	systemctl start docker
	systemctl enable docker
	usermod -aG docker "$USER"
	if docker --version &>/dev/null; then
		log_info "Docker installed successfully"
	else
		log_error "Docker installation failed"
		exit 1
	fi
}

setup_directories() {
    log_info "Creating base directory tree..."
    mkdir -p "$BASE_PATH"

    local dirs=("logs" "docker-game-templates" "subscription-docker-compose" "backups" "configs" "game-data")
    for d in "${dirs[@]}"; do
        mkdir -p "$BASE_PATH/$d"
        log_info " → $BASE_PATH/$d"
    done

    # Set ownership and permissions
    chown -R "$USER:docker" "$BASE_PATH"
    chmod -R 777 "$BASE_PATH"  # rwxrwxrwx - everyone can read/write/execute
    sudo usermod -aG docker "peter"
}

# Kernel & limits tuning
optimize_system() {
	log_info "Applying system optimizations..."
	cat <<EOF | tee /etc/security/limits.d/gameserver.conf
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF
	cat <<EOF | tee /etc/sysctl.d/99-gameserver.conf
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_rmem = 4096 65536 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF
	sysctl -p /etc/sysctl.d/99-gameserver.conf
	log_info "Optimizations applied"
}

# Generate a summary report
generate_system_report() {
	local report="$BASE_PATH/system-setup-report.txt"
	cat <<EOF >"$report"
Game Server System Setup Report
Generated: $(date)
OS: Ubuntu $VERSION_ID
User: $USER
Base Path: $BASE_PATH

Installed Packages:
$(for pkg in "${REQUIRED_PACKAGES[@]}"; do
		echo "- $pkg: $(command -v "$pkg" || echo 'not found')"
	done)

Docker: $(docker --version 2>/dev/null || echo 'n/a')
Docker Compose: $(docker-compose --version 2>/dev/null || echo 'n/a')

Resources: CPU $(nproc) cores, RAM $(free -h | awk '/^Mem:/ {print $2}')
Disk free at $BASE_PATH: $(df -h "$BASE_PATH" | awk 'NR==2 {print $4}')

Firewall: $(ufw status | head -n3)

Log: $LOG_FILE
EOF
	log_info "Report written to $report"
}

main() {
	log_info "Starting Ubuntu-only game server setup…"
	detect_os
	update_system
	install_packages
	setup_docker
	setup_directories
	optimize_system
	generate_system_report
	log_info "🎉 Setup complete! Please relogin to activate Docker group."
}

main "$@"
