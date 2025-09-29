#!/usr/bin/env bash

# Random Wallpaper Changer for i3WM
# Changes wallpaper and saves state for next i3 startup
# Part of i3 configuration - called by keybinding and startup

WALLPAPERS_DIR="$HOME/Wallpapers"
STATE_FILE="$HOME/.config/current_wallpaper"

# Function to set wallpaper
set_wallpaper() {
  local wallpaper_path="$1"
  
  if [[ ! -f "$wallpaper_path" ]]; then
    echo "Error: Wallpaper not found: $wallpaper_path" >&2
    return 1
  fi
  
  # Set wallpaper with feh
  if command -v feh &>/dev/null; then
    feh --bg-fill "$wallpaper_path"
    
    # Save current wallpaper to state file
    echo "$wallpaper_path" > "$STATE_FILE"
    
    # Optional: Send notification if notify-send is available
    if command -v notify-send &>/dev/null; then
      notify-send "Wallpaper Changed" "$(basename "$wallpaper_path")" -t 2000 -i "$wallpaper_path" 2>/dev/null || true
    fi
    
    echo "✓ Wallpaper changed to: $(basename "$wallpaper_path")"
    return 0
  else
    echo "Error: feh not installed. Install with: sudo pacman -S feh" >&2
    return 1
  fi
}

# Function to get random wallpaper
get_random_wallpaper() {
  if [[ ! -d "$WALLPAPERS_DIR" ]]; then
    echo "Error: Wallpapers directory not found: $WALLPAPERS_DIR" >&2
    return 1
  fi
  
  # Find all image files
  local wallpapers=()
  while IFS= read -r -d '' file; do
    wallpapers+=("$file")
  done < <(find "$WALLPAPERS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.webp" \) -print0 2>/dev/null)
  
  if [[ ${#wallpapers[@]} -eq 0 ]]; then
    echo "Error: No wallpapers found in $WALLPAPERS_DIR" >&2
    return 1
  fi
  
  # Avoid selecting the same wallpaper if possible
  local current_wallpaper=""
  if [[ -f "$STATE_FILE" ]]; then
    current_wallpaper=$(cat "$STATE_FILE" 2>/dev/null)
  fi
  
  # If we have more than one wallpaper, try to avoid repeating
  if [[ ${#wallpapers[@]} -gt 1 && -n "$current_wallpaper" ]]; then
    local filtered_wallpapers=()
    for wallpaper in "${wallpapers[@]}"; do
      if [[ "$wallpaper" != "$current_wallpaper" ]]; then
        filtered_wallpapers+=("$wallpaper")
      fi
    done
    
    if [[ ${#filtered_wallpapers[@]} -gt 0 ]]; then
      wallpapers=("${filtered_wallpapers[@]}")
    fi
  fi
  
  # Select random wallpaper
  local random_index=$((RANDOM % ${#wallpapers[@]}))
  echo "${wallpapers[$random_index]}"
}

# Function to restore last wallpaper
restore_wallpaper() {
  if [[ -f "$STATE_FILE" ]]; then
    local last_wallpaper=$(cat "$STATE_FILE" 2>/dev/null)
    if [[ -f "$last_wallpaper" ]]; then
      set_wallpaper "$last_wallpaper"
      return $?
    fi
  fi
  
  # If no state file or wallpaper not found, set random
  local random_wallpaper
  random_wallpaper=$(get_random_wallpaper)
  if [[ -n "$random_wallpaper" ]]; then
    set_wallpaper "$random_wallpaper"
    return $?
  fi
  
  return 1
}

# Function to list available wallpapers
list_wallpapers() {
  if [[ ! -d "$WALLPAPERS_DIR" ]]; then
    echo "Error: Wallpapers directory not found: $WALLPAPERS_DIR" >&2
    return 1
  fi
  
  echo "Available wallpapers in $WALLPAPERS_DIR:"
  find "$WALLPAPERS_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.webp" \) -exec basename {} \; 2>/dev/null | sort
}

# Function to show current wallpaper
show_current() {
  if [[ -f "$STATE_FILE" ]]; then
    local current=$(cat "$STATE_FILE" 2>/dev/null)
    if [[ -f "$current" ]]; then
      echo "Current wallpaper: $(basename "$current")"
      echo "Path: $current"
    else
      echo "Current wallpaper file not found"
    fi
  else
    echo "No wallpaper state saved"
  fi
}

# Main function
main() {
  case "${1:-random}" in
    random|change)
      # Change to random wallpaper
      local random_wallpaper
      random_wallpaper=$(get_random_wallpaper)
      if [[ -n "$random_wallpaper" ]]; then
        set_wallpaper "$random_wallpaper"
      fi
      ;;
    restore)
      # Restore last wallpaper
      restore_wallpaper
      ;;
    list)
      # List available wallpapers
      list_wallpapers
      ;;
    current)
      # Show current wallpaper
      show_current
      ;;
    *)
      echo "Usage: $0 [random|change|restore|list|current]"
      echo "  random/change - Set random wallpaper"
      echo "  restore       - Restore last wallpaper"
      echo "  list          - List available wallpapers"
      echo "  current       - Show current wallpaper"
      ;;
  esac
}

# Execute main function
main "$@"
