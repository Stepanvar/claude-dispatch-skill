#!/usr/bin/env bash
# Probe whether a named tmux window's claude session is idle (safe to dispatch).
# Usage: is-window-idle.sh <window-name>
# Exit 0 = idle, Exit 1 = busy or non-existent
set -euo pipefail

WINDOW="${1:?Usage: is-window-idle.sh <window-name>}"
TMUX_SESSION="claude"
TARGET="${TMUX_SESSION}:${WINDOW}"

# Window must exist
if ! tmux list-windows -t "$TMUX_SESSION" -F '#{window_name}' 2>/dev/null | grep -qx "$WINDOW"; then
  echo "[is-window-idle] $WINDOW: window does not exist" >&2
  exit 1
fi

# Foreground process must be claude
cmd=$(tmux display-message -p -t "$TARGET" '#{pane_current_command}' 2>/dev/null || echo "")
if [[ "$cmd" != "claude" ]]; then
  echo "[is-window-idle] $WINDOW: foreground=$cmd (not claude)" >&2
  exit 1
fi

# Capture full visible pane. Claude UI footer (status bar, input box, dividers)
# can push the spinner line outside a 10-row window even when actively working.
pane_content=$(tmux capture-pane -p -t "$TARGET" 2>/dev/null)

# Busy = structural indicators only. Spinner verbs change between Claude releases
# (Metamorphosing, Flummoxing, etc.) so verb-matching is fragile. These signals
# are stable across versions:
#   - "esc to interrupt"     — shown while a tool/turn is running
#   - "paste again to expand"— pending paste expansion (blocked)
#   - "↓ N" / "↑ N"          — spinner-line throughput counter (down/up)
#   - "tokens ·"             — spinner-line metadata separator
#   - "almost done thinking" — late-stage thinking indicator
busy_pattern='esc to interrupt|paste again to expand|[↓↑] [0-9]|tokens ·|almost done thinking'

if echo "$pane_content" | grep -qiE "$busy_pattern"; then
  echo "[is-window-idle] $WINDOW: busy (active indicator detected)" >&2
  exit 1
fi

echo "[is-window-idle] $WINDOW: idle" >&2
exit 0
