#!/usr/bin/env bash
# ================================================================
# CONTAINERS
# ================================================================

collect_container_status() {

    local now
    now="$(now_epoch)"

    (( now - LAST_CONTAINER_COLLECTION <
       CONTAINER_INTERVAL )) &&
        return 0

    LAST_CONTAINER_COLLECTION="$now"

    DOCKER_CONTAINERS=0
    DOCKER_IMAGES=N/A
    DOCKER_VOLUMES=N/A

    if have_cmd docker; then

        DOCKER_CONTAINERS="$(
            run_timeout 3s \
                docker ps -q 2>/dev/null |
            awk '
                NF {c++}
                END {print c+0}
            '
        )"

        [[ "$DOCKER_CONTAINERS" =~ ^[0-9]+$ ]] ||
            DOCKER_CONTAINERS=0

        DOCKER_IMAGES="$(
            run_timeout 4s \
                docker images -q 2>/dev/null |
            awk '
                NF {c++}
                END {print c+0}
            '
        )"

        [[ "$DOCKER_IMAGES" =~ ^[0-9]+$ ]] ||
            DOCKER_IMAGES=N/A

        DOCKER_VOLUMES="$(
            run_timeout 4s \
                docker volume ls -q 2>/dev/null |
            awk '
                NF {c++}
                END {print c+0}
            '
        )"

        [[ "$DOCKER_VOLUMES" =~ ^[0-9]+$ ]] ||
            DOCKER_VOLUMES=N/A
    fi

    if have_cmd kubectl; then

        if run_timeout 4s \
            kubectl version \
            --request-timeout=2s \
            --output=json >/dev/null 2>&1; then

            K8S_FOUND=1

            K8S_NODES="$(
                run_timeout 5s \
                    kubectl get nodes \
                    --no-headers \
                    --request-timeout=2s 2>/dev/null |
                awk '
                    NF {c++}
                    END {print c+0}
                '
            )"

            K8S_PODS="$(
                run_timeout 5s \
                    kubectl get pods -A \
                    --no-headers \
                    --request-timeout=2s 2>/dev/null |
                awk '
                    NF {c++}
                    END {print c+0}
                '
            )"

            K8S_SERVICES="$(
                run_timeout 5s \
                    kubectl get svc -A \
                    --no-headers \
                    --request-timeout=2s 2>/dev/null |
                awk '
                    NF {c++}
                    END {print c+0}
                '
            )"

        else

            K8S_FOUND=1
            K8S_NODES=N/A
            K8S_PODS=N/A
            K8S_SERVICES=N/A

        fi

    elif have_cmd kubelet ||
         [[ -d /var/lib/kubelet ]]; then

        K8S_FOUND=1
        K8S_NODES=N/A
        K8S_PODS=N/A
        K8S_SERVICES=N/A

    else

        K8S_FOUND=0
        K8S_NODES=N/A
        K8S_PODS=N/A
        K8S_SERVICES=N/A

    fi
}
