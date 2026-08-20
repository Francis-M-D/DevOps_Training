#!/usr/bin/env bash
#
# install-docker.sh
#
# Production-oriented Docker Engine installer.
#
# Supported distributions:
#   - Ubuntu
#   - Debian
#   - RHEL
#   - CentOS Stream
#   - Rocky Linux
#   - AlmaLinux
#   - Fedora
#
# Supported architectures are validated against the architecture reported
# by the host. Package repositories determine the exact package architecture.
#
# Usage:
#   sudo ./install-docker.sh
#   sudo ./install-docker.sh --dry-run
#   sudo ./install-docker.sh --no-user-group
#   sudo ./install-docker.sh --remove-conflicts
#
# Notes:
#   - This installs Docker Engine from Docker's official package repository.
#   - It does NOT use Docker's convenience installation script.
#   - It does NOT automatically remove potentially conflicting packages unless
#     --remove-conflicts is explicitly supplied.
#

set -Eeuo pipefail
IFS=$'\n\t'

###############################################################################
# Configuration
###############################################################################

readonly SCRIPT_NAME="$(basename "$0")"

DRY_RUN=false
ADD_USER_TO_DOCKER_GROUP=true
REMOVE_CONFLICTS=false

readonly DOCKER_PACKAGES_DEB=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)

readonly DOCKER_PACKAGES_RPM=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)

readonly CONFLICT_PACKAGES=(
    docker
    docker-engine
    docker.io
    docker-doc
    docker-compose
    docker-compose-v2
    podman
    podman-docker
    containerd
    runc
)

###############################################################################
# Logging
###############################################################################

log() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    printf '[WARN] %s\n' "$*" >&2
}

error() {
    printf '[ERROR] %s\n' "$*" >&2
}

die() {
    error "$*"
    exit 1
}

run() {
    if [[ "$DRY_RUN" == true ]]; then
        printf '[DRY-RUN]'

        local arg
        for arg in "$@"; do
            printf ' %q' "$arg"
        done

        printf '\n'
        return 0
    fi

    "$@"
}

###############################################################################
# Cleanup
###############################################################################

cleanup() {
    local exit_code=$?

    if [[ "$exit_code" -ne 0 ]]; then
        error "Installation failed."
        error "Review the output above and correct the reported problem."
    fi

    exit "$exit_code"
}

trap cleanup EXIT

###############################################################################
# Arguments
###############################################################################

usage() {
    cat <<EOF
Usage:
  $SCRIPT_NAME [OPTIONS]

Options:
  --dry-run             Show commands without executing them.
  --no-user-group       Do not add the invoking user to the docker group.
  --remove-conflicts    Remove known conflicting container packages.
  -h, --help            Show this help.

Examples:
  sudo ./$SCRIPT_NAME
  sudo ./$SCRIPT_NAME --dry-run
  sudo ./$SCRIPT_NAME --no-user-group
  sudo ./$SCRIPT_NAME --remove-conflicts
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                ;;

            --no-user-group)
                ADD_USER_TO_DOCKER_GROUP=false
                ;;

            --remove-conflicts)
                REMOVE_CONFLICTS=true
                ;;

            -h|--help)
                usage
                exit 0
                ;;

            *)
                die "Unknown option: $1"
                ;;
        esac

        shift
    done
}

###############################################################################
# Privilege handling
###############################################################################

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        die "This script must be run as root. Example: sudo ./$SCRIPT_NAME"
    fi
}

###############################################################################
# OS detection
###############################################################################

OS_ID=""
OS_VERSION_ID=""
OS_VERSION_CODENAME=""
OS_PRETTY_NAME=""
OS_ID_LIKE=""

