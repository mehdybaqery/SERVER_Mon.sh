#!/usr/bin/env bash
# ================================================================
# UI FUNCTIONS
# ================================================================

print_ascii_header() {

    (( QUIET_MODE )) &&
        return

    echo
    echo -e "${RED}${BOLD}"

    cat <<'ASCII'
 ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗
 ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗
 ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝
 ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗
 ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║
 ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝
ASCII

    echo -e "${RESET}${DARK_GRAY}${BOLD}                SERVER HEALTH MONITOR${RESET}"
    echo -e "${DARK_GRAY}                v${VERSION}${RESET}"
    echo
}

reset_screen() {

    (( QUIET_MODE || ONCE_MODE )) &&
        return

    printf '\033c'
}

pause() {

    (( ONCE_MODE )) &&
        return

    echo
    echo -e "${DARK_GRAY}────────────────────────────────────────────────────────────────${RESET}"
    echo -e "${GREEN}${BOLD}[ ENTER ]${RESET} Return to dashboard"

    read -r </dev/tty
}

intel_header() {

    reset_screen

    echo

    echo -e \
        "${RED}${BOLD}╔════════════════════════════════════════════════════════════════╗${RESET}"

    printf \
        "${RED}${BOLD}║${RESET} ${WHITE}${BOLD}%-62s${RESET}${RED}${BOLD}║${RESET}\n" \
        "$1"

    echo -e \
        "${RED}${BOLD}╚════════════════════════════════════════════════════════════════╝${RESET}"

    echo
}

intel_section() {

    echo -e "${CYAN}${BOLD}$1${RESET}"
    echo -e \
        "${DARK_GRAY}────────────────────────────────────────────────────────────────${RESET}"
}

hacker_progress() {

    (( QUIET_MODE || ONCE_MODE )) &&
        return

    local m="$1"
    local i

    printf ' %b[%b' "$CYAN" "$RESET"

    for (( i = 0; i < 30; i++ )); do

        printf \
            '%b━%b' \
            "$GREEN" \
            "$RESET"

        sleep 0.008
    done

    printf \
        '] %b%bOK%b\n' \
        "$GREEN" \
        "$BOLD" \
        "$RESET"

    printf \
        ' %b└─%b %s\n' \
        "$DARK_GRAY" \
        "$RESET" \
        "$m"
}

resource_bar() {

    local label="$1"
    local value="$2"
    local color="$3"
    local max_label="$4"
    local max_value="$5"

    local width=24
    local f
    local e

    f=$(( value * width / 100 ))
    e=$(( width - f ))

    (( f < 0 )) &&
        f=0

    (( e < 0 )) &&
        e=0

    printf \
        ' %b%b%-5s%b %b%3s%%%b ' \
        "$color" \
        "$BOLD" \
        "$label" \
        "$RESET" \
        "$WHITE" \
        "$value" \
        "$RESET"

    printf '%b' "$color"
    repeat_char '█' "$f"

    printf '%b' "$RESET"
    printf '%b' "$DARK_GRAY"

    repeat_char '░' "$e"

    printf '%b' "$RESET"

    if [[ -n "$max_label" &&
          -n "$max_value" ]]; then

        printf \
            "  ${DARK_GRAY}[Max: ${WHITE}%s${DARK_GRAY} ${VALUE}%s%%${DARK_GRAY}]${RESET}" \
            "$max_label" \
            "$max_value"
    fi

    echo
}

score_bar() {

    local v="$1"
    local w=30
    local f
    local e
    local c="$GREEN"

    f=$(( v * w / 100 ))
    e=$(( w - f ))

    (( f < 0 )) &&
        f=0

    (( e < 0 )) &&
        e=0

    (( v < 90 )) &&
        c="$YELLOW"

    (( v < 70 )) &&
        c="$ORANGE"

    (( v < 50 )) &&
        c="$RED"

    printf '%b[%b' \
        "$DARK_GRAY" \
        "$RESET"

    printf '%b' "$c"

    repeat_char '█' "$f"

    printf '%b' "$RESET"
    printf '%b' "$DARK_GRAY"

    repeat_char '░' "$e"

    printf '%b]' "$RESET"

    printf \
        ' %b%b%3s%%%b' \
        "$c" \
        "$BOLD" \
        "$v" \
        "$RESET"
}

score_status() {

    case "$(score_status_plain)" in

        HEALTHY)
            echo -e \
                "${GREEN}${BOLD}[●] HEALTHY${RESET}"
            ;;

        WARNING)
            echo -e \
                "${YELLOW}${BOLD}[▲] WARNING${RESET}"
            ;;

        RISK)
            echo -e \
                "${ORANGE}${BOLD}[◆] RISK${RESET}"
            ;;

        *)
            echo -e \
                "${RED}${BOLD}[■] CRITICAL${RESET}"
            ;;

    esac
}

risk_color() {

    case "$1" in

        CRITICAL)
            printf '%b' "$RED"
            ;;

        HIGH)
            printf '%b' "$ORANGE"
            ;;

        MEDIUM)
            printf '%b' "$YELLOW"
            ;;

        LOW)
            printf '%b' "$BLUE"
            ;;

        *)
            printf '%b' "$WHITE"
            ;;

    esac
}

