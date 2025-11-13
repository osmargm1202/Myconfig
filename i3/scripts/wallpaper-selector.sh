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
            convert "$wallpaper" -resize 200x200^ -gravity center -extent 200x200 "$thumb" 2>/dev/null
            ((count++))
        fi
    done
    
    if [[ $count -gt 0 ]]; then
        echo "Generated $count thumbnail(s)"
    fi
}

# Function to get current monitor (where cursor is)
get_current_monitor() {
    # Try to get monitor where cursor is located using xdotool
    if command -v xdotool &>/dev/null; then
        local mouse_x mouse_y
        mouse_x=$(xdotool getmouselocation --shell 2>/dev/null | grep "X=" | cut -d= -f2)
        mouse_y=$(xdotool getmouselocation --shell 2>/dev/null | grep "Y=" | cut -d= -f2)
        
        if [[ -n "$mouse_x" && -n "$mouse_y" ]]; then
            # Get all connected monitors and their geometry
            while IFS= read -r line; do
                local monitor=$(echo "$line" | awk '{print $1}')
                local geometry=$(xrandr --query | grep "^$monitor" | grep -oE '[0-9]+x[0-9]+\+[0-9]+\+[0-9]+' | head -n1)
                
                if [[ -n "$geometry" ]]; then
                    local width=$(echo "$geometry" | cut -d+ -f1 | cut -dx -f1)
                    local height=$(echo "$geometry" | cut -d+ -f1 | cut -dx -f2)
                    local x_pos=$(echo "$geometry" | cut -d+ -f2)
                    local y_pos=$(echo "$geometry" | cut -d+ -f3)
                    local end_x=$((x_pos + width))
                    local end_y=$((y_pos + height))
                    
                    # Check if cursor is within this monitor's bounds
                    if [[ $mouse_x -ge $x_pos && $mouse_x -lt $end_x && \
                          $mouse_y -ge $y_pos && $mouse_y -lt $end_y ]]; then
                        echo "$monitor"
                        return 0
                    fi
                fi
            done < <(xrandr --query | grep " connected" | awk '{print $1}')
        fi
    fi
    
    # Fallback: get primary monitor
    local primary
    primary=$(xrandr --query | grep " connected" | grep "primary" | awk '{print $1}' | head -n1)
    
    if [[ -n "$primary" ]]; then
        echo "$primary"
        return 0
    fi
    
    # Last fallback: first connected monitor
    xrandr --query | grep " connected" | awk '{print $1}' | head -n1
}

# Function to apply wallpaper
apply_wallpaper() {
    local wallpaper="$1"
    
    if [[ ! -f "$wallpaper" ]]; then
        echo "Error: Wallpaper not found: $wallpaper" >&2
        return 1
    fi
    
    # Get current monitor
    local current_monitor
    current_monitor=$(get_current_monitor)
    
    # Try xwallpaper first (better multi-monitor support - can target specific monitor)
    if command -v xwallpaper &>/dev/null; then
        if [[ -n "$current_monitor" ]]; then
            # Apply wallpaper only to the current monitor
            xwallpaper --output "$current_monitor" --stretch "$wallpaper" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                # Save current wallpaper to state file
                echo "$wallpaper" > "$STATE_FILE"
                
                # Send notification if available
                if command -v notify-send &>/dev/null; then
                    notify-send "Wallpaper Changed" "$(basename "$wallpaper") on $current_monitor" -i "$wallpaper" -t 2000 2>/dev/null || true
                fi
                
                echo "✓ Wallpaper changed to: $(basename "$wallpaper") on monitor: $current_monitor"
                return 0
            fi
        fi
        # If xwallpaper failed or no monitor detected, fall through to feh with workaround
    fi
    
    # Fallback to feh - feh doesn't support single monitor, need xwallpaper
    if command -v feh &>/dev/null; then
        echo "Error: feh cannot apply wallpaper to a single monitor." >&2
        echo "  Current monitor detected: ${current_monitor:-none}" >&2
        echo "  To apply wallpaper to only the current monitor, install xwallpaper:" >&2
        echo "  sudo pacman -S xwallpaper" >&2
        echo "" >&2
        echo "  Applying to all monitors with feh (not recommended for single-monitor setup)..." >&2
        
        # Ask user if they want to continue
        read -p "Continue applying to all monitors? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Operation cancelled."
            return 1
        fi
        
        feh --bg-fill "$wallpaper" 2>/dev/null
        
        # Save current wallpaper to state file
        echo "$wallpaper" > "$STATE_FILE"
        
        # Send notification if available
        if command -v notify-send &>/dev/null; then
            notify-send "Wallpaper Changed" "$(basename "$wallpaper") (all monitors - install xwallpaper for single monitor)" -i "$wallpaper" -t 3000 2>/dev/null || true
        fi
        
        echo "✓ Wallpaper changed to: $(basename "$wallpaper") (applied to all monitors)"
        echo "  ⚠ Install xwallpaper for single-monitor support: sudo pacman -S xwallpaper"
        return 0
    else
        echo "Error: feh or xwallpaper not installed." >&2
        echo "  Install with: sudo pacman -S feh xwallpaper" >&2
        echo "  For single-monitor wallpaper support, install xwallpaper: sudo pacman -S xwallpaper" >&2
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
        -theme-str 'element-icon { size: 5em; }' \
        -theme-str 'window { width: 40%; height: 65%; location: center; anchor: center; x-offset: 0; y-offset: 0; }' \
        -theme-str 'listview { columns: 5; lines: 1; spacing: 5px; }' \
        -theme-str 'element { orientation: vertical; padding: 5px; }' \
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

