#!/usr/bin/env bash

# Icon Theme Selector
# Uses rofi to select and apply icon themes by modifying kdeglobals

ICONS_DIR="$HOME/.local/share/icons"
KDE_GLOBALS="$HOME/.config/kdeglobals"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to get current icon theme
get_current_theme() {
    if [[ -f "$KDE_GLOBALS" ]]; then
        local current=$(grep -A 1 "^\[Icons\]" "$KDE_GLOBALS" | grep "^Theme=" | cut -d'=' -f2 | tr -d '[:space:]')
        echo "$current"
    fi
}

# Function to list available icon themes
list_icon_themes() {
    local -a themes=()
    local exclude=("default" "webapp-icons" "Bibata-Modern-Ice")
    
    if [[ ! -d "$ICONS_DIR" ]]; then
        echo -e "${RED}Error: Icon themes directory not found: $ICONS_DIR${NC}" >&2
        return 1
    fi
    
    # Find all icon theme directories
    for theme_dir in "$ICONS_DIR"/*; do
        if [[ -d "$theme_dir" ]]; then
            local theme_name=$(basename "$theme_dir")
            
            # Check if theme should be excluded
            local skip=false
            for excl in "${exclude[@]}"; do
                if [[ "$theme_name" == "$excl" ]]; then
                    skip=true
                    break
                fi
            done
            
            if [[ "$skip" == false ]]; then
                # Check if it's a valid icon theme (has index.theme)
                if [[ -f "$theme_dir/index.theme" ]]; then
                    themes+=("$theme_name")
                fi
            fi
        fi
    done
    
    # Print themes, one per line
    printf '%s\n' "${themes[@]}"
}

# Function to apply icon theme
apply_icon_theme() {
    local theme_name="$1"
    
    if [[ -z "$theme_name" ]]; then
        echo -e "${RED}Error: No theme name provided${NC}" >&2
        return 1
    fi
    
    # Check if theme exists
    if [[ ! -d "$ICONS_DIR/$theme_name" ]]; then
        echo -e "${RED}Error: Icon theme not found: $theme_name${NC}" >&2
        notify-send "Icon Selector" "Error: Icon theme '$theme_name' not found" -u critical 2>/dev/null || true
        return 1
    fi
    
    # Check if kdeglobals exists
    if [[ ! -f "$KDE_GLOBALS" ]]; then
        echo -e "${YELLOW}Warning: kdeglobals not found, creating it...${NC}" >&2
        mkdir -p "$(dirname "$KDE_GLOBALS")"
        touch "$KDE_GLOBALS"
    fi
    
    # Modify kdeglobals
    # Check if [Icons] section exists
    if grep -q "^\[Icons\]" "$KDE_GLOBALS"; then
        # Section exists, update Theme= line
        # Create temporary file
        local temp_file=$(mktemp)
        local in_icons=false
        local theme_set=false
        
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == "[Icons]" ]]; then
                in_icons=true
                echo "$line" >> "$temp_file"
            elif [[ "$line" =~ ^\[ ]] && [[ "$in_icons" == true ]]; then
                # New section found, add Theme= if not already set
                if [[ "$theme_set" == false ]]; then
                    echo "Theme=$theme_name" >> "$temp_file"
                    theme_set=true
                fi
                in_icons=false
                echo "$line" >> "$temp_file"
            elif [[ "$in_icons" == true ]] && [[ "$line" =~ ^Theme= ]]; then
                # Replace existing Theme= line
                echo "Theme=$theme_name" >> "$temp_file"
                theme_set=true
            else
                echo "$line" >> "$temp_file"
            fi
        done < "$KDE_GLOBALS"
        
        # If we were still in [Icons] section at end, add Theme=
        if [[ "$in_icons" == true ]] && [[ "$theme_set" == false ]]; then
            echo "Theme=$theme_name" >> "$temp_file"
        fi
        
        # Replace original file
        mv "$temp_file" "$KDE_GLOBALS"
    else
        # Section doesn't exist, add it
        echo "" >> "$KDE_GLOBALS"
        echo "[Icons]" >> "$KDE_GLOBALS"
        echo "Theme=$theme_name" >> "$KDE_GLOBALS"
    fi
    
    echo -e "${GREEN}✓ Icon theme changed to: $theme_name${NC}"
    
    # Notify user
    if command -v notify-send &>/dev/null; then
        notify-send "Icon Theme Changed" "Theme changed to: $theme_name" -t 2000 2>/dev/null || true
    fi
    
    # Try to apply changes immediately (for KDE applications)
    if command -v kwriteconfig5 &>/dev/null; then
        kwriteconfig5 --file kdeglobals --group Icons --key Theme "$theme_name" 2>/dev/null || true
    fi
    
    return 0
}

# Function to select icon theme with rofi
select_icon_theme() {
    # Get available themes
    local -a themes
    mapfile -t themes < <(list_icon_themes)
    
    if [[ ${#themes[@]} -eq 0 ]]; then
        echo -e "${RED}Error: No icon themes found in $ICONS_DIR${NC}" >&2
        notify-send "Icon Selector" "No icon themes found" -u critical 2>/dev/null || true
        return 1
    fi
    
    # Get current theme
    local current_theme=$(get_current_theme)
    
    # Build rofi input
    local rofi_input=""
    for theme in "${themes[@]}"; do
        if [[ "$theme" == "$current_theme" ]]; then
            # Mark current theme with indicator
            rofi_input+="${theme} ✓\n"
        else
            rofi_input+="${theme}\n"
        fi
    done
    
    # Show in rofi
    local selected
    selected=$(echo -en "$rofi_input" | \
        rofi -dmenu -i \
        -p "Select Icon Theme" \
        -theme-str 'window { width: 30%; location: center; anchor: center; }' \
        -selection-row 0)
    
    # Remove checkmark if present
    selected="${selected% ✓}"
    
    # Apply selected theme
    if [[ -n "$selected" ]]; then
        # Check if selection is valid
        local valid=false
        for theme in "${themes[@]}"; do
            if [[ "$theme" == "$selected" ]]; then
                valid=true
                break
            fi
        done
        
        if [[ "$valid" == true ]]; then
            apply_icon_theme "$selected"
            return 0
        else
            echo -e "${YELLOW}Selection cancelled or invalid${NC}"
            return 1
        fi
    fi
    
    return 0
}

# Main execution
select_icon_theme "$@"