detect_os() {
    [[ -r /etc/os-release ]] || die "/etc/os-release was not found."

    # shellcheck disable=SC1091
    source /etc/os-release

    OS_ID="${ID:-}"
    OS_VERSION_ID="${VERSION_ID:-}"
    OS_VERSION_CODENAME="${VERSION_CODENAME:-}"
    OS_PRETTY_NAME="${PRETTY_NAME:-unknown}"
    OS_ID_LIKE="${ID_LIKE:-}"

    [[ -n "$OS_ID" ]] || die "Unable to determine Linux distribution."

    log "Operating system : $OS_PRETTY_NAME"
    log "Distribution      : $OS_ID"
    log "Version           : ${OS_VERSION_ID:-unknown}"
    log "Codename          : ${OS_VERSION_CODENAME:-unknown}"
}

###############################################################################
# Architecture detection
###############################################################################

HOST_ARCH=""
DOCKER_ARCH=""

detect_architecture() {
    HOST_ARCH="$(uname -m)"

    case "$HOST_ARCH" in
        x86_64|amd64)
            DOCKER_ARCH="amd64"
            ;;

        aarch64|arm64)
            DOCKER_ARCH="arm64"
            ;;

        armv7l|armv7*)
            DOCKER_ARCH="arm"
            ;;

        ppc64le)
            DOCKER_ARCH="ppc64le"
            ;;

        s390x)
            DOCKER_ARCH="s390x"
            ;;

        *)
            die "Unsupported CPU architecture: $HOST_ARCH"
            ;;
    esac

    log "CPU architecture  : $HOST_ARCH"
    log "Docker architecture: $DOCKER_ARCH"
}

###############################################################################
# Environment validation
###############################################################################

require_linux() {
    [[ "$(uname -s)" == "Linux" ]] || \
        die "This installer supports Linux only."
}

require_systemd() {
    if ! command -v systemctl >/dev/null 2>&1; then
        die "systemctl was not found. This installer expects a systemd-based host."
    fi
}

require_network_tools() {
    if ! command -v curl >/dev/null 2>&1; then
        die "curl is required but was not found."
    fi
}

###############################################################################
# Docker detection
###############################################################################

docker_already_installed() {
    command -v docker >/dev/null 2>&1
}

show_existing_docker() {
    if docker_already_installed; then
        log "Docker CLI already exists."

        if docker --version >/dev/null 2>&1; then
            log "Existing Docker version:"
            docker --version || true
        fi

        return 0
    fi

    return 1
}

###############################################################################
# Conflict detection
###############################################################################

get_installed_deb_conflicts() {
    local package

    for package in "${CONFLICT_PACKAGES[@]}"; do
        if dpkg-query -W -f='${Status}' "$package" 2>/dev/null |
            grep -q "install ok installed"; then
            printf '%s\n' "$package"
        fi
    done
}

get_installed_rpm_conflicts() {
    local package

    for package in "${CONFLICT_PACKAGES[@]}"; do
        if rpm -q "$package" >/dev/null 2>&1; then
            printf '%s\n' "$package"
        fi
    done
}

handle_debian_conflicts() {
    local conflicts

    conflicts="$(get_installed_deb_conflicts || true)"

    if [[ -z "$conflicts" ]]; then
        return 0
    fi

    warn "Potentially conflicting packages detected:"
    printf '%s\n' "$conflicts" >&2

    if [[ "$REMOVE_CONFLICTS" != true ]]; then
        die "Conflicting packages found. Re-run with --remove-conflicts if removal is intentional."
    fi

    log "Removing conflicting packages..."

    # shellcheck disable=SC2086
    run apt-get remove -y $conflicts
}

handle_rpm_conflicts() {
    local conflicts

    conflicts="$(get_installed_rpm_conflicts || true)"

    if [[ -z "$conflicts" ]]; then
        return 0
    fi

    warn "Potentially conflicting packages detected:"
    printf '%s\n' "$conflicts" >&2

    if [[ "$REMOVE_CONFLICTS" != true ]]; then
        die "Conflicting packages found. Re-run with --remove-conflicts if removal is intentional."
    fi

    log "Removing conflicting packages..."

    # shellcheck disable=SC2086
    if command -v dnf >/dev/null 2>&1; then
        run dnf remove -y $conflicts
    else
        run yum remove -y $conflicts
    fi
}

