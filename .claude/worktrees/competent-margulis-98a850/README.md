# FluxCore — VPS Orchestrator

> **Production-Ready VPS Management System**
>
> Automated deployment, security hardening, and management for self-hosted applications.
> Built with modular Bash 4+ scripts, focused on **Debian/Ubuntu**.

---

## 🚀 Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/danielfoca89/fluxcore.git
cd fluxcore

# 2. Run the orchestrator
./orchestrator.sh
```

**Requirements:** `Debian 11+` or `Ubuntu 22.04+` · `Bash 4+` · Root or sudo access

The **Orchestrator** is your single entry point. It:

- **Detects first run** — automatically prompts VPS hardening on a fresh server
- **Resolves dependencies** automatically (Docker, Nginx, DBs)
- **Detects installed apps** and shows their status in the menu
- **Loops back** to the menu after each action — no need to re-run
- **Defensive Execution** — strict Bash modes (`set -Eeuo pipefail`) and error traps

---

## 📂 Project Structure

```text
fluxcore/
├── orchestrator.sh              # Main interactive menu
├── .editorconfig                # Editor formatting rules
├── .shellcheckrc                # ShellCheck static analysis config
├── .shfmt.toml                  # Shell formatter config (4-space indent)
├── .github/workflows/
│   ├── release-please.yml       # Automated versioning & changelogs
│   └── lint.yml                 # ShellCheck + shfmt + bats-core CI
├── apps/                        # Application installers (self-contained)
│   ├── ai/                      # Ollama, Open WebUI, Llama.cpp
│   ├── automation/              # n8n, XyOps
│   ├── databases/               # PostgreSQL, Redis, MongoDB, MariaDB
│   ├── infrastructure/          # Nginx, Docker Engine, Portainer, Arcane, Certbot
│   ├── monitoring/              # Grafana, Prometheus, Netdata, Uptime Kuma
│   ├── security/                # Vault, WireGuard, Fail2Ban, Security Audit
│   └── system/                  # Node.js v25, Log Maintenance
├── config/                      # Global configs
│   ├── apps.conf                # App registry — names, deps, descriptions
│   ├── tools.conf               # Tools registry
│   ├── workflows.conf           # Workflows registry
│   └── docker-daemon.json       # Docker daemon defaults
├── lib/                         # Shared libraries — sourced by all scripts
│   ├── init.sh                  # ★ Auto-loader — sources all libs in order
│   ├── constants.sh             # ★ Readonly constants (colors, paths, version)
│   ├── utils.sh                 # Logging, guards, sudo, service management
│   ├── os-detect.sh             # OS/distro detection
│   ├── preflight.sh             # System checks (disk, RAM, internet, ports)
│   ├── secrets.sh               # Credential generation & storage
│   └── docker.sh                # Docker helpers
├── tests/                       # bats-core test suite
│   ├── test_helper.sh
│   ├── constants.bats
│   ├── init.bats
│   └── syntax.bats
├── tools/                       # Operational scripts (accessible from menu)
│   ├── health-check.sh          # System status — CPU, RAM, containers, SSL
│   ├── update.sh                # Pull new Docker images & recreate containers
│   ├── backup-databases.sh      # Dump Postgres/Mongo/MariaDB → /opt/backups
│   ├── backup-credentials.sh    # Encrypt & archive ~/.vps-secrets
│   ├── generate-self-signed-cert.sh
│   └── setup-dashboard.sh
└── workflows/                   # Complex multi-step flows
    ├── vps-initial-setup.sh     # Full server hardening
    └── proxmox-host-setup.sh    # Proxmox VE host hardening & setup
