# DesktopLens

Ambient, on-device context capture for macOS. DesktopLens watches your screen,
mic, and active apps, reduces each window of activity to **plain text on your
machine**, and then **deletes the raw media**. The text buffer is yours to feed
to any summarizer — a local LLM, or a Claude scheduled task — so an assistant can
stay continuously aware of what you're doing **without ever storing video or audio**.

> **Privacy model:** screenshots and audio exist only for the seconds it takes to
> OCR and transcribe them, then they're `rm`'d. Only redacted text persists, in a
> directory you control. Capture is suppressed for blocklisted apps and while paused.

## How it works

| Stage | What runs | Output | Raw retention |
|---|---|---|---|
| Capture | `screencapture` every N s, mic via `ffmpeg`, frontmost app via `lsappinfo` | JPEG / WAV / log | seconds–minutes |
| Process | Apple **Vision** OCR on frames, **whisper.cpp** on audio | redacted text | raw deleted immediately |
| Consume | your summarizer (Ollama / Claude task) reads the buffer | digest | buffer cleared by you |

Everything runs locally. Nothing is uploaded by DesktopLens itself.

## Requirements

- **macOS** (Apple Silicon or Intel). DesktopLens is macOS-only by design — it uses
  `screencapture`, AVFoundation, Apple Vision, and LaunchServices.
- [Homebrew](https://brew.sh), plus `ffmpeg` and `whisper-cpp` (the installer adds them).
- Xcode command-line tools (`swiftc`) to compile the OCR helper.

## Install

```bash
git clone https://github.com/MAKaminski/DesktopLens ~/dev/DesktopLens
cd ~/dev/DesktopLens
./install.sh          # deps + compile OCR + download model + scaffold config.sh
```

Then grant **Screen Recording** and **Microphone** to your terminal (or the
LaunchAgent's interpreter) in *System Settings → Privacy & Security*.

## Use

```bash
./bin/desktoplens test            # 30-second proof: capture → text → delete
./bin/desktoplens run             # foreground capture loop (30-min windows)
./bin/desktoplens install-agent   # always-on background LaunchAgent
./bin/desktoplens pause | resume  # suppress / resume capture
./bin/desktoplens status          # config + state
./bin/desktoplens block com.acme.app   # never capture while this app is frontmost
```

## Configuration

Copy `config.example.sh` → `config.sh` (the installer does this) and edit:

| Key | Default | Meaning |
|---|---|---|
| `DL_DATA_DIR` | `~/.local/share/desktoplens` | where raw (briefly), buffer, digests live |
| `DL_WINDOW_SECONDS` | `1800` | length of one processed window (30 min) |
| `DL_SHOT_INTERVAL` | `20` | seconds between screenshots |
| `DL_CTX_INTERVAL` | `5` | seconds between frontmost-app samples |
| `DL_CAPTURE_AUDIO` | `1` | `0` = screen + app context only |
| `DL_AUDIO_DEVICE` | `:1` | ffmpeg avfoundation audio index |
| `DL_WHISPER_MODEL` | `…/ggml-base.en.bin` | whisper.cpp model path |
| `DL_CAPTURE_SYSTEM` | `1` | capture meeting/system audio via ScreenCaptureKit (no reroute) |
| `DL_SYSTEM_AUDIO_WHEN` | Teams,Zoom,Webex,Meet | only capture system audio when one of these apps runs; empty = always |
| `DL_SUMMARIZER_CMD` | _(empty)_ | optional: command that receives the buffer path |

## The summarizer is yours (bring-your-own)

DesktopLens stops at a clean text buffer on purpose — it ships with **no LLM
dependency**. Pick a path:

- **Local, fully offline** — set `DL_SUMMARIZER_CMD` to
  [`examples/ollama-digest.sh`](examples/ollama-digest.sh) (needs Ollama).
- **Claude** — leave `DL_SUMMARIZER_CMD` empty and run a Claude scheduled task
  over the buffer dir. See [`examples/claude-cowork-digest.md`](examples/claude-cowork-digest.md).
- **Anything else** — any script that takes a buffer file path as `$1`.

## Privacy & guardrails

- **No media retention.** `lib/process.sh` `rm -rf`'s each window's frames and WAV
  right after extracting text. Only redacted `.md` buffers remain.
- **App blocklist.** Capture is skipped whenever a blocklisted app is frontmost
  (defaults: 1Password, Keychain). `desktoplens block <bundle.id>` to add more.
- **Pause switch.** `desktoplens pause` drops a flag the loop checks every cycle.
- **Redaction.** Long digit runs and `password:` values are masked in the text.
- **Audio capture and screen recording may be subject to consent laws and
  workplace policy.** You are responsible for using DesktopLens lawfully where you are.

## Meeting / system audio (the far side of calls)

DesktopLens captures the other side of meetings with **ScreenCaptureKit** — a
digital tap of system audio that needs **no virtual device, no output rerouting,
and never changes your volume**. Your mic and the system audio are captured
separately and transcribed as labeled sections.

It's gated to meeting apps so it doesn't transcribe your music: `DL_SYSTEM_AUDIO_WHEN`
lists the apps that trigger it (default: Teams, Zoom, Webex, Meet); set it empty to
always capture. Toggle the whole feature with `DL_CAPTURE_SYSTEM`. (BlackHole is
**not** required — and rerouting your default output to a Multi-Output device is
explicitly avoided, since macOS can't volume-control one.)

## Roadmap

- Optional URL-aware blocklisting for browser tabs (needs Automation permission).
- Cross-platform capture backends (Linux/Windows) — contributions welcome.
- Menu-bar control app.

## License

MIT © 2026 Michael Kaminski. See [LICENSE](LICENSE).