process_bar() {

    local value="$1"
    local color="$2"

    local width=10
    local integer
    local f
    local e

    integer="${value%.*}"

    [[ "$integer" =~ ^[0-9]+$ ]] ||
        integer=0

    (( integer > 100 )) &&
        integer=100

    (( integer < 0 )) &&
        integer=0

    f=$(( integer * width / 100 ))

    (( integer > 0 &&
       f == 0 )) &&
        f=1

    e=$(( width - f ))

    printf '%b' "$color"

    repeat_char '█' "$f"

    printf '%b' "$DARK_GRAY"

    repeat_char '░' "$e"

    printf '%b' "$RESET"
}

metric_color() {

    local value="${1%.*}"

    [[ "$value" =~ ^[0-9]+$ ]] ||
        value=0

    if (( value >= 80 )); then

        printf '%b' "$RED"

    elif (( value >= 50 )); then

        printf '%b' "$ORANGE"

    else

        printf '%b' "$GREEN"

    fi
}

# ================================================================
# INTELLIGENCE SCREENS
# ================================================================

hacker_user_intel() {

    intel_header 'USER INTELLIGENCE & HOME DIRECTORIES'

    local -a users=()

    local n
    local uid
    local gid
    local gecos
    local home
    local shell

    while IFS=: read -r n _ uid gid gecos home shell; do

        if [[ "$n" == root ]]; then

            users+=("$n")

        elif (( uid >= 1000 )) &&
             [[ ! "$shell" =~ (nologin|false)$ ]] &&
             [[ -d "$home" ]]; then

            users+=("$n")
        fi

    done </etc/passwd

    if (( ${#users[@]} == 0 )); then

        echo -e "${RED}[!] No users found.${RESET}"

        pause
        return
    fi

    printf \
        '%b┌────────────┬────────┬──────────┬───────────────────────────┬─────────────┬──────────────┐%b\n' \
        "$DARK_GRAY" \
        "$RESET"

    printf \
        '%b│ USER       │ UID    │ GROUPS   │ HOME                      │ SHELL       │ SUDO?        │%b\n' \
        "$DARK_GRAY" \
        "$RESET"

    printf \
        '%b├────────────┼────────┼──────────┼───────────────────────────┼─────────────┼──────────────┤%b\n' \
        "$DARK_GRAY" \
        "$RESET"

    local u
    local info
    local pg
    local is_sudo
    local gname
    local members
    local member
    local sc
    local groups_display

    for u in "${users[@]}"; do

        info="$(
            awk \
                -F: \
                -v user="$u" \
                '$1==user{print;exit}' \
                /etc/passwd
        )"

        [[ -n "$info" ]] ||
            continue

        IFS=: read -r n _ uid gid gecos home shell <<<"$info"

        pg="$(
            awk \
                -F: \
                -v gid="$gid" \
                '$3==gid{print $1;exit}' \
                /etc/group
        )"

        is_sudo=0

        [[ "$pg" == sudo ||
           "$pg" == wheel ]] &&
            is_sudo=1

        if (( is_sudo == 0 )); then

            while IFS=: read -r gname _ _ members; do

                [[ "$gname" == sudo ||
                   "$gname" == wheel ]] ||
                    continue

                [[ -n "$members" ]] ||
                    continue

                IFS=',' read -ra member_array <<<"$members"

                for member in "${member_array[@]}"; do

                    [[ "$member" == "$u" ]] && {
                        is_sudo=1
                        break
                    }

                done

                (( is_sudo == 1 )) &&
                    break

            done </etc/group
        fi

        if (( is_sudo == 1 )); then
            sc="${GREEN}✓${RESET}"
        else
            sc="${RED}✗${RESET}"
        fi

        groups_display="${pg:-$gid}"

        printf \
            '%b│ %-10s │ %-6s │ %-8s │ %-25s │ %-11s │  %b  %b│%b\n' \
            "$DARK_GRAY" \
            "$(printf '%s' "$n" | cut -c1-10)" \
            "$uid" \
            "$(printf '%s' "$groups_display" | cut -c1-8)" \
            "$(printf '%s' "$home" | cut -c1-25)" \
            "$(basename "$shell" | cut -c1-11)" \
            "$sc" \
            "$DARK_GRAY" \
            "$RESET"

    done

    printf \
        '%b└────────────┴────────┴──────────┴───────────────────────────┴─────────────┴──────────────┘%b\n' \
        "$DARK_GRAY" \
        "$RESET"

    echo

    intel_section 'HOME DIRECTORY PERMISSIONS'

    if [[ -d /home ]]; then

        ls -lah /home/ 2>/dev/null |
        grep -v '^total' |
        while read -r l; do

            echo -e \
                " ${DARK_GRAY}→${RESET} $l"

        done

    else

        echo -e \
            " ${YELLOW}⚠ /home not found.${RESET}"

    fi

    echo

    intel_section 'RECENT LOGINS'

    if have_cmd lastlog; then

        run_timeout 10s \
            lastlog -t 30 2>/dev/null |
        tail -n +2 |
        head -50 |
        while read -r l; do

            echo -e \
                " ${DARK_GRAY}→${RESET} $l"

        done

    else

        echo -e \
            " ${YELLOW}⚠ lastlog unavailable.${RESET}"

    fi

    echo

    intel_section 'CURRENT LOGGED IN USERS'

    collect_logged_users

    echo -e \
        " ${WHITE}Count:${RESET} $LOGGED_COUNT"

    [[ "$LOGGED_USERS" != None ]] &&
        echo -e \
            " ${WHITE}Users:${RESET} $LOGGED_USERS"

    echo

    intel_section 'USER STATISTICS'

    echo -e \
        " ${WHITE}Total:${RESET} $TOTAL_USERS"

    echo -e \
        " ${WHITE}Login-Capable:${RESET} $LOGIN_USERS"

    echo -e \
        " ${WHITE}UID 0:${RESET} $UID0_USERS"

    echo -e \
        " ${WHITE}Locked:${RESET} $LOCKED_USERS"

    echo -e \
        " ${WHITE}Sudo/Wheel:${RESET} $SUDO_USERS"

    echo -e \
        " ${WHITE}Groups:${RESET} $TOTAL_GROUPS"

    pause
}

hacker_cron_intel() {

    intel_header 'CRONJOB INTELLIGENCE'

    intel_section 'SYSTEM CRONJOBS'

    if [[ -f /etc/crontab ]]; then

        grep -vE \
            '^[[:space:]]*(#|$)' \
            /etc/crontab 2>/dev/null |
        while read -r l; do

            echo -e \
                " ${DARK_GRAY}→${RESET} $l"

        done

    else

        echo -e \
            " ${DARK_GRAY}None found${RESET}"

    fi

    echo

    intel_section 'USER CRONJOBS'

    local f=0
    local u
    local cf
    local l
    local d

    while IFS=: read -r u _; do

        for cf in \
            "/var/spool/cron/$u" \
            "/var/spool/cron/crontabs/$u"; do

            [[ -f "$cf" ]] ||
                continue

            f=1

            echo -e \
                " ${GREEN}→${RESET} $u"

            grep -vE \
                '^[[:space:]]*(#|$)' \
                "$cf" 2>/dev/null |
            while read -r l; do

                echo -e \
                    "   ${DARK_GRAY}↳${RESET} $l"

            done

            break
        done

    done </etc/passwd

    (( f == 0 )) &&
        echo -e \
            " ${DARK_GRAY}No user cronjobs found${RESET}"

    echo

    intel_section 'CRON DIRECTORIES'

    for d in \
        /etc/cron.d \
        /etc/cron.daily \
        /etc/cron.hourly \
        /etc/cron.weekly \
        /etc/cron.monthly; do

        [[ -d "$d" ]] ||
            continue

        echo -e \
            " ${WHITE}$d:${RESET} $(
                find "$d" \
                    -mindepth 1 \
                    -maxdepth 1 \
                    -type f \
                    2>/dev/null |
                wc -l
            ) files"

    done

    pause
}

