#!/usr/bin/env bash
# ================================================================
# USERS
# ================================================================

collect_users() {

    local now

    now="$(now_epoch)"

    (( now - LAST_USER_COLLECTION <
       USER_INTERVAL )) &&
        return 0

    LAST_USER_COLLECTION="$now"

    TOTAL_USERS=0
    LOGIN_USERS=0
    UID0_USERS=0
    LOCKED_USERS=0
    SUDO_USERS=0
    TOTAL_GROUPS=0
    USER_NAMES_LIST=""

    MONITORED_USER_SET=()
    MONITORED_GROUP_SET=()

    local list=""
    local n
    local uid
    local gid
    local gecos
    local home
    local shell
    local primary_group
    local is_sudo

    while IFS=: read -r n _ uid gid gecos home shell; do

        if [[ "$n" == root ]]; then

            MONITORED_USER_SET["$n"]=1

            TOTAL_USERS=$((TOTAL_USERS + 1))
            LOGIN_USERS=$((LOGIN_USERS + 1))
            UID0_USERS=$((UID0_USERS + 1))

            [[ -n "$list" ]] &&
                list+=", "

            list+="$n"

            continue
        fi

        (( uid >= 1000 )) ||
            continue

        [[ "$shell" =~ (nologin|false)$ ]] &&
            continue

        [[ -d "$home" ]] ||
            continue

        MONITORED_USER_SET["$n"]=1

        TOTAL_USERS=$((TOTAL_USERS + 1))
        LOGIN_USERS=$((LOGIN_USERS + 1))

        [[ -n "$list" ]] &&
            list+=", "

        list+="$n"

    done < /etc/passwd

    USER_NAMES_LIST="$list"

    while IFS=: read -r n _ uid gid gecos home shell; do

        [[ "${MONITORED_USER_SET[$n]:-0}" == 1 ]] ||
            continue

        primary_group="$(
            awk -F: -v gid="$gid" \
                '$3==gid{print $1;exit}' \
                /etc/group 2>/dev/null
        )"

        [[ -z "$primary_group" ]] &&
            primary_group="GID:$gid"

        MONITORED_GROUP_SET["$primary_group"]=1

        while IFS=: read -r gname _ _ members; do

            [[ -n "$gname" && -n "$members" ]] ||
                continue

            local found=0
            local member

            IFS=',' read -ra member_array <<<"$members"

            for member in "${member_array[@]}"; do

                [[ "$member" == "$n" ]] && {
                    found=1
                    break
                }

            done

            (( found == 1 )) &&
                MONITORED_GROUP_SET["$gname"]=1

        done < /etc/group

        is_sudo=0

        [[ "$primary_group" == sudo ||
           "$primary_group" == wheel ]] &&
            is_sudo=1

        if (( is_sudo == 0 )); then

            while IFS=: read -r gname _ _ members; do

                [[ "$gname" == sudo ||
                   "$gname" == wheel ]] ||
                    continue

                [[ -n "$members" ]] ||
                    continue

                IFS=',' read -ra member_array <<<"$members"

                for member in "${member_array[@]}"; do

                    [[ "$member" == "$n" ]] && {
                        is_sudo=1
                        break
                    }

                done

                (( is_sudo == 1 )) &&
                    break

            done < /etc/group
        fi

        (( is_sudo == 1 )) &&
            SUDO_USERS=$((SUDO_USERS + 1))

        if have_cmd passwd &&
           passwd -S "$n" 2>/dev/null |
           awk '
               {
                   if ($2 == "L")
                       exit 0
                   exit 1
               }
           '; then

            LOCKED_USERS=$((LOCKED_USERS + 1))

        fi

    done < /etc/passwd

    TOTAL_GROUPS="${#MONITORED_GROUP_SET[@]}"
}

collect_logged_users() {

    local who_data
    local current_count

    who_data="$(
        who 2>/dev/null |
        awk 'NF >= 1 {print $1}'
    )"

    current_count="$(
        printf '%s\n' "$who_data" |
        awk '
            NF {c++}
            END {print c+0}
        '
    )"

    [[ "$current_count" =~ ^[0-9]+$ ]] ||
        current_count=0

    LOGGED_COUNT="$current_count"

    if (( LOGGED_COUNT == 0 )); then
        LOGGED_USERS="None"
        return 0
    fi

    LOGGED_USERS="$(
        printf '%s\n' "$who_data" |
        awk '
            NF && !seen[$1]++ {
                if (out != "")
                    out=out ","
                out=out $1
            }

            END {
                print out
            }
        '
    )"

    [[ -n "$LOGGED_USERS" ]] ||
        LOGGED_USERS="None"
}
