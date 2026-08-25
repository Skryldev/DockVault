````markdown
# Docker One-File Offline Installer

A self-contained, offline Docker CE installer for Ubuntu 24.04.

The installer packages the complete Docker installation payload into a single executable Bash file:

```text
docker-offline-installer.sh
````

The resulting file contains:

* Docker Engine
* Docker CLI
* containerd
* Docker Buildx
* Docker Compose Plugin
* Docker Rootless Extras
* Required `.deb` packages
* A local offline APT repository
* Package metadata
* SHA256 integrity checks
* Installation logic

No Internet connection is required on the target Ubuntu system.

---

# Table of Contents

* [Overview](#overview)
* [Architecture](#architecture)
* [Requirements](#requirements)
* [Project Structure](#project-structure)
* [One-File Installer](#one-file-installer)
* [Building the Installer](#building-the-installer)
* [Verifying the Installer](#verifying-the-installer)
* [Using the Installer on an Ubuntu VM](#using-the-installer-on-an-ubuntu-vm)
* [Installing Docker](#installing-docker)
* [Verifying Docker Installation](#verifying-docker-installation)
* [Running Docker After Installation](#running-docker-after-installation)
* [Using VMware Shared Folders](#using-vmware-shared-folders)
* [Using SSH and Tabby](#using-ssh-and-tabby)
* [Using the Installer Inside a Docker Image](#using-the-installer-inside-a-docker-image)
* [Important Container Limitation](#important-container-limitation)
* [Testing the Installer in a Container](#testing-the-installer-in-a-container)
* [Offline Installation Model](#offline-installation-model)
* [Integrity Verification](#integrity-verification)
* [Uninstalling Docker](#uninstalling-docker)
* [Troubleshooting](#troubleshooting)
* [Security Considerations](#security-considerations)
* [Limitations](#limitations)
* [Expected Result](#expected-result)

---

# Overview

The project provides a completely offline installation mechanism for Docker CE on Ubuntu 24.04.

The primary artifact is:

```text
docker-offline-installer.sh
```

The file is a self-extracting Bash installer.

Although the file has a `.sh` extension, it is not only a small shell script.

The installer consists of:

```text
Bash installer
       +
embedded compressed TAR.GZ payload
       +
Debian packages
       +
APT repository metadata
       +
SHA256 checksums
```

This is why the final file can be approximately 143 MB.

---

# Architecture

The build process has two stages.

## Stage 1 — Offline Repository

The following structure is created:

```text
docker-offline/
├── install.sh
└── repo/
    ├── *.deb
    ├── Packages
    ├── Packages.gz
    └── SHA256SUMS
```

The `repo/` directory contains all required Debian packages.

For example:

```text
docker-ce_*.deb
docker-ce-cli_*.deb
containerd.io_*.deb
docker-buildx-plugin_*.deb
docker-compose-plugin_*.deb
docker-ce-rootless-extras_*.deb
```

as well as their required dependencies.

---

## Stage 2 — One-File Packaging

The directory is compressed:

```text
docker-offline.tar.gz
```

Then the archive is appended to the Bash installer.

The final result is:

```text
docker-offline-installer.sh
```

Conceptually:

```text
┌──────────────────────────────────────┐
│ Bash Installer                       │
│                                      │
│ - argument handling                  │
│ - root check                         │
│ - payload extraction                 │
│ - integrity verification             │
│ - Docker installation               │
│                                      │
├──────────────────────────────────────┤
│ Embedded Marker                      │
├──────────────────────────────────────┤
│                                      │
│ gzip compressed TAR payload          │
│                                      │
│ ├── install.sh                       │
│ └── repo/                            │
│     ├── *.deb                         │
│     ├── Packages                      │
│     ├── Packages.gz                   │
│     └── SHA256SUMS                    │
│                                      │
└──────────────────────────────────────┘
```

---

# Requirements

## Build Machine

The build machine should have:

* Ubuntu 24.04
* Bash
* `tar`
* `gzip`
* `sha256sum`
* Docker
* Internet access during the build process

Example:

```bash
bash --version
tar --version
sha256sum --version
docker --version
```

---

## Target VM

The target system should be:

```text
Ubuntu 24.04
amd64
```

The target machine does NOT need Internet access.

It only needs:

* Ubuntu 24.04
* amd64 architecture
* root/sudo access
* systemd
* sufficient disk space

Recommended:

```text
RAM:     >= 2 GB
Disk:    >= 10 GB free
CPU:     >= 2 cores
```

---

# Project Structure

A typical build directory looks like:

```text
docker-offline-build/
├── build-one-file.sh
├── docker-offline-installer.sh
└── docker-offline/
    ├── install.sh
    └── repo/
        ├── *.deb
        ├── Packages
        ├── Packages.gz
        └── SHA256SUMS
