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

# Create necessary directories
mkdir -p "$APPS_DIR" "$ICONS_DIR" "$SYNC_DIR"

# Initialize config file if it doesn't exist
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[]" >"$CONFIG_FILE"
fi

# Function to display header
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
  echo -e "${WHITE}Select Category:${NC}"
  echo -e "${WHITE}───────────────${NC}"
  echo
  echo -e "${CYAN}1.${NC} AudioVideo (Media applications)"
  echo -e "${CYAN}2.${NC} Development (Programming tools)"
  echo -e "${CYAN}3.${NC} Education (Learning applications)"
  echo -e "${CYAN}4.${NC} Game (Games and entertainment)"
  echo -e "${CYAN}5.${NC} Graphics (Image/video editing)"
  echo -e "${CYAN}6.${NC} Network (Web browsers, chat)"
  echo -e "${CYAN}7.${NC} Office (Productivity applications)"
  echo -e "${CYAN}8.${NC} Science (Scientific applications)"
  echo -e "${CYAN}9.${NC} System (System tools)"
  echo -e "${CYAN}10.${NC} Utility (General utilities)"
  echo -e "${CYAN}11.${NC} Custom (Enter your own)"
  echo

  while true; do
    echo -ne "${YELLOW}Select category (1-11): ${NC}"
    read -r choice

    case $choice in
    1)
      echo "AudioVideo;"
      return 0
      ;;
    2)
      echo "Development;"
      return 0
      ;;
    3)
      echo "Education;"
      return 0
      ;;
    4)
      echo "Game;"
      return 0
      ;;
    5)
      echo "Graphics;"
      return 0
      ;;
    6)
      echo "Network;WebBrowser;"
      return 0
      ;;
    7)
      echo "Office;"
      return 0
      ;;
    8)
      echo "Science;"
      return 0
      ;;
    9)
      echo "System;"
      return 0
      ;;
    10)
      echo "Utility;"
      return 0
      ;;
    11)
      echo
      get_input "Enter custom categories (separated by semicolons)" custom_category "Network;WebBrowser;"
      echo "$custom_category"
      return 0
      ;;
    *) echo -e "${RED}Invalid option. Please select 1-11.${NC}" ;;
    esac
  done
}
get_input() {
  local prompt="$1"
  local var_name="$2"
  local default="$3"

  echo -ne "${YELLOW}$prompt${NC}"
  if [[ -n "$default" ]]; then
    echo -ne " ${PURPLE}(default: $default)${NC}"
  fi
  echo -ne ": "
  read -r input

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
  show_header
  echo -e "${WHITE}Create New WebApp${NC}"
  echo -e "${WHITE}─────────────────${NC}"
  echo

  get_input "App Name" app_name
  get_input "URL (https:// will be added if missing)" app_url
  get_input "Description" app_description "$app_name Web Application"

  echo
  echo -e "${WHITE}Select Category:${NC}"
  echo -e "${WHITE}───────────────${NC}"
  echo
  echo -e "${CYAN}1.${NC} AudioVideo (Media applications)"
  echo -e "${CYAN}2.${NC} Development (Programming tools)"
  echo -e "${CYAN}3.${NC} Education (Learning applications)"
  echo -e "${CYAN}4.${NC} Game (Games and entertainment)"
  echo -e "${CYAN}5.${NC} Graphics (Image/video editing)"
  echo -e "${CYAN}6.${NC} Network (Web browsers, chat)"
  echo -e "${CYAN}7.${NC} Office (Productivity applications)"
  echo -e "${CYAN}8.${NC} Science (Scientific applications)"
  echo -e "${CYAN}9.${NC} System (System tools)"
  echo -e "${CYAN}10.${NC} Utility (General utilities)"
  echo -e "${CYAN}11.${NC} Custom (Enter your own)"
  echo

  while true; do
    echo -ne "${YELLOW}Select category (1-11): ${NC}"
    read -r cat_choice

    case $cat_choice in
    1)
      app_categories="AudioVideo;"
      break
      ;;
    2)
      app_categories="Development;"
      break
      ;;
    3)
      app_categories="Education;"
      break
      ;;
    4)
      app_categories="Game;"
      break
      ;;
    5)
      app_categories="Graphics;"
      break
      ;;
    6)
      app_categories="Network;WebBrowser;"
      break
      ;;
    7)
      app_categories="Office;"
      break
      ;;
    8)
      app_categories="Science;"
      break
      ;;
    9)
      app_categories="System;"
      break
      ;;
    10)
      app_categories="Utility;"
      break
      ;;
    11)
      echo
      get_input "Enter custom categories (separated by semicolons)" app_categories "Network;WebBrowser;"
      break
      ;;
    *) echo -e "${RED}Invalid option. Please select 1-11.${NC}" ;;
    esac
  done

  if [[ -z "$app_name" || -z "$app_url" ]]; then
    echo -e "${RED}✗ Name and URL are required!${NC}"
    read -p "Press Enter to continue..."
    return 1
  fi

  # Auto-add https:// if not present
  if [[ ! "$app_url" =~ ^https?:// ]]; then
    app_url="https://$app_url"
    echo -e "${BLUE}Added https:// to URL: $app_url${NC}"
  fi

  echo
  echo -e "${BLUE}Creating webapp...${NC}"

  # Download icon
  download_favicon "$app_url" "$app_name"

  # Create desktop file
  create_desktop_file "$app_name" "$app_url" "$app_description" "$app_categories"

  # Add to sync config
  add_to_sync_config "$app_name" "$app_url" "$app_description" "$app_categories"

  echo
  echo -e "${GREEN}✓ WebApp '$app_name' created successfully!${NC}"
  echo -e "${BLUE}You can now find it in your applications menu${NC}"

  read -p "Press Enter to continue..."
}

# Function to list existing webapps
list_webapps() {
  show_header
  echo -e "${WHITE}Installed WebApps${NC}"
  echo -e "${WHITE}─────────────────${NC}"
  echo

  if [[ ! -s "$CONFIG_FILE" ]] || [[ "$(jq length "$CONFIG_FILE")" -eq 0 ]]; then
    echo -e "${YELLOW}No webapps found.${NC}"
  else
    echo -e "${CYAN}Name${NC} | ${CYAN}URL${NC} | ${CYAN}Description${NC}"
    echo "─────────────────────────────────────────────────"
    jq -r '.[] | "\(.name) | \(.url) | \(.description)"' "$CONFIG_FILE"
  fi

  echo
  read -p "Press Enter to continue..."
}

# Function to export webapps
export_webapps() {
  show_header
  echo -e "${WHITE}Export WebApps${NC}"
  echo -e "${WHITE}──────────────${NC}"
  echo

  local script_dir="$(dirname "$(readlink -f "$0")")"
  local export_file="$script_dir/webapps.tar.gz"

  echo -e "${BLUE}Creating export package...${NC}"

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

  echo -e "${GREEN}✓ Export created: $export_file${NC}"
  echo -e "${BLUE}WebApps exported to: $(basename "$script_dir")/webapps.tar.gz${NC}"

  read -p "Press Enter to continue..."
}

# Function to check chromium installation
check_chromium() {
  if command -v chromium &>/dev/null; then
    echo -e "${GREEN}✓ Chromium is already installed${NC}"
    return 0
  elif command -v chromium-browser &>/dev/null; then
    echo -e "${GREEN}✓ Chromium browser is already installed${NC}"
    return 0
  else
    echo -e "${YELLOW}⚠ Chromium not found${NC}"
    echo -e "${BLUE}WebApp Creator requires Chromium to create web applications${NC}"
    echo
    echo -ne "${YELLOW}Would you like to install Chromium now? (y/N): ${NC}"
    read -r install_choice

    if [[ "$install_choice" =~ ^[Yy]$ ]]; then
      echo -e "${BLUE}Installing Chromium...${NC}"
      if sudo pacman -S chromium; then
        echo -e "${GREEN}✓ Chromium installed successfully${NC}"
        return 0
      else
        echo -e "${RED}✗ Failed to install Chromium${NC}"
        echo -e "${YELLOW}You can install it manually later with: sudo pacman -S chromium${NC}"
        return 1
      fi
    else
      echo -e "${YELLOW}Skipping Chromium installation${NC}"
      echo -e "${BLUE}Note: WebApp Creator won't work properly without Chromium${NC}"
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

  local bin_dir="$HOME/.local/bin"
  local script_name="webapp-creator"
  local script_path="$0"
  local launcher_file="./launcher.sh"
  local installer_file="./install.sh"
  local gamemode_file="./game-mode.sh"
  local webapps_archive="./webapps.tar.gz"

  # Function to install app (self-install)
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
    local launcher_file="./launcher.sh"
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
      read -p "Press Enter to continue..."
      return 1
    fi

    # Copy launcher.sh if it exists
    if [[ -f "$launcher_file" ]]; then
      cp "$launcher_file" "$bin_dir/"
      chmod +x "$bin_dir/launcher.sh"
      echo -e "${GREEN}✓ Copied launcher.sh to: $bin_dir/launcher.sh${NC}"
    else
      echo -e "${YELLOW}! launcher.sh not found, skipping...${NC}"
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

    read -p "Press Enter to continue..."
  }
}

