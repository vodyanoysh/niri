#!/usr/bin/env bash
# Тоггл плавающего скретч-терминала по F9.
#
# Терминал распознаётся по своему app-id (org.niri.scratchterm). Пока он
# скрыт — он тайловый и сидит на последнем workspace того монитора, на
# котором был открыт. По F9 он всплывает поверх текущего workspace как
# floating-окно; повторный F9 убирает его обратно на последний workspace.
#
# Режим "ensure" (используется при старте niri, см. spawn-sh-at-startup в
# config.kdl) создаёт терминал, если он ещё не запущен, и сразу прячет его,
# не показывая пользователю.
set -euo pipefail

APP_ID="org.niri.scratchterm"

windows_json() {
    niri msg -j windows
}

workspaces_json() {
    niri msg -j workspaces
}

find_window_id() {
    windows_json | jq -r --arg app_id "$APP_ID" \
        '[.[] | select(.app_id == $app_id)][0].id // empty'
}

is_floating() {
    windows_json | jq -r --argjson id "$1" \
        '[.[] | select(.id == $id)][0].is_floating'
}

window_output() {
    local id="$1" ws_id
    ws_id=$(windows_json | jq -r --argjson id "$id" '[.[] | select(.id == $id)][0].workspace_id')
    workspaces_json | jq -r --argjson wid "$ws_id" '[.[] | select(.id == $wid)][0].output'
}

last_workspace_idx_on_output() {
    workspaces_json | jq -r --arg output "$1" \
        '[.[] | select(.output == $output)] | max_by(.idx) | .idx'
}

focused_output() {
    niri msg -j focused-output | jq -r '.name'
}

wait_for_window() {
    for _ in $(seq 1 50); do
        local id
        id=$(find_window_id)
        if [ -n "$id" ]; then
            printf '%s\n' "$id"
            return 0
        fi
        sleep 0.1
    done
    return 1
}

spawn_terminal() {
    setsid ghostty --class="$APP_ID" >/dev/null 2>&1 &
    disown
}

show_terminal() {
    local id="$1" output
    output=$(focused_output)

    niri msg action move-window-to-floating --id "$id"
    niri msg action move-window-to-monitor --id "$id" "$output"
    niri msg action focus-window --id "$id"
    niri msg action center-window --id "$id"
}

hide_terminal() {
    local id="$1" output idx
    output=$(window_output "$id")

    niri msg action move-window-to-tiling --id "$id"
    idx=$(last_workspace_idx_on_output "$output")
    niri msg action move-window-to-workspace "$idx" --window-id "$id" --focus false
}

toggle() {
    local id
    id=$(find_window_id)

    if [ -z "$id" ]; then
        spawn_terminal
        id=$(wait_for_window) || exit 1
        show_terminal "$id"
        return
    fi

    if [ "$(is_floating "$id")" = "true" ]; then
        hide_terminal "$id"
    else
        show_terminal "$id"
    fi
}

ensure() {
    local id
    id=$(find_window_id)

    if [ -z "$id" ]; then
        spawn_terminal
        id=$(wait_for_window) || exit 1
    fi

    # На случай, если окно открылось не на последнем workspace своего
    # монитора (например, только что заспавнилось) — убираем его туда.
    hide_terminal "$id"
}

case "${1:-toggle}" in
    ensure) ensure ;;
    *) toggle ;;
esac
