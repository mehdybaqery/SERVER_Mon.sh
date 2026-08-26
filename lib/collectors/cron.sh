#!/usr/bin/env bash
# ================================================================
# CRON
# ================================================================

collect_crons() {

    local now

    now="$(now_epoch)"

    (( now - LAST_CRON_COLLECTION <
       CRON_INTERVAL )) &&
        return 0

    LAST_CRON_COLLECTION="$now"

    CRON_ENTRIES=0

    local c
    local user
    local cf
    local d

    if [[ -f /etc/crontab ]]; then

        c="$(
            grep -vcE '^[[:space:]]*(#|$)' \
                /etc/crontab 2>/dev/null || true
        )"

        [[ "$c" =~ ^[0-9]+$ ]] ||
            c=0

        CRON_ENTRIES=$((CRON_ENTRIES + c))
    fi

    while IFS=: read -r user _; do

        for cf in \
            "/var/spool/cron/$user" \
            "/var/spool/cron/crontabs/$user"; do

            [[ -f "$cf" ]] ||
                continue

            c="$(
                grep -vcE '^[[:space:]]*(#|$)' \
                    "$cf" 2>/dev/null || true
            )"

            [[ "$c" =~ ^[0-9]+$ ]] ||
                c=0

            CRON_ENTRIES=$((CRON_ENTRIES + c))

            break
        done

    done </etc/passwd

    for d in \
        /etc/cron.d \
        /etc/cron.daily \
        /etc/cron.hourly \
        /etc/cron.weekly \
        /etc/cron.monthly; do

        [[ -d "$d" ]] ||
            continue

        c="$(
            find "$d" \
                -mindepth 1 \
                -maxdepth 1 \
                -type f \
                2>/dev/null |
            wc -l
        )"

        [[ "$c" =~ ^[0-9]+$ ]] ||
            c=0

        CRON_ENTRIES=$((CRON_ENTRIES + c))
    done
}
