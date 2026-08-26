#!/usr/bin/env bash
# ================================================================
# AUDIT FUNCTIONS
# ================================================================

audit_suid() {

    SUID_FILES_CACHED=()
    SUID_FILES_COUNT=0

    local base
    local p

    for base in \
        /bin \
        /sbin \
        /usr/bin \
        /usr/sbin; do

        [[ -d "$base" ]] ||
            continue

        while IFS= read -r p; do

            [[ -n "$p" ]] ||
                continue

            SUID_FILES_CACHED+=("$p")

            (( ${#SUID_FILES_CACHED[@]} >= 20 )) &&
                break

        done < <(
            run_timeout 5s \
                find "$base" \
                    -xdev \
                    -type f \
                    \( -perm -4000 -o -perm -2000 \) \
                    -print 2>/dev/null |
            head -20
        )

        (( ${#SUID_FILES_CACHED[@]} >= 20 )) &&
            break

    done

    SUID_FILES_COUNT=${#SUID_FILES_CACHED[@]}
}

audit_large_logs() {

    LOG_BIG_FILES_CACHED=""

    local p
    local size

    [[ -d /var/log ]] ||
        return 0

    for p in /var/log/*; do

        [[ -f "$p" ]] ||
            continue

        size="$(
            stat -c '%s' "$p" 2>/dev/null || true
        )"

        [[ "$size" =~ ^[0-9]+$ ]] ||
            continue

        if (( size > 104857600 )); then

            [[ -n "$LOG_BIG_FILES_CACHED" ]] &&
                LOG_BIG_FILES_CACHED+=$'\n'

            LOG_BIG_FILES_CACHED+="$p"

        fi

    done

    LOG_BIG_FILES_CACHED="$(
        printf '%s\n' "$LOG_BIG_FILES_CACHED" |
        head -5
    )"
}

audit_failed_ssh() {

    LOG_SSH_FAILED_CACHED=""

    local log_file=""

    [[ -f /var/log/secure ]] &&
        log_file=/var/log/secure

    [[ -z "$log_file" &&
       -f /var/log/auth.log ]] &&
        log_file=/var/log/auth.log

    [[ -n "$log_file" ]] ||
        return 0

    LOG_SSH_FAILED_CACHED="$(
        tail -n 5000 "$log_file" 2>/dev/null |
        grep 'Failed password' |
        tail -n 3
    )"
}

audit_all() {
    audit_suid
    audit_large_logs
    audit_failed_ssh
    collect_ssl_safe
    analyze_security_light
}
