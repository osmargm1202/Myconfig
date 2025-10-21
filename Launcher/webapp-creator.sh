#!/bin/bash

# WebApp Creator - Similar to Omarchy but with sync capabilities
# Usage: ./webapp-creator.sh

APPS_DIR="$HOME/.local/share/applications"
ICONS_DIR="$HOME/.local/share/icons/webapp-icons"
SYNC_DIR="$HOME/.local/share/webapp-sync"
CONFIG_FILE="$SYNC_DIR/webapps.json"

# Colors for TUI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Gum configuration
GUM_FOREGROUND="212" # Purple color
GUM_BOLD="true"
export GUM_CHOOSE_SELECTED_FOREGROUND="#87CEEB"  # Sky Blue
export GUM_CHOOSE_CURSOR_FOREGROUND="#00BFFF"    # Deep Sky Blue
export GUM_CONFIRM_SELECTED_FOREGROUND="#87CEEB"
export GUM_INPUT_CURSOR_FOREGROUND="#00BFFF"
export GUM_INPUT_PROMPT_FOREGROUND="#87CEEB"
export GUM_FILTER_INDICATOR_FOREGROUND="#00BFFF"
export GUM_FILTER_MATCH_FOREGROUND="#87CEEB"
# Create necessary directories
mkdir -p "$APPS_DIR" "$ICONS_DIR" "$SYNC_DIR"

# Initialize config file if it doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[]" >"$CONFIG_FILE"
fi

# Function to display header (not used with rofi interface)
show_header() {
  clear
  echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║           WebApp Creator               ║${NC}"
  echo -e "${CYAN}║        (Chromium Web Apps)             ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
  echo
}

# Function to select category
select_category() {
  local choice
  choice=$(gum choose --header="Select Category:" \
    "AudioVideo (Media applications)" \
    "Development (Programming tools)" \
    "Education (Learning applications)" \
    "Game (Games and entertainment)" \
    "Graphics (Image/video editing)" \
    "Network (Web browsers, chat)" \
    "Office (Productivity applications)" \
    "Science (Scientific applications)" \
    "System (System tools)" \
    "Utility (General utilities)" \
    "Custom (Enter your own)")

  # If user cancelled (ESC), return empty
  if [[ $? -ne 0 ]]; then
    echo ""
    return 1
  fi

  case "$choice" in
    "AudioVideo (Media applications)")
      echo "AudioVideo;"
      return 0
      ;;
    "Development (Programming tools)")
      echo "Development;"
      return 0
      ;;
    "Education (Learning applications)")
      echo "Education;"
      return 0
      ;;
    "Game (Games and entertainment)")
      echo "Game;"
      return 0
      ;;
    "Graphics (Image/video editing)")
      echo "Graphics;"
      return 0
      ;;
    "Network (Web browsers, chat)")
      echo "Network;WebBrowser;"
      return 0
      ;;
    "Office (Productivity applications)")
      echo "Office;"
      return 0
      ;;
    "Science (Scientific applications)")
      echo "Science;"
      return 0
      ;;
    "System (System tools)")
      echo "System;"
      return 0
      ;;
    "Utility (General utilities)")
      echo "Utility;"
      return 0
      ;;
    "Custom (Enter your own)")
      get_input "Enter custom categories (separated by semicolons)" custom_category "Network;WebBrowser;"
      if [[ $? -eq 0 ]]; then
        echo "$custom_category"
        return 0
      else
        echo ""
        return 1
      fi
      ;;
    *)
      echo ""
      return 1
      ;;
  esac
}
get_input() {
  local prompt="$1"
  local var_name="$2"
  local default="$3"

  local gum_prompt="$prompt: "
  if [[ -n "$default" ]]; then
    gum_prompt="$prompt (default: $default): "
  fi

  local input
  input=$(gum input --placeholder="$default" --prompt="$gum_prompt")

  # If user cancelled (ESC), return empty
  if [[ $? -ne 0 ]]; then
    eval "$var_name=''"
    return 1
  fi

  # If input is empty and default exists, use default
  if [[ -z "$input" && -n "$default" ]]; then
    input="$default"
  fi

  eval "$var_name='$input'"
}

