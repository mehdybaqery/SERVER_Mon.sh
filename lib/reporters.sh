#!/usr/bin/env bash
# ================================================================
# REPORTERS
# ================================================================

log_cycle() {

    printf \
        '%s SCORE=%s CPU=%s MEM=%s SWAP=%s DISK=%s INODE=%s LOAD=%s LOAD_RATIO=%s FINDINGS=%s\n' \
        "$(date '+%F %T')" \
        "$SCORE" \
        "$CPU_USAGE" \
        "$MEM_USAGE" \
        "$SWAP_USAGE" \
        "$DISK_USAGE" \
        "$DISK_INODE_USAGE" \
        "$LOAD_AVG" \
        "$LOAD_RATIO" \
        "$FINDING_COUNT" \
        >>"$LOG_FILE" 2>/dev/null ||
        true
}

rotate_logs() {

    [[ -d "$LOG_DIR" ]] ||
        return 0

    find "$LOG_DIR" \
        -type f \
        \( \
            -name 'health_*.log' \
            -o -name 'health_*.json' \
            -o -name 'health_*.html' \
        \) \
        -mtime +"$LOG_RETENTION_DAYS" \
        -delete 2>/dev/null ||
        true
}

generate_json() {

    local tmp_file="${JSON_FILE}.tmp.$$"

    {
        cat <<EOF2
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(json_escape "$HOSTNAME")",
  "version": "$VERSION",
  "score": $SCORE,
  "status": "$(score_status_plain)",
  "show_top_mode": $SHOW_TOP_MODE,
  "resources": {
    "cpu": $CPU_USAGE,
    "memory": $MEM_USAGE,
    "swap": $SWAP_USAGE,
    "disk": $DISK_USAGE,
    "inode": $DISK_INODE_USAGE,
    "load": "$(json_escape "$LOAD_AVG")",
    "load_ratio": "$(json_escape "$LOAD_RATIO")"
  },
  "users": {
    "total": $TOTAL_USERS,
    "login_capable": $LOGIN_USERS,
    "root": $UID0_USERS,
    "locked": $LOCKED_USERS,
    "sudoers": $SUDO_USERS,
    "groups": $TOTAL_GROUPS,
    "names": "$(json_escape "$USER_NAMES_LIST")"
  },
  "logged_users": {
    "count": $LOGGED_COUNT,
    "users": "$(json_escape "$LOGGED_USERS")"
  },
  "processes": {
    "total": $TOTAL_PROCESSES,
    "zombies": $ZOMBIE_PROCESSES,
    "threads": $TOTAL_THREADS
  },
  "network": {
    "listening_ports": $LISTEN_PORTS,
    "established": $ESTABLISHED,
    "tcp_connections": $TCP_CONNS,
    "udp_connections": $UDP_CONNS
  },
  "security": {
    "ssh_status": "$(json_escape "$SSH_STATUS")",
    "ssh_port": "$(json_escape "$SSH_PORT")",
    "ssh_root_login": "$(json_escape "$SSH_ROOT")",
    "ssh_password_auth": "$(json_escape "$SSH_PASSWORD")",
    "ssh_empty_pass": "$(json_escape "$SSH_EMPTY_PASS")",
    "ssh_protocol": "$(json_escape "$SSH_PROTOCOL")",
    "selinux": "$(json_escape "$SELINUX")",
    "firewall": "$(json_escape "$FIREWALL")",
    "ntp_sync": "$(json_escape "$NTP_SYNC")",
    "sudoers_nopasswd": $SUDOERS_NOPASSWD,
    "ssl_expiring": $SSL_EXPIRING,
    "ssl_expired": $SSL_EXPIRED
  },
  "services": {
    "docker": "$(json_escape "$DOCKER_STATUS")",
    "containerd": "$(json_escape "$CONTAINERD_STATUS")",
    "kubelet": "$(json_escape "$KUBELET_STATUS")"
  },
  "containers": {
    "docker_containers": $DOCKER_CONTAINERS,
    "docker_images": "$(json_escape "$DOCKER_IMAGES")",
    "docker_volumes": "$(json_escape "$DOCKER_VOLUMES")",
    "k8s_nodes": "$(json_escape "$K8S_NODES")",
    "k8s_pods": "$(json_escape "$K8S_PODS")",
    "k8s_services": "$(json_escape "$K8S_SERVICES")"
  },
  "hardware": {
    "cpu_model": "$(json_escape "$CPU_MODEL")",
    "cpu_cores": $CPU_CORES,
    "cpu_freq_mhz": $CPU_FREQ,
    "total_ram_mb": $TOTAL_RAM_MB,
    "disk_model": "$(json_escape "$DISK_MODEL")",
    "disk_size": "$(json_escape "$DISK_SIZE")"
  },
  "system": {
    "os": "$(json_escape "$OS_NAME")",
    "kernel": "$(json_escape "$KERNEL")",
    "arch": "$(json_escape "$ARCH")",
    "virtualization": "$(json_escape "$VIRTUALIZATION")",
    "uptime": "$(json_escape "$UPTIME")",
    "role": "$(json_escape "$SERVER_ROLE")",
    "cronjobs": $CRON_ENTRIES,
    "package_updates": "$(json_escape "$PACKAGE_UPDATES")"
  },
  "findings": [
EOF2

        local i

        for (( i = 0; i < FINDING_COUNT; i++ )); do

            (( i > 0 )) &&
                printf ',\n'

            printf \
                '    {"level":"%s","text":"%s","fix":"%s"}' \
                "$(json_escape "${FINDING_LEVEL[$i]}")" \
                "$(json_escape "${FINDING_TEXT[$i]}")" \
                "$(json_escape "${FINDING_FIX[$i]}")"

        done

        cat <<EOF2
  ],
  "findings_count": $FINDING_COUNT
}
EOF2

    } >"$tmp_file" 2>/dev/null ||
    {
        rm -f -- "$tmp_file" 2>/dev/null || true
        return 1
    }

    chmod 640 "$tmp_file" 2>/dev/null || true

    mv -f -- "$tmp_file" "$JSON_FILE" 2>/dev/null ||
    {
        rm -f -- "$tmp_file" 2>/dev/null || true
        return 1
    }

    if have_cmd jq; then

        jq empty "$JSON_FILE" >/dev/null 2>&1 ||
            return 1

    fi

    (( JSON_MODE )) &&
        cat "$JSON_FILE"
}

