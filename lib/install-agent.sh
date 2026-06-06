#!/bin/bash
# DesktopLens — install/uninstall the always-on LaunchAgent.
source "$(dirname "$0")/common.sh"
LABEL="com.desktoplens.capture"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
ACTION="${1:-install}"

if [ "$ACTION" = uninstall ]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
  launchctl unload "$PLIST" 2>/dev/null
  rm -f "$PLIST"
  echo "uninstalled $LABEL"
  exit 0
fi

mkdir -p "$HOME/Library/LaunchAgents"
sed -e "s#@DL_HOME@#$DL_HOME#g" -e "s#@DL_DATA_DIR@#$DL_DATA_DIR#g" \
    "$DL_HOME/launchagent/$LABEL.plist.template" > "$PLIST"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || launchctl load "$PLIST"
echo "installed $LABEL -> $PLIST"
echo "logs: $DL_DATA_DIR/logs/agent.{out,err}.log"
echo "NOTE: grant Screen Recording + Microphone to the agent's interpreter the first time."