hacker_network_intel() {

    intel_header 'NETWORK INTELLIGENCE'

    intel_section 'ACTIVE CONNECTIONS'

    run_timeout 7s \
        ss -tunap 2>/dev/null |
    tail -n +2 |
    head -20 |
    while read -r l; do

        echo -e \
            " ${DARK_GRAY}→${RESET} $l"

    done

    echo

    intel_section 'LISTENING PORTS'

    run_timeout 7s \
        ss -lntup 2>/dev/null |
    tail -n +2 |
    head -50 |
    while read -r l; do

        echo -e \
            " ${DARK_GRAY}→${RESET} $l"

    done

    echo

    intel_section 'NETWORK INTERFACES'

    run_timeout 5s \
        ip -br addr 2>/dev/null |
    while read -r l; do

        echo -e \
            " ${DARK_GRAY}→${RESET} $l"

    done

    echo

    intel_section 'ROUTING TABLE'

    run_timeout 5s \
        ip route 2>/dev/null |
    while read -r l; do

        echo -e \
            " ${DARK_GRAY}→${RESET} $l"

    done

    echo

    intel_section 'DNS & HOSTS'

    echo -e \
        " ${WHITE}/etc/resolv.conf${RESET}"

    grep -v '^#' \
        /etc/resolv.conf 2>/dev/null |
    head -30 |
    while read -r l; do

        echo -e \
            "   ${DARK_GRAY}↳${RESET} $l"

    done

    echo -e \
        " ${WHITE}/etc/hosts${RESET}"

    grep -v '^#' \
        /etc/hosts 2>/dev/null |
    grep -v '^$' |
    head -50 |
    while read -r l; do

        echo -e \
            "   ${DARK_GRAY}↳${RESET} $l"

    done

    echo

    intel_section 'NTP'

    echo -e \
        " ${WHITE}Status:${RESET} $NTP_SYNC"

    pause
}