generate_html() {

    local cls=score-healthy

    (( SCORE < 90 )) &&
        cls=score-warning

    (( SCORE < 50 )) &&
        cls=score-critical

    local tmp_file="${HTML_FILE}.tmp.$$"

    {
        cat <<EOF2
<!doctype html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Server Health Monitor - $(html_escape "$HOSTNAME")</title>

<style>
body{
    font-family:Consolas,"Courier New",monospace;
    background:#090909;
    color:#ddd;
    padding:24px
}
.container{
    max-width:1200px;
    margin:auto;
    background:#111;
    border:1px solid #2c2c2c;
    border-radius:12px;
    padding:28px
}
h1{
    text-align:center;
    color:#ff4444
}
.meta{
    text-align:center;
    color:#777
}
.score{
    font-size:48px;
    font-weight:700;
    text-align:center;
    padding:20px;
    background:#161616;
    border-radius:10px;
    margin:20px 0
}
.score-healthy{
    color:#00d26a
}
.score-warning{
    color:#ffaa00
}
.score-critical{
    color:#ff4242
}
.section{
    margin-top:20px;
    padding:16px;
    background:#0d0d0d;
    border:1px solid #252525;
    border-left:3px solid #00d26a;
    border-radius:8px
}
table{
    width:100%;
    border-collapse:collapse
}
td,th{
    border-bottom:1px solid #2a2a2a;
    padding:9px;
    text-align:left
}
th{
    color:#00d26a
}
.critical{
    color:#ff4242
}
.high{
    color:#ff7a00
}
.medium{
    color:#ffd24a
}
.low{
    color:#45b7ff
}
.ok{
    color:#00d26a
}
.footer{
    text-align:center;
    color:#666;
    font-size:12px;
    margin-top:28px
}
.warning-box{
    background:#2a1a00;
    border-left:4px solid #ffaa00;
    padding:10px;
    margin:10px 0;
    color:#ffaa00
}
</style>

</head>

<body>

<div class="container">

<h1>SERVER HEALTH MONITOR</h1>

<div class="meta">
v$VERSION |
$(html_escape "$HOSTNAME") |
$(date '+%Y-%m-%d %H:%M:%S')
</div>

EOF2

        if (( SHOW_TOP_MODE == 1 )); then
            echo '<div class="warning-box">⚠ SHOW-TOP MODE ACTIVE: Resource values reflect top process, not system totals</div>'
        fi

        cat <<EOF2

<div class="score $cls">
SCORE: $SCORE/100
</div>

<div class="section">
<h2>Summary</h2>

<table>
<tr><td>Status</td><td>$(score_status_plain)</td></tr>
<tr><td>Critical</td><td class="critical">$CRITICAL</td></tr>
<tr><td>High</td><td class="high">$HIGH</td></tr>
<tr><td>Medium</td><td class="medium">$MEDIUM</td></tr>
<tr><td>Low</td><td class="low">$LOW</td></tr>
</table>

</div>

<div class="section">
<h2>System</h2>

<table>
<tr><td>OS</td><td>$(html_escape "$OS_NAME")</td></tr>
<tr><td>Kernel</td><td>$(html_escape "$KERNEL")</td></tr>
<tr><td>Architecture</td><td>$(html_escape "$ARCH")</td></tr>
<tr><td>Uptime</td><td>$(html_escape "$UPTIME")</td></tr>
<tr><td>IP</td><td>$(html_escape "$PRIMARY_IP")</td></tr>
<tr><td>Role</td><td>$(html_escape "$SERVER_ROLE")</td></tr>
</table>

</div>

<div class="section">
<h2>Resources</h2>

<table>
<tr><td>CPU</td><td>$CPU_USAGE%</td></tr>
<tr><td>Memory</td><td>$MEM_USAGE%</td></tr>
<tr><td>Swap</td><td>$SWAP_USAGE%</td></tr>
<tr><td>Disk</td><td>$DISK_USAGE%</td></tr>
<tr><td>Load</td><td>$(html_escape "$LOAD_AVG")</td></tr>
<tr><td>Load Ratio</td><td>$(html_escape "$LOAD_RATIO")</td></tr>
</table>

</div>

<div class="section">
<h2>Security</h2>

<table>
<tr><td>SSH Status</td><td>$(html_escape "$SSH_STATUS")</td></tr>
<tr><td>Root Login</td><td>$(html_escape "$SSH_ROOT")</td></tr>
<tr><td>Password Auth</td><td>$(html_escape "$SSH_PASSWORD")</td></tr>
<tr><td>SELinux</td><td>$(html_escape "$SELINUX")</td></tr>
<tr><td>Firewall</td><td>$(html_escape "$FIREWALL")</td></tr>
<tr><td>NTP</td><td>$(html_escape "$NTP_SYNC")</td></tr>
<tr><td>SSL Expiring</td><td>$SSL_EXPIRING</td></tr>
<tr><td>SSL Expired</td><td>$SSL_EXPIRED</td></tr>
</table>

</div>

<div class="section">
<h2>Operations</h2>

<table>
<tr><td>Users</td><td>$TOTAL_USERS</td></tr>
<tr><td>Processes</td><td>$TOTAL_PROCESSES</td></tr>
<tr><td>Zombies</td><td>$ZOMBIE_PROCESSES</td></tr>
<tr><td>Threads</td><td>$TOTAL_THREADS</td></tr>
<tr><td>Cronjobs</td><td>$CRON_ENTRIES</td></tr>
<tr><td>Updates</td><td>$PACKAGE_UPDATES</td></tr>
</table>

</div>

<div class="section">
<h2>Containers</h2>

<table>
<tr><td>Docker</td><td>$(html_escape "$DOCKER_STATUS")</td></tr>
<tr><td>Containers</td><td>$DOCKER_CONTAINERS</td></tr>
<tr><td>Images</td><td>$(html_escape "$DOCKER_IMAGES")</td></tr>
<tr><td>Volumes</td><td>$(html_escape "$DOCKER_VOLUMES")</td></tr>
<tr>
<td>Kubernetes</td>
<td>
$([[ $K8S_FOUND -eq 1 ]] && printf Detected || printf 'Not detected')
</td>
</tr>

<tr><td>K8s Nodes</td><td>$(html_escape "$K8S_NODES")</td></tr>
<tr><td>K8s Pods</td><td>$(html_escape "$K8S_PODS")</td></tr>
<tr><td>K8s Services</td><td>$(html_escape "$K8S_SERVICES")</td></tr>

</table>

</div>

<div class="section">
<h2>Findings ($FINDING_COUNT)</h2>

EOF2

        if (( FINDING_COUNT == 0 )); then

            echo '<div class="ok">✓ No issues found based on configured checks.</div>'

        else

            echo '<table>'
            echo '<tr><th>Level</th><th>Issue</th><th>Fix</th></tr>'

            local i
            local l
            local c
            local t
            local f

            for (( i = 0; i < FINDING_COUNT; i++ )); do

                l="${FINDING_LEVEL[$i]}"

                c="$(
                    printf '%s' "$l" |
                    tr '[:upper:]' '[:lower:]'
                )"

                t="$(
                    html_escape "${FINDING_TEXT[$i]}"
                )"

                f="$(
                    html_escape "${FINDING_FIX[$i]}"
                )"

                printf \
                    '<tr><td class="%s">%s</td><td>%s</td><td>%s</td></tr>\n' \
                    "$c" \
                    "$l" \
                    "$t" \
                    "$f"

            done

            echo '</table>'
        fi

        cat <<EOF2