```

The final deliverable is:

```text
docker-offline-installer.sh
```

---

# One-File Installer

The main artifact is:

```text
docker-offline-installer.sh
```

Example:

```bash
ls -lh docker-offline-installer.sh
```

Expected output:

```text
-rwxr-xr-x ... 143M docker-offline-installer.sh
```

The size depends on the package set.

---

# Building the Installer

Run:

```bash
cd ~/docker-offline-build
```

Make the build script executable:

```bash
chmod +x build-one-file.sh
```

Validate the Bash syntax:

```bash
bash -n build-one-file.sh
```

Build:

```bash
./build-one-file.sh
```

Expected:

```text
[INFO] Building one-file Docker offline installer...
[INFO] Build completed:
       /home/alireza/docker-offline-build/docker-offline-installer.sh

[INFO] File size:
143M    /home/alireza/docker-offline-build/docker-offline-installer.sh

[INFO] SHA256:
<checksum>  /home/alireza/docker-offline-build/docker-offline-installer.sh
```

---

# Verifying the Installer

Check the file:

```bash
ls -lh docker-offline-installer.sh
```

Check the beginning:

```bash
head -5 docker-offline-installer.sh
```

Expected:

```text
#!/usr/bin/env bash

set -Eeuo pipefail
```

The end of the file contains binary compressed data.

Therefore commands such as:

```bash
tail docker-offline-installer.sh
```

may display unreadable characters.

This is normal.

---

## Verify Payload Marker

The installer contains a payload marker:

```bash
grep -an '__DOCKER_OFFLINE_PAYLOAD__' docker-offline-installer.sh
```

There should be a marker near the end of the shell portion.

To locate the actual payload marker:

```bash
grep -abo '^__DOCKER_OFFLINE_PAYLOAD__$' docker-offline-installer.sh
```

Example:

```text
1932:__DOCKER_OFFLINE_PAYLOAD__
```

---

# SHA256 Verification

Generate a checksum:

```bash
sha256sum docker-offline-installer.sh
```

Example:

```text
10da881e36406e2e305a7fb388aa93811f658380aa4ec117df01203889fd8aaf
```

Store the checksum somewhere trusted.

For example:

```text
docker-offline-installer.sh.sha256
```

with:

```text
10da881e36406e2e305a7fb388aa93811f658380aa4ec117df01203889fd8aaf  docker-offline-installer.sh
```

Verify:

```bash
sha256sum -c docker-offline-installer.sh.sha256
```

Expected:

```text
docker-offline-installer.sh: OK
```

---

# Using the Installer on an Ubuntu VM

The recommended production use case is installing Docker directly on an Ubuntu VM.

For example:

```text
VMware Workstation
        │
        ▼
Ubuntu 24.04 VM
        │
        ▼
docker-offline-installer.sh
        │
        ▼
