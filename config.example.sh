#!/bin/bash
# DesktopLens configuration — copy to config.sh (gitignored) and edit.
# Find your audio index:  ffmpeg -f avfoundation -list_devices true -i ""

# Where ephemeral raw media, the text buffer, and digests live (NOT in the repo).
DL_DATA_DIR="${DL_DATA_DIR:-$HOME/.local/share/desktoplens}"

# Capture cadence
DL_WINDOW_SECONDS=1800     # length of one processed window (prod: 1800 = 30 min)
DL_SHOT_INTERVAL=20        # seconds between screenshots
DL_CTX_INTERVAL=5          # seconds between frontmost-app samples

# Audio
DL_CAPTURE_AUDIO=1         # 1 = capture audio, 0 = screen + app-context only
DL_AUDIO_DEVICE=":1"       # ffmpeg avfoundation audio index (":1" is usually the built-in mic)

# Transcription (whisper.cpp)
DL_WHISPER_BIN="${DL_WHISPER_BIN:-$(command -v whisper-cli)}"
DL_WHISPER_MODEL="${DL_WHISPER_MODEL:-$DL_DATA_DIR/models/ggml-base.en.bin}"

# Bring-your-own summarizer (optional). Receives the buffer file path as $1.
# Empty = leave the text buffer for an external consumer (a Claude scheduled task,
# examples/ollama-digest.sh, etc.). Example:
#   DL_SUMMARIZER_CMD="$HOME/dev/DesktopLens/examples/ollama-digest.sh"
DL_SUMMARIZER_CMD=""
