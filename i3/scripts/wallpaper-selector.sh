#!/usr/bin/env bash

# Visual Wallpaper Selector with Large Thumbnails
# Uses rofi with large icon display to browse and select wallpapers

WALLPAPERS_DIR="$HOME/Wallpapers"
STATE_FILE="$HOME/.config/current_wallpaper"
CACHE_DIR="$HOME/.cache/wallpaper-thumbnails"

# Create cache directory
mkdir -p "$CACHE_DIR"

# Function to generate thumbnails
generate_thumbnails() {
    # Check if imagemagick is installed
    if ! command -v convert &>/dev/null; then
        echo "Warning: ImageMagick not installed. Install with: sudo pacman -S imagemagick" >&2
        return 1
    fi
    
    local count=0
    for wallpaper in "$WALLPAPERS_DIR"/*.{jpg,jpeg,png,bmp,webp}; do
        [[ -f "$wallpaper" ]] || continue
        local basename=$(basename "$wallpaper")
        local name="${basename%.*}"
        local thumb="$CACHE_DIR/${name}.png"
        
        # Generate thumbnail if not exists or if source is newer
        if [[ ! -f "$thumb" ]] || [[ "$wallpaper" -nt "$thumb" ]]; then
            convert "$wallpaper" -resize 400x400^ -gravity center -extent 400x400 "$thumb" 2>/dev/null
            ((count++))
        fi
    done
    
    if [[ $count -gt 0 ]]; then
        echo "Generated $count thumbnail(s)"
    fi
}

# Function to apply wallpaper
apply_wallpaper() {
    local wallpaper="$1"
    
    if [[ ! -f "$wallpaper" ]]; then
        echo "Error: Wallpaper not found: $wallpaper" >&2
        return 1
    fi
    
    # Set wallpaper with feh
    if command -v feh &>/dev/null; then
        feh --bg-fill "$wallpaper" 2>/dev/null
        
        # Save current wallpaper to state file
        echo "$wallpaper" > "$STATE_FILE"
        
        # Send notification if available
        if command -v notify-send &>/dev/null; then
            notify-send "Wallpaper Changed" "$(basename "$wallpaper")" -i "$wallpaper" -t 2000 2>/dev/null || true
        fi
        
        echo "✓ Wallpaper changed to: $(basename "$wallpaper")"
        return 0
    else
        echo "Error: feh not installed. Install with: sudo pacman -S feh" >&2
        return 1
    fi
}

# Function to select wallpaper
select_wallpaper() {
    # Generate thumbnails
    generate_thumbnails
    
    # Build arrays for options and full paths
    local -a options=()
    local -a wallpapers=()
    local -a icons=()
    
    for wallpaper in "$WALLPAPERS_DIR"/*.{jpg,jpeg,png,bmp,webp}; do
        [[ -f "$wallpaper" ]] || continue
        local basename=$(basename "$wallpaper")
        local name="${basename%.*}"
        local thumb="$CACHE_DIR/${name}.png"
        
        # Add to arrays
        options+=("$name")
        wallpapers+=("$wallpaper")
        
        # Add icon path if thumbnail exists
        if [[ -f "$thumb" ]]; then
            icons+=("$thumb")
        else
            icons+=("")
        fi
    done
    
    # Check if any wallpapers found
    if [[ ${#options[@]} -eq 0 ]]; then
        notify-send "Wallpaper Selector" "No wallpapers found in $WALLPAPERS_DIR" 2>/dev/null || true
        echo "Error: No wallpapers found in $WALLPAPERS_DIR"
        return 1
    fi
    
    # Build rofi input with icon paths using null separator format
    local rofi_input=""
    for i in "${!options[@]}"; do
        local name="${options[i]}"
        local thumb="${icons[i]}"
        
        if [[ -f "$thumb" ]]; then
            # Format: name\0icon\x1ficon_path
            rofi_input+="${name}\0icon\x1f${thumb}\n"
        else
            # No icon available
            rofi_input+="${name}\n"
        fi
    done
    
    # Show in rofi with large thumbnails
    local selected
    selected=$(echo -en "$rofi_input" | \
        rofi -dmenu -i \
        -p "Select Wallpaper" \
        -show-icons \
        -theme-str 'element-icon { size: 16em; }' \
        -theme-str 'window { width: 90%; height: 85%; }' \
        -theme-str 'window { location: northwest; anchor: northwest; x-offset: 5%; y-offset: 5%; }' \
        -theme-str 'listview { columns: 3; lines: 3; spacing: 20px; }' \
        -theme-str 'element { orientation: vertical; padding: 15px; }' \
        -theme-str 'element-text { horizontal-align: 0.5; margin-top: 10px; }' \
        -theme-str 'element-icon { border-radius: 8px; }' \
        -theme-str 'element selected { background-color: #1e3a5f; border-radius: 10px; }' \
        -selection-row 0 \
        -scroll-method 1)
    
    # Apply selected wallpaper
    if [[ -n "$selected" ]]; then
        for i in "${!options[@]}"; do
            if [[ "${options[i]}" == "$selected" ]]; then
                apply_wallpaper "${wallpapers[i]}"
                return 0
            fi
        done
    fi
    
    return 0
}

# Main execution
select_wallpaper "$@"

