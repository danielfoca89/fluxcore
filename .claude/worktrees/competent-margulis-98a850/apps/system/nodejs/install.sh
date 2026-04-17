#!/usr/bin/env bash

# ==============================================================================
# NODE.JS GLOBAL INSTALLATION
# System-wide Node.js (via NodeSource) tailored for secure environments
# ==============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/os-detect.sh"

APP_NAME="nodejs"
# Best for stability: LTS version
NODE_MAJOR="25"

log_info "═══════════════════════════════════════════"
log_info "  Installing Global Node.js (v${NODE_MAJOR}.x LTS)"
log_info "═══════════════════════════════════════════"
echo ""

audit_log "INSTALL_START" "$APP_NAME" "Node.js $NODE_MAJOR"

# Check dependencies
log_step "Step 1: Checking dependencies"
COMMANDS=("curl" "git" "make" "gcc" "g++" "gnupg")
MISSING=()

for cmd in "${COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING+=("$cmd")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    log_warn "Missing dependencies: ${MISSING[*]}"
    log_info "Installing..."
    pkg_update
    
    if is_debian_based; then
        pkg_install curl git build-essential gnupg
    elif is_rhel_based; then
        pkg_install curl git gcc gcc-c++ make gnupg
    else
        log_error "Unsupported OS: $OS_ID"
        exit 1
    fi
    
    log_success "Dependencies installed"
else
    log_success "All dependencies available"
fi
echo ""

# Check for existing Node.js
log_step "Step 2: Checking for existing Node.js installation"
if command -v node &> /dev/null; then
    EXISTING_VERSION=$(node --version)
    log_success "✓ Node.js is already installed ($EXISTING_VERSION)"
    if confirm_action "Update to NodeSource $NODE_MAJOR.x LTS?"; then
        log_info "Proceeding with Node.js update..."
    else
        log_info "Installation cancelled"
        exit 0
    fi
fi
echo ""

# Setup NodeSource repository and install Node.js
log_step "Step 3: Setting up NodeSource repository and installing"
if is_debian_based; then
    log_info "Downloading NodeSource setup script..."
    run_sudo mkdir -p /etc/apt/keyrings
    run_sudo curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | run_sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | run_sudo tee /etc/apt/sources.list.d/nodesource.list > /dev/null
    
    pkg_update
    pkg_install nodejs
elif is_rhel_based; then
    log_info "Setting up NodeSource RPM repository..."
    run_sudo curl -fsSL https://rpm.nodesource.com/setup_$NODE_MAJOR.x | run_sudo bash -
    pkg_install nodejs
fi

if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    NPM_VERSION=$(npm --version)
    log_success "Node.js successfully installed natively: $NODE_VERSION"
    log_success "npm version: v$NPM_VERSION"
else
    log_error "Node.js installation failed"
    exit 1
fi
echo ""

# Update npm to latest
log_step "Step 4: Updating npm to latest version"
run_sudo npm install -g npm@latest
NPM_VERSION=$(npm --version)
log_success "npm updated globally: v$NPM_VERSION"
echo ""

# Install common global packages
log_step "Step 5: Installing common global packages"
log_info "Installing essential development tools globally..."

GLOBAL_PACKAGES=(
    "pm2"           # Process manager
    "yarn"          # Alternative package manager
    "tsx"           # TypeScript execution (modern ts-node)
    "typescript"    # TypeScript compiler
    "nodemon"       # Auto-restart development server
    "eslint"        # JavaScript linter
    "prettier"      # Code formatter
)

for package in "${GLOBAL_PACKAGES[@]}"; do
    log_info "Installing $package..."
    run_sudo npm install -g "$package" --silent
done

log_success "Global packages successfully installed"
echo ""

# PM2 Setup for systemd
log_step "Step 6: Configuring PM2 startup scripts"
log_info "Configuring PM2 to start on boot for the current user..."
PM2_STARTUP_CMD=$(pm2 startup | grep 'sudo env' || echo "")
if [[ -n "$PM2_STARTUP_CMD" ]]; then
    eval "$PM2_STARTUP_CMD" > /dev/null 2>&1 || run_sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $USER --hp $HOME
    pm2 save > /dev/null 2>&1
    log_success "PM2 configured to start automatically on system boot."
else
    log_warn "Could not automatically configure PM2 startup. You may need to run 'pm2 startup' manually."
fi
echo ""