</div>

<div class="footer">
Generated by Server Health Monitor v$VERSION
</div>

</div>
</body>
</html>

EOF2

    } >"$tmp_file" 2>/dev/null ||
    {
        rm -f -- "$tmp_file" 2>/dev/null || true
        return 1
    }

    chmod 640 "$tmp_file" 2>/dev/null || true

    mv -f -- "$tmp_file" "$HTML_FILE" 2>/dev/null ||
    {
        rm -f -- "$tmp_file" 2>/dev/null || true
        return 1
    }

    (( HTML_MODE )) &&
        printf \
            'HTML report generated: %s\n' \
            "$HTML_FILE"
}

send_telegram_alert() {

    [[ -n "$TELEGRAM_BOT_TOKEN" &&
       -n "$TELEGRAM_CHAT_ID" ]] ||
        return 0

    have_cmd curl ||
        return 0

    local message

    message="SERVER HEALTH MONITOR v$VERSION"

    (( SHOW_TOP_MODE == 1 )) &&
        message+=" [SHOW-TOP MODE]"

    message+="
Score: $SCORE/100
Status: $(score_status_plain)

CRITICAL: $CRITICAL
HIGH: $HIGH
MEDIUM: $MEDIUM
LOW: $LOW

Host: $HOSTNAME
Time: $(date '+%Y-%m-%d %H:%M:%S')"

    if (( FINDING_COUNT > 0 )); then

        local i
        local c=0

        message+=$'\n\nTop Issues:'

        for (( i = 0;
              i < FINDING_COUNT && c < 5;
              i++ )); do

            if [[ "${FINDING_LEVEL[$i]}" == CRITICAL ||
                  "${FINDING_LEVEL[$i]}" == HIGH ]]; then

                message+=$'\n- '
                message+="${FINDING_TEXT[$i]}"

                c=$((c + 1))
            fi
        done
    fi

    run_timeout 12s \
        curl -fsS \
        --connect-timeout 5 \
        --max-time 10 \
        -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode \
        "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode \
        "text=${message}" \
        >/dev/null 2>&1 ||
        true
}
