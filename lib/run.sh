#!/bin/bash
# DesktopLens — capture+process loop. Used by the daemon and by `desktoplens test`.
#   run.sh once  [seconds]   -> one window then exit
#   run.sh loop  [seconds]   -> windows forever (LaunchAgent target)
source "$(dirname "$0")/common.sh"
MODE="${1:-loop}"; SECS="${2:-$DL_WINDOW_SECONDS}"

do_window() {
  local secs="$1" win out
  win=$("$DL_HOME/lib/capture.sh" "$secs")
  case "$win" in
    win_*) ;;
    *) echo "[run] $win"; return 0 ;;
  esac
  out=$("$DL_HOME/lib/process.sh" "$win")
  echo "[run] buffer: $out"
  if [ -n "$DL_SUMMARIZER_CMD" ]; then
    echo "[run] summarizer: $DL_SUMMARIZER_CMD"
    eval "$DL_SUMMARIZER_CMD \"$out\"" || echo "[run] summarizer failed (buffer kept)"
  fi
}

if [ "$MODE" = once ]; then
  do_window "$SECS"
else
  echo "[run] DesktopLens daemon: ${SECS}s windows. Ctrl-C to stop."
  while :; do do_window "$SECS"; done
fi