# ---------------------------------------------------------------------------
# Dual-Tier npm prefix: system tools stay root-owned, user installs go to
# ~/.npm-global — no sudo needed for CLI tools like NemoClaw, etc.
# ---------------------------------------------------------------------------
log_step "Step 7: Configuring user-local npm prefix (Dual-Tier setup)"
NPM_PROFILE_D="/etc/profile.d/npm-user-prefix.sh"
log_info "Deploying ${NPM_PROFILE_D} for all non-root users..."

run_sudo bash -c "cat > '${NPM_PROFILE_D}'" <<'PROFILE_SCRIPT'
# ==============================================================================
# npm User-Local Prefix — deployed by FluxCore nodejs installer
#
# Purpose : Allow non-root users to run `npm install -g` and `npm link`
#           without sudo.  Each user gets their own ~/.npm-global prefix.
#
# Scope   : Applies to EVERY non-root login shell (bash, sh, zsh, etc.)
#           Root is intentionally excluded — root still uses the system
#           prefix (/usr/lib/node_modules) for infrastructure packages.
# ==============================================================================

# Only activate for non-root users and only when not already overridden
if [[ "$(id -u)" -ne 0 ]] && [[ -z "${NPM_CONFIG_PREFIX:-}" ]]; then
    export NPM_CONFIG_PREFIX="${HOME}/.npm-global"
    mkdir -p "${NPM_CONFIG_PREFIX}/bin" 2>/dev/null
    case ":${PATH}:" in
        *":${NPM_CONFIG_PREFIX}/bin:"*) ;;
        *) export PATH="${NPM_CONFIG_PREFIX}/bin:${PATH}" ;;
    esac
fi
PROFILE_SCRIPT

run_sudo chmod 644 "${NPM_PROFILE_D}"
run_sudo chown root:root "${NPM_PROFILE_D}"

# Verify the file was created correctly
if [[ -f "${NPM_PROFILE_D}" ]]; then
    log_success "User-local npm prefix configured: ${NPM_PROFILE_D}"
else
    log_warn "Could not create ${NPM_PROFILE_D} — user-local npm prefix NOT configured"
fi

# Apply immediately to the current non-root session (no re-login needed)
if [[ "$(id -u)" -ne 0 ]] && [[ -z "${NPM_CONFIG_PREFIX:-}" ]]; then
    # shellcheck source=/dev/null
    source "${NPM_PROFILE_D}" 2>/dev/null || true
fi
echo ""

# Display installation summary
log_success "═══════════════════════════════════════════"
log_success "  Node.js Global Installation Complete!"
log_success "═══════════════════════════════════════════"
audit_log "INSTALL_COMPLETE" "$APP_NAME" "Node.js $NODE_VERSION"
echo ""

log_info "📦 System-wide versions:"
echo "  Node.js:     $NODE_VERSION"
echo "  npm:         v$NPM_VERSION"
echo ""

log_info "🔧 Global packages (accessible system-wide):"
echo "  pm2          - Process manager for Node.js apps"
echo "  yarn         - Fast, reliable package manager"
echo "  tsx          - Modern execution for TypeScript"
echo "  typescript   - TypeScript compiler"
echo "  nodemon      - Auto-restart on file changes"
echo "  eslint       - JavaScript linting tool"
echo "  prettier     - Code formatter"
echo ""

log_warn "⚠️  Important notes:"
echo "  • Node.js is installed directly into the system (/usr/bin/node)"
echo ""
echo "  📦 Dual-Tier npm Strategy:"
echo "  ┌─ Tier 1 [System]  ─────────────────────────────────────────────────┐"
echo "  │  Path: /usr/lib/node_modules  │  Owner: root  │  Needs: sudo       │"
echo "  │  Packages: pm2, yarn, tsx, typescript, nodemon, eslint, prettier   │"
echo "  │  Accessible to: ALL users system-wide (via /usr/bin/*)             │"
echo "  └────────────────────────────────────────────────────────────────────┘"
echo "  ┌─ Tier 2 [User]  ───────────────────────────────────────────────────┐"
echo "  │  Path: ~/.npm-global          │  Owner: user  │  Needs: nothing     │"
echo "  │  Activated by: /etc/profile.d/npm-user-prefix.sh  (auto on login)  │"
echo "  │  Allows: npm install -g <cli-tool>  WITHOUT sudo, for ANY user     │"
echo "  └────────────────────────────────────────────────────────────────────┘"
echo ""
echo "  • PM2 has been configured to revive persistent Node apps automatically."
echo "  • CLI tools (e.g. NemoClaw) can now be installed WITHOUT sudo."
echo "  • Re-login or: source /etc/profile.d/npm-user-prefix.sh"
echo ""
