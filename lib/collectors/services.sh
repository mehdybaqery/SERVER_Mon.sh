#!/usr/bin/env bash
# ================================================================
# SERVICES
# ================================================================

collect_services() {

    local now
    local svc
    local st

    now="$(now_epoch)"

    (( now - LAST_SERVICE_COLLECTION <
       SERVICE_INTERVAL )) &&
        return 0

    LAST_SERVICE_COLLECTION="$now"

    for svc in docker containerd kubelet; do

        st="not-installed"

        if run_timeout 2s \
            systemctl is-active --quiet "$svc" 2>/dev/null; then

            st="active"

        elif run_timeout 2s \
            systemctl list-unit-files \
            --no-legend "$svc.service" 2>/dev/null |
            grep -qE "^${svc}\.service[[:space:]]"; then

            st="installed"
        fi

        case "$svc" in

            docker)
                DOCKER_STATUS="$st"
                ;;

            containerd)
                CONTAINERD_STATUS="$st"
                ;;

            kubelet)
                KUBELET_STATUS="$st"
                ;;

        esac
    done

    FAILED_SERVICES="$(
        run_timeout 4s \
            systemctl --failed \
            --type=service \
            --no-legend 2>/dev/null |
        wc -l
    )"

    [[ "$FAILED_SERVICES" =~ ^[0-9]+$ ]] ||
        FAILED_SERVICES=0
}