Docker CE
```

The target VM does not require Internet access.

---

# Transferring the Installer to the VM

There are several options.

## Option 1 — VMware Shared Folder

VMware Shared Folders are convenient when the VM and host are on the same physical machine.

On Ubuntu, verify VMware tools:

```bash
systemctl status open-vm-tools --no-pager
```

Expected:

```text
Active: active (running)
```

Find available shared folders:

```bash
vmware-hgfsclient
```

Example:

```text
offline
```

Mount:

```bash
sudo mkdir -p /mnt/hgfs

sudo mount -t fuse.vmhgfs-fuse .host:/ /mnt/hgfs \
    -o allow_other
```

Check:

```bash
ls -la /mnt/hgfs
```

Example:

```text
offline
```

Then:

```bash
ls -lh /mnt/hgfs/offline
```

Example:

```text
docker-offline-installer.sh
```

---

# Copy the Installer

Instead of executing directly from the shared folder, it is recommended to copy the installer into the VM filesystem.

For example:

```bash
cp /mnt/hgfs/offline/docker-offline-installer.sh ~/
```

Then:

```bash
cd ~
```

Check:

```bash
ls -lh docker-offline-installer.sh
```

---

# Verify the Installer

If a trusted checksum is available:

```bash
sha256sum docker-offline-installer.sh
```

Compare it with the expected checksum.

Do not install the file if the checksum does not match.

---

# Make the Installer Executable

```bash
chmod +x docker-offline-installer.sh
```

Verify:

```bash
ls -l docker-offline-installer.sh
```

It should contain executable permissions:

```text
-rwxr-xr-x
```

---

# Installing Docker

Run:

```bash
sudo ./docker-offline-installer.sh
```

The installer requires root privileges.

It performs approximately these steps:

```text
1. Verify root
2. Locate embedded payload
3. Extract payload
4. Verify SHA256SUMS
5. Verify package count
6. Execute offline installer
7. Install Docker packages
8. Configure Docker systemd units
9. Enable Docker
10. Start Docker
```

No Internet access is required.

---

# Offline Requirement

The target VM can be completely disconnected from the Internet.

For example:

```bash
ping -c 1 8.8.8.8
```

may fail with:

```text
Network is unreachable
```

This does not prevent the offline installer from working.

The installer uses the embedded `.deb` packages.

---

# Verifying Docker Installation

After installation:

```bash
docker version
```

Expected:

```text
Client:
 Version: 29.7.2
 ...
```

Check the daemon:

```bash
sudo systemctl status docker --no-pager
```

Expected:

```text
Active: active (running)
```

Check Docker information:

```bash
sudo docker info
```

Test a container:

```bash
sudo docker run --rm hello-world
```

Important:

The `hello-world` image must already exist locally if the VM has no Internet access.

Check:

```bash
docker images
```

---

# Docker Service

Check:

```bash
systemctl is-enabled docker
```

Expected:

```text
enabled
```

Check:

```bash
systemctl is-active docker
```

Expected:

```text
active
```

---

# Docker Compose

The installer includes the Docker Compose plugin.

Check:

```bash
docker compose version
```

Expected:

```text
Docker Compose version v5.5.0
```

Use:

```bash
docker compose up -d
```

instead of the legacy:

```bash
docker-compose
```

---

# Docker Buildx

Check:

```bash
docker buildx version
```

The Buildx plugin is included in the offline package set.

---

# Using Docker After Installation

Once Docker is installed, normal Docker commands work normally.

Examples:

```bash
docker ps
```

```bash
docker images
```

```bash
docker volume ls
```

```bash
docker network ls
```

```bash
docker compose version
```

```bash
docker buildx version
```

The fact that Docker was installed offline does not change normal Docker usage.

---

# Using SSH and Tabby

The VM can be managed remotely over SSH.

Check SSH:

```bash
sudo systemctl status ssh --no-pager
```

If necessary:

```bash
sudo systemctl enable --now ssh
```

Find the VM IP:

```bash
ip addr
```

Example:

```text
192.168.79.130
```

From another machine:

```bash
ssh askari@192.168.79.130
```

After connecting through SSH, commands are executed on the VM exactly as if they were executed from the VM's local terminal.

Tabby can be used as the SSH client.

---

# Using the Installer Inside a Docker Image

The installer can also be copied into a Docker image.

Example:

```dockerfile
FROM ubuntu:24.04

