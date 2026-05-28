#!/usr/bin/env bash
# ==================================================
#  Daily wallpaper rotator — shuffle without repeat
#  Queue: ~/.local/share/wallpaper-daily/queue
#  Exhausted queue is reshuffled before repeating.
# ==================================================

QUEUE_DIR="$HOME/.local/share/wallpaper-daily"
QUEUE_FILE="$QUEUE_DIR/queue"
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
WALL_DIR="$PICTURES_DIR/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"

# shellcheck source=/dev/null
. "$SCRIPTSDIR/WallpaperCmd.sh"

# Ensure daemon is running
if ! "$WWW_CMD" query >/dev/null 2>&1; then
    "$WWW_DAEMON" "${WWW_DAEMON_ARGS[@]}" &
    sleep 2
fi

# Rebuild queue when empty
mkdir -p "$QUEUE_DIR"
if [[ ! -s "$QUEUE_FILE" ]]; then
    find -L "$WALL_DIR" -type f \( \
        -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \
        -o -name "*.webp" -o -name "*.bmp" -o -name "*.gif" \
        -o -name "*.tiff" -o -name "*.tga" -o -name "*.pnm" \
    \) | shuf > "$QUEUE_FILE"
fi

# Pop first wallpaper
WALL=$(head -1 "$QUEUE_FILE")
[[ -z "$WALL" ]] && { echo "WallpaperDaily: no wallpapers found in $WALL_DIR" >&2; exit 1; }
sed -i '1d' "$QUEUE_FILE"

# Transition params (match WallpaperRandom.sh style)
SWWW_PARAMS=""
if [[ "$WWW_CMD" == "swww" || "$WWW_CMD" == "awww" ]]; then
    SWWW_PARAMS="--transition-fps 30 --transition-type random --transition-duration 1 --transition-bezier .43,1.19,1,.4"
fi

# Apply to all connected monitors
while IFS= read -r monitor; do
    "$WWW_CMD" img -o "$monitor" "$WALL" $SWWW_PARAMS
done < <(hyprctl monitors -j | jq -r '.[].name')

# Regenerate wallust colors and refresh UI
"$SCRIPTSDIR/WallustSwww.sh" "$WALL"
sleep 2
"$SCRIPTSDIR/Refresh.sh"
