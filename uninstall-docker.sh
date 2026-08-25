#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME="$(basename "$0")"

log() {
    echo "[INFO] $*"
}

warn() {
    echo "[WARN] $*" >&2
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        error "This script must be run as root. Use: sudo ./${SCRIPT_NAME}"
    fi
}

confirm() {
    echo
    warn "This will COMPLETELY REMOVE Docker from this system."
    echo
    warn "The following data will be permanently deleted:"
    warn "  - Containers"
    warn "  - Images"
    warn "  - Volumes"
    warn "  - Networks"
    warn "  - Build cache"
    warn "  - /var/lib/docker"
    warn "  - /var/lib/containerd"
    warn "  - /etc/docker"
    echo

    read -r -p "Type 'REMOVE DOCKER' to continue: " confirmation

    if [[ "$confirmation" != "REMOVE DOCKER" ]]; then
        echo
        log "Aborted."
        exit 0
    fi
}

stop_services() {
    log "Stopping Docker services..."

    systemctl stop docker.service 2>/dev/null || true
    systemctl stop docker.socket 2>/dev/null || true
    systemctl stop containerd.service 2>/dev/null || true

    systemctl disable docker.service 2>/dev/null || true
    systemctl disable docker.socket 2>/dev/null || true
    systemctl disable containerd.service 2>/dev/null || true

    # Kill remaining Docker/containerd processes if any.
    pkill -x dockerd 2>/dev/null || true
    pkill -x docker-proxy 2>/dev/null || true
    pkill -x containerd 2>/dev/null || true
    pkill -x containerd-shim 2>/dev/null || true
    pkill -x containerd-shim-runc-v2 2>/dev/null || true
}

remove_packages() {
    log "Removing Docker packages..."

    local packages=(
        docker-ce
        docker-ce-cli
        containerd.io
        docker-buildx-plugin
        docker-compose-plugin
        docker-ce-rootless-extras
    )

    # Only pass packages that are actually installed.
    local installed=()

    for package in "${packages[@]}"; do
        if dpkg-query -W -f='${Status}' "$package" 2>/dev/null \
            | grep -q '^install ok installed$'; then
            installed+=("$package")
        fi
    done

    if [[ "${#installed[@]}" -eq 0 ]]; then
        log "No Docker packages found."
        return
    fi

    log "Packages to remove:"
    printf '       %s
' "${installed[@]}"

    apt-get purge -y "${installed[@]}"
}

remove_data() {
    log "Removing Docker data..."

    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd

    rm -rf /etc/docker
    rm -rf /run/docker
    rm -rf /run/containerd

    rm -rf /var/cache/docker
    rm -rf /var/log/docker

    # Rootless Docker data.
    rm -rf /root/.docker

    # Remove Docker configuration for regular users.
    for home_dir in /home/*; do
        [[ -d "$home_dir" ]] || continue

        rm -rf "$home_dir/.docker"
    done
}

remove_systemd_units() {
    log "Removing Docker systemd units..."

    rm -f /etc/systemd/system/docker.service
    rm -f /etc/systemd/system/docker.socket
    rm -f /etc/systemd/system/containerd.service

    rm -f /usr/lib/systemd/system/docker.service
    rm -f /usr/lib/systemd/system/docker.socket
    rm -f /usr/lib/systemd/system/containerd.service

    rm -rf /etc/systemd/system/docker.service.d
    rm -rf /etc/systemd/system/docker.socket.d
    rm -rf /etc/systemd/system/containerd.service.d

    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null || true
}

remove_repository() {
    log "Removing Docker APT repository configuration..."

    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/sources.list.d/docker.sources

    rm -f /etc/apt/keyrings/docker.asc
    rm -f /etc/apt/keyrings/docker.gpg
    rm -f /usr/share/keyrings/docker-archive-keyring.gpg
}

remove_docker_group() {
    log "Removing docker group..."

    if getent group docker >/dev/null 2>&1; then
        groupdel docker 2>/dev/null || true
    fi
}

remove_user_config() {
    log "Removing Docker user configuration..."

    rm -rf /root/.config/docker

    for home_dir in /home/*; do
        [[ -d "$home_dir" ]] || continue

        rm -rf "$home_dir/.config/docker"
    done
}

clean_apt() {
    log "Cleaning APT metadata..."

    apt-get autoremove -y --purge
    apt-get autoclean -y
    apt-get clean

    rm -rf /var/lib/apt/lists/*
}

remove_leftover_binaries() {
    log "Checking for leftover Docker binaries..."

    local binaries=(
        /usr/bin/docker
        /usr/bin/dockerd
        /usr/bin/containerd
        /usr/bin/containerd-shim
        /usr/bin/containerd-shim-runc-v2
        /usr/bin/docker-proxy
        /usr/bin/ctr
        /usr/bin/runc
    )

    for binary in "${binaries[@]}"; do
        if [[ -e "$binary" ]]; then
            local owner

            owner="$(dpkg-query -S "$binary" 2>/dev/null || true)"

            if [[ -n "$owner" ]]; then
                warn "Binary still belongs to package: $owner"
            else
                warn "Removing unowned leftover binary: $binary"
                rm -f "$binary"
            fi
        fi
    done
}

verify_removal() {
    log "Verifying Docker removal..."

    local failed=0

    echo

    # Package verification.
    if dpkg -l | grep -Eiq '^(ii|rc).* (docker|containerd|runc)'; then
        warn "Docker-related packages still exist:"
        dpkg -l | grep -Ei '^(ii|rc).* (docker|containerd|runc)' || true
        failed=1
    else
        log "Docker packages: CLEAN"
    fi

    # Binary verification.
    local binaries=(
        docker
        dockerd
        containerd
    )

    for command_name in "${binaries[@]}"; do
        if command -v "$command_name" >/dev/null 2>&1; then
            warn "$command_name command still exists: $(command -v "$command_name")"
            failed=1
        else
            log "$command_name: NOT FOUND"
        fi
    done

    # Data verification.
    local directories=(
        /var/lib/docker
        /var/lib/containerd
        /etc/docker
    )

    for directory in "${directories[@]}"; do
        if [[ -e "$directory" ]]; then
            warn "Docker artifact still exists: $directory"
            failed=1
        else
            log "$directory: REMOVED"
        fi
    done

    echo

    if [[ "$failed" -eq 0 ]]; then
        log "========================================"
        log "Docker has been COMPLETELY REMOVED."
        log "========================================"
        return 0
    fi

    warn "========================================"
    warn "Some Docker artifacts may still exist."
    warn "========================================"

    return 1
}

main() {
    require_root
    confirm

    stop_services
    remove_packages
    remove_data
    remove_systemd_units
    remove_repository
    remove_docker_group
    remove_user_config
    clean_apt
    remove_leftover_binaries
    verify_removal
}

main "$@"
