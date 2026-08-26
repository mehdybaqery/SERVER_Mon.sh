# SERVER HEALTH MONITOR

**Production‑grade, read‑only health monitoring for Linux servers.**

![Version](https://img.shields.io/badge/version-1.3.3-blue)
![Bash](https://img.shields.io/badge/bash-4.0%2B-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## Overview

**SERVER HEALTH MONITOR** is a comprehensive, interactive Bash tool designed for DevOps engineers and system administrators. It performs real‑time health checks, security assessments, and resource monitoring on Linux systems – **without making any changes** to the system (read‑only by design). It is safe to run in production environments.

The tool provides:
- Live dashboard with resource bars, process list, and security scores.
- Detailed intelligence screens for users, cron, network, security, logs, hardware, packages, containers, Kubernetes, and SSL certificates.
- JSON, HTML, and plain‑text logging.
- Optional Telegram alerts for critical findings.

---

## Features

| Category                | Checks & Metrics |
|-------------------------|------------------|
| **System**              | OS, kernel, architecture, uptime, virtualization, primary IP, server role (K8s/DB/Web/DNS) |
| **Resources**           | CPU usage, memory usage, swap usage, disk usage, inode usage, load average, load ratio |
| **Processes**           | Total processes, zombie processes, total threads, top 10 processes by CPU/RAM |
| **Network**             | Listening ports, established connections, TCP/UDP connections |
| **Users**               | Total users, login‑capable users, UID 0 accounts, locked accounts, sudo/wheel members, active logged‑in users |
| **Cron**                | System and user crontabs, cron directory file counts |
| **Services**            | Docker, Containerd, Kubelet status; failed systemd services |
| **Security**            | SSH configuration (root login, password auth, pubkey, protocol, empty passwords), SELinux status, firewall detection, NTP sync, sudoers NOPASSWD entries |
| **Containers & K8s**    | Docker containers, images, volumes; Kubernetes nodes, pods, services (if kubectl is available) |
| **SSL Certificates**    | Expiration status for Let's Encrypt, Nginx, Apache, and PKI certificates |
| **Audit**               | SUID/SGID files (top 20), large log files (>100 MB), recent SSH failed logins |

All checks are **cached** with configurable intervals to minimise system impact, and the monitor runs with lowered CPU/I/O priority (`renice` + `ionice`).

---

## Installation

Clone the repository and make the main script executable:

```bash
git clone https://github.com/yourusername/SERVER-Mon.git
cd SERVER-Mon
chmod +x monitor.sh