# Function to remove webapp
remove_webapp() {
  show_header
  echo -e "${WHITE}Remove WebApp${NC}"
  echo -e "${WHITE}──────────────${NC}"
  echo

  if [[ ! -s "$CONFIG_FILE" ]] || [[ "$(jq length "$CONFIG_FILE")" -eq 0 ]]; then
    echo -e "${YELLOW}No webapps found.${NC}"
    read -p "Press Enter to continue..."
    return
  fi

  echo -e "${CYAN}Available WebApps:${NC}"
  jq -r 'to_entries | .[] | "\(.key + 1): \(.value.name)"' "$CONFIG_FILE"
  echo

  get_input "Select webapp number to remove" selection

  if [[ ! "$selection" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}✗ Invalid selection${NC}"
    read -p "Press Enter to continue..."
    return
  fi

  local index=$((selection - 1))
  local app_name=$(jq -r ".[$index].name // empty" "$CONFIG_FILE")

  if [[ -z "$app_name" ]]; then
    echo -e "${RED}✗ Invalid selection${NC}"
    read -p "Press Enter to continue..."
    return
  fi

  echo -e "${YELLOW}Remove webapp '$app_name'? (y/N)${NC}"
  read -r confirm

  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    # Remove desktop file
    rm -f "$APPS_DIR/${app_name}.desktop"

    # Remove icon
    rm -f "$ICONS_DIR/${app_name}.png"

    # Remove from config
    local temp_file=$(mktemp)
    jq "del(.[$index])" "$CONFIG_FILE" >"$temp_file" && mv "$temp_file" "$CONFIG_FILE"

    echo -e "${GREEN}✓ WebApp '$app_name' removed${NC}"
  else
    echo -e "${BLUE}Operation cancelled${NC}"
  fi

  read -p "Press Enter to continue..."
}

# Main menu
main_menu() {
  while true; do
    show_header
    echo -e "${WHITE}Main Menu${NC}"
    echo -e "${WHITE}─────────${NC}"
    echo
    echo -e "${CYAN}1.${NC} Create New WebApp"
    echo -e "${CYAN}2.${NC} List WebApps"
    echo -e "${CYAN}3.${NC} Export WebApps"
    echo -e "${CYAN}4.${NC} Remove WebApp"
    echo -e "${CYAN}5.${NC} Exit"
    echo
    echo -ne "${YELLOW}Select option (1-5): ${NC}"
    read -r choice

    case $choice in
    1) create_webapp ;;
    2) list_webapps ;;
    3) export_webapps ;;
    4) remove_webapp ;;
    5)
      echo -e "${GREEN}Goodbye!${NC}"
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid option${NC}"
      sleep 1
      ;;
    esac
  done
}

# Check dependencies
check_dependencies() {
  local deps=("wget" "jq")
  local missing=()

  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing+=("$dep")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${RED}Missing dependencies: ${missing[*]}${NC}"
    echo -e "${BLUE}Install with: sudo pacman -S ${missing[*]}${NC}"
    exit 1
  fi
}

# Start the application
check_dependencies
main_menu
