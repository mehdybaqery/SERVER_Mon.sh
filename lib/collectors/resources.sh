#!/usr/bin/env bash
# ================================================================
# RESOURCES
# ================================================================

collect_cpu_usage() {

    # ---------- PRIMARY METHOD: top (reliable, no sleep needed) ----------
    if have_cmd top; then
        local idle
        idle="$(
            top -bn1 2>/dev/null |
            grep -E '^%?Cpu' |
            head -1 |
            awk '{print $8}' |
            cut -d',' -f1
        )"

        if [[ "$idle" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            awk -v idle="$idle" 'BEGIN { printf "%.0f", 100 - idle }'
            return 0
        fi
    fi

    # ---------- FALLBACK: /proc/stat with safe division ----------
    local user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1
    local user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2
    local total1 total2 idle_total1 idle_total2 delta_total delta_idle

    read -r _ user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1 _ _ \
        < /proc/stat 2>/dev/null ||
        {
            echo 0
            return
        }

    sleep "$CPU_SAMPLE_SECONDS"

    read -r _ user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 _ _ \
        < /proc/stat 2>/dev/null ||
        {
            echo 0
            return
        }

    total1=$((user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1 + steal1))
    total2=$((user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2 + steal2))
    idle_total1=$((idle1 + iowait1))
    idle_total2=$((idle2 + iowait2))
    delta_total=$((total2 - total1))
    delta_idle=$((idle_total2 - idle_total1))

    awk -v total="$delta_total" -v idle="$delta_idle" \
        'BEGIN {
            if (total > 0)
                printf "%.0f", ((total - idle) / total) * 100
            else
                print 0
        }'
}

collect_resources() {

    if (( SHOW_TOP_MODE == 1 )); then

        if [[ -n "$TOP_PROCESS_CACHE" ]]; then

            CPU_USAGE="$(
                printf '%s\n' "$TOP_PROCESS_CACHE" |
                awk 'NR==1 {split($3,a,"."); print a[1]}'
            )"

            MEM_USAGE="$(
                printf '%s\n' "$TOP_PROCESS_CACHE" |
                awk 'NR==1 {split($4,a,"."); print a[1]}'
            )"

            [[ "$CPU_USAGE" =~ ^[0-9]+$ ]] ||
                CPU_USAGE=0

            [[ "$MEM_USAGE" =~ ^[0-9]+$ ]] ||
                MEM_USAGE=0

        else

            CPU_USAGE=0
            MEM_USAGE=0

        fi

    else

        CPU_USAGE="$(collect_cpu_usage)"

        [[ "$CPU_USAGE" =~ ^[0-9]+$ ]] ||
            CPU_USAGE=0

        (( CPU_USAGE < 0 )) &&
            CPU_USAGE=0

        (( CPU_USAGE > 100 )) &&
            CPU_USAGE=100

        MEM_USAGE="$(
            awk '
                /MemTotal:/     {t=$2}
                /MemAvailable:/ {a=$2}
                END {
                    if (t > 0 && a >= 0)
                        printf "%.0f", ((t-a)/t)*100
                    else
                        print 0
                }
            ' /proc/meminfo 2>/dev/null
        )"

        [[ "$MEM_USAGE" =~ ^[0-9]+$ ]] ||
            MEM_USAGE=0

    fi

    SWAP_USAGE="$(
        awk '
            /SwapTotal:/ {t=$2}
            /SwapFree:/  {f=$2}
            END {
                if (t > 0)
                    printf "%.0f", ((t-f)/t)*100
                else
                    print 0
            }
        ' /proc/meminfo 2>/dev/null
    )"

    [[ "$SWAP_USAGE" =~ ^[0-9]+$ ]] ||
        SWAP_USAGE=0

    LOAD_AVG="$(
        awk '{print $1}' /proc/loadavg 2>/dev/null
    )"

    [[ -n "$LOAD_AVG" ]] ||
        LOAD_AVG=0

    if [[ "$CPU_CORES" =~ ^[1-9][0-9]*$ ]]; then

        LOAD_RATIO="$(
            awk \
                -v l="$LOAD_AVG" \
                -v c="$CPU_CORES" \
                'BEGIN {
                    printf "%.2f", l/c
                }'
        )"

    else
        LOAD_RATIO=0
    fi
}

collect_filesystems() {

    local now
    local entry
    local usage
    local mount
    local root_found=0

    now="$(now_epoch)"

    (( now - LAST_FILESYSTEM_COLLECTION <
       FILESYSTEM_INTERVAL )) &&
        return 0

    LAST_FILESYSTEM_COLLECTION="$now"

    FILESYSTEM_CACHE=()

    while IFS= read -r entry; do

        [[ -n "$entry" ]] &&
            FILESYSTEM_CACHE+=("$entry")

    done < <(
        df -P \
            -x tmpfs \
            -x devtmpfs \
            -x squashfs \
            2>/dev/null |
        awk '
            NR > 1 {
                gsub("%","",$5)

                if ($5 ~ /^[0-9]+$/)
                    print $5 "|" $6
            }
        '
    )

    for entry in "${FILESYSTEM_CACHE[@]}"; do

        usage="${entry%%|*}"
        mount="${entry#*|}"

        if [[ "$mount" == "/" ]]; then

            DISK_USAGE="$usage"
            root_found=1

            break
        fi
    done

    (( root_found == 0 )) &&
        DISK_USAGE=0

    DISK_INODE_USAGE="$(
        df -Pi / 2>/dev/null |
        awk '
            NR == 2 {
                gsub("%","",$5)
                print $5
            }
        '
    )"

    [[ "$DISK_INODE_USAGE" =~ ^[0-9]+$ ]] ||
        DISK_INODE_USAGE=0
}