###############################################################################
# Debian / Ubuntu
###############################################################################

install_docker_debian_family() {
    local repo_distribution=""
    local repo_suite=""
    local arch

    command -v apt-get >/dev/null 2>&1 || \
        die "apt-get was not found."

    command -v dpkg >/dev/null 2>&1 || \
        die "dpkg was not found."

    arch="$(dpkg --print-architecture)"

    case "$OS_ID" in
        ubuntu)
            repo_distribution="ubuntu"

            # Ubuntu uses UBUNTU_CODENAME when VERSION_CODENAME is not set
            # on some derivative/release combinations.
            repo_suite="${UBUNTU_CODENAME:-${OS_VERSION_CODENAME:-}}"

            if [[ -z "$repo_suite" ]]; then
                die "Unable to determine Ubuntu release codename."
            fi
            ;;

        debian)
            repo_distribution="debian"
            repo_suite="${OS_VERSION_CODENAME:-}"

            if [[ -z "$repo_suite" ]]; then
                die "Unable to determine Debian release codename."
            fi
            ;;

        *)
            die "Internal error: unsupported Debian-family distribution: $OS_ID"
            ;;
    esac

    log "Using Docker repository:"
    log "  Distribution : $repo_distribution"
    log "  Suite        : $repo_suite"
    log "  Architecture : $arch"

    case "$OS_ID" in
        ubuntu)
            case "$OS_VERSION_ID" in
                20.04|22.04|24.04|25.04|25.10)
                    ;;
                *)
                    warn "Ubuntu version $OS_VERSION_ID is not explicitly validated by this script."
                    warn "Attempting installation using Docker's current repository."
                    ;;
            esac
            ;;

        debian)
            case "$OS_VERSION_ID" in
                11|12|13)
                    ;;
                *)
                    warn "Debian version $OS_VERSION_ID is not explicitly validated by this script."
                    warn "Attempting installation using Docker's current repository."
                    ;;
            esac
            ;;
    esac

    handle_debian_conflicts

    log "Installing prerequisites..."

    run apt-get update

    run apt-get install -y \
        ca-certificates \
        curl \
        gnupg

    log "Installing Docker GPG key..."

    run install -m 0755 -d /etc/apt/keyrings

    if [[ "$DRY_RUN" == true ]]; then
        printf '[DRY-RUN] curl -fsSL https://download.docker.com/linux/%s/gpg -o /etc/apt/keyrings/docker.asc\n' \
            "$repo_distribution"
    else
        curl -fsSL \
            "https://download.docker.com/linux/${repo_distribution}/gpg" \
            -o /etc/apt/keyrings/docker.asc
    fi

    run chmod a+r /etc/apt/keyrings/docker.asc

    log "Configuring Docker APT repository..."

    if [[ "$DRY_RUN" == true ]]; then
        cat <<EOF
[DRY-RUN] Would create:
/etc/apt/sources.list.d/docker.sources

Types: deb
URIs: https://download.docker.com/linux/${repo_distribution}
Suites: ${repo_suite}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    else
        cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/${repo_distribution}
Suites: ${repo_suite}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    fi

    log "Updating APT metadata..."

    run apt-get update

    log "Installing Docker Engine..."

    run apt-get install -y \
        "${DOCKER_PACKAGES_DEB[@]}"
}

###############################################################################
# RPM family helpers
###############################################################################

rpm_package_manager() {
    if command -v dnf >/dev/null 2>&1; then
        printf '%s\n' "dnf"
        return 0
    fi

    if command -v yum >/dev/null 2>&1; then
        printf '%s\n' "yum"
        return 0
    fi

    die "Neither dnf nor yum was found."
}

###############################################################################
# Fedora
###############################################################################