hacker_security_intel() {

    intel_header 'SECURITY & SENSITIVE FILES'

    audit_all

    intel_section 'SENSITIVE FILE PERMISSIONS'

    local file
    local p
    local o

    local files=(
        /etc/passwd
        /etc/shadow
        /etc/sudoers
        /etc/ssh/sshd_config
    )

    for file in "${files[@]}"; do

        if [[ -f "$file" ]]; then

            p="$(
                stat -c '%A' "$file" \
                    2>/dev/null || true
            )"

            o="$(
                stat -c '%U' "$file" \
                    2>/dev/null || true
            )"

            echo -e \
                " ${GREEN}→${RESET} $file"

            echo -e \
                "   ${DARK_GRAY}Permissions:${RESET} $p  ${DARK_GRAY}Owner:${RESET} $o"

        else

            echo -e \
                " ${YELLOW}→${RESET} $file ${DARK_GRAY}(not found)${RESET}"

        fi

    done

    echo

    intel_section 'SUID / SGID FILES'

    if (( SUID_FILES_COUNT > 0 )); then

        for file in "${SUID_FILES_CACHED[@]}"; do

            echo -e \
                " ${DARK_GRAY}→${RESET} $file"

        done

    else

        echo -e \
            " ${DARK_GRAY}No files found in bounded audit paths.${RESET}"

    fi

    echo

    intel_section 'SUDOERS NOPASSWD'

    if (( SUDOERS_NOPASSWD > 0 )); then

        echo -e \
            " ${RED}⚠ $SUDOERS_NOPASSWD entries${RESET}"

    else

        echo -e \
            " ${GREEN}✓ None found${RESET}"

    fi

    echo

    intel_section 'SSH CONFIGURATION'

    echo -e \
        " Port: $SSH_PORT"

    echo -e \
        " Root Login: $SSH_ROOT"

    echo -e \
        " Password Auth: $SSH_PASSWORD"

    echo -e \
        " Pubkey Auth: $SSH_PUBKEY"

    echo

    intel_section 'FIREWALL'

    echo -e \
        " Status: $FIREWALL"

    echo

    intel_section 'SELINUX'

    echo -e \
        " Status: $SELINUX"

    pause
}

hacker_logs_intel() {

    intel_header 'LOGS & ERROR ANALYSIS'

    audit_large_logs
    audit_failed_ssh

    intel_section 'RECENT SYSTEM ERRORS'

    local e=""

    if [[ -f /var/log/messages ]]; then

        e="$(
            tail -n 1000 \
                /var/log/messages 2>/dev/null |
            grep -i error |
            head -5
        )"

    elif have_cmd journalctl; then

        e="$(
            run_timeout 7s \
                journalctl \
                    -p err \
                    -n 10 \
                    2>/dev/null |
            tail -5
        )"
    fi

    if [[ -n "$e" ]]; then

        echo "$e" |
        while read -r l; do

            echo -e \
                " ${RED}→${RESET} $l"

        done

    else

        echo -e \
            " ${GREEN}→ none found${RESET}"

    fi

    echo

    intel_section 'SSH FAILED LOGINS'

    if [[ -n "$LOG_SSH_FAILED_CACHED" ]]; then

        echo "$LOG_SSH_FAILED_CACHED" |
        while read -r l; do

            echo -e \
                " ${RED}→${RESET} $l"

        done

    else

        echo -e \
            " ${GREEN}→ none found${RESET}"

    fi

    echo

    intel_section 'FAILED SYSTEMD SERVICES'

    run_timeout 7s \
        systemctl --failed \
        --type=service \
        --no-legend 2>/dev/null |
    head -20 |
    while read -r l; do

        echo -e \
            " ${RED}→${RESET} $l"

    done

    echo

    intel_section 'LARGE LOG FILES'

    if [[ -n "$LOG_BIG_FILES_CACHED" ]]; then

        echo "$LOG_BIG_FILES_CACHED" |
        while read -r l; do

            echo -e \
                " ${YELLOW}→${RESET} $l"

        done

    else

        echo -e \
            " ${GREEN}→ none found${RESET}"

    fi

    echo

    intel_section 'LAST BOOT LOGS'

    run_timeout 7s \
        journalctl -b -n 5 2>/dev/null |
    tail -5 |
    while read -r l; do

        echo -e \
            " ${DARK_GRAY}→${RESET} $l"

    done

    pause
}

hacker_hardware_intel() {

    intel_header 'HARDWARE INTELLIGENCE'

    intel_section 'CPU'

    echo -e \
        " Model: $CPU_MODEL"

    echo -e \
        " Cores: $CPU_CORES"

    echo -e \
        " Max Frequency: ${CPU_FREQ}MHz"

    echo

    intel_section 'MEMORY'

    echo -e \
        " Total: ${TOTAL_RAM_MB}MB"

    echo -e \
        " Used: $((TOTAL_RAM_MB * MEM_USAGE / 100))MB (${MEM_USAGE}%)"

    echo

    intel_section 'DISK'

    echo -e \
        " Model: $DISK_MODEL"

    echo -e \
        " Size: $DISK_SIZE"

    echo -e \
        " Usage: ${DISK_USAGE}%"

    echo

    intel_section 'PARTITIONS'

    df -h 2>/dev/null |
    head -10 |
    while read -r l; do

        echo -e \
            " ${DARK_GRAY}→${RESET} $l"

    done

    echo

    intel_section 'INODES'

    df -i 2>/dev/null |
    head -10 |
    while read -r l; do

        echo -e \
            " ${DARK_GRAY}→${RESET} $l"

    done

    echo

    intel_section 'VIRTUALIZATION'

    echo -e \
        " Type: $VIRTUALIZATION"

    pause
}

hacker_package_intel() {

    intel_header 'PACKAGE UPDATES'

    intel_section 'AVAILABLE UPDATES'

    echo -e \
        " ${YELLOW}Package repository checks are disabled in LIVE production mode.${RESET}"

    echo -e \
        " ${DARK_GRAY}No dnf/yum/apt network query was executed.${RESET}"

    echo -e \
        " ${DARK_GRAY}Use the normal change-management/package-audit process.${RESET}"

    echo

    intel_section 'INSTALLED PACKAGES'

    if have_cmd rpm; then

        run_timeout 7s \
            rpm -qa 2>/dev/null |
        head -10 |
        while read -r l; do

            echo -e \
                " ${DARK_GRAY}→${RESET} $l"

        done

    elif have_cmd dpkg-query; then

        run_timeout 7s \
            dpkg-query \
            -W \
            -f='${binary:Package}\n' \
            2>/dev/null |
        head -10 |
        while read -r l; do

            echo -e \
                " ${DARK_GRAY}→${RESET} $l"

        done

    fi

    pause
}

