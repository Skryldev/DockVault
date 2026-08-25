```markdown
<div align="center">

# 🐳 Docker One-File Offline Installer

**A self-contained, zero-dependency Docker CE installer for Ubuntu 24.04.**

[![Ubuntu 24.04](https://img.shields.io/badge/Ubuntu-24.04-E95420?style=flat-square&logo=ubuntu&logoColor=white)](#)
[![Docker CE](https://img.shields.io/badge/Docker-CE-2496ED?style=flat-square&logo=docker&logoColor=white)](#)
[![Bash](https://img.shields.io/badge/Bash-Script-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)](#)
[![Offline](https://img.shields.io/badge/Network-Offline-red?style=flat-square)](#)

</div>

---

## 📑 Table of Contents

- [📖 Overview](#-overview)
- [🏗️ Architecture](#️-architecture)
- [⚙️ Requirements](#️-requirements)
- [📂 Project Structure](#-project-structure)
- [🔨 Building the Installer](#-building-the-installer)
- [🔍 Verifying the Installer](#-verifying-the-installer)
- [💻 Using the Installer on an Ubuntu VM](#-using-the-installer-on-an-ubuntu-vm)
- [✅ Verifying Docker Installation](#-verifying-docker-installation)
- [🐳 Using Docker After Installation](#-using-docker-after-installation)
- [🌐 Remote Management (SSH & Tabby)](#-remote-management-ssh--tabby)
- [📦 Using the Installer Inside a Docker Image](#-using-the-installer-inside-a-docker-image)
- [🔄 Offline Installation Model](#-offline-installation-model)
- [🛡️ Integrity & Payload Extraction](#️-integrity--payload-extraction)
- [🗑️ Uninstalling Docker](#️-uninstalling-docker)
- [🔧 Troubleshooting](#-troubleshooting)
- [🔒 Security Considerations](#-security-considerations)
- [⚠️ Limitations](#️-limitations)
- [🚀 Recommended Offline Deployment](#-recommended-offline-deployment)
- [⚡ Quick Start](#-quick-start)
- [📝 Summary](#-summary)

---

## 📖 Overview

The project provides a completely offline installation mechanism for Docker CE on Ubuntu 24.04.

The primary artifact is a single executable Bash file: `docker-offline-installer.sh`.

Although the file has a `.sh` extension, it is not just a small shell script. The installer packages the complete Docker installation payload into a single file containing:

* Docker Engine, CLI, and containerd
* Docker Buildx & Compose Plugins
* Docker Rootless Extras
* Required `.deb` packages & local offline APT repository
* Package metadata & SHA256 integrity checks
* Installation logic

> 💡 **Note:** No Internet connection is required on the target Ubuntu system. The final file size is approximately **143 MB** due to the embedded payload.

---

## 🏗️ Architecture

The build process consists of two main stages.

### Stage 1 — Offline Repository

The following structure is created locally:

```text
docker-offline/
├── install.sh
└── repo/
    ├── *.deb (docker-ce, containerd.io, plugins, dependencies)
    ├── Packages
    ├── Packages.gz
    └── SHA256SUMS
```

### Stage 2 — One-File Packaging

The directory is compressed into `docker-offline.tar.gz` and appended to the Bash installer.

```text
┌──────────────────────────────────────┐
│ Bash Installer                       │
│ - argument handling                  │
│ - root check                         │
│ - payload extraction                 │
│ - integrity verification             │
│ - Docker installation                │
├──────────────────────────────────────┤
│ Embedded Marker                      │
├──────────────────────────────────────┤
│ gzip compressed TAR payload          │
│ ├── install.sh                       │
│ └── repo/                            │
│     ├── *.deb                        │
│     ├── Packages / Packages.gz       │
│     └── SHA256SUMS                   │
└──────────────────────────────────────┘
```

---

## ⚙️ Requirements

### Build Machine
* **OS:** Ubuntu 24.04 (Internet access required *only* during build)
* **Tools:** `bash`, `tar`, `gzip`, `sha256sum`, `docker`

### Target VM
* **OS:** Ubuntu 24.04 (amd64)
* **Network:** ❌ **No Internet required**
* **Access:** root/sudo privileges, systemd
* **Recommended Specs:** >= 2 GB RAM, >= 10 GB Disk, >= 2 CPU cores

---

## 📂 Project Structure

A typical build directory looks like:

```text
docker-offline-build/
├── build-one-file.sh
├── docker-offline-installer.sh  <-- Final Deliverable
└── docker-offline/
    ├── install.sh
    └── repo/
