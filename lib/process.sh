#!/bin/bash
# DesktopLens — turn one captured window into a TEXT buffer, then DELETE raw media.
# Output: buffer/<win>.md  (app log + OCR text + transcript). No video/audio kept.
source "$(dirname "$0")/common.sh"
WIN="$1"; [ -z "$WIN" ] && { echo "usage: process.sh <win>"; exit 1; }
WDIR="$RAW/$WIN"; OUT="$BUFFER/${WIN}.md"
[ -d "$WDIR" ] || { echo "no such window: $WDIR"; exit 1; }

{
  echo "# DesktopLens window $WIN"
  echo "_processed: $(date)_"
  echo
  echo "## Active apps / windows (sampled)"
  echo '```'; cat "$WDIR/context.log" 2>/dev/null; echo '```'
  echo
  echo "## Screen text (Vision OCR, redacted)"
  shopt -s nullglob
  for img in "$WDIR"/shot_*.jpg; do
    echo; echo "### frame ${img##*/}"
    "$OCR_BIN" "$img" 2>/dev/null | lens_redact
  done
  shopt -u nullglob
  echo
  echo "## Your mic transcript (whisper.cpp, redacted)"
  if [ -f "$WDIR/audio.wav" ] && [ -n "$DL_WHISPER_BIN" ]; then
    "$DL_WHISPER_BIN" -m "$DL_WHISPER_MODEL" -f "$WDIR/audio.wav" -nt -otxt -of "$WDIR/audio" >/dev/null 2>&1
    if [ -s "$WDIR/audio.txt" ]; then lens_redact < "$WDIR/audio.txt"
    else echo "_(silence / no speech detected)_"; fi
  else
    echo "_(no mic audio captured)_"
  fi
  echo
  echo "## Meeting / system audio transcript (others — ScreenCaptureKit, redacted)"
  if [ -f "$WDIR/sysaudio.wav" ] && [ -n "$DL_WHISPER_BIN" ]; then
    "$DL_FFMPEG" -nostdin -loglevel error -i "$WDIR/sysaudio.wav" -ac 1 -ar 16000 -sample_fmt s16 -y "$WDIR/sys16.wav" 2>/dev/null
    "$DL_WHISPER_BIN" -m "$DL_WHISPER_MODEL" -f "$WDIR/sys16.wav" -nt -otxt -of "$WDIR/sys16" >/dev/null 2>&1
    if [ -s "$WDIR/sys16.txt" ]; then lens_redact < "$WDIR/sys16.txt"
    else echo "_(no system speech detected)_"; fi
  else
    echo "_(no system audio this window — not in a meeting)_"
  fi
} > "$OUT"

rm -rf "$WDIR"   # <-- raw media deleted; nothing visual/audio retained
echo "$OUT"
