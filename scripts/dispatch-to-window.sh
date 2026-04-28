#!/usr/bin/env bash
# Paste content into a tmux window's claude session.
# Usage:
#   dispatch-to-window.sh <window-name> --paste-file <path>
#   dispatch-to-window.sh <window-name> --text <string>
set -euo pipefail

WINDOW="${1:?Usage: dispatch-to-window.sh <window-name> --paste-file <path>|--text <str>}"
TMUX_SESSION="${TMUX_SESSION:-claude}"
TARGET="${TMUX_SESSION}:${WINDOW}"

shift
MODE="${1:?Expected --paste-file or --text}"
shift

TMPFILE=""
cleanup() { [[ -n "$TMPFILE" && -f "$TMPFILE" ]] && rm -f "$TMPFILE"; }
trap cleanup EXIT

case "$MODE" in
  --paste-file)
    SOURCE_FILE="${1:?--paste-file requires a path}"
    ;;
  --text)
    TMPFILE=$(mktemp)
    printf '%s' "${1:?--text requires a string}" > "$TMPFILE"
    SOURCE_FILE="$TMPFILE"
    ;;
  *)
    echo "Unknown mode: $MODE" >&2; exit 1 ;;
esac

SIZE=$(stat -c%s "$SOURCE_FILE")
MAX_CHUNK=61440  # 60 KB

paste_chunk() {
  local f="$1"
  tmux load-buffer "$f"
  tmux paste-buffer -t "$TARGET"
  tmux delete-buffer
}

if (( SIZE > MAX_CHUNK )); then
  echo "[dispatch] file ${SIZE}b > ${MAX_CHUNK}b — chunking" >&2
  CHUNK_DIR=$(mktemp -d)
  split -b "$MAX_CHUNK" "$SOURCE_FILE" "${CHUNK_DIR}/chunk_"
  for chunk in "${CHUNK_DIR}"/chunk_*; do
    paste_chunk "$chunk"
    sleep 0.1  # brief gap between chunks
  done
  rm -rf "$CHUNK_DIR"
else
  paste_chunk "$SOURCE_FILE"
fi

tmux send-keys -t "$TARGET" "" Enter
echo "[dispatch] sent to ${TARGET}"
