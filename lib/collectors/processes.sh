#!/usr/bin/env bash
# ================================================================
# PROCESS
# ================================================================

collect_processes() {

    local now

    now="$(now_epoch)"

    (( now - LAST_PROCESS_COLLECTION <
       PROCESS_INTERVAL )) &&
        return 0

    LAST_PROCESS_COLLECTION="$now"

    TOTAL_PROCESSES="$(
        ps -e --no-headers 2>/dev/null |
        wc -l
    )"

    [[ "$TOTAL_PROCESSES" =~ ^[0-9]+$ ]] ||
        TOTAL_PROCESSES=0

    ZOMBIE_PROCESSES="$(
        ps -eo stat= 2>/dev/null |
        awk '
            $1 ~ /^Z/ {c++}
            END {print c+0}
        '
    )"

    [[ "$ZOMBIE_PROCESSES" =~ ^[0-9]+$ ]] ||
        ZOMBIE_PROCESSES=0

    # Production optimization:
    # One ps + one awk instead of spawning awk once per /proc/PID.
    TOTAL_THREADS="$(
        ps -e -o nlwp= 2>/dev/null |
        awk '
            {t += $1}
            END {print t+0}
        '
    )"

    [[ "$TOTAL_THREADS" =~ ^[0-9]+$ ]] ||
        TOTAL_THREADS=0
}

collect_top_processes() {

    local now

    now="$(now_epoch)"

    (( now - LAST_TOP_PROCESS_COLLECTION <
       15 )) &&
        return 0

    LAST_TOP_PROCESS_COLLECTION="$now"

    TOP_PROCESS_CACHE="$(
        ps -eo pid,user,pcpu,pmem,comm \
            --sort=-pcpu \
            2>/dev/null |
        head -n 11 |
        tail -n 10
    )"
}

collect_top_summary() {

    TOP_CPU_PROC=""
    TOP_CPU_VAL=0
    TOP_RAM_PROC=""
    TOP_RAM_VAL=0

    [[ -n "$TOP_PROCESS_CACHE" ]] ||
        return 0

    read -r TOP_CPU_PROC TOP_CPU_VAL TOP_RAM_PROC TOP_RAM_VAL < <(
        awk '
            NR == 1 {
                cpu_proc=$5
                cpu=$3
            }

            {
                if (($4+0) > (maxmem+0)) {
                    maxmem=$4
                    ram_proc=$5
                }
            }

            END {
                split(cpu,c,".")
                split(maxmem,m,".")

                if (c[1] == "")
                    c[1]=0

                if (m[1] == "")
                    m[1]=0

                print cpu_proc, c[1], ram_proc, m[1]
            }
        ' <<<"$TOP_PROCESS_CACHE"
    )

    [[ "$TOP_CPU_VAL" =~ ^[0-9]+$ ]] ||
        TOP_CPU_VAL=0

    [[ "$TOP_RAM_VAL" =~ ^[0-9]+$ ]] ||
        TOP_RAM_VAL=0
}
