#!/usr/bin/env bash
# ================================================================
# SECURITY ANALYSIS
# ================================================================

analyze_security_light() {

    SCORE=100
    CRITICAL=0
    HIGH=0
    MEDIUM=0
    LOW=0

    FINDING_COUNT=0

    FINDING_LEVEL=()
    FINDING_TEXT=()
    FINDING_FIX=()

    [[ "$SSH_ROOT" == yes ]] &&
        add_finding \
            CRITICAL \
            'SSH root login is enabled' \
            'Review PermitRootLogin and apply your SSH hardening policy.'

    [[ "$SSH_PASSWORD" == yes ]] &&
        add_finding \
            HIGH \
            'SSH password authentication is enabled' \
            'Prefer key-based SSH authentication where appropriate.'

    [[ "$SSH_EMPTY_PASS" == yes ]] &&
        add_finding \
            CRITICAL \
            'SSH allows empty passwords' \
            'Set PermitEmptyPasswords no.'

    [[ "$SSH_PROTOCOL" == 1 ]] &&
        add_finding \
            HIGH \
            'SSH protocol 1 is enabled' \
            'Use SSH protocol 2 only.'

    [[ "$SELINUX" == Disabled ]] &&
        add_finding \
            HIGH \
            'SELinux is disabled' \
            'Enable SELinux according to distribution policy.'

    [[ "$SELINUX" == Permissive ]] &&
        add_finding \
            MEDIUM \
            'SELinux is permissive' \
            'Validate policies and move to enforcing.'

    case "$FIREWALL" in

        NONE)

            add_finding \
                HIGH \
                'No active host firewall detected' \
                'Enable a host firewall according to network policy.'

            ;;

        *_POLICY_ACCEPT)

            add_finding \
                MEDIUM \
                "Firewall rules detected but default policy appears permissive: $FIREWALL" \
                'Review INPUT/FORWARD policy and host firewall requirements.'

            ;;

    esac

    (( UID0_USERS > 1 )) &&
        add_finding \
            HIGH \
            "$UID0_USERS accounts have UID 0" \
            'Review and remove unnecessary UID 0 accounts.'

    if [[ -f /etc/shadow ]]; then

        local shadow_perm
        local shadow_owner

        shadow_perm="$(
            stat -c '%A' \
                /etc/shadow 2>/dev/null || true
        )"

        shadow_owner="$(
            stat -c '%U' \
                /etc/shadow 2>/dev/null || true
        )"

        [[ "$shadow_owner" != root ]] &&
            add_finding \
                HIGH \
                "/etc/shadow owner is ${shadow_owner:-UNKNOWN}" \
                'Review /etc/shadow ownership.'

        if [[ "$shadow_perm" == *o+r* ||
              "$shadow_perm" == *o+w* ||
              "$shadow_perm" == *g+w* ]]; then

            add_finding \
                HIGH \
                "/etc/shadow has insecure permissions: ${shadow_perm:-UNKNOWN}" \
                'Review /etc/shadow ownership and permissions.'
        fi
    fi

    (( SUDOERS_NOPASSWD > 0 )) &&
        add_finding \
            HIGH \
            "$SUDOERS_NOPASSWD sudoers entries contain NOPASSWD" \
            'Review sudoers and sudoers.d policies.'

    (( SSL_EXPIRED > 0 )) &&
        add_finding \
            CRITICAL \
            "$SSL_EXPIRED SSL certificate(s) are expired" \
            'Renew expired certificates immediately and verify service bindings.'

    (( SSL_EXPIRING > 0 )) &&
        add_finding \
            HIGH \
            "$SSL_EXPIRING SSL certificate(s) expire within 30 days" \
            'Renew certificates before expiration.'

    [[ "$NTP_SYNC" == UNSYNCED ]] &&
        add_finding \
            MEDIUM \
            'NTP is not synchronized' \
            'Configure and synchronize the system time source.'

    (( FAILED_SERVICES > 0 )) &&
        add_finding \
            MEDIUM \
            "$FAILED_SERVICES systemd services are failed" \
            'Review systemctl --failed and service logs.'

    (( ZOMBIE_PROCESSES > 5 )) &&
        add_finding \
            MEDIUM \
            "$ZOMBIE_PROCESSES zombie processes detected" \
            'Identify parent processes and correct application lifecycle.'

    (( ZOMBIE_PROCESSES > 0 &&
       ZOMBIE_PROCESSES <= 5 )) &&
        add_finding \
            LOW \
            "$ZOMBIE_PROCESSES zombie process(es) detected" \
            'Review parent processes of zombie tasks.'

    (( MEM_USAGE >= 95 )) &&
        add_finding \
            CRITICAL \
            "Memory critically high: ${MEM_USAGE}%" \
            'Identify top memory consumers.'

    (( MEM_USAGE >= 85 &&
       MEM_USAGE < 95 )) &&
        add_finding \
            HIGH \
            "Memory high: ${MEM_USAGE}%" \
            'Review memory pressure and workload behavior.'

    (( DISK_USAGE >= 95 )) &&
        add_finding \
            CRITICAL \
            "Root filesystem usage: ${DISK_USAGE}%" \
            'Identify large files or expand storage.'

    (( DISK_USAGE >= 85 &&
       DISK_USAGE < 95 )) &&
        add_finding \
            HIGH \
            "Root filesystem usage: ${DISK_USAGE}%" \
            'Review disk growth and capacity planning.'

    (( DISK_INODE_USAGE >= 95 )) &&
        add_finding \
            CRITICAL \
            "Root filesystem inode usage: ${DISK_INODE_USAGE}%" \
            'Identify excessive file count or inode exhaustion.'

    (( DISK_INODE_USAGE >= 85 &&
       DISK_INODE_USAGE < 95 )) &&
        add_finding \
            HIGH \
            "Root filesystem inode usage: ${DISK_INODE_USAGE}%" \
            'Review filesystem inode consumption.'

    (( SWAP_USAGE >= 80 )) &&
        add_finding \
            MEDIUM \
            "Swap usage high: ${SWAP_USAGE}%" \
            'Review memory pressure.'

    if awk \
        -v ratio="$LOAD_RATIO" \
        'BEGIN {exit !(ratio>=2.0)}'; then

        add_finding \
            HIGH \
            "Load pressure is high: load ${LOAD_AVG} (${LOAD_RATIO}x CPU capacity)" \
            'Identify CPU/I/O-bound workload and top processes.'

    elif awk \
        -v ratio="$LOAD_RATIO" \
        'BEGIN {exit !(ratio>=1.0)}'; then

        add_finding \
            MEDIUM \
            "Load pressure detected: load ${LOAD_AVG} (${LOAD_RATIO}x CPU capacity)" \
            'Review workload trend and system load.'
    fi

    finalize_score
}

add_finding() {

    local l="$1"
    local t="$2"
    local f="$3"

    FINDING_LEVEL[$FINDING_COUNT]="$l"
    FINDING_TEXT[$FINDING_COUNT]="$t"
    FINDING_FIX[$FINDING_COUNT]="$f"

    FINDING_COUNT=$((FINDING_COUNT + 1))

    case "$l" in

        CRITICAL)
            CRITICAL=$((CRITICAL + 1))
            SCORE=$((SCORE - 20))
            ;;

        HIGH)
            HIGH=$((HIGH + 1))
            SCORE=$((SCORE - 10))
            ;;

        MEDIUM)
            MEDIUM=$((MEDIUM + 1))
            SCORE=$((SCORE - 5))
            ;;

        LOW)
            LOW=$((LOW + 1))
            SCORE=$((SCORE - 2))
            ;;

    esac
}

finalize_score() {

    (( SCORE < 0 )) &&
        SCORE=0

    (( SCORE > 100 )) &&
        SCORE=100
}
