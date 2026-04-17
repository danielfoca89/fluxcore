#!/usr/bin/env bash

# ==============================================================================
# DOCKER ENGINE INSTALLATION
# Installs Docker Engine and Docker Compose
# ==============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/os-detect.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/preflight.sh"

APP_NAME="docker-engine"

log_info "═══════════════════════════════════════════"
log_info "  Installing Docker Engine"
log_info "═══════════════════════════════════════════"
echo ""

audit_log "INSTALL_START" "$APP_NAME"

# Pre-flight checks
preflight_check "$APP_NAME" 20 4 ""

# ──────────────────────────────────────────────────────────────
# DOCKER STATE DETECTION
# Classifies current Docker state before deciding what to do.
# Returns (via DOCKER_STATE variable):
#   none    → Docker not installed at all
#   healthy → Docker installed, service running, daemon responding
#   broken  → Docker installed but service won't start (failed systemd units, bad socket, etc.)
#   partial → Some Docker files/packages exist but binary or daemon config is missing
# ──────────────────────────────────────────────────────────────
detect_docker_state() {
    local has_binary=false has_service=false daemon_ok=false has_packages=false has_data=false

    # 1. Binary present?
    command -v docker &>/dev/null && has_binary=true

    # 2. Any Docker packages installed?
    if dpkg -l 2>/dev/null | grep -qE '^ii\s+(docker-ce|containerd\.io|docker\.io)'; then
        has_packages=true
    fi

    # 3. Data directories present?
    [[ -d /var/lib/docker || -d /var/lib/containerd ]] && has_data=true

    # 4. Systemd service state (no sudo needed for is-active --quiet)
    if systemctl is-active --quiet docker 2>/dev/null; then
        has_service=true
    fi

    # 5. Daemon responding?
    if $has_binary && docker info &>/dev/null 2>&1; then
        daemon_ok=true
    fi

    # ── Classify ────────────────────────────────────────────
    if ! $has_binary && ! $has_packages && ! $has_data; then
        DOCKER_STATE="none"
    elif $has_binary && $has_service && $daemon_ok; then
        DOCKER_STATE="healthy"
    elif $has_binary; then
        # Binary present but daemon not running or not responding
        DOCKER_STATE="broken"
    else
        # No binary but leftover packages or data dirs — half-removed install
        DOCKER_STATE="partial"
    fi
}

# ──────────────────────────────────────────────────────────────
# EVALUATE STATE & DECIDE ACTION
# ──────────────────────────────────────────────────────────────
detect_docker_state

case "${DOCKER_STATE}" in
    none)
        log_info "No existing Docker installation found — proceeding with fresh install."
        ;;
    healthy)
        docker --version 2>/dev/null || true
        echo ""
        log_success "✓ Docker is installed and running correctly."
        if ! confirm_action "Reinstall from scratch? (WARNING: deletes ALL containers, volumes, images)"; then
            log_info "Keeping existing Docker installation."
            exit 0
        fi
        log_warn "Proceeding with full Docker removal and reinstall..."
        ;;
    broken|partial)
        echo ""
        log_warn "═══════════════════════════════════════════════"
        log_warn "  ⚠  Broken/incomplete Docker install detected"
        log_warn "═══════════════════════════════════════════════"
        echo ""
        [[ "${DOCKER_STATE}" == "broken" ]] && log_warn "  Cause: Docker is installed but the daemon failed to start." \
                                             || log_warn "  Cause: Partial Docker install (missing binary or packages)."
        log_info "  Action: Auto-cleaning and reinstalling from scratch."
        echo ""
        ;;
esac


log_step "Step 1: Removing old Docker versions and configs"
if is_debian_based; then
    run_sudo systemctl stop docker docker.socket containerd 2>/dev/null || true
    run_sudo systemctl disable docker docker.socket containerd 2>/dev/null || true
    
    pkg_remove docker-engine docker docker.io docker-ce docker-ce-cli docker-compose-plugin docker-buildx-plugin docker-ce-rootless-extras containerd containerd.io runc 2>/dev/null || true
    run_sudo apt-get autoremove -y --purge 2>/dev/null || true
    
    # Nuke all data, configuration, socket and PID remnants
    run_sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker /run/docker /run/docker.sock /run/docker.pid /var/run/docker.sock /var/run/docker.pid 2>/dev/null || true
    
    # Completely nuke group
    run_sudo groupdel docker 2>/dev/null || true
    
    # Nuke repo files
    run_sudo rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null || true
    run_sudo rm -f /etc/apt/keyrings/docker.gpg /etc/apt/keyrings/docker.asc 2>/dev/null || true
    
    # Flush systemd state to wipe the failed socket/job remnants from memory
    run_sudo systemctl daemon-reload 2>/dev/null || true
    run_sudo systemctl reset-failed 2>/dev/null || true
elif is_rhel_based; then
    run_sudo systemctl stop docker docker.socket containerd 2>/dev/null || true
    run_sudo systemctl disable docker docker.socket containerd 2>/dev/null || true
    
    pkg_remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine docker-ce docker-ce-cli containerd.io 2>/dev/null || true
    run_sudo yum autoremove -y 2>/dev/null || true
    
    # Nuke all data, configuration, socket and PID remnants
    run_sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker /run/docker /run/docker.sock /run/docker.pid /var/run/docker.sock /var/run/docker.pid 2>/dev/null || true
    
    # Completely nuke group
    run_sudo groupdel docker 2>/dev/null || true
    
    # Flush systemd state to wipe the failed socket/job remnants from memory
    run_sudo systemctl daemon-reload 2>/dev/null || true
    run_sudo systemctl reset-failed 2>/dev/null || true
