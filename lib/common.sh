#!/bin/bash
# DesktopLens — shared config loader + helpers. Sourced by every script.
DL_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DL_HOME

# launchd runs with a bare PATH — ensure Homebrew + system tools are findable
# BEFORE config (which may call `command -v`).
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Load user config, falling back to the committed example.
if   [ -f "$DL_HOME/config.sh" ];        then source "$DL_HOME/config.sh"
elif [ -f "$DL_HOME/config.example.sh" ]; then source "$DL_HOME/config.example.sh"
fi

# Defaults (only set if config didn't)
: "${DL_DATA_DIR:=$HOME/.local/share/desktoplens}"
: "${DL_WINDOW_SECONDS:=1800}"
: "${DL_SHOT_INTERVAL:=20}"
: "${DL_CTX_INTERVAL:=5}"
: "${DL_CAPTURE_AUDIO:=1}"
: "${DL_AUDIO_DEVICE:=:1}"
: "${DL_WHISPER_BIN:=$(command -v whisper-cli)}"
[ -z "$DL_WHISPER_BIN" ] && [ -x /opt/homebrew/bin/whisper-cli ] && DL_WHISPER_BIN=/opt/homebrew/bin/whisper-cli
: "${DL_WHISPER_MODEL:=$DL_DATA_DIR/models/ggml-base.en.bin}"
: "${DL_FFMPEG:=$(command -v ffmpeg)}"
[ -z "$DL_FFMPEG" ] && [ -x /opt/homebrew/bin/ffmpeg ] && DL_FFMPEG=/opt/homebrew/bin/ffmpeg
export DL_FFMPEG
: "${DL_CAPTURE_SYSTEM:=1}"        # capture system/meeting audio via ScreenCaptureKit (no output reroute)
: "${DL_SYSTEM_AUDIO_WHEN:=Microsoft Teams,zoom.us,CptHost,Webex,Google Meet}"  # only capture system audio when one of these is running; empty = always
: "${DL_SUMMARIZER_CMD:=}"

export RAW="$DL_DATA_DIR/raw" BUFFER="$DL_DATA_DIR/buffer" DIGESTS="$DL_DATA_DIR/digests"
export STATE="$DL_DATA_DIR/state" LOGS="$DL_DATA_DIR/logs"
export OCR_BIN="$DL_HOME/bin/lens-ocr"
export LENS_AUDIO="$DL_HOME/bin/lens-audio"
export BLOCKLIST_FILE="$STATE/blocklist.txt" PAUSE_FLAG="$STATE/PAUSED"
mkdir -p "$RAW" "$BUFFER" "$DIGESTS" "$STATE" "$LOGS"

# Seed a default blocklist on first run.
if [ ! -f "$BLOCKLIST_FILE" ]; then
  cat > "$BLOCKLIST_FILE" <<'EOF'
com.1password.1password
com.1password.1password-launcher
com.agilebits.onepassword
com.apple.keychainaccess
EOF
fi

# Frontmost app (LaunchServices; no TCC permission required).
lens_front_bundle() { local f; f=$(lsappinfo front 2>/dev/null)
  lsappinfo info -only bundleid "$f" 2>/dev/null | sed -E 's/.*"CFBundleIdentifier"="([^"]*)".*/\1/'; }
lens_front_name() { local f; f=$(lsappinfo front 2>/dev/null)
  lsappinfo info -only name "$f" 2>/dev/null | sed -E 's/.*"LSDisplayName"="([^"]*)".*/\1/'; }

# Capture suppressed? (paused OR frontmost app blocklisted)
lens_is_blocked() {
  [ -f "$PAUSE_FLAG" ] && return 0
  local bid; bid=$(lens_front_bundle); [ -z "$bid" ] && return 1
  grep -qiF "$bid" "$BLOCKLIST_FILE" 2>/dev/null && return 0
  return 1
}

# Defense-in-depth redaction on extracted text.
lens_redact() {
  sed -E -e 's/[0-9]{12,}/[REDACTED-NUM]/g' \
         -e 's/([Pp]assword[[:space:]:=]+)[^[:space:]]+/\1[REDACTED]/g'
}