# Function to download favicon
download_favicon() {
  local url="$1"
  local app_name="$2"
  local icon_path="$ICONS_DIR/${app_name}.png"

  echo -e "${BLUE}Downloading favicon...${NC}"

  # Try different favicon locations
  local favicon_urls=(
    "https://www.google.com/s2/favicons?sz=128&domain_url=$url"
    "${url%/}/favicon.ico"
    "${url%/}/favicon.png"
    "${url%/}/apple-touch-icon.png"
  )

  for favicon_url in "${favicon_urls[@]}"; do
    if wget -q --timeout=10 -O "$icon_path" "$favicon_url" 2>/dev/null; then
      if file "$icon_path" | grep -q "image"; then
        echo -e "${GREEN}✓ Icon downloaded successfully${NC}"
        return 0
      fi
    fi
  done

  # If no favicon found, create a simple text-based icon
  echo -e "${YELLOW}! Creating default icon${NC}"
  convert -size 128x128 xc:lightblue -font DejaVu-Sans-Bold -pointsize 20 \
    -fill black -gravity center -annotate +0+0 "${app_name:0:3}" \
    "$icon_path" 2>/dev/null || {
    # Fallback: copy a system icon
    cp /usr/share/pixmaps/web-browser.png "$icon_path" 2>/dev/null || {
      echo -e "${RED}✗ Could not create icon${NC}"
      return 1
    }
  }
  return 0
}

# Function to create desktop file
create_desktop_file() {
  local name="$1"
  local url="$2"
  local description="$3"
  local categories="$4"
  local icon_path="$ICONS_DIR/${name}.png"
  local desktop_file="$APPS_DIR/${name}.desktop"

  cat >"$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=$description
Exec=chromium --app="$url" --new-window --class="$name"
Icon=$icon_path
Categories=$categories
NoDisplay=false
StartupWMClass=$name
StartupNotify=true
Terminal=false
EOF

  chmod +x "$desktop_file"
  echo -e "${GREEN}✓ Desktop file created: $desktop_file${NC}"
}

# Function to add app to sync config
add_to_sync_config() {
  local name="$1"
  local url="$2"
  local description="$3"
  local categories="$4"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Read current config, add new app, write back
  local temp_file=$(mktemp)
  jq --arg name "$name" --arg url "$url" --arg desc "$description" \
    --arg cat "$categories" --arg time "$timestamp" \
    '. += [{
         "name": $name,
         "url": $url,
         "description": $desc,
         "categories": $cat,
         "created": $time,
         "icon": ($name + ".png")
       }]' "$CONFIG_FILE" >"$temp_file" && mv "$temp_file" "$CONFIG_FILE"

  echo -e "${GREEN}✓ Added to sync configuration${NC}"
}

