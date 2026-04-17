#!/usr/bin/env bash

# ==============================================================================
# OPEN WEBUI - AI INTERFACE
# User-friendly AI Interface supporting Ollama, OpenAI API, and more
# Docker deployment with optional Ollama integration
# ==============================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/os-detect.sh"
source "${SCRIPT_DIR}/lib/docker.sh"
source "${SCRIPT_DIR}/lib/preflight.sh"

APP_NAME="open-webui"
CONTAINER_NAME="open-webui"
DATA_DIR="/opt/ai/open-webui"
NETWORK="vps_network"
PORT="3000"

log_info "═══════════════════════════════════════════"
log_info "  Installing Open WebUI"
log_info "═══════════════════════════════════════════"
echo ""

audit_log "INSTALL_START" "$APP_NAME"

# Pre-flight checks
preflight_check "$APP_NAME" 20 2 "$PORT"

# Check dependencies
log_step "Step 1: Checking dependencies"

# Docker check
if ! check_docker; then
    log_error "Docker is not installed"
    log_info "Please install Docker first: Infrastructure > Docker Engine"
    exit 1
fi
log_success "✓ Docker is available"
echo ""

# Check for existing installation
if run_sudo docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_success "Open WebUI is already installed"
    if confirm_action "Reinstall?"; then
        log_info "Removing existing installation..."
        run_sudo docker stop "$CONTAINER_NAME" 2>/dev/null || true
        run_sudo docker rm "$CONTAINER_NAME" 2>/dev/null || true
    else
        log_info "Installation cancelled"
        exit 0
    fi
fi
echo ""

# Setup directories
log_step "Step 2: Setting up directories"
create_app_directory "$DATA_DIR"
create_app_directory "$DATA_DIR/data"

log_success "Open WebUI directories created"
echo ""

# Check if Ollama is installed
log_step "Step 3: Checking for Ollama integration"
OLLAMA_URL=""
if run_sudo docker ps --format '{{.Names}}' | grep -q "^ollama$"; then
    log_success "✓ Ollama container detected"
    OLLAMA_URL="http://ollama:11434"
    log_info "Open WebUI will connect to Ollama at: $OLLAMA_URL"
else
    log_warn "Ollama container not found"
    log_info "You can install Ollama from: Apps > AI > Ollama"
    log_info "Or use OpenAI API by setting OPENAI_API_KEY environment variable"
fi
echo ""

# Create .env file
log_step "Step 4: Creating .env configuration file"

# Generate secret key if not exists
if [[ ! -f "$DATA_DIR/.env" ]] || ! grep -q "WEBUI_SECRET_KEY" "$DATA_DIR/.env" 2>/dev/null; then
    SECRET_KEY=$(openssl rand -hex 32)
else
    SECRET_KEY=$(grep "WEBUI_SECRET_KEY" "$DATA_DIR/.env" | cut -d'=' -f2)
fi

run_sudo tee "$DATA_DIR/.env" > /dev/null << EOF
# ==============================================================================
# OPEN WEBUI CONFIGURATION
# ==============================================================================

# Application Settings
WEBUI_NAME=Open WebUI
WEBUI_SECRET_KEY=$SECRET_KEY
DATA_DIR=/app/backend/data

# Server Configuration
PORT=8080
HOST=0.0.0.0

# Ollama Configuration
# If Ollama is running, set the URL here
# Format: http://ollama:11434 (for Docker) or http://localhost:11434 (for local)
$(if [[ -n "$OLLAMA_URL" ]]; then
    echo "OLLAMA_BASE_URL=$OLLAMA_URL"
    echo "ENABLE_OLLAMA_API=true"
else
    echo "# OLLAMA_BASE_URL=http://ollama:11434"
    echo "# ENABLE_OLLAMA_API=true"
fi)

# OpenAI Configuration (optional)
# Uncomment and set your API key to use OpenAI models
# OPENAI_API_KEY=sk-your-api-key-here
# OPENAI_API_BASE_URL=https://api.openai.com/v1

# Authentication Settings
# ENABLE_SIGNUP=true
# DEFAULT_USER_ROLE=user
# ENABLE_LOGIN_FORM=true

# RAG (Retrieval Augmented Generation)
# Vector database for document storage
VECTOR_DB=chroma
CHROMA_DATA_PATH=/app/backend/data/vector_db
CHROMA_TENANT=default_tenant
CHROMA_DATABASE=default_database

# Embedding Model
RAG_EMBEDDING_MODEL=sentence-transformers/all-MiniLM-L6-v2
SENTENCE_TRANSFORMERS_HOME=/app/backend/data/cache/embedding/models

# Whisper (Speech to Text)
WHISPER_MODEL=base
WHISPER_MODEL_DIR=/app/backend/data/cache/whisper/models