COPY docker-offline-installer.sh /installer/docker-offline-installer.sh

RUN chmod +x /installer/docker-offline-installer.sh
```

Build:

```bash
docker build -t docker-offline-test .
```

Run:

```bash
docker run --rm -it docker-offline-test bash
```

Inside the container:

```bash
ls -lh /installer/docker-offline-installer.sh
```

---

# Important Container Limitation

Installing Docker packages inside a Docker container is NOT equivalent to installing Docker on the host.

A normal Docker container does not run systemd as PID 1.

For example:

```bash
docker run --rm -it \
    --network none \
    -v "$PWD/docker-offline-installer.sh:/installer/docker-offline-installer.sh:ro" \
    ubuntu:24.04 \
    bash
```

Inside:

```bash
./docker-offline-installer.sh
```

The package installation can succeed.

However, the installer may eventually report:

```text
[ERROR] systemd is not running as PID 1.
```

This is expected.

---

# Why?

A normal Docker container looks approximately like:

```text
Docker Host
│
├── dockerd
│
└── Container
    │
    └── bash
```

PID 1 inside the container is usually:

```text
bash
```

or another application.

Docker's systemd service expects:

```text
systemd
    │
    ├── docker.service
    ├── docker.socket
    └── containerd.service
```

Therefore:

```text
Normal Docker Container
        │
        └── systemd unavailable
```

cannot behave like a normal Ubuntu VM.

---

# Testing the Installer in a Container

A container is still useful for testing the installer itself.

You can verify:

* File integrity
* Payload extraction
* SHA256 verification
* Package availability
* Package installation
* Script correctness

Example:

```bash
docker run --rm -it \
    --network none \
    -v "$HOME/docker-offline-build/docker-offline-installer.sh:/installer/docker-offline-installer.sh:ro" \
    ubuntu:24.04 \
    bash
```

Inside:

```bash
cd /installer
```

Check:

```bash
ls -lh docker-offline-installer.sh
```

Run:

```bash
./docker-offline-installer.sh
```

The expected behavior is:

```text
Locating embedded payload...
Extracting payload...
Verifying payload...
...
Docker packages installed
...
systemd is not running as PID 1
```

The important point is that package installation and payload verification can be tested even though Docker cannot be started normally.

---

# Do NOT Use a Normal Container as the Production Target

Do not use:

```bash
docker run ubuntu:24.04
```

as the actual Docker installation target.

For production installation use:

```text
Physical Ubuntu Machine
        OR
Ubuntu VM
        OR
Ubuntu Server
```

For example:

```text
VMware Workstation
        │
        ▼
Ubuntu 24.04 VM
        │
        ▼
docker-offline-installer.sh
        │
        ▼
systemd
        │
        ▼
Docker Engine
```

---

# Offline Installation Model

The offline architecture is:

```text
              BUILD MACHINE
                   │
                   │ Internet
                   ▼
        ┌───────────────────────┐
        │ Ubuntu Package Sources│
        │ Docker Repository     │
        └───────────┬───────────┘
                    │
                    ▼
             Download .deb
                    │
                    ▼
        ┌───────────────────────┐
        │ docker-offline/repo/  │
        │                       │
        │ 94 Debian packages    │
        │ Packages              │
        │ Packages.gz           │
        │ SHA256SUMS            │
        └───────────┬───────────┘
                    │
                    ▼
             docker-offline.tar.gz
                    │
                    ▼
       docker-offline-installer.sh
                    │
                    │ USB / Shared Folder /
                    │ SSH / SCP / Network
                    ▼
              OFFLINE VM
                    │
                    ▼
             Docker CE