hacker_container_intel() {

    intel_header 'CONTAINER & KUBERNETES INTEL'

    collect_container_status

    intel_section 'DOCKER'

    echo -e \
        " Status: $DOCKER_STATUS"

    echo -e \
        " Running: $DOCKER_CONTAINERS"

    echo -e \
        " Images: $DOCKER_IMAGES"

    echo -e \
        " Volumes: $DOCKER_VOLUMES"

    if (( DOCKER_CONTAINERS > 0 )) &&
       have_cmd docker; then

        echo

        run_timeout 5s \
            docker ps 2>/dev/null |
        tail -n +2 |
        head -10 |
        while read -r l; do

            echo -e \
                " ${DARK_GRAY}→${RESET} $l"

        done
    fi

    echo

    intel_section 'KUBERNETES'

    if (( K8S_FOUND == 1 )); then

        echo -e \
            " Status: ${GREEN}Detected${RESET}"

        echo -e \
            " Nodes: $K8S_NODES"

        echo -e \
            " Pods: $K8S_PODS"

        echo -e \
            " Services: $K8S_SERVICES"

        echo -e \
            " Kubelet: $KUBELET_STATUS"

    else

        echo -e \
            " Status: ${DARK_GRAY}Not detected${RESET}"

    fi

    echo

    intel_section 'CONTAINERD'

    echo -e \
        " Status: $CONTAINERD_STATUS"

    pause
}