# Image Generation (optional)
# Uncomment to enable image generation with AUTOMATIC1111 or ComfyUI
# ENABLE_IMAGE_GENERATION=true
# IMAGE_GENERATION_ENGINE=automatic1111
# AUTOMATIC1111_BASE_URL=http://localhost:7860

# Web Search (optional)
# Uncomment and configure to enable web search
# ENABLE_RAG_WEB_SEARCH=true
# RAG_WEB_SEARCH_ENGINE=searxng
# SEARXNG_QUERY_URL=http://searxng:8080/search?q=<query>

# Logs and Monitoring
GLOBAL_LOG_LEVEL=INFO
SCARF_NO_ANALYTICS=true
DO_NOT_TRACK=true
ANONYMIZED_TELEMETRY=false

# Database (SQLite by default, can use PostgreSQL)
# DATABASE_URL=sqlite:///app/backend/data/webui.db
# For PostgreSQL:
# DATABASE_URL=postgresql://user:password@postgres:5432/openwebui

# ==============================================================================
# ADVANCED SETTINGS (uncomment to customize)
# ==============================================================================

# Session Configuration
# WEBUI_SESSION_COOKIE_SAME_SITE=lax
# WEBUI_SESSION_COOKIE_SECURE=false

# Model Settings
# ENABLE_MODEL_FILTER=true
# MODEL_FILTER_LIST=llama2,mistral,codellama

# Task Settings
# ENABLE_AUTOCOMPLETE_GENERATION=false
# ENABLE_FOLLOW_UP_GENERATION=true

# Security
# ENABLE_API_KEY=true
# JWT_EXPIRES_IN=-1

EOF

run_sudo chmod 644 "$DATA_DIR/.env"
log_success ".env configuration file created"
echo ""

# Create Docker Compose file
log_step "Step 5: Creating Docker Compose configuration"

# Configuration using .env file
run_sudo tee "$DATA_DIR/docker-compose.yml" > /dev/null << 'EOF'
version: '3.8'

services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    
    ports:
      - "127.0.0.1:3000:8080"
    
    env_file:
      - .env
      
    volumes:
      - ./data:/app/backend/data
      
    networks:
      - n8n_network
      
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

networks:
  n8n_network:
    external: true
EOF

log_success "Docker Compose configuration created"
echo ""

# Deploy container
log_step "Step 6: Deploying Open WebUI container"
if ! deploy_with_compose "$DATA_DIR"; then
    log_error "Failed to deploy Open WebUI"
    exit 1
fi
echo ""

# Connect to n8n network if available and Ollama exists
if [[ -n "$OLLAMA_URL" ]]; then
    log_step "Step 7: Connecting to n8n network"
    if run_sudo docker network inspect n8n_network &>/dev/null 2>&1; then
        # Check if already connected
        if run_sudo docker network inspect n8n_network --format '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
            log_info "Open WebUI already connected to n8n_network"
        else
            log_info "Connecting Open WebUI to n8n_network..."
            run_sudo docker network connect n8n_network $CONTAINER_NAME || true
            log_success "✓ Open WebUI connected to n8n_network"
        fi
    else
        log_warn "n8n_network not found - creating it..."
        run_sudo docker network create n8n_network || true
        run_sudo docker network connect n8n_network $CONTAINER_NAME || true
        log_success "✓ Network created and connected"
    fi
    echo ""
fi

# Wait for container to be ready
log_step "Step 8: Waiting for Open WebUI to be ready"
RETRIES=30
COUNT=0
while [[ $COUNT -lt $RETRIES ]]; do
    if curl -sf http://localhost:$PORT/health &>/dev/null; then
        log_success "Open WebUI is ready!"
        break
    fi
    COUNT=$((COUNT + 1))
    if [[ $COUNT -eq $RETRIES ]]; then
        log_error "Open WebUI failed to become ready"
        run_sudo docker logs $CONTAINER_NAME --tail 50
        exit 1
    fi
    sleep 2
done
echo ""

# Display installation info
log_success "═══════════════════════════════════════════"
log_success "  Open WebUI Installation Complete!"
log_success "═══════════════════════════════════════════"
audit_log "INSTALL_COMPLETE" "$APP_NAME" "Accessible at http://localhost:$PORT"
echo ""

log_info "Access Information:"
echo "  Web Interface: http://localhost:$PORT"
if [[ -n "$OLLAMA_URL" ]]; then
    echo "  Ollama Connection: $OLLAMA_URL (via n8n_network)"
    echo "  Ollama Status: Connected"
else
    echo "  Ollama Status: Not connected"
    echo "  To connect to Ollama later: Install Ollama and restart Open WebUI"
