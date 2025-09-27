#!/bin/bash

# Install Script for WebApp Creator
# This script installs webapp-creator to system locations and sets up permissions

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
WEBAPP_CREATOR="$SCRIPT_DIR/webapp-creator.sh"
LAUNCHER_SCRIPT="$SCRIPT_DIR/launcher.sh"
GAMEMODE_SCRIPT="$SCRIPT_DIR/game-mode.sh"
SYSTEM_BIN="/usr/local/bin"
LOCAL_BIN="$HOME/.local/bin"

# Function to display header
show_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         WebApp Creator Installer       ║${NC}"
    echo -e "${CYAN}║        System Installation Tool        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${RED}⚠ Warning: Running as root${NC}"
        echo -e "${YELLOW}This script will install to system directories${NC}"
        return 0
    else
        return 1
    fi
}

# Function to copy to system directories (requires sudo)
install_system() {
    echo -e "${BLUE}Installing to system directories...${NC}"
    
    # Copy webapp-creator to /usr/local/bin
    if [[ -f "$WEBAPP_CREATOR" ]]; then
        sudo cp "$WEBAPP_CREATOR" "$SYSTEM_BIN/webapp-creator"
        sudo chmod +x "$SYSTEM_BIN/webapp-creator"
        echo -e "${GREEN}✓ Copied webapp-creator to: $SYSTEM_BIN/webapp-creator${NC}"
    else
        echo -e "${RED}✗ WebApp Creator script not found: $WEBAPP_CREATOR${NC}"
        return 1
    fi
    
    # Copy launcher if it exists
    if [[ -f "$LAUNCHER_SCRIPT" ]]; then
        sudo cp "$LAUNCHER_SCRIPT" "$SYSTEM_BIN/webapp-launcher"
        sudo chmod +x "$SYSTEM_BIN/webapp-launcher"
        echo -e "${GREEN}✓ Copied launcher to: $SYSTEM_BIN/webapp-launcher${NC}"
    else
        echo -e "${YELLOW}! Launcher script not found, skipping...${NC}"
    fi
    
    # Copy game-mode script if it exists
    if [[ -f "$GAMEMODE_SCRIPT" ]]; then
        sudo cp "$GAMEMODE_SCRIPT" "$SYSTEM_BIN/webapp-gamemode"
        sudo chmod +x "$SYSTEM_BIN/webapp-gamemode"
        echo -e "${GREEN}✓ Copied game-mode to: $SYSTEM_BIN/webapp-gamemode${NC}"
    else
        echo -e "${YELLOW}! Game-mode script not found, skipping...${NC}"
    fi
    
    # Create symlinks for easier access
    if [[ ! -L "$SYSTEM_BIN/wac" ]]; then
        sudo ln -s "$SYSTEM_BIN/webapp-creator" "$SYSTEM_BIN/wac"
        echo -e "${GREEN}✓ Created symlink: wac -> webapp-creator${NC}"
    fi
    
    if [[ -f "$SYSTEM_BIN/webapp-gamemode" && ! -L "$SYSTEM_BIN/wac-game" ]]; then
        sudo ln -s "$SYSTEM_BIN/webapp-gamemode" "$SYSTEM_BIN/wac-game"
        echo -e "${GREEN}✓ Created symlink: wac-game -> webapp-gamemode${NC}"
    fi
    
    echo -e "${GREEN}✓ System installation completed${NC}"
    return 0
}

# Function to copy to user directories
install_user() {
    echo -e "${BLUE}Installing to user directories...${NC}"
    
    # Create local bin directory
    mkdir -p "$LOCAL_BIN"
    
    # Copy webapp-creator to ~/.local/bin
    if [[ -f "$WEBAPP_CREATOR" ]]; then
        cp "$WEBAPP_CREATOR" "$LOCAL_BIN/webapp-creator"
        chmod +x "$LOCAL_BIN/webapp-creator"
        echo -e "${GREEN}✓ Copied webapp-creator to: $LOCAL_BIN/webapp-creator${NC}"
    else
        echo -e "${RED}✗ WebApp Creator script not found: $WEBAPP_CREATOR${NC}"
        return 1
    fi
    
    # Copy launcher if it exists
    if [[ -f "$LAUNCHER_SCRIPT" ]]; then
        cp "$LAUNCHER_SCRIPT" "$LOCAL_BIN/webapp-launcher"
        chmod +x "$LOCAL_BIN/webapp-launcher"
        echo -e "${GREEN}✓ Copied launcher to: $LOCAL_BIN/webapp-launcher${NC}"
    else
        echo -e "${YELLOW}! Launcher script not found, skipping...${NC}"
    fi
    
    # Copy game-mode script if it exists
    if [[ -f "$GAMEMODE_SCRIPT" ]]; then
        cp "$GAMEMODE_SCRIPT" "$LOCAL_BIN/webapp-gamemode"
        chmod +x "$LOCAL_BIN/webapp-gamemode"
        echo -e "${GREEN}✓
