#!/usr/bin/env bash
#
# Wallpaper Helper - Funciones reutilizables para manejo de wallpapers por monitor
# Usado por display-manager y autorandr hooks
#

# Function to apply wallpaper to a specific monitor
# Usage: apply_wallpaper_to_monitor <monitor> <wallpaper_path>
apply_wallpaper_to_monitor() {
    local monitor="$1"
    local wallpaper="$2"
    
    if [[ -z "$monitor" || -z "$wallpaper" ]]; then
        echo "Error: apply_wallpaper_to_monitor requires monitor and wallpaper arguments" >&2
        return 1
    fi
    
    if [[ ! -f "$wallpaper" ]]; then
        echo "Warning: Wallpaper not found: $wallpaper (skipping monitor $monitor)" >&2
        return 1
    fi
    
    # Verify monitor is connected
    local connected_monitors
    connected_monitors=$(xrandr --query | grep " connected" | awk '{print $1}')
    if ! echo "$connected_monitors" | grep -q "^$monitor$"; then
        echo "Warning: Monitor $monitor is not connected, skipping wallpaper application" >&2
        return 1
    fi
    
    # Try xwallpaper first (best multi-monitor support - applies to specific monitor only)
    if command -v xwallpaper &>/dev/null; then
        # xwallpaper --output applies to specific monitor only
        if xwallpaper --output "$monitor" --stretch "$wallpaper" 2>/dev/null; then
            return 0
        else
            echo "Warning: Failed to apply wallpaper to $monitor with xwallpaper" >&2
        fi
    fi
    
    # Fallback to feh (applies to all monitors, not ideal but better than nothing)
    if command -v feh &>/dev/null; then
        echo "Warning: Using feh fallback - wallpaper will be applied to all monitors" >&2
        feh --bg-fill "$wallpaper" 2>/dev/null
        return 0
    fi
    
    echo "Error: Neither xwallpaper nor feh is installed" >&2
    return 1
}

# Function to get current wallpaper for a monitor
# Since xwallpaper doesn't have --get, we maintain a state file
# Usage: get_current_wallpaper_for_monitor <monitor>
get_current_wallpaper_for_monitor() {
    local monitor="$1"
    local state_file="$HOME/.config/wallpaper-state.json"
    
    if [[ -z "$monitor" ]]; then
        echo "Error: get_current_wallpaper_for_monitor requires monitor argument" >&2
        return 1
    fi
    
    # Try to read from state file
    if [[ -f "$state_file" ]]; then
        # Use jq if available, otherwise use grep/sed
        if command -v jq &>/dev/null; then
            jq -r ".[\"$monitor\"] // empty" "$state_file" 2>/dev/null
        else
            # Fallback: simple grep/sed parsing (basic JSON)
            grep -o "\"$monitor\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$state_file" 2>/dev/null | \
                sed -n 's/.*"\([^"]*\)"$/\1/p'
        fi
    fi
}

# Function to save wallpaper state for a monitor
# Usage: save_wallpaper_state <monitor> <wallpaper_path>
save_wallpaper_state() {
    local monitor="$1"
    local wallpaper="$2"
    local state_file="$HOME/.config/wallpaper-state.json"
    
    if [[ -z "$monitor" || -z "$wallpaper" ]]; then
        return 1
    fi
    
    # Create config directory if it doesn't exist
    mkdir -p "$HOME/.config"
    
    # Update JSON file
    if command -v jq &>/dev/null; then
        # Use jq for proper JSON handling
        if [[ -f "$state_file" ]]; then
            jq ".[\"$monitor\"] = \"$wallpaper\"" "$state_file" > "${state_file}.tmp" && \
                mv "${state_file}.tmp" "$state_file"
        else
            echo "{\"$monitor\": \"$wallpaper\"}" > "$state_file"
        fi
    else
        # Fallback: simple JSON manipulation (not perfect but works for our use case)
        local temp_file="${state_file}.tmp"
        local found=false
        
        if [[ -f "$state_file" ]]; then
            # Check if monitor already exists in file
            if grep -q "\"$monitor\"" "$state_file"; then
                # Replace existing entry
                sed "s|\"$monitor\"[[:space:]]*:[[:space:]]*\"[^\"]*\"|\"$monitor\": \"$wallpaper\"|g" \
                    "$state_file" > "$temp_file"
                found=true
            fi
        fi
        
        if [[ "$found" == false ]]; then
            # Add new entry
            if [[ -f "$state_file" ]]; then
                # Remove last } and add new entry
                sed '$ s/}$//' "$state_file" > "$temp_file"
                echo ", \"$monitor\": \"$wallpaper\"}" >> "$temp_file"
            else
                echo "{\"$monitor\": \"$wallpaper\"}" > "$temp_file"
            fi
        fi
        
        mv "$temp_file" "$state_file"
    fi
}

