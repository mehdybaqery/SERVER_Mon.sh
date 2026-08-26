#!/usr/bin/env bash
# ================================================================
# SSL
# ================================================================

collect_ssl_safe() {

    local now
    local cert
    local exp
    local epoch
    local days

    now="$(now_epoch)"

    (( now - LAST_SSL_COLLECTION <
       SSL_INTERVAL )) &&
        return 0

    LAST_SSL_COLLECTION="$now"

    SSL_CERTS_COUNT=0
    SSL_EXPIRING=0
    SSL_EXPIRED=0

    have_cmd openssl ||
        return 0

    local -a cert_paths=(
        /etc/letsencrypt/live/*/fullchain.pem
        /etc/nginx/ssl/*.crt
        /etc/apache2/ssl/*.crt
        /etc/pki/tls/certs/*.pem
    )

    for cert in "${cert_paths[@]}"; do

        [[ -f "$cert" ]] ||
            continue

        SSL_CERTS_COUNT=$((SSL_CERTS_COUNT + 1))

        exp="$(
            run_timeout 2s \
                openssl x509 \
                -enddate \
                -noout \
                -in "$cert" 2>/dev/null |
            cut -d= -f2
        )"

        [[ -n "$exp" ]] ||
            continue

        epoch="$(
            date -d "$exp" +%s 2>/dev/null || true
        )"

        [[ "$epoch" =~ ^[0-9]+$ ]] ||
            continue

        days=$(( (epoch - now) / 86400 ))

        if (( days < 0 )); then

            SSL_EXPIRED=$((SSL_EXPIRED + 1))

        elif (( days < 30 )); then

            SSL_EXPIRING=$((SSL_EXPIRING + 1))

        fi
    done
}
