#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$HOME/Library/Logs/icon-watcher.log"

apply_icon() {
    local APP_PATH="$1"
    local ICON_PATH="$2"

    if [[ ! -d "$APP_PATH" ]]; then
        echo "$(date): SKIP — $APP_PATH not found" >> "$LOG"
        return
    fi

    if [[ ! -f "$ICON_PATH" ]]; then
        echo "$(date): SKIP — icon $ICON_PATH not found" >> "$LOG"
        return
    fi

    fileicon set "$APP_PATH" "$ICON_PATH" && \
        echo "$(date): OK — applied icon to $APP_PATH" >> "$LOG" || \
        echo "$(date): FAIL — $APP_PATH" >> "$LOG"
}

apply_chatgpt_icon() {
    local APP_PATH="/Applications/ChatGPT.app"
    local ICON_PATH="$SCRIPT_DIR/../custom-icons-app/dark-chat-gpt.icns"
    local BUNDLE_ICON_PATH="$APP_PATH/Contents/Resources/electron.icns"

    apply_icon "$APP_PATH" "$ICON_PATH"

    if [[ ! -d "$APP_PATH" ]]; then
        return
    fi

    if [[ ! -f "$ICON_PATH" ]]; then
        return
    fi

    cp "$ICON_PATH" "$BUNDLE_ICON_PATH" && \
        touch "$APP_PATH" && \
        echo "$(date): OK — updated ChatGPT bundle icon $BUNDLE_ICON_PATH" >> "$LOG" || \
        echo "$(date): FAIL — ChatGPT bundle icon $BUNDLE_ICON_PATH" >> "$LOG"
}

run_icon() {
    case "$1" in
        zalo)     apply_icon "/Applications/Zalo.app"                       "$SCRIPT_DIR/../custom-icons-app/zalo.icns" ;;
        whatsapp) apply_icon "/Applications/wa.app"                         "$SCRIPT_DIR/../custom-icons-app/whatsapp.icns" ;;
        firefox)  apply_icon "/Applications/Firefox Developer Edition.app"  "$SCRIPT_DIR/../custom-icons-app/firefox.icns" ;;
        wallper)  apply_icon "/Applications/Wallper.app"                    "$SCRIPT_DIR/../custom-icons-app/wallper.icns" ;;
        sigmaos)  apply_icon "/Applications/SigmaOS.app"                    "$SCRIPT_DIR/../custom-icons-app/sigma-os.icns" ;;
        chatgpt)  apply_chatgpt_icon ;;
        zed)      apply_icon "/Applications/Zed.app"                        "$SCRIPT_DIR/../custom-icons-app/zed-ide.icns" ;;
        safari)   apply_icon "/Applications/Safari Technology Preview.app"  "$SCRIPT_DIR/../custom-icons-app/safari.icns" ;;
        webstorm)   apply_icon "/Applications/Webstorm.app"                 "$SCRIPT_DIR/../custom-icons-app/webstorm.icns" ;;
        cursor)   apply_icon "/Applications/Cursor.app"                   "$SCRIPT_DIR/../custom-icons-app/cursor.icns" ;;
        steam)   apply_icon "/Applications/Steam.app"                   "$SCRIPT_DIR/../custom-icons-app/steam.icns" ;;
        *)        echo "Unknown app: $1. Available: zalo whatsapp firefox wallper sigmaos chatgpt zed safari" ;;
    esac
}

ALL_KEYS="zalo whatsapp firefox wallper sigmaos chatgpt zed safari"

if [[ $# -eq 0 ]]; then
    for key in $ALL_KEYS; do
        run_icon "$key"
    done
else
    for key in "$@"; do
        run_icon "$key"
    done
fi

# Refresh Launch Services and Dock to show updated icons
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -kill -r -domain local -domain system -domain user
killall Dock