# Function to get all connected monitors
# Usage: get_connected_monitors
get_connected_monitors() {
    xrandr --query | grep " connected" | awk '{print $1}'
}

# Function to get all monitors from state file (including disconnected ones)
# Usage: get_all_monitors_from_state
get_all_monitors_from_state() {
    local state_file="$HOME/.config/wallpaper-state.json"
    
    if [[ ! -f "$state_file" ]]; then
        return 0
    fi
    
    if command -v jq &>/dev/null; then
        jq -r 'keys[]' "$state_file" 2>/dev/null
    else
        # Fallback: simple grep/sed parsing
        grep -o "\"[^\"]*\"[[:space:]]*:" "$state_file" 2>/dev/null | \
            sed 's/"\([^"]*\)".*/\1/'
    fi
}

# Function to save wallpapers for all monitors to a profile
# IMPORTANT: Saves ALL monitors that have wallpapers in state, not just connected ones
# This ensures wallpapers are preserved even when monitors are disconnected
# Usage: save_wallpapers_to_profile <profile_name>
save_wallpapers_to_profile() {
    local profile_name="$1"
    local profile_dir="$HOME/.config/autorandr/$profile_name"
    local wallpapers_file="$profile_dir/wallpapers.json"
    local state_file="$HOME/.config/wallpaper-state.json"
    
    if [[ -z "$profile_name" ]]; then
        echo "Error: save_wallpapers_to_profile requires profile name" >&2
        return 1
    fi
    
    # Create profile directory if it doesn't exist
    mkdir -p "$profile_dir"
    
    # Get all monitors that have wallpapers in state (including disconnected ones)
    local all_monitors_in_state
    all_monitors_in_state=$(get_all_monitors_from_state)
    
    # Also get currently connected monitors to save their current wallpapers
    local connected_monitors
    connected_monitors=$(get_connected_monitors)
    
    # Build JSON object with monitor->wallpaper mappings
    local json_content="{"
    local first=true
    local saved_any=false
    
    # First, save wallpapers for all monitors in state (preserves disconnected monitors)
    while IFS= read -r monitor; do
        [[ -z "$monitor" ]] && continue
        
        local wallpaper
        wallpaper=$(get_current_wallpaper_for_monitor "$monitor")
        
        if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
            if [[ "$first" == true ]]; then
                first=false
            else
                json_content+=", "
            fi
            json_content+="\"$monitor\": \"$wallpaper\""
            saved_any=true
        fi
    done <<< "$all_monitors_in_state"
    
    # Then, save wallpapers for currently connected monitors (in case they're not in state yet)
    while IFS= read -r monitor; do
        [[ -z "$monitor" ]] && continue
        
        # Skip if already saved
        if echo "$all_monitors_in_state" | grep -q "^$monitor$"; then
            continue
        fi
        
        local wallpaper
        wallpaper=$(get_current_wallpaper_for_monitor "$monitor")
        
        # If no wallpaper in state, try to get from current_wallpaper file (legacy)
        if [[ -z "$wallpaper" && -f "$HOME/.config/current_wallpaper" ]]; then
            local legacy_wallpaper
            legacy_wallpaper=$(cat "$HOME/.config/current_wallpaper" 2>/dev/null)
            # Only use if file exists
            if [[ -n "$legacy_wallpaper" && -f "$legacy_wallpaper" ]]; then
                wallpaper="$legacy_wallpaper"
                # Save it to state for this monitor
                save_wallpaper_state "$monitor" "$wallpaper"
            fi
        fi
        
        if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
            if [[ "$first" == true ]]; then
                first=false
            else
                json_content+=", "
            fi
            json_content+="\"$monitor\": \"$wallpaper\""
            saved_any=true
        fi
    done <<< "$connected_monitors"
    
    json_content+="}"
    
    # Save to profile directory (even if empty, to preserve structure)
    echo "$json_content" > "$wallpapers_file"
    
    # Also update global state file for all connected monitors
    while IFS= read -r monitor; do
        [[ -z "$monitor" ]] && continue
        local wallpaper
        wallpaper=$(get_current_wallpaper_for_monitor "$monitor")
        if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
            save_wallpaper_state "$monitor" "$wallpaper"
        fi
    done <<< "$connected_monitors"
    
    return 0
}