```

---

# Integrity Verification

The repository contains:

```text
SHA256SUMS
```

The installer validates every `.deb` package:

```bash
cd repo
sha256sum -c SHA256SUMS
```

Expected result:

```text
package-name.deb: OK
```

The installer also verifies the expected package count.

Example:

```text
Expected: 94
Found:    94
```

This protects against:

* Missing packages
* Corrupted packages
* Modified packages
* Incomplete payloads

---

# Payload Extraction

The installer dynamically locates:

```text
__DOCKER_OFFLINE_PAYLOAD__
```

and extracts the compressed payload after the marker.

Conceptually:

```text
docker-offline-installer.sh
        │
        ├── Bash code
        │
        ├── __DOCKER_OFFLINE_PAYLOAD__
        │
        └── gzip/tar payload
```

The payload is extracted into a temporary directory:

```text
/tmp/docker-offline-installer.XXXXXX/
```

After installation, the temporary directory is automatically removed.

---

# Uninstalling Docker

A separate uninstall script can completely remove Docker.

Example:

```bash
sudo ./uninstall.sh
```

The script asks for explicit confirmation:

```text
Type 'REMOVE DOCKER' to continue:
```

Enter:

```text
REMOVE DOCKER
```

The uninstall process removes:

```text
docker-ce
docker-ce-cli
containerd.io
docker-buildx-plugin
docker-compose-plugin
docker-ce-rootless-extras
```

and Docker data:

```text
/var/lib/docker
/var/lib/containerd
/etc/docker
```

It also removes:

```text
Docker systemd units
Docker APT repository
Docker keyrings
Docker group
User Docker configuration
```

---

# Verifying Docker Removal

After uninstall:

```bash
command -v docker
```

Should produce no output.

Check:

```bash
command -v dockerd
```

Should produce no output.

Check:

```bash
command -v containerd
```

Should produce no output.

Check packages:

```bash
dpkg -l | grep -Ei 'docker|containerd|runc'
```

Expected:

```text
```

No output.

Check data:

```bash
test ! -e /var/lib/docker && echo "/var/lib/docker: CLEAN"
```

```bash
test ! -e /var/lib/containerd && echo "/var/lib/containerd: CLEAN"
```

```bash
test ! -e /etc/docker && echo "/etc/docker: CLEAN"
```

---

# Shell Command Hashing After Uninstall

After removing Docker, Bash may still remember the old path.

For example:

```bash
docker version
```

could temporarily produce:

```text
-bash: /usr/bin/docker: No such file or directory
```

This does not mean Docker is still installed.

Clear Bash's command hash:

```bash
hash -r
```

Then:

```bash
docker version
```

should produce:

```text
-bash: docker: command not found
```

---

# Troubleshooting

## Installer says "must be run as root"

Run:

```bash
sudo ./docker-offline-installer.sh
```

---

## Installer says payload marker not found

Verify:

```bash
grep -an '__DOCKER_OFFLINE_PAYLOAD__' docker-offline-installer.sh
```

If the marker is missing, rebuild the installer:

```bash
./build-one-file.sh
```

---

## Installer reports SHA256 verification failure

Example:

```text
Payload integrity verification failed.
```

This usually indicates:

* Corrupted installer
* Modified `.deb`
* Incomplete file transfer
* Incorrect payload
* Build artifact changed

Recalculate:

```bash
sha256sum docker-offline-installer.sh
```

Compare with the trusted checksum.

If necessary, rebuild the installer.

---

## Installer reports incorrect package count

Example:

```text
Expected 94 packages, found 93.
```

The offline repository is incomplete.

Rebuild the repository and regenerate:

```text
Packages
Packages.gz
SHA256SUMS
```

Then rebuild:

```bash
./build-one-file.sh
```

---

## `systemd is not running as PID 1`

If you see:

```text
systemd is not running as PID 1
```

you are most likely running the installer inside a normal Docker container.

This is expected.

Install Docker on:

```text
Ubuntu VM
Ubuntu Server
Physical Ubuntu host
```

instead.

---

## Docker service does not start

Check:

```bash
sudo systemctl status docker --no-pager
```

Then:

```bash
sudo journalctl -u docker --no-pager -n 100
```

Check containerd:

```bash
sudo systemctl status containerd --no-pager
```

Check:

```bash
sudo journalctl -u containerd --no-pager -n 100
```

---

## Network is unavailable

The offline installer itself does not require Internet.

For example:

```bash
ping -c 1 8.8.8.8
```

can fail while installation still succeeds.

However, Docker operations that require downloading images do require network access unless the image is already available locally.

---

# Security Considerations

The installer should only be executed if it comes from a trusted source.

Before execution:

```bash
sha256sum docker-offline-installer.sh
```

Compare the checksum with the trusted value.

Do not execute an installer if:

```text
SHA256 mismatch
Unknown source
Unexpected file size
Unexpected package set
```

The installer requires root privileges because Docker installation modifies:

```text
/usr/bin
/etc
/var/lib
/systemd
APT configuration
```

---

# Limitations

## Architecture

The current package set targets:

```text
Ubuntu 24.04
amd64
```

It is not automatically portable to:

```text
Ubuntu arm64
Ubuntu 22.04
Debian
Fedora
RHEL
Alpine
```

A separate package repository/build process should be created for those platforms.

---

## Docker Images Are Not Included

The one-file installer contains Docker packages.

It does NOT automatically contain Docker images.

For example:

```bash
docker run nginx
```

still requires the `nginx` image to exist locally.

For a completely offline application deployment, images should be transferred separately.

Example:

On an Internet-connected machine:

```bash
docker pull nginx:latest
docker save nginx:latest -o nginx.tar
```

Transfer:

```text
nginx.tar
```

to the offline VM.

Then:

```bash
docker load -i nginx.tar
```

Now:

```bash
docker images
```

will show the image.

---

# Recommended Offline Deployment

For a fully offline environment:

```text
                    Offline Deployment Bundle
                    ┌─────────────────────────┐
                    │                         │
                    │ docker-offline-         │
                    │ installer.sh             │
                    │                         │
                    │ application-images.tar   │
                    │                         │
                    │ SHA256SUMS               │
                    │                         │
                    └─────────────────────────┘