install_docker_fedora() {
    local pm

    pm="$(rpm_package_manager)"

    handle_rpm_conflicts

    log "Using Docker Fedora repository."

    log "Installing repository management tools..."

    if [[ "$pm" == "dnf" ]]; then
        run dnf -y install dnf-plugins-core
        run dnf config-manager --add-repo \
            https://download.docker.com/linux/fedora/docker-ce.repo
    else
        run yum -y install dnf-plugins-core
        run yum config-manager --add-repo \
            https://download.docker.com/linux/fedora/docker-ce.repo
    fi

    log "Installing Docker Engine..."

    run "$pm" install -y \
        "${DOCKER_PACKAGES_RPM[@]}"
}

###############################################################################
# RHEL
###############################################################################

install_docker_rhel() {
    local pm

    pm="$(rpm_package_manager)"

    handle_rpm_conflicts

    log "Using Docker RHEL repository."

    if [[ "$pm" == "dnf" ]]; then
        run dnf -y install dnf-plugins-core
        run dnf config-manager --add-repo \
            https://download.docker.com/linux/rhel/docker-ce.repo
    else
        run yum -y install yum-utils
        run yum-config-manager --add-repo \
            https://download.docker.com/linux/rhel/docker-ce.repo
    fi

    log "Installing Docker Engine..."

    run "$pm" install -y \
        "${DOCKER_PACKAGES_RPM[@]}"
}

###############################################################################
# CentOS Stream
###############################################################################

install_docker_centos() {
    local pm

    pm="$(rpm_package_manager)"

    handle_rpm_conflicts

    log "Using Docker CentOS repository."

    if [[ "$pm" == "dnf" ]]; then
        run dnf -y install dnf-plugins-core
        run dnf config-manager --add-repo \
            https://download.docker.com/linux/centos/docker-ce.repo
    else
        run yum -y install yum-utils
        run yum-config-manager --add-repo \
            https://download.docker.com/linux/centos/docker-ce.repo
    fi

    log "Installing Docker Engine..."

    run "$pm" install -y \
        "${DOCKER_PACKAGES_RPM[@]}"
}

###############################################################################
# Rocky / AlmaLinux
#
# Rocky and AlmaLinux are RHEL-compatible derivatives. Docker documents
# RHEL/CentOS repositories; these derivatives commonly use the corresponding
# EL repositories. We keep this explicit rather than pretending they are
# officially separate Docker distributions.
###############################################################################

install_docker_el_derivative() {
    local pm
    local repo_url

    pm="$(rpm_package_manager)"

    handle_rpm_conflicts

    repo_url="https://download.docker.com/linux/centos/docker-ce.repo"

    log "Distribution: $OS_ID"
    log "Using Enterprise Linux compatible Docker repository."
    log "Repository: $repo_url"

    if [[ "$pm" == "dnf" ]]; then
        run dnf -y install dnf-plugins-core
        run dnf config-manager --add-repo "$repo_url"
    else
        run yum -y install yum-utils
        run yum-config-manager --add-repo "$repo_url"
    fi

    log "Installing Docker Engine..."

    run "$pm" install -y \
        "${DOCKER_PACKAGES_RPM[@]}"
}

###############################################################################
# Dispatch
###############################################################################

install_docker() {
    case "$OS_ID" in

        ubuntu)
            install_docker_debian_family
            ;;

        debian)
            install_docker_debian_family
            ;;

        fedora)
            install_docker_fedora
            ;;

        rhel)
            install_docker_rhel
            ;;

        centos)
            install_docker_centos
            ;;

        rocky|almalinux)
            install_docker_el_derivative
            ;;

        *)
            cat >&2 <<EOF

Unsupported Linux distribution: $OS_ID

Detected:
  Distribution : $OS_PRETTY_NAME
  Version      : ${OS_VERSION_ID:-unknown}
  Architecture: $HOST_ARCH

This installer intentionally refuses to guess the correct Docker
repository for an unsupported distribution.

Supported distributions:
  Ubuntu
  Debian
  Fedora
  RHEL
  CentOS Stream
  Rocky Linux
  AlmaLinux