# Function to restore wallpapers from a profile
# Usage: restore_wallpapers_from_profile <profile_name>
restore_wallpapers_from_profile() {
    local profile_name="$1"
    local profile_dir="$HOME/.config/autorandr/$profile_name"
    local wallpapers_file="$profile_dir/wallpapers.json"
    
    if [[ -z "$profile_name" ]]; then
        echo "Error: restore_wallpapers_from_profile requires profile name" >&2
        return 1
    fi
    
    if [[ ! -f "$wallpapers_file" ]]; then
        # No wallpapers saved for this profile, skip silently
        return 0
    fi
    
    # Wait a moment for monitors to stabilize
    sleep 0.5
    
    # Get currently connected monitors to verify they exist
    local connected_monitors
    connected_monitors=$(get_connected_monitors)
    
    # Parse JSON and apply wallpapers
    if command -v jq &>/dev/null; then
        # Use jq for proper JSON parsing
        local monitors
        monitors=$(jq -r 'keys[]' "$wallpapers_file" 2>/dev/null)
        
        while IFS= read -r monitor; do
            [[ -z "$monitor" ]] && continue
            
            # Only apply if monitor is currently connected
            if ! echo "$connected_monitors" | grep -q "^$monitor$"; then
                continue
            fi
            
            local wallpaper
            wallpaper=$(jq -r ".[\"$monitor\"]" "$wallpapers_file" 2>/dev/null)
            
            if [[ -n "$wallpaper" && "$wallpaper" != "null" && -f "$wallpaper" ]]; then
                echo "Restaurando wallpaper para $monitor: $(basename "$wallpaper")"
                apply_wallpaper_to_monitor "$monitor" "$wallpaper"
                save_wallpaper_state "$monitor" "$wallpaper"
                # Small delay between applications to avoid conflicts
                sleep 0.2
            fi
        done <<< "$monitors"
    else
        # Fallback: simple grep/sed parsing
        while IFS= read -r line; do
            if [[ "$line" =~ \"([^\"]+)\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
                local monitor="${BASH_REMATCH[1]}"
                local wallpaper="${BASH_REMATCH[2]}"
                
                # Only apply if monitor is currently connected
                if ! echo "$connected_monitors" | grep -q "^$monitor$"; then
                    continue
                fi
                
                if [[ -n "$monitor" && -n "$wallpaper" && -f "$wallpaper" ]]; then
                    echo "Restaurando wallpaper para $monitor: $(basename "$wallpaper")"
                    apply_wallpaper_to_monitor "$monitor" "$wallpaper"
                    save_wallpaper_state "$monitor" "$wallpaper"
                    # Small delay between applications to avoid conflicts
                    sleep 0.2
                fi
            fi
        done < "$wallpapers_file"
    fi
    
    return 0
}