```

Example:

```text
offline-bundle/
├── docker-offline-installer.sh
├── application-images.tar
└── SHA256SUMS
```

Verify:

```bash
sha256sum -c SHA256SUMS
```

Install Docker:

```bash
sudo ./docker-offline-installer.sh
```

Load application images:

```bash
docker load -i application-images.tar
```

Then deploy:

```bash
docker compose up -d
```

---

# Expected Final State

After successful installation:

```bash
docker version
```

works.

```bash
docker compose version
```

works.

```bash
docker buildx version
```

works.

```bash
systemctl is-active docker
```

returns:

```text
active
```

and:

```bash
systemctl is-enabled docker
```

returns:

```text
enabled
```

The VM can then run Docker completely normally.

---

# Quick Start

For a normal offline Ubuntu 24.04 VM:

```bash
chmod +x docker-offline-installer.sh
```

Verify:

```bash
sha256sum docker-offline-installer.sh
```

Install:

```bash
sudo ./docker-offline-installer.sh
```

Verify:

```bash
docker version
```

```bash
docker compose version
```

```bash
docker buildx version
```

Check service:

```bash
sudo systemctl status docker --no-pager
```

---

# Summary

The Docker One-File Offline Installer provides:

* Single-file distribution
* Offline Docker CE installation
* Embedded `.deb` packages
* Embedded APT repository
* SHA256 package verification
* Payload integrity validation
* Docker Compose support
* Docker Buildx support
* Systemd integration
* Ubuntu 24.04 support
* No Internet dependency on the target machine

The recommended production target is an Ubuntu 24.04 VM or physical Ubuntu system running systemd.

Docker containers can be used for installer testing and package validation, but a normal Docker container should not be treated as the target environment for running the Docker daemon.

````