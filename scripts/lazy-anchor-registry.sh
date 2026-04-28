#!/usr/bin/env bash
# Manage per-lazy-anchor mtime tracking for watchdog GC.
# Usage:
#   lazy-anchor-registry.sh touch <name>       — update last-seen timestamp
#   lazy-anchor-registry.sh age <name>         — print seconds since last touch
#   lazy-anchor-registry.sh list               — print all tracked anchors + ages
#   lazy-anchor-registry.sh remove <name>      — remove tracking file
set -euo pipefail

REG_DIR="${DISPATCH_REG_DIR:-${HOME}/.claude/dispatch/anchors}"
mkdir -p "$REG_DIR"

CMD="${1:?Usage: lazy-anchor-registry.sh <touch|age|list|remove> [name]}"
shift

case "$CMD" in
  touch)
    NAME="${1:?touch requires a name}"
    touch "${REG_DIR}/${NAME}.last"
    ;;
  age)
    NAME="${1:?age requires a name}"
    FILE="${REG_DIR}/${NAME}.last"
    if [[ ! -f "$FILE" ]]; then
      echo "9999999"  # treat as infinitely old if no record
    else
      NOW=$(date +%s)
      MTIME=$(stat -c%Y "$FILE")
      echo $(( NOW - MTIME ))
    fi
    ;;
  list)
    for f in "${REG_DIR}"/*.last; do
      [[ -f "$f" ]] || continue
      name=$(basename "$f" .last)
      NOW=$(date +%s)
      MTIME=$(stat -c%Y "$f")
      age=$(( NOW - MTIME ))
      printf "%-20s %ds ago\n" "$name" "$age"
    done
    ;;
  remove)
    NAME="${1:?remove requires a name}"
    rm -f "${REG_DIR}/${NAME}.last"
    ;;
  *)
    echo "Unknown command: $CMD" >&2; exit 1 ;;
esac
