# Wiring DesktopLens to Claude (Cowork) for 30-minute digests

DesktopLens ships **buffer-only**: the daemon writes plain-text buffers to
`$DL_DATA_DIR/buffer/` and stops. To get Claude to condense them on a schedule,
keep the summarizer out of the repo and use a Claude **scheduled task** instead.

## Recommended setup

1. Point DesktopLens at a data dir Claude can read (your workspace), e.g. in `config.sh`:

   ```bash
   DL_DATA_DIR="$HOME/.local/share/desktoplens"   # or a Cowork-visible folder
   ```

2. Create a Claude scheduled task that runs every 30 minutes with a prompt like:

   > Read every file in `~/.local/share/desktoplens/buffer/`. Condense into a
   > digest (worked-on, decisions, numbers, people/meetings, open loops,
   > follow-ups). Append to `~/.local/share/desktoplens/digests/YYYY-MM-DD.md`.
   > Then delete the buffer files you consumed.

3. Leave `DL_SUMMARIZER_CMD=""` so the daemon doesn't also summarize.

This keeps the open-source tool free of any LLM dependency while giving *you*
high-quality Claude digests. Anyone else can instead set `DL_SUMMARIZER_CMD`
to `examples/ollama-digest.sh` for a fully local pipeline.
