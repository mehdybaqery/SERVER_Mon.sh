#!/usr/bin/env bash
# ================================================================
# BASIC HELPERS
# ================================================================

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

now_epoch() {
    date +%s
}

run_timeout() {
    local duration="$1"
    shift

    if have_cmd timeout; then
        timeout "$duration" "$@"
        return $?
    fi

    local seconds="${duration%s}"
    local pid
    local elapsed=0

    [[ "$seconds" =~ ^[0-9]+$ ]] || seconds=10

    "$@" &
    pid=$!

    while kill -0 "$pid" 2>/dev/null; do
        sleep 0.2

        elapsed=$((elapsed + 1))

        if (( elapsed >= seconds * 5 )); then
            kill "$pid" 2>/dev/null || true
            sleep 0.2
            kill -KILL "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
            return 124
        fi
    done

    wait "$pid"
}

json_escape() {
    local s="$1"

    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\r'/\\r}
    s=${s//$'\n'/\\n}
    s=${s//$'\t'/\\t}

    printf '%s' "$s"
}

html_escape() {
    local s="$1"

    s=${s//&/&amp;}
    s=${s//</&lt;}
    s=${s//>/&gt;}
    s=${s//\"/&quot;}
    s=${s//\'/&#39;}

    printf '%s' "$s"
}

score_status_plain() {
    if (( SCORE >= 90 )); then
        printf 'HEALTHY'
    elif (( SCORE >= 70 )); then
        printf 'WARNING'
    elif (( SCORE >= 50 )); then
        printf 'RISK'
    else
        printf 'CRITICAL'
    fi
}

repeat_char() {

    local char="$1"
    local count="$2"
    local out=""
    local i

    (( count <= 0 )) &&
        return 0

    for (( i = 0; i < count; i++ )); do
        out+="$char"
    done

    printf '%s' "$out"
}

truncate_text() {

    local text="$1"
    local max="$2"

    if (( ${#text} <= max )); then

        printf '%s' "$text"

    else

        printf '%s…' \
            "${text:0:max-1}"

    fi
}

box_row() {

    printf \
        "${DARK_GRAY}║${RESET} %-62s ${DARK_GRAY}║${RESET}\n" \
        "$1"
}