```

---

## 🔨 Building the Installer

Navigate to your build directory and execute the build script:

```bash
cd ~/docker-offline-build
chmod +x build-one-file.sh
bash -n build-one-file.sh # Validate syntax
./build-one-file.sh
```

**Expected Output:**
```text
[INFO] Building one-file Docker offline installer...
[INFO] Build completed: /home/user/docker-offline-build/docker-offline-installer.sh
[INFO] File size: 143M
[INFO] SHA256: <checksum>
```

---

## 🔍 Verifying the Installer

### File Structure Check
```bash
head -5 docker-offline-installer.sh
```
*Expected:* `#!/usr/bin/env bash` and `set -Eeuo pipefail`.
*(Note: `tail` will show binary compressed data, which is normal).*

### Payload Marker
```bash
grep -abo '^__DOCKER_OFFLINE_PAYLOAD__$' docker-offline-installer.sh
```

### SHA256 Verification
Generate and store the checksum:
```bash
sha256sum docker-offline-installer.sh | tee docker-offline-installer.sh.sha256
```
Verify later:
```bash
sha256sum -c docker-offline-installer.sh.sha256
```

---

## 💻 Using the Installer on an Ubuntu VM

The recommended production use case is installing Docker directly on an Ubuntu VM.

```text
VMware Workstation ➔ Ubuntu 24.04 VM ➔ docker-offline-installer.sh ➔ Docker CE
```

### Transferring via VMware Shared Folder
```bash
sudo mkdir -p /mnt/hgfs
sudo mount -t fuse.vmhgfs-fuse .host:/ /mnt/hgfs -o allow_other
cp /mnt/hgfs/offline/docker-offline-installer.sh ~/
```

### Installing Docker
```bash
cd ~
chmod +x docker-offline-installer.sh
sudo ./docker-offline-installer.sh
```

The installer dynamically locates the payload, extracts it to `/tmp`, verifies SHA256 sums, installs packages, and configures systemd units.

---

## ✅ Verifying Docker Installation

```bash
docker version
sudo systemctl status docker --no-pager
sudo docker info
```

> 💡 **Note:** To test `sudo docker run --rm hello-world`, ensure the `hello-world` image is already loaded locally, as the VM has no internet access to pull it.

### Plugins Check
```bash
docker compose version  # Expected: v5.5.0+
docker buildx version
```

---

## 🐳 Using Docker After Installation

Once installed, Docker behaves exactly like a standard online installation. Normal commands (`docker ps`, `docker images`, `docker network ls`, `docker compose up -d`) work seamlessly.

---

## 🌐 Remote Management (SSH & Tabby)

You can manage the offline VM remotely via SSH:

```bash
sudo systemctl enable --now ssh
ip addr # Find VM IP (e.g., 192.168.79.130)
```
Connect from your host using Tabby or standard SSH: `ssh user@192.168.79.130`.

---

## 📦 Using the Installer Inside a Docker Image

You can copy the installer into a Docker image for testing:

```dockerfile
FROM ubuntu:24.04
COPY docker-offline-installer.sh /installer/
RUN chmod +x /installer/docker-offline-installer.sh
```

> ⚠️ **Important Container Limitation**
> Installing Docker packages inside a standard Docker container is **NOT** equivalent to installing Docker on the host.
> A normal Docker container does not run `systemd` as PID 1. The package installation will succeed, but the installer will eventually report: `[ERROR] systemd is not running as PID 1.`
> **Do NOT use a normal container as the production target.** Use a VM or physical host.

### Testing in a Container
Containers are still useful for testing payload extraction, SHA256 verification, and package availability:
```bash
docker run --rm -it --network none -v "$PWD/docker-offline-installer.sh:/installer/docker-offline-installer.sh:ro" ubuntu:24.04 bash
```

---

## 🔄 Offline Installation Model

