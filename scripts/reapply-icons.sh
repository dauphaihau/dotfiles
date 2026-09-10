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

apply_orca_icon() {
    local APP_PATH="/Applications/Orca.app"
    local ICON_PATH="$SCRIPT_DIR/../custom-icons-app/telegram-dark.icns"
    local BUNDLE_ICON_PATH="$APP_PATH/Contents/Resources/icon.icns"
    local RESOURCE_DIR="$APP_PATH/Contents/Resources/app.asar.unpacked/resources"
    local TEMP_DIR
    local PNG_ICON_PATH
    local PNG_TARGET_PATH
    local PNG_ICON_PATHS=(
        "$RESOURCE_DIR/icon.png"
        "$RESOURCE_DIR/app-icons/orca-watercolor.png"
        "$RESOURCE_DIR/app-icons/orca-blue.png"
    )

    apply_icon "$APP_PATH" "$ICON_PATH"

    if [[ ! -d "$APP_PATH" || ! -f "$ICON_PATH" ]]; then
        return
    fi

    # Orca loads these PNGs at startup and overrides the Dock/Finder icon.
    for PNG_TARGET_PATH in "${PNG_ICON_PATHS[@]}"; do
        if [[ ! -f "$PNG_TARGET_PATH" ]]; then
            echo "$(date): FAIL — Orca runtime icon not found: $PNG_TARGET_PATH" >> "$LOG"
            return 1
        fi
    done

    TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp/}orca-icon.XXXXXX")" || return 1
    PNG_ICON_PATH="$TEMP_DIR/icon.png"
    if ! sips -s format png "$ICON_PATH" --out "$PNG_ICON_PATH" >/dev/null; then
        rm -rf "$TEMP_DIR"
        echo "$(date): FAIL — could not convert Orca icon to PNG" >> "$LOG"
        return 1
    fi

    for PNG_TARGET_PATH in "${PNG_ICON_PATHS[@]}"; do
        if ! cp "$PNG_ICON_PATH" "$PNG_TARGET_PATH"; then
            rm -rf "$TEMP_DIR"
            echo "$(date): FAIL — Orca runtime icon $PNG_TARGET_PATH" >> "$LOG"
            return 1
        fi
        echo "$(date): OK — updated Orca runtime icon $PNG_TARGET_PATH" >> "$LOG"
    done
    rm -rf "$TEMP_DIR"

    if cp "$ICON_PATH" "$BUNDLE_ICON_PATH"; then
        touch "$APP_PATH"
        echo "$(date): OK — updated Orca bundle icon $BUNDLE_ICON_PATH" >> "$LOG"
    else
        echo "$(date): FAIL — Orca bundle icon $BUNDLE_ICON_PATH" >> "$LOG"
        return 1
    fi
}

apply_chatgpt_icon() {
    local APP_PATH="/Applications/ChatGPT.app"
    local ICON_PATH="$SCRIPT_DIR/../custom-icons-app/dark-chat-gpt.icns"
    local INFO_PLIST="$APP_PATH/Contents/Info.plist"
    local PNG_ICON_PATH="/tmp/dark-chat-gpt.png"
    local BUNDLE_ICON_PATHS=(
        "$APP_PATH/Contents/Resources/electron.icns"
        "$APP_PATH/Contents/Resources/app.icns"
        "$APP_PATH/Contents/Resources/icon-chatgpt.icns"
    )
    local PNG_ICON_PATHS=(
        "$APP_PATH/Contents/Resources/icon-chatgpt.png"
        "$APP_PATH/Contents/Resources/default_app/icon.png"
        "$APP_PATH/Contents/Resources/icon-codex-dark-color.png"
        "$APP_PATH/Contents/Resources/icon-codex-light.png"
    )
    local BUNDLE_ICON_PATH
    local PNG_TARGET_PATH

    apply_icon "$APP_PATH" "$ICON_PATH"

    if [[ ! -d "$APP_PATH" ]]; then
        return
    fi

    if [[ ! -f "$ICON_PATH" ]]; then
        return
    fi

    for BUNDLE_ICON_PATH in "${BUNDLE_ICON_PATHS[@]}"; do
        cp "$ICON_PATH" "$BUNDLE_ICON_PATH" && \
            echo "$(date): OK — updated ChatGPT bundle icon $BUNDLE_ICON_PATH" >> "$LOG" || \
            echo "$(date): FAIL — ChatGPT bundle icon $BUNDLE_ICON_PATH" >> "$LOG"
    done

    if [[ -f "$INFO_PLIST" ]]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile electron.icns" "$INFO_PLIST" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$INFO_PLIST" 2>/dev/null || true
        echo "$(date): OK — configured ChatGPT to use CFBundleIconFile" >> "$LOG"
    fi

    if sips -s format png "$ICON_PATH" --out "$PNG_ICON_PATH" >/dev/null 2>&1; then
        for PNG_TARGET_PATH in "${PNG_ICON_PATHS[@]}"; do
            cp "$PNG_ICON_PATH" "$PNG_TARGET_PATH" && \
                echo "$(date): OK — updated ChatGPT PNG icon $PNG_TARGET_PATH" >> "$LOG" || \
                echo "$(date): FAIL — ChatGPT PNG icon $PNG_TARGET_PATH" >> "$LOG"
        done
    else
        echo "$(date): FAIL — could not convert ChatGPT icon to PNG" >> "$LOG"
    fi

    touch "$APP_PATH"
}

refresh_icon_caches() {
    local USER_CACHE_DIR

    USER_CACHE_DIR="$(dirname "$(dirname "$TMPDIR")")/C"

    if [[ -d "$USER_CACHE_DIR" ]]; then
        rm -rf "$USER_CACHE_DIR/com.apple.dock.iconcache" \
               "$USER_CACHE_DIR/com.apple.iconservices"
    fi

    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
        -kill -r -domain local -domain system -domain user

    killall iconservicesagent 2>/dev/null || true
    killall Finder 2>/dev/null || true
    killall Dock
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
        orca)    apply_orca_icon ;;
        *)        echo "Unknown app: $1. Available: zalo whatsapp firefox wallper sigmaos chatgpt zed safari webstorm cursor steam orca" ;;
    esac
}

ALL_KEYS="zalo whatsapp firefox wallper sigmaos chatgpt zed safari webstorm cursor steam orca"

if [[ $# -eq 0 ]]; then
    for key in $ALL_KEYS; do
        run_icon "$key"
    done
else
    for key in "$@"; do
        run_icon "$key"
    done
fi

# Refresh macOS icon caches to show updated icons
refresh_icon_caches
