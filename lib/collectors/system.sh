#!/usr/bin/env bash
# ================================================================
# SYSTEM DISCOVERY
# ================================================================

detect_system() {

    if [[ -f /etc/os-release ]]; then

        local monitor_version="$VERSION"

        . /etc/os-release

        VERSION="$monitor_version"
        OS_NAME="${PRETTY_NAME:-Unknown}"

    fi

    KERNEL="$(uname -r 2>/dev/null || true)"
    ARCH="$(uname -m 2>/dev/null || true)"
    UPTIME="$(uptime -p 2>/dev/null || true)"

    PRIMARY_IP="$(
        hostname -I 2>/dev/null |
        awk '{print $1}'
    )"

    if have_cmd systemd-detect-virt; then

        VIRTUALIZATION="$(
            run_timeout 2s systemd-detect-virt 2>/dev/null || true
        )"

        [[ "$VIRTUALIZATION" == none ]] &&
            VIRTUALIZATION="Physical"

        [[ -z "$VIRTUALIZATION" ]] &&
            VIRTUALIZATION="Unknown"

    else
        VIRTUALIZATION="Unknown"
    fi
}

detect_roles() {

    SERVER_ROLE="Linux Server"

    local unit_files

    unit_files="$(
        run_timeout 3s \
        systemctl list-unit-files --no-legend 2>/dev/null || true
    )"

    if have_cmd kubelet ||
       grep -qE '^kubelet\.service[[:space:]]' <<<"$unit_files"; then

        K8S_FOUND=1
        SERVER_ROLE="Kubernetes Node"

    fi

    grep -qE \
        '^containerd\.service[[:space:]]' <<<"$unit_files" &&
        CONTAINERD_STATUS="installed"

    grep -qE \
        '^docker\.service[[:space:]]' <<<"$unit_files" &&
        DOCKER_STATUS="installed"

    grep -qE \
        '^(mariadb|mysql|postgresql)[^[:space:]]*\.service[[:space:]]' \
        <<<"$unit_files" &&
        SERVER_ROLE="$SERVER_ROLE + Database"

    grep -qE \
        '^(nginx|httpd)[^[:space:]]*\.service[[:space:]]' \
        <<<"$unit_files" &&
        SERVER_ROLE="$SERVER_ROLE + Web"

    grep -qE \
        '^(named|bind)[^[:space:]]*\.service[[:space:]]' \
        <<<"$unit_files" &&
        SERVER_ROLE="$SERVER_ROLE + DNS"
}

collect_hardware() {

    CPU_MODEL="$(
        lscpu 2>/dev/null |
        awk -F: '
            /Model name/ {
                gsub(/^ +/,"",$2)
                print $2
                exit
            }
        '
    )"

    [[ -z "$CPU_MODEL" ]] &&
        CPU_MODEL="$(
            awk -F: '
                /model name/ {
                    gsub(/^ +/,"",$2)
                    print $2
                    exit
                }
            ' /proc/cpuinfo 2>/dev/null
        )"

    [[ -z "$CPU_MODEL" ]] &&
        CPU_MODEL=Unknown

    CPU_CORES="$(
        nproc 2>/dev/null || true
    )"

    [[ "$CPU_CORES" =~ ^[0-9]+$ ]] ||
        CPU_CORES=0

    CPU_FREQ="$(
        lscpu 2>/dev/null |
        awk -F: '
            /CPU max MHz/ {
                gsub(/^ +/,"",$2)
                sub(/\..*/,"",$2)
                print $2
                exit
            }
        '
    )"

    [[ "$CPU_FREQ" =~ ^[0-9]+$ ]] ||
        CPU_FREQ=0

    TOTAL_RAM_MB="$(
        awk '
            /MemTotal:/ {
                printf "%d",$2/1024
                exit
            }
        ' /proc/meminfo 2>/dev/null
    )"

    [[ "$TOTAL_RAM_MB" =~ ^[0-9]+$ ]] ||
        TOTAL_RAM_MB=0

    DISK_MODEL="$(
        lsblk -d -o MODEL 2>/dev/null |
        sed '1d' |
        head -1 |
        sed 's/^ *//'
    )"

    [[ -z "$DISK_MODEL" ]] &&
        DISK_MODEL=Unknown

    DISK_SIZE="$(
        lsblk -d -o SIZE 2>/dev/null |
        sed '1d' |
        head -1 |
        sed 's/^ *//'
    )"

    [[ -z "$DISK_SIZE" ]] &&
        DISK_SIZE=Unknown
}