```

---

## 🛡️ Security Architecture

### VPS Hardening (`workflows/vps-initial-setup.sh`)

| Step | What it does |
| :--- | :----------- |
| 1  | System update + upgrade |
| 2  | Install security tools (fail2ban, auditd, ufw) |
| 3  | Create admin user + systemd user fix + polkit power rules |
| 4  | Kernel hardening — ASLR, sysctl params, IPv6 protection |
| 5  | SSH hardening — key-only auth, custom port, strict config |
| 6  | Firewall — UFW (Debian) or firewalld (RHEL) |
| 7  | Fail2Ban — SQLite persistent bans, 24h SSH ban, recidivists jail (7 days) |
| 8  | Audit logging — identity, SSH, sudo escalation, cron, kernel modules |
| 9  | Automatic security updates |
| 10 | Custom MOTD |
| 11 | Final verification (all services status) |
| 12 | Sudo hardening — NOPASSWD + full command log for admin group |
| 12.1 | Restrict password changes and user creation |
| 12.2 | User flexibility — polkit (reboot/systemctl without sudo), groups (docker/adm/systemd-journal) |

### Admin User Permissions

The created admin user has maximum flexibility with minimal restrictions:

| Can do (no sudo prefix needed) | Mechanism |
| :--- | :--- |
| `reboot`, `poweroff`, `suspend` | polkit rule |
| `systemctl start/stop/restart <service>` | polkit rule |
| `docker ps/logs/exec/...` | `docker` group |
| `cat /var/log/syslog`, `tail /var/log/auth.log` | `adm` group |
| `journalctl -u nginx -f` | `systemd-journal` group |
| `sudo <anything>` | NOPASSWD — no password prompt |

| Restricted | Reason |
| :--- | :--- |
| `passwd` / `chpasswd` | Cannot change passwords |
| `useradd` / `adduser` | Cannot create new users |

### Proxmox Host Hardening (`workflows/proxmox-host-setup.sh`)

8-step process for Debian 13 (Trixie) with **Intelligent Detection** for pre-existing Proxmox clusters:

| Step | What it does |
| :--- | :--- |
| 1 | Hostname & FQDN Configuration |
| 2 | System update & Proxmox repository setup |
| 3 | Essential tools & CPU Microcode |
| 4 | Proxmox 9 No-Subscription Repository (DEB822) |
| 5 | Admin user creation |
| 6 | SSH Hardening (port 22, key-only, PermitRootLogin prohibit-password) |
| 7 | Fail2Ban (SSH jail only) |
| 8 | Audit logging |

### Network Isolation

- **Public**: only through Nginx (ports 80/443)
- **Internal**: databases and admin UIs bound to `127.0.0.1` or Docker network `vps_network`
- **SSH**: key-only, no root login, no passwords

### Credential Management

- Storage: `~/.vps-secrets/` (mode `700`, files `600`)
- Cryptographically random passwords (32+ chars)
- Separate `.env` files per service
- Audit log: `~/.vps-secrets/.audit.log`

---

## 🛠️ Management Tools

| Script | Purpose |
| :----- | :------ |
| `health-check.sh` | CPU/RAM, active containers, SSL expiry |
| `backup-credentials.sh` | Encrypts `~/.vps-secrets` |
| `backup-databases.sh` | Dumps Postgres/Mongo/MariaDB → `/opt/backups` |
| `update.sh` | Pulls new Docker images, recreates containers |
| `setup-dashboard.sh` | Terminal dashboard for quick status overview |
| `generate-self-signed-cert.sh` | Self-signed TLS certificates for local dev |

---

## 🧩 Applications Catalog

### 🤖 AI
- **Ollama** — Local LLM runner
- **Open WebUI** — Chat interface for Ollama
- **Llama.cpp** — Run LLMs with minimal overhead

### ⚡ Automation
- **n8n** — Workflow automation (PostgreSQL + Redis backed)
- **XyOps** — Lightweight orchestration tool (Node.js)

### 🗄️ Databases
- **PostgreSQL** — Docker or Native. Includes `pgvector` extension.
- **Redis** — Docker (`redis-docker`) or Native (`redis`)
- **MongoDB** — Docker container
- **MariaDB** — Docker container

### 🏗️ Infrastructure
- **Docker Engine** — Base dependency for most apps
- **Nginx** — Reverse proxy with auto-generated site configs
- **Portainer** — Docker UI (localhost only, SSH tunnel)
- **Arcane** — Lightweight Docker manager (localhost only)
- **Certbot** — SSL/TLS certificate management (Let's Encrypt)

### 📊 Monitoring
- **Grafana** — Visualization platform (Docker or Native)
- **Prometheus** — Metrics collection (Docker or Native)
- **Netdata** — Real-time performance monitoring
- **Uptime Kuma** — Uptime monitoring & alerting

### 🔐 Security
- **HashiCorp Vault** — Secure secret management
- **WireGuard** — Modern VPN tunnel
- **Fail2Ban** — Intrusion prevention
- **Security Audit** — Local vulnerability scanner

### ⚙️ System
- **Node.js v25** — Environment setup (NodeSource)
- **Log Maintenance** — Auto-rotates logs to prevent disk exhaustion

---

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

---

## 📌 Versioning

[Semantic Versioning](https://semver.org/spec/v2.0.0.html) · [Tags](https://github.com/danielfoca89/fluxcore/tags)

> **Automated Versioning via GitHub Actions**
> Uses [Release Please](https://github.com/googleapis/release-please-action) for automated versioning and CHANGELOG generation based on [Conventional Commits](https://www.conventionalcommits.org/). Each push to `main` is tracked. On merge of the release PR, the version is bumped and a GitHub Release is created automatically.

---

## 📜 License

MIT License — Copyright © 2026 Daniel Foca

## Author

**Daniel Foca** ([@danielfoca89](https://github.com/danielfoca89))
