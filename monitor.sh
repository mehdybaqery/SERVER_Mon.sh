#!/usr/bin/env bash
# ================================================================
# SERVER HEALTH MONITOR - v1.3.3 (PRODUCTION FINAL)
# ================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ================================================================
# LOAD ALL MODULES
# ================================================================

source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/helpers.sh"
source "$SCRIPT_DIR/lib/collectors/system.sh"
source "$SCRIPT_DIR/lib/collectors/resources.sh"
source "$SCRIPT_DIR/lib/collectors/processes.sh"
source "$SCRIPT_DIR/lib/collectors/network.sh"
source "$SCRIPT_DIR/lib/collectors/users.sh"
source "$SCRIPT_DIR/lib/collectors/cron.sh"
source "$SCRIPT_DIR/lib/collectors/services.sh"
source "$SCRIPT_DIR/lib/collectors/security.sh"
source "$SCRIPT_DIR/lib/collectors/containers.sh"
source "$SCRIPT_DIR/lib/collectors/ssl.sh"
source "$SCRIPT_DIR/lib/collectors/audit.sh"
source "$SCRIPT_DIR/lib/analysis.sh"
source "$SCRIPT_DIR/lib/reporters.sh"
source "$SCRIPT_DIR/lib/ui.sh"

# ================================================================
# LOCK FUNCTIONS
# ================================================================

acquire_lock() {

    have_cmd flock || {
        printf '%s\n' 'flock is required for production-safe locking.' >&2
        exit 1
    }

    if (( EUID == 0 )); then
        LOCK_FILE="/run/server-health-monitor.lock"
    else
        LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/server-health-monitor.lock"
    fi

    exec 9>"$LOCK_FILE" 2>/dev/null || {
        printf 'Unable to create monitor lock: %s\n' "$LOCK_FILE" >&2
        exit 1
    }

    flock -n 9 || {
        printf '%s\n' 'Another SERVER HEALTH MONITOR instance is already running.' >&2
        exit 1
    }

    LOCK_FD_OPEN=1
}

release_lock() {
    if (( LOCK_FD_OPEN )); then
        flock -u 9 2>/dev/null || true
        exec 9>&- 2>/dev/null || true
        LOCK_FD_OPEN=0
    fi
}

# ================================================================
# PROCESS PRIORITY
# ================================================================

lower_monitor_priority() {

    # Reduce CPU scheduling priority.
    if have_cmd renice; then
        renice +10 -p "$$" >/dev/null 2>&1 || true
    fi

    # Reduce disk I/O scheduling priority when supported.
    if have_cmd ionice; then
        ionice -c 3 -p "$$" >/dev/null 2>&1 || true
    fi
}

# ================================================================
# ARGUMENTS
# ================================================================

parse_args() {

    while [[ $# -gt 0 ]]; do

        case "$1" in

            --once)
                ONCE_MODE=1
                ;;

            --json)
                JSON_MODE=1
                ;;

            --html)
                HTML_MODE=1
                ;;

            --quiet)
                QUIET_MODE=1
                ;;

            --show-top)
                SHOW_TOP_MODE=1
                ;;

            --telegram)

                TELEGRAM_MODE=1

                if [[ -n "${2:-}" && "$2" != --* ]]; then
                    TELEGRAM_BOT_TOKEN="$2"
                    shift
                fi

                if [[ -n "${2:-}" && "$2" != --* ]]; then
                    TELEGRAM_CHAT_ID="$2"
                    shift
                fi

                ;;

            --help|-h)

                cat <<'HELP'

SERVER HEALTH MONITOR v1.3.3

Usage:
  ./server-health-monitor.sh [OPTIONS]

Options:
  --once
      Run once and exit

  --json
      Generate JSON report and exit

  --html
      Generate HTML report and exit

  --quiet
      Suppress interactive UI

  --show-top
      Show only top process usage (CPU/RAM) in Resource Monitor

      WARNING:
      This overrides system-wide CPU/RAM totals.

  --telegram [TOKEN] [ID]
      Send Telegram alert

Production Telegram:
  /etc/server-health-monitor/telegram.conf
  chmod 600 /etc/server-health-monitor/telegram.conf

Production Notes:
  Monitor is intentionally read-only.
  No service restart.
  No process kill.
  No package update.
  No configuration modification.

HELP

                exit 0
                ;;

            *)

                printf 'Unknown option: %s\n' "$1" >&2
                exit 2
                ;;

        esac

        shift
    done
}

# ================================================================
# CLEANUP
# ================================================================

cleanup() {

    if [[ -t 1 ]]; then

        printf '\033[0m\n'

        stty sane 2>/dev/null ||
            true
    fi

    release_lock
}

# ================================================================
# MAIN
# ================================================================

main() {

    parse_args "$@"

    acquire_lock

    # Lower monitor scheduling priority.
    # This does not change the priority of the monitored applications.
    lower_monitor_priority

    if (( JSON_MODE ||
          HTML_MODE ||
          ONCE_MODE ||
          QUIET_MODE )); then

        QUIET_MODE=1
    fi

    reset_screen
    print_ascii_header

    if (( ! QUIET_MODE )); then

        echo -e \
            "${DARK_GRAY}${BOLD}>> INITIALIZING SERVER HEALTH MONITOR...${RESET}"

        sleep 0.5
    fi

    detect_system
    detect_roles

    collect_hardware

    collect_resources
    collect_filesystems
    collect_processes
    collect_top_processes
    collect_top_summary
    collect_network
    collect_logged_users
    collect_users
    collect_crons
    collect_services
    collect_security_baseline
    collect_container_status
    collect_ssl_safe

    analyze_security_light

    log_cycle
    rotate_logs

    if (( ! QUIET_MODE )); then
        hacker_discovery
    fi

    (( JSON_MODE )) &&
        generate_json

    (( HTML_MODE )) &&
        generate_html

    if (( ONCE_MODE )); then

        if (( ! JSON_MODE &&
              ! HTML_MODE )); then

            printf \
                'Health check completed. Score: %s/100\n' \
                "$SCORE"
        fi

        (( TELEGRAM_MODE )) &&
            send_telegram_alert

        exit 0
    fi

    if (( JSON_MODE ||
          HTML_MODE ||
          QUIET_MODE )); then

        (( TELEGRAM_MODE )) &&
            send_telegram_alert

        exit 0
    fi

    hacker_dashboard
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

main "$@"