hacker_ssl_intel() {

    intel_header 'SSL CERTIFICATE INTELLIGENCE'

    # Force refresh for interactive SSL screen.
    LAST_SSL_COLLECTION=0
    collect_ssl_safe

    intel_section 'CERTIFICATES'

    local found=0
    local cert
    local exp
    local epoch
    local now
    local days

    local -a cert_paths=(
        /etc/letsencrypt/live/*/fullchain.pem
        /etc/nginx/ssl/*.crt
        /etc/apache2/ssl/*.crt
        /etc/pki/tls/certs/*.pem
    )

    now="$(date +%s)"

    if have_cmd openssl; then

        for cert in "${cert_paths[@]}"; do

            [[ -f "$cert" ]] ||
                continue

            found=1

            echo -e \
                " ${GREEN}→${RESET} $cert"

            exp="$(
                run_timeout 2s \
                    openssl x509 \
                    -enddate \
                    -noout \
                    -in "$cert" 2>/dev/null |
                cut -d= -f2
            )"

            epoch="$(
                date -d "$exp" +%s 2>/dev/null || true
            )"

            if [[ "$epoch" =~ ^[0-9]+$ ]]; then

                days=$(( (epoch - now) / 86400 ))

                if (( days < 0 )); then

                    echo -e \
                        " ${RED}EXPIRED${RESET}"

                elif (( days < 30 )); then

                    echo -e \
                        " ${YELLOW}Expires in $days days${RESET}"

                else

                    echo -e \
                        " ${GREEN}Expires in $days days${RESET}"

                fi
            fi
        done
    fi

    (( found == 0 )) &&
        echo -e \
            " ${DARK_GRAY}No application certificates found.${RESET}"

    echo

    intel_section 'SUMMARY'

    echo -e \
        " Found: $SSL_CERTS_COUNT"

    echo -e \
        " Expiring soon: $SSL_EXPIRING"

    echo -e \
        " Expired: $SSL_EXPIRED"

    pause
}

# ================================================================
# DISCOVERY
# ================================================================

hacker_discovery() {

    reset_screen

    print_ascii_header

    echo -e \
        "${DARK_GRAY}╔════════════════════════════════════════════════════════════════╗${RESET}"

    printf \
        "${DARK_GRAY}║${RESET} ${RED}${BOLD}TARGET${RESET}  : ${WHITE}%-50s${RESET}${DARK_GRAY}║${RESET}\n" \
        "$HOSTNAME"

    printf \
        "${DARK_GRAY}║${RESET} ${RED}${BOLD}ADDRESS${RESET} : ${WHITE}%-50s${RESET}${DARK_GRAY}║${RESET}\n" \
        "$PRIMARY_IP"

    printf \
        "${DARK_GRAY}║${RESET} ${RED}${BOLD}STATUS${RESET}  : ${GREEN}${BOLD}%-50s${RESET}${DARK_GRAY}║${RESET}\n" \
        'ONLINE / ALIVE'

    echo -e \
        "${DARK_GRAY}╚════════════════════════════════════════════════════════════════╝${RESET}"

    echo

    echo -e \
        "${ACCENT}${BOLD}SCAN INITIALIZATION${RESET}"

    hacker_progress "OS: $OS_NAME"
    hacker_progress "Kernel: $KERNEL"
    hacker_progress "Architecture: $ARCH"
    hacker_progress "Virtualization: $VIRTUALIZATION"
    hacker_progress "CPU: $CPU_MODEL ($CPU_CORES cores)"
    hacker_progress "RAM: ${TOTAL_RAM_MB}MB"

    echo

    echo -e \
        "${GREEN}${BOLD}[✓] INITIAL SCAN COMPLETE${RESET}"

    (( QUIET_MODE || ONCE_MODE )) ||
        sleep 0.4
}

hacker_details() {

    reset_screen

    intel_header 'DETAILED HEALTH REPORT'

    echo -ne \
        "${WHITE}${BOLD}SECURITY SCORE${RESET}   "

    score_bar "$SCORE"

    echo -e \
        "   $(score_status)"

    echo

    printf \
        ' CRITICAL %s | HIGH %s | MEDIUM %s | LOW %s\n' \
        "$CRITICAL" \
        "$HIGH" \
        "$MEDIUM" \
        "$LOW"

    echo

    if (( FINDING_COUNT == 0 )); then

        echo -e \
            "${GREEN}[✓] No active findings.${RESET}"

    else

        local i

        for (( i = 0; i < FINDING_COUNT; i++ )); do

            echo -e \
                "${DARK_GRAY}┌────────────────────────────────────────────────────────────────┐${RESET}"

            echo -e \
                " ${RED}${BOLD}${FINDING_LEVEL[$i]}${RESET} #$((i+1))"

            echo -e \
                " ${WHITE}${FINDING_TEXT[$i]}${RESET}"

            echo -e \
                " ${GREEN}FIX:${RESET} ${FINDING_FIX[$i]}"

            echo -e \
                "${DARK_GRAY}└────────────────────────────────────────────────────────────────┘${RESET}"

            echo
        done
    fi

    intel_section 'SYSTEM INTELLIGENCE'

    printf \
        ' Users: %s (login:%s root:%s locked:%s sudo:%s)\n' \
        "$TOTAL_USERS" \
        "$LOGIN_USERS" \
        "$UID0_USERS" \
        "$LOCKED_USERS" \
        "$SUDO_USERS"

    printf \
        ' Processes: %s (zombies:%s threads:%s)\n' \
        "$TOTAL_PROCESSES" \
        "$ZOMBIE_PROCESSES" \
        "$TOTAL_THREADS"

    printf \
        ' Network: listen:%s established:%s tcp:%s udp:%s\n' \
        "$LISTEN_PORTS" \
        "$ESTABLISHED" \
        "$TCP_CONNS" \
        "$UDP_CONNS"

    printf \
        ' Containers: Docker:%s | Containerd:%s | Kubelet:%s\n' \
        "$DOCKER_CONTAINERS" \
        "$CONTAINERD_STATUS" \
        "$KUBELET_STATUS"

    printf \
        ' SSL: %s found | %s expiring | %s expired\n' \
        "$SSL_CERTS_COUNT" \
        "$SSL_EXPIRING" \
        "$SSL_EXPIRED"

    printf \
        ' Cronjobs: %s | Updates: %s | NTP: %s\n' \
        "$CRON_ENTRIES" \
        "$PACKAGE_UPDATES" \
        "$NTP_SYNC"

    echo -e \
        "${MUTED}Log: $LOG_FILE${RESET}"

    pause
}

# ================================================================
# DASHBOARD
# ================================================================

hacker_dashboard() {

    (( QUIET_MODE )) &&
        return 0

    local key

    while true; do

        collect_resources
        collect_processes
        collect_top_processes
        collect_top_summary
        collect_logged_users
        collect_network
        collect_services
        collect_users
        collect_crons
        collect_security_baseline
        collect_container_status
        collect_ssl_safe
        analyze_security_light
        log_cycle
        rotate_logs

        reset_screen
        print_ascii_header

        local host_ui
        local ip_ui
        local role_ui
        local os_ui
        local kernel_ui
        local arch_ui
        local uptime_ui
        local virt_ui

        host_ui="$(
            truncate_text "$HOSTNAME" 18
        )"

        ip_ui="$(
            truncate_text "$PRIMARY_IP" 15
        )"

        role_ui="$(
            truncate_text "$SERVER_ROLE" 44
        )"

        os_ui="$(
            truncate_text "$OS_NAME" 20
        )"

        kernel_ui="$(
            truncate_text "$KERNEL" 18
        )"

        arch_ui="$(
            truncate_text "$ARCH" 8
        )"

        uptime_ui="$(
            truncate_text "$UPTIME" 16
        )"

        virt_ui="$(
            truncate_text "$VIRTUALIZATION" 10
        )"

        echo -e \
            "${DARK_GRAY}╔════════════════════════════════════════════════════════════════╗${RESET}"

        box_row \
            "HOST     : $host_ui    |    IP      : $ip_ui"

        box_row \
            "ROLE     : $role_ui"

        box_row \
            "OS       : $os_ui"

        box_row \
            "KERNEL   : $kernel_ui    |    ARCH    : $arch_ui"

        box_row \
            "UPTIME   : $uptime_ui  |    VIRT    : $virt_ui"

        box_row \
            "NTP      : $NTP_SYNC   |    SELINUX : $SELINUX"

        box_row \
            "FIREWALL : $FIREWALL  |    SSH     : $SSH_STATUS"

        box_row \
            "RESOURCES: CPU $CPU_USAGE%  |  RAM $MEM_USAGE%  |  DISK $DISK_USAGE%"

        echo -e \
            "${DARK_GRAY}╚════════════════════════════════════════════════════════════════╝${RESET}"

        echo

        if (( SHOW_TOP_MODE == 1 )); then

            echo -e \
                " ${YELLOW}${BOLD}⚠ SHOW-TOP MODE ACTIVE: Resource values reflect top process, not system totals${RESET}"

            echo
        fi

        echo -e \
            "${RED}${BOLD} SECURITY SCORE${RESET}"

        echo -e \
            "${DARK_GRAY}────────────────────────────────────────────────────────────────${RESET}"

        score_bar "$SCORE"

        echo -e \
            " ${DARK_GRAY}|${RESET} $(score_status)"

        printf \
            " ${RED}${BOLD}■${RESET} ${RED}CRITICAL %-2s${RESET}   " \
            "$CRITICAL"

        printf \
            "${ORANGE}${BOLD}▲${RESET} ${ORANGE}HIGH %-2s${RESET}   " \
            "$HIGH"

        printf \
            "${YELLOW}${BOLD}●${RESET} ${YELLOW}MEDIUM %-2s${RESET}   " \
            "$MEDIUM"

        printf \
            "${BLUE}${BOLD}·${RESET} ${BLUE}LOW %-2s${RESET}\n" \
            "$LOW"

        echo

        echo -e \
            "${CYAN}${BOLD} RESOURCE MONITOR${RESET}"

        echo -e \
            "${DARK_GRAY}────────────────────────────────────────────────────────────────${RESET}"

        resource_bar \
            "CPU" \
            "$CPU_USAGE" \
            "$GREEN" \
            "$TOP_CPU_PROC" \
            "$TOP_CPU_VAL"

        resource_bar \
            "RAM" \
            "$MEM_USAGE" \
            "$YELLOW" \
            "$TOP_RAM_PROC" \
            "$TOP_RAM_VAL"

        resource_bar \
            "SWAP" \
            "$SWAP_USAGE" \
            "$MAGENTA" \
            "" \
            ""

        resource_bar \
            "DISK" \
            "$DISK_USAGE" \
            "$RED" \
            "" \
            ""

        printf \
            " ${BLUE}${BOLD}LOAD ${RESET}${WHITE}%s${RESET}\n" \
            "$LOAD_AVG"

        echo

        echo -e \
            "${RED}${BOLD} ACTIVE FINDINGS ${RESET}${DARK_GRAY}($FINDING_COUNT)${RESET}"

        echo -e \
            "${DARK_GRAY}────────────────────────────────────────────────────────────────${RESET}"

        if (( FINDING_COUNT == 0 )); then

            echo -e \
                " ${GREEN}${BOLD}[✓]${RESET} ${GREEN}No active threats detected.${RESET}"

        else

            local i
            local riskc
            local icon
            local iconc

            for (( i = 0;
                   i < FINDING_COUNT && i < 5;
                   i++ )); do

                riskc="$(
                    risk_color "${FINDING_LEVEL[$i]}"
                )"

                case "${FINDING_LEVEL[$i]}" in

                    CRITICAL)
                        icon='■'
                        iconc="$RED"
                        ;;

                    HIGH)
                        icon='▲'
                        iconc="$ORANGE"
                        ;;

                    MEDIUM)
                        icon='●'
                        iconc="$YELLOW"
                        ;;

                    LOW)
                        icon='·'
                        iconc="$BLUE"
                        ;;

                    *)
                        icon='•'
                        iconc="$WHITE"
                        ;;

                esac

                printf \
                    ' %b%b%s%b %b%-9s%b %s\n' \
                    "$iconc" \
                    "$BOLD" \
                    "$icon" \
                    "$RESET" \
                    "$riskc" \
                    "${FINDING_LEVEL[$i]}" \
                    "$RESET" \
                    "${FINDING_TEXT[$i]}"

            done

            (( FINDING_COUNT > 5 )) &&
                echo -e \
                    " ${DARK_GRAY}└─ ... $((FINDING_COUNT-5)) more — press D for details${RESET}"
        fi

        echo

        echo -e \
            "${CYAN}${BOLD} TOP PROCESSES${RESET}"

        echo -e \
            "${DARK_GRAY}────────────────────────────────────────────────────────────────${RESET}"

        echo -e \
            " ${DARK_GRAY}PID     USER         CPU%   CPU LOAD      RAM%   RAM LOAD     COMMAND${RESET}"

        echo -e \
            " ${DARK_GRAY}------- ---------- ------  ----------   ------  ----------   ------------------${RESET}"

        while read -r pid user cpu mem comm; do

            [[ -n "$pid" ]] ||
                continue

            local cpu_color
            local mem_color

            cpu_color="$(
                metric_color "$cpu"
            )"

            mem_color="$(
                metric_color "$mem"
            )"

            printf \
                ' %-7s %-10s %b%6s%%%b  ' \
                "$pid" \
                "$user" \
                "$cpu_color" \
                "$cpu" \
                "$RESET"

            process_bar \
                "$cpu" \
                "$cpu_color"

            printf \
                '  %b%6s%%%b  ' \
                "$mem_color" \
                "$mem" \
                "$RESET"

            process_bar \
                "$mem" \
                "$mem_color"

            printf \
                ' %-18s\n' \
                "$(printf '%s' "$comm" | cut -c1-18)"

        done <<<"$TOP_PROCESS_CACHE"

        echo

        echo -e \
            "${CYAN}${BOLD} QUICK STATUS${RESET}"

        echo -e \
            "${DARK_GRAY}────────────────────────────────────────────────────────────────${RESET}"

        local ssh_color="$GREEN"
        local sel_color="$GREEN"
        local fw_color="$GREEN"

        [[ "$SSH_ROOT" == yes ]] &&
            ssh_color="$RED"

        [[ "$SELINUX" != Enforcing ]] &&
            sel_color="$YELLOW"

        [[ "$FIREWALL" == NONE ||
           "$FIREWALL" == *_POLICY_ACCEPT ]] &&
            fw_color="$RED"

        printf \
            " ${WHITE}SSH${RESET} ${VALUE}%-10s${RESET}   ${WHITE}RootLogin${RESET} %b%-7s%b   ${WHITE}SELinux${RESET} %b%-10s%b   ${WHITE}Firewall${RESET} %b%-18s%b\n" \
            "$SSH_STATUS" \
            "$ssh_color" \
            "$SSH_ROOT" \
            "$RESET" \
            "$sel_color" \
            "$SELINUX" \
            "$RESET" \
            "$fw_color" \
            "$FIREWALL" \
            "$RESET"

        printf \
            " ${WHITE}Users${RESET} %-4s  ${DARK_GRAY}(login:%-2s root:%-2s sudo:%-2s)${RESET}   ${WHITE}Processes${RESET} %-5s   ${WHITE}Zombies${RESET} %-3s   ${WHITE}Cron${RESET} %-3s   ${WHITE}Updates${RESET} %-3s\n" \
            "$TOTAL_USERS" \
            "$LOGIN_USERS" \
            "$UID0_USERS" \
            "$SUDO_USERS" \
            "$TOTAL_PROCESSES" \
            "$ZOMBIE_PROCESSES" \
            "$CRON_ENTRIES" \
            "$PACKAGE_UPDATES"

        printf \
            " ${WHITE}Docker${RESET} %-3s containers   ${WHITE}K8s${RESET} %-3s nodes / %-3s pods   ${WHITE}Logged${RESET} %-2s   ${WHITE}SSL${RESET} %-2s certs" \
            "$DOCKER_CONTAINERS" \
            "$K8S_NODES" \
            "$K8S_PODS" \
            "$LOGGED_COUNT" \
            "$SSL_CERTS_COUNT"

        (( SSL_EXPIRING > 0 )) &&
            printf \
                " ${YELLOW}(%s expiring)${RESET}" \
                "$SSL_EXPIRING"

        (( SSL_EXPIRED > 0 )) &&
            printf \
                " ${RED}(%s expired)${RESET}" \
                "$SSL_EXPIRED"

        echo
        echo

        echo -e \
            "${RED}${BOLD} SERVER HEALTH MONITOR${RESET} ${DARK_GRAY}|${RESET} ${GREEN}${BOLD}● LIVE${RESET} ${DARK_GRAY}$(date '+%H:%M:%S')${RESET}"

        echo -e \
            "${DARK_GRAY}════════════════════════════════════════════════════════════════${RESET}"

        echo -e \
            " ${GREEN}[R]${RESET} Rescan   ${BLUE}[U]${RESET} Users   ${BLUE}[C]${RESET} Cron   ${BLUE}[N]${RESET} Network   ${BLUE}[S]${RESET} Security"

        echo -e \
            " ${BLUE}[L]${RESET} Logs     ${BLUE}[H]${RESET} Hardware   ${BLUE}[P]${RESET} Packages   ${BLUE}[K]${RESET} K8s/Docker   ${BLUE}[X]${RESET} SSL"

        printf \
            " ${BLUE}[D]${RESET} Details   %b[Q]%b Quit\n" \
            "$RED$BOLD" \
            "$RESET"

        echo -e \
            "${DARK_GRAY}────────────────────────────────────────────────────────────────${RESET}"

        read -r \
            -t "$INTERVAL" \
            -n 1 \
            key </dev/tty ||
            key=''

        case "$key" in

            U|u)
                hacker_user_intel
                ;;

            C|c)
                hacker_cron_intel
                ;;

            N|n)
                hacker_network_intel
                ;;

            S|s)
                hacker_security_intel
                ;;

            L|l)
                hacker_logs_intel
                ;;

            H|h)
                hacker_hardware_intel
                ;;

            P|p)
                hacker_package_intel
                ;;

            K|k)
                hacker_container_intel
                ;;

            X|x)
                hacker_ssl_intel
                ;;

            D|d)
                hacker_details
                ;;

            R|r)

                LAST_NETWORK_COLLECTION=0
                LAST_SERVICE_COLLECTION=0
                LAST_USER_COLLECTION=0
                LAST_SECURITY_COLLECTION=0
                LAST_TOP_PROCESS_COLLECTION=0
                LAST_SSL_COLLECTION=0
                LAST_FILESYSTEM_COLLECTION=0
                LAST_CRON_COLLECTION=0
                LAST_PROCESS_COLLECTION=0
                LAST_CONTAINER_COLLECTION=0

                continue
                ;;

            Q|q)

                echo -e \
                    "\n${GREEN}${BOLD}[✓] Exiting. Stay secure.${RESET}"

                generate_json
                generate_html

                (( TELEGRAM_MODE )) &&
                    send_telegram_alert

                exit 0
                ;;

        esac
    done
}