EOF
            exit 1
            ;;
    esac
}

###############################################################################
# Docker service
###############################################################################

configure_docker_service() {
    log "Configuring Docker service..."

    if ! command -v systemctl >/dev/null 2>&1; then
        die "systemctl is required to manage the Docker service."
    fi

    run systemctl daemon-reload
    run systemctl enable docker
    run systemctl start docker

    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    if ! systemctl is-active --quiet docker; then
        systemctl status docker --no-pager || true
        die "Docker service failed to start."
    fi

    log "Docker service is running."
}

###############################################################################
# User configuration
###############################################################################

get_target_user() {
    # SUDO_USER is preferable when the script was invoked with sudo.
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        printf '%s\n' "$SUDO_USER"
        return 0
    fi

    # If running directly as root, there may be no sensible non-root target.
    printf '%s\n' ""
}

configure_docker_group() {
    local target_user

    if [[ "$ADD_USER_TO_DOCKER_GROUP" != true ]]; then
        log "Skipping docker group configuration."
        return 0
    fi

    target_user="$(get_target_user)"

    if [[ -z "$target_user" ]]; then
        log "No invoking non-root user detected; skipping docker group configuration."
        return 0
    fi

    if ! id "$target_user" >/dev/null 2>&1; then
        warn "Unable to find invoking user '$target_user'."
        return 0
    fi

    log "Adding '$target_user' to the docker group..."

    run groupadd -f docker
    run usermod -aG docker "$target_user"

    warn "The user '$target_user' must log out and back in before the"
    warn "new docker group membership is reflected in a normal shell."
}

###############################################################################
# Verification
###############################################################################

verify_installation() {
    if [[ "$DRY_RUN" == true ]]; then
        log "Dry-run complete. No changes were made."
        return 0
    fi

    log "Verifying Docker installation..."

    command -v docker >/dev/null 2>&1 || \
        die "Docker CLI was not found after installation."

    log "Docker version:"
    docker --version

    log "Docker Compose version:"
    docker compose version

    log "Docker Buildx version:"
    docker buildx version

    log "Docker service status:"
    systemctl is-active docker

    log "Docker installation completed successfully."
}

###############################################################################
# Diagnostics
###############################################################################

print_summary() {
    cat <<EOF

============================================================
Docker Installation Summary
============================================================

Operating system : $OS_PRETTY_NAME
Distribution     : $OS_ID
OS version       : ${OS_VERSION_ID:-unknown}
OS codename      : ${OS_VERSION_CODENAME:-unknown}
Kernel           : $(uname -r)
Architecture     : $HOST_ARCH
Docker arch      : $DOCKER_ARCH

Docker packages:
  - docker-ce
  - docker-ce-cli
  - containerd.io
  - docker-buildx-plugin
  - docker-compose-plugin

Docker service:
  - enabled
  - started

============================================================

EOF
}

###############################################################################
# Main
###############################################################################

main() {
    parse_args "$@"

    require_linux
    require_root
    require_systemd

    detect_os
    detect_architecture

    # curl is installed as part of prerequisites on Debian-family systems.
    # RPM systems may already have it; install it if required.
    if ! command -v curl >/dev/null 2>&1; then
        case "$OS_ID" in
            ubuntu|debian)
                run apt-get update
                run apt-get install -y curl
                ;;

            fedora|rhel|centos|rocky|almalinux)
                local pm
                pm="$(rpm_package_manager)"
                run "$pm" install -y curl
                ;;

            *)
                die "curl is required."
                ;;
        esac
    fi

    if show_existing_docker; then
        log "Docker appears to already be installed."
        log "This script will not replace an existing installation automatically."

        if [[ "$DRY_RUN" != true ]]; then
            configure_docker_service
            configure_docker_group
        fi

        verify_installation
        print_summary
        return 0
    fi

    install_docker
    configure_docker_service
    configure_docker_group
    verify_installation
    print_summary
}

main "$@"


