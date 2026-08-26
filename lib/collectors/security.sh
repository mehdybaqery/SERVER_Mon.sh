#!/usr/bin/env bash
# ================================================================
# SECURITY BASELINE
# ================================================================

collect_security_baseline() {

    local now
    local effective
    local sshd_rc=0

    now="$(now_epoch)"

    (( now - LAST_SECURITY_COLLECTION <
       SECURITY_INTERVAL )) &&
        return 0

    LAST_SECURITY_COLLECTION="$now"

    if have_cmd sshd; then

        if run_timeout 2s \
            systemctl is-active --quiet sshd 2>/dev/null; then

            SSH_STATUS=ACTIVE

        else
            SSH_STATUS=INACTIVE
        fi

        effective="$(
            run_timeout 4s \
                sshd -T 2>/dev/null
        )" || sshd_rc=$?

        if (( sshd_rc == 0 )) &&
           [[ -n "$effective" ]]; then

            SSH_PORT="$(
                printf '%s\n' "$effective" |
                awk '$1=="port"{print $2;exit}'
            )"

            SSH_ROOT="$(
                printf '%s\n' "$effective" |
                awk '$1=="permitrootlogin"{print $2;exit}'
            )"

            SSH_PASSWORD="$(
                printf '%s\n' "$effective" |
                awk '$1=="passwordauthentication"{print $2;exit}'
            )"

            SSH_PUBKEY="$(
                printf '%s\n' "$effective" |
                awk '$1=="pubkeyauthentication"{print $2;exit}'
            )"

            SSH_PROTOCOL="$(
                printf '%s\n' "$effective" |
                awk '$1=="protocol"{print $2;exit}'
            )"

            SSH_EMPTY_PASS="$(
                printf '%s\n' "$effective" |
                awk '$1=="permitemptypasswords"{print $2;exit}'
            )"

            [[ -z "$SSH_PORT" ]] &&
                SSH_PORT=22

            [[ -z "$SSH_PROTOCOL" ]] &&
                SSH_PROTOCOL=2

            [[ -z "$SSH_EMPTY_PASS" ]] &&
                SSH_EMPTY_PASS=no

        else

            SSH_PORT=UNKNOWN
            SSH_ROOT=UNKNOWN
            SSH_PASSWORD=UNKNOWN
            SSH_PUBKEY=UNKNOWN
            SSH_PROTOCOL=UNKNOWN
            SSH_EMPTY_PASS=UNKNOWN

        fi

    else

        SSH_STATUS='NOT INSTALLED'

    fi

    if have_cmd getenforce; then

        SELINUX="$(
            run_timeout 2s \
                getenforce 2>/dev/null || true
        )"

        [[ -z "$SELINUX" ]] &&
            SELINUX=UNKNOWN

    else

        SELINUX=N/A

    fi

    FIREWALL=UNKNOWN

    if run_timeout 2s \
        systemctl is-active --quiet firewalld 2>/dev/null; then

        FIREWALL=ACTIVE

    elif have_cmd ufw &&
         run_timeout 3s ufw status 2>/dev/null |
         grep -q 'Status: active'; then

        FIREWALL='UFW ACTIVE'

    elif have_cmd nft; then

        local nft_rules

        nft_rules="$(
            run_timeout 3s \
                nft list ruleset 2>/dev/null || true
        )"

        if grep -qE \
            '(^|[[:space:]])(drop|reject)([[:space:]]|$)' \
            <<<"$nft_rules"; then

            FIREWALL=NFTABLES

        elif [[ -n "$nft_rules" ]]; then

            FIREWALL=NFTABLES_POLICY_ACCEPT

        else
            FIREWALL=NONE
        fi

    elif have_cmd iptables; then

        local ipt_rules

        ipt_rules="$(
            run_timeout 3s \
                iptables -S 2>/dev/null || true
        )"

        if grep -qE \
            '(-j[[:space:]]+(DROP|REJECT)|-P[[:space:]]+(INPUT|FORWARD)[[:space:]]+(DROP|REJECT))' \
            <<<"$ipt_rules"; then

            FIREWALL=IPTABLES

        elif [[ -n "$ipt_rules" ]]; then

            FIREWALL=IPTABLES_POLICY_ACCEPT

        else
            FIREWALL=NONE
        fi

    else
        FIREWALL=NONE
    fi

    if have_cmd timedatectl; then

        local ntp_show

        ntp_show="$(
            run_timeout 3s \
                timedatectl show 2>/dev/null || true
        )"

        if grep -q 'NTPSynchronized=yes' <<<"$ntp_show"; then

            NTP_SYNC=SYNCED

        elif [[ -n "$ntp_show" ]]; then

            NTP_SYNC=UNSYNCED

        else

            NTP_SYNC=UNKNOWN
        fi

    elif have_cmd chronyc; then

        if run_timeout 3s \
            chronyc tracking 2>/dev/null |
            grep -qi 'Leap status.*Normal'; then

            NTP_SYNC=SYNCED

        else
            NTP_SYNC=UNSYNCED
        fi

    elif have_cmd ntpq; then

        if run_timeout 3s \
            ntpq -p 2>/dev/null |
            grep -q '^\*'; then

            NTP_SYNC=SYNCED

        else
            NTP_SYNC=UNSYNCED
        fi

    else

        NTP_SYNC=UNKNOWN

    fi

    SUDOERS_NOPASSWD="$(
        {
            grep -hE \
                '^[[:space:]]*[^#].*NOPASSWD' \
                /etc/sudoers 2>/dev/null || true

            if [[ -d /etc/sudoers.d ]]; then

                for f in /etc/sudoers.d/*; do

                    [[ -f "$f" ]] ||
                        continue

                    grep -hE \
                        '^[[:space:]]*[^#].*NOPASSWD' \
                        "$f" 2>/dev/null || true

                done

            fi

        } |
        wc -l
    )"

    [[ "$SUDOERS_NOPASSWD" =~ ^[0-9]+$ ]] ||
        SUDOERS_NOPASSWD=0

    collect_filesystems
}