```text
              BUILD MACHINE (Internet)
                   │
                   ▼
        ┌───────────────────────┐
        │ Download .deb packages│
        │ Generate APT metadata │
        └───────────┬───────────┘
                    │
                    ▼
       docker-offline-installer.sh
                    │
                    │ USB / Shared Folder / SCP
                    ▼
              OFFLINE VM (No Internet)
                    │
                    ▼
             Docker CE Installed
```

---

## 🛡️ Integrity & Payload Extraction

The installer validates every `.deb` package against the embedded `SHA256SUMS` file and verifies the expected package count (e.g., Expected: 94, Found: 94). This protects against missing, corrupted, or modified packages.

The payload is extracted to a temporary directory (`/tmp/docker-offline-installer.XXXXXX/`) which is automatically cleaned up post-installation.

---

## 🗑️ Uninstalling Docker

Run the separate uninstall script:
```bash
sudo ./uninstall.sh
```
Type `REMOVE DOCKER` when prompted. This removes all packages, `/var/lib/docker`, `/etc/docker`, systemd units, and APT configurations.

### Shell Command Hashing
After uninstalling, Bash might temporarily remember the old path. If `docker version` returns `-bash: /usr/bin/docker: No such file or directory`, simply run:
```bash
hash -r
```

---

## 🔧 Troubleshooting

<details>
<summary><strong>Installer says "must be run as root"</strong></summary>
<br>
Run the installer with elevated privileges:
```bash
sudo ./docker-offline-installer.sh
```
</details>

<details>
<summary><strong>Installer says payload marker not found</strong></summary>
<br>
Verify the marker exists:
```bash
grep -an '__DOCKER_OFFLINE_PAYLOAD__' docker-offline-installer.sh
```
If missing, rebuild the installer using `./build-one-file.sh`.
</details>

<details>
<summary><strong>SHA256 verification failure</strong></summary>
<br>
This usually indicates a corrupted installer, modified `.deb`, or incomplete file transfer. Recalculate the checksum and compare it with your trusted source. If necessary, rebuild the installer.
</details>

<details>
<summary><strong>Incorrect package count</strong></summary>
<br>
If you see `Expected 94 packages, found 93`, the offline repository is incomplete. Rebuild the repository, regenerate `Packages`, `Packages.gz`, and `SHA256SUMS`, then run `./build-one-file.sh`.
</details>

<details>
<summary><strong>"systemd is not running as PID 1"</strong></summary>
<br>
You are likely running the installer inside a standard Docker container. This is expected. Install Docker on an Ubuntu VM, Server, or physical host instead.
</details>

<details>
<summary><strong>Docker service does not start</strong></summary>
<br>
Check the service and journal logs:
```bash
sudo systemctl status docker --no-pager
sudo journalctl -u docker --no-pager -n 100
```
</details>

---

## 🔒 Security Considerations

* **Trust:** Only execute the installer if it comes from a trusted source. Always verify the SHA256 checksum before execution.
* **Privileges:** The installer requires `root` because Docker installation modifies `/usr/bin`, `/etc`, `/var/lib`, and `systemd`.

---

## ⚠️ Limitations

### Architecture
The current package set targets **Ubuntu 24.04 (amd64)**. It is not automatically portable to `arm64`, `Ubuntu 22.04`, `Debian`, `Fedora`, `RHEL`, or `Alpine`.

### Docker Images Are Not Included
The installer contains Docker **packages**, but it does **NOT** contain Docker **images**.
To run `docker run nginx` offline, you must transfer the image separately:
```bash
# On Internet machine:
docker pull nginx:latest
docker save nginx:latest -o nginx.tar

# On Offline VM:
docker load -i nginx.tar
```

---

## 🚀 Recommended Offline Deployment

For a fully offline environment, bundle the installer with your application images:

```text
offline-bundle/
├── docker-offline-installer.sh
├── application-images.tar
└── SHA256SUMS
```

---

## ⚡ Quick Start

```bash
# 1. Verify
sha256sum docker-offline-installer.sh

# 2. Install
chmod +x docker-offline-installer.sh
sudo ./docker-offline-installer.sh

# 3. Verify Service
sudo systemctl status docker --no-pager
docker version
```

---

## 📝 Summary

The **Docker One-File Offline Installer** provides single-file distribution, embedded APT repositories, SHA256 validation, and zero internet dependency for the target machine. The recommended production target is an Ubuntu 24.04 VM or physical system running `systemd`.
```