#!/bin/bash
# DesktopLens installer (macOS). Installs deps, compiles the OCR helper,
# downloads a Whisper model, and scaffolds config.sh.
set -euo pipefail
DL_HOME="$(cd "$(dirname "$0")" && pwd)"
cd "$DL_HOME"

[ "$(uname)" = "Darwin" ] || { echo "DesktopLens is macOS-only."; exit 1; }

echo "==> Checking dependencies"
if ! command -v brew >/dev/null; then
  echo "Homebrew required: https://brew.sh"; exit 1
fi
command -v ffmpeg      >/dev/null || brew install ffmpeg
command -v whisper-cli >/dev/null || brew install whisper-cpp

echo "==> Compiling Vision OCR helper"
swiftc -O -o bin/lens-ocr lib/lens-ocr.swift -framework Vision -framework AppKit
chmod +x bin/desktoplens lib/*.sh

echo "==> Config"
[ -f config.sh ] || { cp config.example.sh config.sh; echo "created config.sh (edit me)"; }
# shellcheck disable=SC1091
source config.sh
: "${DL_DATA_DIR:=$HOME/.local/share/desktoplens}"
mkdir -p "$DL_DATA_DIR/models"

echo "==> Whisper model"
MODEL="${DL_WHISPER_MODEL:-$DL_DATA_DIR/models/ggml-base.en.bin}"
if [ ! -f "$MODEL" ]; then
  echo "downloading ggml-base.en.bin (~142 MB)"
  curl -L --fail -o "$MODEL" \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
fi

echo "==> Audio devices (set DL_AUDIO_DEVICE in config.sh to the audio index you want):"
ffmpeg -hide_banner -f avfoundation -list_devices true -i "" 2>&1 | grep -A20 "audio devices" || true

cat <<EOF

Done. Next:
  1) Grant Screen Recording + Microphone to your terminal/agent in System Settings.
  2) Test it:        ./bin/desktoplens test
  3) Run always-on:  ./bin/desktoplens install-agent
EOF
