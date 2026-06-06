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
  echo "## Audio transcript (whisper.cpp, redacted)"
  if [ -f "$WDIR/audio.wav" ] && [ -n "$DL_WHISPER_BIN" ]; then
    "$DL_WHISPER_BIN" -m "$DL_WHISPER_MODEL" -f "$WDIR/audio.wav" -nt -otxt -of "$WDIR/audio" >/dev/null 2>&1
    if [ -s "$WDIR/audio.txt" ]; then lens_redact < "$WDIR/audio.txt"
    else echo "_(silence / no speech detected)_"; fi
  else
    echo "_(no audio captured)_"
  fi
} > "$OUT"

rm -rf "$WDIR"   # <-- raw media deleted; nothing visual/audio retained
echo "$OUT"
