# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — 2026-03-22

### 🚀 Initial Release — FluxCore VPS Orchestrator

Production-ready, modular VPS management system for Debian/Ubuntu environments.

#### 🏗 Core Architecture

- **Interactive Orchestrator** (`orchestrator.sh`) — terminal UI with dynamic app detection, dependency resolution, and automatic status indicators
- **Modular library system** (`lib/`) — 7 shared libraries with double-sourcing guards:
  - `init.sh` — auto-loader, sources all libs in dependency order
  - `constants.sh` — readonly constants (colors, paths, version)
  - `utils.sh` — logging, sudo wrapper, service management, nginx helpers
  - `os-detect.sh` — OS/distro detection with readonly globals
  - `preflight.sh` — system checks (disk, RAM, internet, ports)
  - `secrets.sh` — cryptographically random credential generation
  - `docker.sh` — Docker helpers and network management
- **Config-driven menu** — `apps.conf`, `tools.conf`, `workflows.conf` drive the orchestrator menu without hardcoded lists

#### 🛡 Security & Hardening

- **VPS Initial Setup** (`workflows/vps-initial-setup.sh`) — 12-step hardening:
  - SSH: key-only auth, custom port, strict sshd_config
  - Firewall: UFW (Debian/Ubuntu) or firewalld (RHEL)
  - Fail2Ban: SQLite persistent bans, 24h SSH lock, 7-day recidivists jail
  - Kernel hardening: ASLR, SYN flood protection, IP spoofing prevention, BPF hardening
  - Audit logging: identity, SSH, sudo, cron, kernel module changes
  - Unattended security updates
  - Sudo: NOPASSWD for admin group + full I/O command logging
- **Proxmox Host Hardening** (`workflows/proxmox-host-setup.sh`) — 8-step Debian 13 hardening with intelligent cluster detection (skips steps safely if Proxmox cluster already present)
- **Admin user flexibility** — polkit rules for passwordless `reboot`/`poweroff`/`systemctl`, docker/adm/systemd-journal group membership
- **Restricted operations** — admin user cannot change passwords or create new accounts

#### 📦 Applications (29 installers across 7 categories)

- **AI**: Ollama, Open WebUI, Llama.cpp
- **Automation**: n8n (PostgreSQL + Redis backed), XyOps
- **Databases**: PostgreSQL (Docker + Native + pgvector), Redis (Docker + Native), MongoDB, MariaDB
- **Infrastructure**: Docker Engine, Nginx, Portainer, Arcane, Certbot
- **Monitoring**: Grafana (Docker + Native), Prometheus (Docker + Native), Netdata, Uptime Kuma
- **Security**: HashiCorp Vault, WireGuard, Fail2Ban, Security Audit
- **System**: Node.js v25 (NodeSource), Log Maintenance

#### 🔧 Management Tools

- `health-check.sh` — CPU/RAM, active containers, SSL expiry
- `backup-databases.sh` — Postgres/Mongo/MariaDB dumps to `/opt/backups`
- `backup-credentials.sh` — encrypted `~/.vps-secrets` archive
- `update.sh` — pull new Docker images and recreate containers
- `setup-dashboard.sh` — terminal status dashboard
- `generate-self-signed-cert.sh` — TLS certificates for local development

#### 🧪 Quality & CI

- `shellcheckrc`, `.editorconfig`, `.shfmt.toml` — consistent code style project-wide
- `tests/` — bats-core test suite: constants, init loader, syntax validation for all scripts
- `.github/workflows/lint.yml` — CI: ShellCheck + shfmt + bats-core on every push
- `.github/workflows/release-please.yml` — automated semantic versioning via Conventional Commits
