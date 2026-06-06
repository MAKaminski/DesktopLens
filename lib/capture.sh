#!/bin/bash
# DesktopLens — capture ONE window of N seconds into raw/<win>/.
# Screenshots every DL_SHOT_INTERVAL, frontmost-app samples every DL_CTX_INTERVAL,
# one audio WAV for the window (if DL_CAPTURE_AUDIO=1). Honors pause/blocklist.
source "$(dirname "$0")/common.sh"
DUR=${1:-$DL_WINDOW_SECONDS}
WIN="win_$(date +%Y%m%d_%H%M%S)"
WDIR="$RAW/$WIN"
mkdir -p "$WDIR"

if lens_is_blocked; then
  echo "SKIPPED (blocked/paused; front=$(lens_front_name))"
  rmdir "$WDIR" 2>/dev/null
  exit 7
fi

APID=""
if [ "$DL_CAPTURE_AUDIO" = "1" ]; then
  "$DL_FFMPEG" -nostdin -loglevel error -f avfoundation -i "$DL_AUDIO_DEVICE" \
         -t "$DUR" -ac 1 -ar 16000 -y "$WDIR/audio.wav" &
  APID=$!
fi

# System/meeting audio via ScreenCaptureKit (no output reroute). Gated to meeting apps.
SPID=""
if [ "$DL_CAPTURE_SYSTEM" = "1" ] && [ -x "$LENS_AUDIO" ]; then
  run_sys=1
  if [ -n "$DL_SYSTEM_AUDIO_WHEN" ]; then
    run_sys=0; OLDIFS=$IFS; IFS=,
    for app in $DL_SYSTEM_AUDIO_WHEN; do
      pgrep -i -f "$app" >/dev/null 2>&1 && { run_sys=1; break; }
    done
    IFS=$OLDIFS
  fi
  [ "$run_sys" = "1" ] && { "$LENS_AUDIO" "$WDIR/sysaudio.wav" "$DUR" 2>/dev/null & SPID=$!; }
fi

START=$(date +%s); last_shot=-999
while :; do
  now=$(date +%s); el=$((now-START))
  [ "$el" -ge "$DUR" ] && break
  if ! lens_is_blocked; then
    printf '%s | %s | %s\n' "$(date +%H:%M:%S)" "$(lens_front_name)" "$(lens_front_bundle)" >> "$WDIR/context.log"
    if [ $((el - last_shot)) -ge "$DL_SHOT_INTERVAL" ]; then
      # Prefer the native grantable helper; fall back to screencapture.
      { [ -x "$DL_HOME/bin/lens-shot" ] && "$DL_HOME/bin/lens-shot" "$WDIR/shot_${el}.jpg" 2>/dev/null; } \
        || screencapture -x -t jpg "$WDIR/shot_${el}.jpg" 2>/dev/null
      [ -s "$WDIR/shot_${el}.jpg" ] && last_shot=$el
    fi
  else
    printf '%s | [BLOCKED:%s] | suppressed\n' "$(date +%H:%M:%S)" "$(lens_front_name)" >> "$WDIR/context.log"
  fi
  sleep "$DL_CTX_INTERVAL"
done
[ -n "$APID" ] && wait "$APID" 2>/dev/null
[ -n "$SPID" ] && wait "$SPID" 2>/dev/null
echo "$WIN"
