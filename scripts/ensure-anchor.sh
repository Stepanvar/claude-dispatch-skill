#!/usr/bin/env bash
# Idempotently create a named tmux window with claude + /remote-control.
# Usage: ensure-anchor.sh <window-name> <cwd> [--lazy]
set -euo pipefail

WINDOW="${1:?Usage: ensure-anchor.sh <window-name> <cwd> [--lazy] [--overnight]}"
CWD="${2:?}"
LAZY=0
OVERNIGHT=0
for _arg in "${@:3}"; do
  [[ "$_arg" == "--lazy" ]] && LAZY=1
  [[ "$_arg" == "--overnight" ]] && OVERNIGHT=1
done
unset _arg

TMUX_SESSION="claude"
DISPATCH_DIR="${HOME}/.claude/dispatch"
CLAUDE_BIN="${HOME}/.local/bin/claude"
MAX_LIVE_LAZY="${MAX_LIVE_LAZY:-1}"
SPAWN_LOCK="${DISPATCH_DIR}/anchors/spawn.lock"

# Check if window already exists.
if tmux list-windows -t "$TMUX_SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "$WINDOW"; then
  echo "[ensure-anchor] $WINDOW already exists — skipping"
  exit 0
fi

# For lazy anchors, enforce MAX_LIVE_LAZY and serialize via flock.
if [[ $LAZY -eq 1 ]]; then
  live_lazy=$(tmux list-windows -t "$TMUX_SESSION" -F '#{window_name}' 2>/dev/null \
    | grep -cE '^(life|metagap)$' || true)
  if (( live_lazy >= MAX_LIVE_LAZY )); then
    echo "[ensure-anchor] lazy cap (${MAX_LIVE_LAZY}) reached — already live: ${live_lazy}. Kill existing anchor first (e.g. 'kill life')." >&2
    exit 1
  fi
fi

spawn_window() {
  echo "[ensure-anchor] spawning $WINDOW in $CWD"
  tmux new-window -t "$TMUX_SESSION" -n "$WINDOW" -c "$CWD"

  # Boot claude (no CLAUDE_DISPATCH_ROLE for non-manager anchors/task windows)
  if [[ $OVERNIGHT -eq 1 ]]; then
    echo "[ensure-anchor] overnight mode → opus"
    tmux send-keys -t "${TMUX_SESSION}:${WINDOW}" "$CLAUDE_BIN --model claude-opus-4-7" Enter
  else
    tmux send-keys -t "${TMUX_SESSION}:${WINDOW}" "$CLAUDE_BIN" Enter
  fi

  # Wait for ready
  local script_dir
  script_dir="$(dirname "$(realpath "$0")")"
  "${script_dir}/wait-for-claude-ready.sh" "$WINDOW" --timeout "${CLAUDE_READY_TIMEOUT:-30}"

  # Send /remote-control
  tmux send-keys -t "${TMUX_SESSION}:${WINDOW}" "/remote-control ${WINDOW}" Enter
  echo "[ensure-anchor] $WINDOW ready with /remote-control ${WINDOW}"
}

if [[ $LAZY -eq 1 ]]; then
  (
    flock -w 60 200
    spawn_window
  ) 200>"$SPAWN_LOCK"
else
  spawn_window
fi