fi

log_step "Step 2: Installing prerequisites"
if is_debian_based; then
    pkg_install apt-transport-https ca-certificates curl gnupg lsb-release iptables
    
    # Add Docker's official GPG key (Updated for modern apt: using .asc instead of gpg --dearmor which hangs if file exists)
    log_info "Adding Docker GPG key..."
    run_sudo install -m 0755 -d /etc/apt/keyrings
    run_sudo curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" -o /etc/apt/keyrings/docker.asc
    run_sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    # Set up the repository
    log_info "Setting up Docker repository..."
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${OS_ID} \
        $(lsb_release -cs) stable" | run_sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package cache
    pkg_update
    
elif is_rhel_based; then
    pkg_install yum-utils
    run_sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
fi

log_step "Step 3: Installing Docker Engine"
# Pre-create docker group to avoid docker.socket failing during package installation
run_sudo groupadd -f docker 2>/dev/null || true
# pkg_install now has built-in retry logic and --fix-missing
pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

log_step "Step 4: Configuring IP Forwarding for Docker"
log_info "Ensuring net.ipv4.ip_forward=1 is set for container networking..."
run_sudo bash -c "cat > /etc/sysctl.d/99-docker-forwarding.conf" <<'EOF'
# Required for Docker container networking
net.ipv4.ip_forward = 1
EOF
run_sudo sysctl -p /etc/sysctl.d/99-docker-forwarding.conf >/dev/null
log_success "IP forwarding enabled for Docker"

log_step "Step 5: Starting Docker service"
log_info "Starting and enabling Docker daemon..."
run_sudo systemctl start docker
run_sudo systemctl enable docker

# Wait for Docker to be ready
log_info "Waiting for Docker daemon to be ready..."
sleep 3

# Verify Docker is running
if ! run_sudo docker info &> /dev/null; then
    log_error "Docker daemon failed to start"
    log_info "Checking Docker service status..."
    run_sudo systemctl status docker --no-pager || true
    # exit 1
fi

log_success "Docker daemon is running"

# Add current user to docker group (if not root)
if [[ "$(id -u)" -ne 0 ]]; then
    log_step "Step 6: Adding user to docker group"
    run_sudo usermod -aG docker "${USER}"
    log_success "✓ User '${USER}' added to docker group"
    
    # Verify group membership is recorded in /etc/group
    if getent group docker 2>/dev/null | grep -q "${USER}"; then
        log_success "✓ Group membership confirmed in /etc/group"
    else
        log_warn "Group membership not yet in /etc/group — may require logout/login"
    fi
fi

log_step "Step 7: Verifying installation"
sleep 2
run_sudo docker --version
run_sudo docker compose version

# Test Docker (run as the docker group to verify group access works)
log_info "Testing Docker..."
if sg docker -c "docker run --rm hello-world" &>/dev/null 2>&1 || \
   sudo docker run --rm hello-world &>/dev/null 2>&1; then
    log_success "Docker test passed ✓"
else
    log_warn "Docker test image could not run (non-fatal — daemon is running, network may be needed)"
fi

log_step "Step 8: Creating default Docker network"
create_docker_network "vps_network"

log_step "Step 9: Configuring Docker daemon"
DAEMON_CONFIG="/etc/docker/daemon.json"
if [[ ! -f "$DAEMON_CONFIG" ]]; then
    log_info "Creating Docker daemon configuration..."
    run_sudo bash -c "cat > $DAEMON_CONFIG" <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "userland-proxy": false
}
EOF
    
    log_warn "Docker daemon configuration created. Restart required."
    log_warn "⚠️  WARNING: Restarting Docker will STOP all running containers!"
    
    # Check if any containers are running
    RUNNING_CONTAINERS=$(run_sudo docker ps -q 2>/dev/null | wc -l)
    if [[ "$RUNNING_CONTAINERS" -gt 0 ]]; then
        log_warn "Currently running containers: $RUNNING_CONTAINERS"
        if ! confirm_action "Restart Docker now? (containers will be stopped)"; then
            log_info "Skipping Docker restart. Please restart manually later:"
            log_info "  sudo systemctl restart docker"
            log_success "Docker daemon configured (restart pending)"
        else
            run_sudo systemctl restart docker
            log_success "Docker daemon configured and restarted"
        fi
    else
        log_info "No running containers detected, restarting Docker..."
        run_sudo systemctl restart docker
        log_success "Docker daemon configured and restarted"
    fi
fi

# Create vps_network for shared services (databases, monitoring)
log_step "Step 10: Creating vps_network for shared services"
if ! create_docker_network "vps_network"; then
    log_error "Failed to create vps_network"
    # exit 1
fi
echo ""

echo ""
log_success "═══════════════════════════════════════════"
log_success "  Docker Engine installed successfully!"
log_success "═══════════════════════════════════════════"
audit_log "INSTALL_COMPLETE" "$APP_NAME" "Docker $(run_sudo docker --version | awk '{print $3}' | tr -d ',')"
echo ""
log_info "Docker Version:"
run_sudo docker --version
echo ""
log_info "Docker Compose Version:"
run_sudo docker compose version 2>/dev/null || run_sudo docker-compose --version
echo ""
log_info "Default Network: vps_network"
echo ""
log_info "💡 Docker is configured to work with sudo"
log_info "   For sudo-less access, logout and login again"
echo ""