fi
echo ""

log_info "First Time Setup:"
echo "  1. Open http://localhost:$PORT in your browser"
echo "  2. Create your admin account (first signup becomes admin)"
echo "  3. If using Ollama, models should be auto-detected"
echo "  4. If using OpenAI, configure API key in Settings"
echo ""

log_info "Storage Configuration:"
echo "  Data directory: $DATA_DIR/data"
echo "  Container path: /app/backend/data"
echo "  Persistent storage: Enabled"
echo ""

log_info "Docker Management:"
echo "  View logs:      docker logs $CONTAINER_NAME -f"
echo "  Restart:        docker restart $CONTAINER_NAME"
echo "  Stop:           docker stop $CONTAINER_NAME"
echo "  Start:          docker start $CONTAINER_NAME"
echo "  Remove:         cd $DATA_DIR && docker-compose down"
echo ""

if [[ -n "$OLLAMA_URL" ]]; then
    log_info "Using Ollama Models:"
    echo "  Open WebUI will automatically detect installed Ollama models"
    echo "  Install new models via Ollama:"
    echo "    docker exec ollama ollama pull llama2"
    echo "    docker exec ollama ollama pull mistral"
    echo "    docker exec ollama ollama pull codellama"
    echo ""
    log_info "Available in Open WebUI after pulling:"
    echo "  - Go to Settings > Models"
    echo "  - Select any installed Ollama model"
    echo "  - Start chatting!"
    echo ""
fi

log_info "Configuration Files:"
echo "  Environment: $DATA_DIR/.env"
echo "  Docker Compose: $DATA_DIR/docker-compose.yml"
echo ""
log_info "To modify configuration:"
echo "  1. Edit .env file: sudo nano $DATA_DIR/.env"
echo "  2. Restart container: docker restart $CONTAINER_NAME"
echo ""
log_info "Key .env variables you can customize:"
echo "  - OLLAMA_BASE_URL: Ollama server URL (currently: ${OLLAMA_URL:-not set})"
echo "  - OPENAI_API_KEY: Your OpenAI API key (for OpenAI models)"
echo "  - WEBUI_NAME: Custom name for your instance"
echo "  - ENABLE_SIGNUP: Enable/disable user registration"
echo "  - DEFAULT_USER_ROLE: Default role for new users"
echo "  - RAG_EMBEDDING_MODEL: Embedding model for RAG"
echo "  - ENABLE_IMAGE_GENERATION: Enable image generation"
echo "  - ENABLE_RAG_WEB_SEARCH: Enable web search"
echo ""

log_info "Features:"
echo "  ✓ User-friendly chat interface"
echo "  ✓ Support for multiple AI models (Ollama, OpenAI, etc.)"
echo "  ✓ Conversation history and management"
echo "  ✓ Model builder and customization"
echo "  ✓ RAG (Retrieval Augmented Generation)"
echo "  ✓ Web search integration"
echo "  ✓ Image generation support"
echo "  ✓ Voice chat capabilities"
echo "  ✓ Code execution"
echo "  ✓ Multi-user support with RBAC"
echo "  ✓ API access"
echo ""

log_info "Additional Configuration:"
echo "  All settings are in: $DATA_DIR/.env"
echo "  To add OpenAI API alongside Ollama:"
echo "    1. Edit: sudo nano $DATA_DIR/.env"
echo "    2. Uncomment and set: OPENAI_API_KEY=sk-your-key"
echo "    3. Restart: docker restart $CONTAINER_NAME"
echo ""

log_info "Security Notes:"
echo "  - First user signup becomes admin"
echo "  - Change default credentials immediately"
echo "  - Use strong passwords"
echo "  - Consider setting up HTTPS with reverse proxy"
echo "  - Restrict port access if needed"
echo ""

log_info "Troubleshooting:"
echo "  - Check logs: docker logs $CONTAINER_NAME -f"
echo "  - Verify Ollama: docker ps | grep ollama"
echo "  - Test Ollama connection: docker exec ollama ollama list"
echo "  - Restart container: docker restart $CONTAINER_NAME"
echo ""

log_info "Documentation:"
echo "  - Official docs: https://docs.openwebui.com/"
echo "  - GitHub: https://github.com/open-webui/open-webui"
echo "  - Your fork: https://github.com/danielfoca89/open-webui"
echo ""

log_info "Next Steps:"
echo "  1. Open http://localhost:$PORT in your browser"
echo "  2. Create your admin account"
if [[ -n "$OLLAMA_URL" ]]; then
    echo "  3. Select an Ollama model and start chatting"
else
    echo "  3. Configure OpenAI API or install Ollama"
    echo "  4. Start chatting!"
fi
echo ""
