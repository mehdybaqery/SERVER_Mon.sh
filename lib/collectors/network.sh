#!/usr/bin/env bash
# ================================================================
# NETWORK
# ================================================================

collect_network() {

    local now
    local tcp_data
    local listen_data
    local udp_data

    now="$(now_epoch)"

    (( now - LAST_NETWORK_COLLECTION <
       NETWORK_INTERVAL )) &&
        return 0

    LAST_NETWORK_COLLECTION="$now"

    tcp_data="$(
        run_timeout 5s ss -H -tan 2>/dev/null || true
    )"

    ESTABLISHED="$(
        printf '%s\n' "$tcp_data" |
        awk '
            $1 == "ESTAB" {c++}
            END {print c+0}
        '
    )"

    TCP_CONNS="$(
        printf '%s\n' "$tcp_data" |
        awk '
            NF {c++}
            END {print c+0}
        '
    )"

    listen_data="$(
        run_timeout 5s ss -H -lnt 2>/dev/null || true
    )"

    LISTEN_PORTS="$(
        printf '%s\n' "$listen_data" |
        awk '
            NF {c++}
            END {print c+0}
        '
    )"

    udp_data="$(
        run_timeout 5s ss -H -uan 2>/dev/null || true
    )"

    UDP_CONNS="$(
        printf '%s\n' "$udp_data" |
        awk '
            NF {c++}
            END {print c+0}
        '
    )"

    [[ "$ESTABLISHED" =~ ^[0-9]+$ ]] ||
        ESTABLISHED=0

    [[ "$TCP_CONNS" =~ ^[0-9]+$ ]] ||
        TCP_CONNS=0

    [[ "$LISTEN_PORTS" =~ ^[0-9]+$ ]] ||
        LISTEN_PORTS=0

    [[ "$UDP_CONNS" =~ ^[0-9]+$ ]] ||
        UDP_CONNS=0
}
