#!/bin/bash
# Example bring-your-own summarizer: condense a DesktopLens buffer with a local Ollama model.
# Wire it up in config.sh:  DL_SUMMARIZER_CMD="$HOME/dev/DesktopLens/examples/ollama-digest.sh"
# Requires: ollama installed and a model pulled (e.g. `ollama pull llama3.1`).
set -euo pipefail
BUFFER_FILE="${1:?usage: ollama-digest.sh <buffer.md>}"
MODEL="${OLLAMA_MODEL:-llama3.1}"
DIGEST_DIR="$(cd "$(dirname "$BUFFER_FILE")/../digests" && pwd)"
mkdir -p "$DIGEST_DIR"
OUT="$DIGEST_DIR/$(date +%Y-%m-%d).md"

PROMPT='You are summarizing 30 minutes of a user\x27s desktop activity captured as OCR
text, an app-usage log, and an audio transcript. Produce a tight digest: what they
worked on, key decisions/numbers, people/meetings, open loops, and any follow-ups.
Be specific. Here is the buffer:'

{
  echo "## $(date '+%H:%M') — ${BUFFER_FILE##*/}"
  printf '%s\n\n' "$PROMPT" | cat - "$BUFFER_FILE" | ollama run "$MODEL"
  echo
} >> "$OUT"
echo "appended digest -> $OUT"