# Function to create new webapp
create_webapp() {
  # Get app details using rofi
  get_input "App Name: " app_name
  if [[ $? -ne 0 || -z "$app_name" ]]; then
    return 1
  fi

  get_input "URL (https:// will be added if missing): " app_url
  if [[ $? -ne 0 || -z "$app_url" ]]; then
    return 1
  fi

  get_input "Description: " app_description "$app_name Web Application"
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Select category using rofi
  app_categories=$(select_category)
  if [[ $? -ne 0 || -z "$app_categories" ]]; then
    return 1
  fi

  # Auto-add https:// if not present
  if [[ ! "$app_url" =~ ^https?:// ]]; then
    app_url="https://$app_url"
    gum style --foreground="$GUM_FOREGROUND" --bold "Added https:// to URL: $app_url"
  fi

  # Show progress notification
  gum style --foreground="$GUM_FOREGROUND" --bold "Creating webapp '$app_name'..."

  # Download icon
  download_favicon "$app_url" "$app_name"

  # Create desktop file
  create_desktop_file "$app_name" "$app_url" "$app_description" "$app_categories"

  # Add to sync config
  add_to_sync_config "$app_name" "$app_url" "$app_description" "$app_categories"

  # Success notification
  gum style --foreground="$GUM_FOREGROUND" --bold "✓ WebApp '$app_name' created successfully!"
  gum style --foreground="$GUM_FOREGROUND" --bold "You can now find it in your applications menu"
}

# Function to list existing webapps
list_webapps() {
  if [[ ! -s "$CONFIG_FILE" ]] || [[ "$(jq length "$CONFIG_FILE")" -eq 0 ]]; then
    gum style --foreground="$GUM_FOREGROUND" --bold "No webapps found"
    return
  fi

  # Create formatted list for display
  local webapp_list
  webapp_list=$(jq -r '.[] | "\(.name) - \(.url) - \(.description)"' "$CONFIG_FILE")

  # Show list using gum choose and execute selected app
  local selected_webapp
  selected_webapp=$(echo "$webapp_list" | gum choose --header="Select WebApp to Launch:" --no-limit)

  # If user cancelled (ESC), return
  if [[ $? -ne 0 || -z "$selected_webapp" ]]; then
    return
  fi

  # Extract the app name (first part before " - ")
  local app_name
  app_name=$(echo "$selected_webapp" | cut -d' ' -f1-2 | sed 's/ -$//')

  # Get the URL from the config
  local app_url
  app_url=$(jq -r --arg name "$app_name" '.[] | select(.name == $name) | .url' "$CONFIG_FILE")

  if [[ -n "$app_url" ]]; then
    gum style --foreground="$GUM_FOREGROUND" --bold "Launching $app_name..."
    
    # Launch the webapp
    if command -v chromium &>/dev/null; then
      chromium --app="$app_url" --new-window --class="$app_name" &
    elif command -v chromium-browser &>/dev/null; then
      chromium-browser --app="$app_url" --new-window --class="$app_name" &
    else
      gum style --foreground="$GUM_FOREGROUND" --bold "✗ Chromium not found. Cannot launch webapp."
      return 1
    fi
    
    gum style --foreground="$GUM_FOREGROUND" --bold "✓ $app_name launched successfully!"
  else
    gum style --foreground="$GUM_FOREGROUND" --bold "✗ Could not find URL for $app_name"
  fi
}

# Function to export webapps
export_webapps() {
  local script_dir="$(dirname "$(readlink -f "$0")")"
  local export_file="$script_dir/webapps.tar.gz"

  # Show progress notification
  gum style --foreground="$GUM_FOREGROUND" --bold "Creating export package..."

  # Create temporary directory for export
  local temp_dir=$(mktemp -d)

  # Copy config and icons
  if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "$temp_dir/"
  fi

  if [[ -d "$ICONS_DIR" ]]; then
    cp -r "$ICONS_DIR" "$temp_dir/"
  fi

  # Copy all .desktop files from applications directory
  local desktop_dir="$temp_dir/applications"
  mkdir -p "$desktop_dir"

  if [[ -f "$CONFIG_FILE" ]]; then
    jq -r '.[].name' "$CONFIG_FILE" 2>/dev/null | while read -r app_name; do
      if [[ -f "$APPS_DIR/${app_name}.desktop" ]]; then
        cp "$APPS_DIR/${app_name}.desktop" "$desktop_dir/"
      fi
    done
  fi

  # Create the tar.gz file
  tar -czf "$export_file" -C "$temp_dir" .
  rm -rf "$temp_dir"

  # Show success notification with file location
  local export_msg="✓ Export created: $(basename "$script_dir")/webapps.tar.gz"

  # Show confirmation with gum
  gum style --foreground="$GUM_FOREGROUND" --bold "$export_msg"
}

# Function to check chromium installation
check_chromium() {
  if command -v chromium &>/dev/null; then
    return 0
  elif command -v chromium-browser &>/dev/null; then
    return 0
  else
    # Show installation prompt using gum
    if gum confirm "Chromium not found. Install now?"; then
      gum spin --title="Installing Chromium..." -- sudo pacman -S chromium
      if [[ $? -eq 0 ]]; then
        gum style --foreground="$GUM_FOREGROUND" --bold "✓ Chromium installed successfully"
        return 0
      else
        gum style --foreground="$GUM_FOREGROUND" --bold "✗ Failed to install Chromium. Install manually: sudo pacman -S chromium"
        return 1
      fi
    else
      gum style --foreground="$GUM_FOREGROUND" --bold "⚠ WebApp Creator needs Chromium to work properly"
      return 1
    fi
  fi
}

# Function to create webapp-creator desktop file
create_webapp_creator_desktop() {
  local desktop_file="$APPS_DIR/webapp-creator.desktop"
  local icon_path="$ICONS_DIR/webapp-creator.png"
  local bin_path="$HOME/.local/bin/webapp-creator"

  echo -e "${BLUE}Creating WebApp Creator desktop entry...${NC}"

  # Create icon for webapp-creator (using a gear/settings icon concept)
  if command -v convert &>/dev/null; then
    convert -size 128x128 xc:transparent -fill "#4A90E2" -draw "circle 64,64 64,20" \
      -fill white -font DejaVu-Sans-Bold -pointsize 14 -gravity center \
      -annotate +0+0 "WEB\nAPP" "$icon_path" 2>/dev/null
    echo -e "${GREEN}✓ Created WebApp Creator icon${NC}"
  else
    # Try to copy a system icon as fallback
    for sys_icon in /usr/share/icons/hicolor/*/apps/preferences-system.png \
      /usr/share/pixmaps/preferences-system.png \
      /usr/share/icons/*/*/apps/application-default-icon.png; do
      if [[ -f "$sys_icon" ]]; then
        cp "$sys_icon" "$icon_path" 2>/dev/null && break
      fi
    done

    if [[ ! -f "$icon_path" ]]; then
      # Create simple text-based icon as last resort
      echo -e "${YELLOW}Creating simple text icon${NC}"
      convert -size 128x128 xc:"#4A90E2" -font DejaVu-Sans-Bold -pointsize 16 \
        -fill white -gravity center -annotate +0+0 "WEBAPP\nCREATOR" \
        "$icon_path" 2>/dev/null || {
        # If convert fails completely, create a placeholder
        touch "$icon_path"
      }
    fi
  fi

  # Create the desktop file
  cat >"$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=WebApp Creator
Comment=Create and manage web applications using Chromium
Exec=$bin_path
Icon=$icon_path
Categories=Development;System;Utility;
Keywords=webapp;chromium;browser;application;
NoDisplay=false
StartupNotify=true
Terminal=true
StartupWMClass=webapp-creator
EOF

  chmod +x "$desktop_file"
  echo -e "${GREEN}✓ WebApp Creator desktop file created${NC}"
}
install_app() {
  show_header
  echo -e "${WHITE}Install WebApp Creator${NC}"
  echo -e "${WHITE}──────────────────────${NC}"
  echo

  # First check if Chromium is installed
  echo -e "${BLUE}Checking dependencies...${NC}"
  check_chromium
  echo

  local bin_dir="$HOME/.local/bin"
  local script_name="webapp-creator"
  local script_path="$0"
  local installer_file="./install.sh"
  local gamemode_file="$REPO_DIR/i3/scripts/game-mode.sh"
  local webapps_archive="./webapps.tar.gz"

  echo -e "${BLUE}Installing WebApp Creator...${NC}"

  # Create .local/bin directory
  mkdir -p "$bin_dir"
  echo -e "${GREEN}✓ Created directory: $bin_dir${NC}"

  # Copy this script to .local/bin
  if [[ -f "$script_path" ]]; then
    cp "$script_path" "$bin_dir/$script_name"
    chmod +x "$bin_dir/$script_name"
    echo -e "${GREEN}✓ Copied script to: $bin_dir/$script_name${NC}"
  else
    echo -e "${RED}✗ Current script not found: $script_path${NC}"
    return 1
  fi

  # Copy install.sh if it exists
  if [[ -f "$installer_file" ]]; then
    cp "$installer_file" "$bin_dir/"
    chmod +x "$bin_dir/install.sh"
    echo -e "${GREEN}✓ Copied install.sh to: $bin_dir/install.sh${NC}"
  else
    echo -e "${YELLOW}! install.sh not found, skipping...${NC}"
  fi

  # Copy game-mode.sh if it exists
  if [[ -f "$gamemode_file" ]]; then
    cp "$gamemode_file" "$bin_dir/"
    chmod +x "$bin_dir/game-mode.sh"
    echo -e "${GREEN}✓ Copied game-mode.sh to: $bin_dir/game-mode.sh${NC}"
  else
    echo -e "${YELLOW}! game-mode.sh not found, skipping...${NC}"
  fi

  # Create WebApp Creator desktop entry
  create_webapp_creator_desktop

  # Import default webapps if archive exists
  if [[ -f "$webapps_archive" ]]; then
    echo -e "${BLUE}Importing default webapps...${NC}"

    # Create temporary directory for import
    local temp_dir=$(mktemp -d)
    tar -xzf "$webapps_archive" -C "$temp_dir"

    # Import icons
    if [[ -d "$temp_dir/webapp-icons" ]]; then
      cp -r "$temp_dir/webapp-icons/"* "$ICONS_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Default icons imported${NC}"
    fi

    # Import applications
    if [[ -d "$temp_dir/applications" ]]; then
      cp "$temp_dir/applications/"*.desktop "$APPS_DIR/" 2>/dev/null
      echo -e "${GREEN}✓ Default applications imported${NC}"
    fi

    # Import and merge config
    if [[ -f "$temp_dir/webapps.json" ]]; then
      if [[ -f "$CONFIG_FILE" ]]; then
        # Merge with existing config
        local temp_config=$(mktemp)
        jq -s '.[0] + .[1] | unique_by(.name)' "$CONFIG_FILE" "$temp_dir/webapps.json" >"$temp_config"
        mv "$temp_config" "$CONFIG_FILE"
      else
        # Copy as new config
        cp "$temp_dir/webapps.json" "$CONFIG_FILE"
      fi
      echo -e "${GREEN}✓ Default configuration imported${NC}"
    fi

    rm -rf "$temp_dir"
    echo -e "${GREEN}✓ Default webapps installed${NC}"
  else
    echo -e "${YELLOW}! webapps.tar.gz not found, skipping default apps...${NC}"
  fi

  # Check if .local/bin is in PATH
  if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
    echo
    echo -e "${YELLOW}⚠ Warning: $bin_dir is not in your PATH${NC}"
    echo -e "${BLUE}Add this line to your ~/.bashrc or ~/.zshrc:${NC}"
    echo -e "${WHITE}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo
    echo -e "${BLUE}Then reload your shell with: source ~/.bashrc${NC}"
  fi

  echo
  echo -e "${GREEN}✓ WebApp Creator installed successfully!${NC}"
  echo -e "${BLUE}You can now:${NC}"
  echo -e "${WHITE}  • Run 'webapp-creator' from terminal${NC}"
  echo -e "${WHITE}  • Find 'WebApp Creator' in your application menu${NC}"
  echo -e "${WHITE}  • Launch from rofi/launcher${NC}"
}

# Function to remove webapp
remove_webapp() {
  if [[ ! -s "$CONFIG_FILE" ]] || [[ "$(jq length "$CONFIG_FILE")" -eq 0 ]]; then
    gum style --foreground="$GUM_FOREGROUND" --bold "No webapps found"
    return
  fi

  # Create list of webapps for selection
  local webapp_list
  webapp_list=$(jq -r '.[] | .name' "$CONFIG_FILE")

  # Let user select webapp to remove using gum choose
  local selected_app
  selected_app=$(echo "$webapp_list" | gum choose --header="Select WebApp to Remove:")

  # If user cancelled (ESC), return
  if [[ $? -ne 0 || -z "$selected_app" ]]; then
    return
  fi

  # Get index of selected app
  local index
  index=$(jq -r --arg name "$selected_app" 'to_entries | .[] | select(.value.name == $name) | .key' "$CONFIG_FILE")

  if [[ -z "$index" ]]; then
    gum style --foreground="$GUM_FOREGROUND" --bold "✗ WebApp not found"
    return
  fi

  # Confirm removal using gum confirm
  if gum confirm "Remove webapp '$selected_app'?"; then
    # Remove desktop file
    rm -f "$APPS_DIR/${selected_app}.desktop"

    # Remove icon
    rm -f "$ICONS_DIR/${selected_app}.png"

    # Remove from config
    local temp_file=$(mktemp)
    jq "del(.[$index])" "$CONFIG_FILE" >"$temp_file" && mv "$temp_file" "$CONFIG_FILE"

    gum style --foreground="$GUM_FOREGROUND" --bold "✓ WebApp '$selected_app' removed"
  else
    gum style --foreground="$GUM_FOREGROUND" --bold "Operation cancelled"
  fi
}

# Main menu
main_menu() {
  while true; do
    local choice
    choice=$(gum choose --header="WebApp Creator - Main Menu:" \
      "Create New WebApp" \
      "List WebApps" \
      "Export WebApps" \
      "Remove WebApp" \
      "Exit")

    # If user cancelled (ESC), exit
    if [[ $? -ne 0 ]]; then
      gum style --foreground="$GUM_FOREGROUND" --bold "Goodbye!"
      exit 0
    fi

    case "$choice" in
      "Create New WebApp") 
        create_webapp 
        ;;
      "List WebApps") 
        list_webapps 
        ;;
      "Export WebApps") 
        export_webapps 
        ;;
      "Remove WebApp") 
        remove_webapp 
        ;;
      "Exit")
        gum style --foreground="$GUM_FOREGROUND" --bold "Goodbye!"
        exit 0
        ;;
      *)
        gum style --foreground="$GUM_FOREGROUND" --bold "Invalid option"
        ;;
    esac
  done
}

# Check dependencies
check_dependencies() {
  local deps=("wget" "jq" "gum")
  local missing=()

  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing+=("$dep")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    gum style --foreground="$GUM_FOREGROUND" --bold "Missing dependencies: ${missing[*]}"
    gum style --foreground="$GUM_FOREGROUND" --bold "Install with: sudo pacman -S ${missing[*]}"
    exit 1
  fi
}

# Check if we have a TTY available
if [[ ! -t 0 ]] || [[ ! -c /dev/tty ]]; then
  echo "Error: This script requires an interactive terminal"
  echo "Please run it from a terminal or menu system"
  exit 1
fi

# Start the application
check_dependencies
main_menu
