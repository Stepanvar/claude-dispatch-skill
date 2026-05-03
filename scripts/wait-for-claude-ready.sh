#!/usr/bin/env bash
# Wait until a claude pane is at the prompt with a live remote-control bridge.
# Usage: wait-for-claude-ready.sh <tmux-window-name> [--timeout <seconds>] [--trace]
set -euo pipefail

WINDOW="${1:?Usage: wait-for-claude-ready.sh <window-name> [--timeout N] [--trace]}"
TIMEOUT="${CLAUDE_READY_TIMEOUT:-30}"
TRACE=0
shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --trace)   TRACE=1; shift ;;
    *)         shift ;;
  esac
done

TMUX_SESSION="claude"
DISPATCH_DIR="${HOME}/.claude/dispatch"
SESSIONS_DIR="${HOME}/.claude/sessions"

log() { [[ $TRACE -eq 1 ]] && echo "[wait-for-claude-ready] $*" >&2; }

# Find the PID of claude running in the target pane.
get_claude_pid() {
  local pane_pid
  pane_pid=$(tmux display-message -p -t "${TMUX_SESSION}:${WINDOW}" "#{pane_pid}" 2>/dev/null) || return 1
  # Child of the pane shell that matches 'claude' binary
  pgrep -P "$pane_pid" -f 'claude' 2>/dev/null | head -1
}

bridge_ready() {
  local pid="$1"
  local f="${SESSIONS_DIR}/${pid}.json"
  [[ -f "$f" ]] && grep -q '"bridgeSessionId"' "$f"
}

pane_at_prompt() {
  # Claude's interactive prompt typically shows a line with │ or ❯ or > at the tail
  tmux capture-pane -p -t "${TMUX_SESSION}:${WINDOW}" 2>/dev/null \
    | tail -5 \
    | grep -qE '(│|❯|^\s*>\s|✓|╭|─)'
}

ELAPSED=0
INTERVAL=0.5
while (( ELAPSED < TIMEOUT )); do
  CPID=$(get_claude_pid 2>/dev/null || true)
  if [[ -n "$CPID" ]]; then
    log "claude PID=$CPID found"
    if bridge_ready "$CPID"; then
      log "bridge ready"
      if pane_at_prompt; then
        log "pane at prompt — ready"
        exit 0
      else
        log "bridge ready but pane not at prompt yet"
      fi
    else
      log "claude running, no bridge yet"
    fi
  else
    log "no claude PID yet"
  fi
  sleep "$INTERVAL"
  ELAPSED=$(echo "$ELAPSED + $INTERVAL" | bc)
done

echo "[wait-for-claude-ready] TIMEOUT after ${TIMEOUT}s waiting for ${WINDOW}" >&2
exit 1
