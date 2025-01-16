#!/bin/bash

# Configuration
TITLE="Steam Debloat"
GITHUB="Github.com/mtytyx/Steam-Debloat"
VERSION="v1.0.101"
DEBUG="off"
STEAM_INSTALL_DIR="$HOME/.local/share/Steam"
RETRY_ATTEMPTS=3
RETRY_DELAY=5
LOG_FILE="/tmp/Steam-Debloat.log"
STEAM_SCRIPT_PATH="/tmp/steam.sh"

# URLs
STEAM_SETUP_URL="https://cdn.akamai.steamstatic.com/client/installer/steam.deb"
STEAM_SCRIPT_URL="https://raw.githubusercontent.com/mtytyx/Steam-Debloat/refs/heads/main/script/steam.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Debug logging function
write_debug_log() {
    local message="$1"
    local level="${2:-Info}"
    local is_path="${3:-false}"
    
    echo -ne "${YELLOW}== [$level] ${NC}"
    
    if [ "$is_path" = true ] || [[ "$message" =~ ^(/|~/|\./) ]]; then
        echo -e "${MAGENTA}$message${NC}"
    else
        echo -e "${CYAN}$message${NC}"
    fi
    
    if [ "$DEBUG" = "on" ]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "== [$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

# Check for root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        write_debug_log "This script requires root privileges" "Warning"
        sudo "$0"
        exit $?
    fi
}

# Check if Steam is installed
check_steam_installation() {
    if [ -f "$STEAM_INSTALL_DIR/steam" ]; then
        return 0
    else
        return 1
    fi
}

# Download steam script
get_steam_script() {
    local attempt=0
    while [ $attempt -lt $RETRY_ATTEMPTS ]; do
        attempt=$((attempt + 1))
        if curl -s -o "$STEAM_SCRIPT_PATH" "$STEAM_SCRIPT_URL"; then
            if [ -s "$STEAM_SCRIPT_PATH" ]; then
                return 0
            fi
        fi
        write_debug_log "Attempt $attempt to download steam.sh failed" "Warning"
        sleep $RETRY_DELAY
    done
    return 1
}

# Wait for path to exist
wait_for_path() {
    local path="$1"
    local timeout="${2:-300}"
    local start_time=$(date +%s)
    
    while [ ! -e "$path" ]; do
        current_time=$(date +%s)
        if [ $((current_time - start_time)) -gt $timeout ]; then
            write_debug_log "Timeout waiting for: $path" "Error"
            return 1
        fi
        sleep 1
    done
    return 0
}

# Install Steam
install_steam() {
    local setup_path="/tmp/steam.deb"
    
    if ! curl -s -o "$setup_path" "$STEAM_SETUP_URL"; then
        write_debug_log "Failed to download Steam installer" "Error"
        return 1
    fi
    
    write_debug_log "Installing Steam..." "Info"
    if ! dpkg -i "$setup_path"; then
        apt-get -f install -y
    fi
    
    write_debug_log "Waiting for installation to complete..." "Info"
    if ! wait_for_path "$STEAM_INSTALL_DIR" 300; then
        write_debug_log "Steam installation did not complete in the expected time" "Error"
        return 1
    fi
    
    if [ -f "$STEAM_INSTALL_DIR/steam" ]; then
        write_debug_log "Steam installed successfully!" "Success"
        rm -f "$setup_path"
        return 0
    else
        write_debug_log "Steam installation failed - steam executable not found" "Error"
        return 1
    fi
    
    rm -f "$setup_path"
    return 1
}

# Start Steam with parameters
start_steam_with_parameters() {
    local mode="$1"
    
    if [ ! -f "$STEAM_INSTALL_DIR/steam" ]; then
        return 1
    fi
    
    local arguments
    if [ "$mode" = "Lite" ] || [ "$mode" = "TEST" ]; then
        arguments="-forcesteamupdate -forcepackagedownload -overridepackageurl -exitsteam"
    else
        arguments="-forcesteamupdate -forcepackagedownload -overridepackageurl -exitsteam"
    fi
    
    "$STEAM_INSTALL_DIR/steam" $arguments &
    
    local timeout=300
    local start_time=$(date +%s)
    while pgrep -x "steam" >/dev/null; do
        current_time=$(date +%s)
        if [ $((current_time - start_time)) -gt $timeout ]; then
            write_debug_log "Steam update process timed out after $timeout seconds." "Warning"
            break
        fi
        sleep 5
    done
    
    write_debug_log "Steam update process completed" "Info"
    return 0
}

# Stop Steam processes
stop_steam_processes() {
    pkill -f "steam"
    sleep 2
    write_debug_log "Stopped Steam processes" "Info"
}

# Get required files
get_required_files() {
    local selected_mode="$1"
    local steam_bat_path="/tmp/Steam-$selected_mode.sh"
    
    bash "$STEAM_SCRIPT_PATH" "$selected_mode"
    
    local steam_cfg_path="/tmp/steam.cfg"
    echo "BootStrapperInhibitAll=enable" > "$steam_cfg_path"
    echo "BootStrapperForceSelfUpdate=disable" >> "$steam_cfg_path"
    
    echo "$steam_bat_path:$steam_cfg_path"
}

# Move configuration file
move_config_file() {
    local source_path="$1"
    local destination_path="$STEAM_INSTALL_DIR/steam.cfg"
    
    cp -f "$source_path" "$destination_path"
    write_debug_log "Moved steam.cfg to $destination_path" "Info"
}

# Move Steam script to desktop
move_steam_script() {
    local source_path="$1"
    local desktop_path="$HOME/Desktop/steam.sh"
    
    cp -f "$source_path" "$desktop_path"
    chmod +x "$desktop_path"
    write_debug_log "Moved steam.sh to desktop" "Info"
    
    echo -e "\n${YELLOW}Do you want optimized Steam to start with the system? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Ss]$ ]]; then
        move_steam_script_to_startup "$desktop_path"
    fi
}

# Move Steam script to startup
move_steam_script_to_startup() {
    local source_path="$1"
    local startup_dir="$HOME/.config/autostart"
    mkdir -p "$startup_dir"
    
    local desktop_entry="$startup_dir/steam-optimized.desktop"
    cat > "$desktop_entry" << EOF
[Desktop Entry]
Type=Application
Name=Steam Optimized
Exec=$source_path
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    
    chmod +x "$desktop_entry"
    write_debug_log "Added Steam to startup" "Info"
}

# Remove temporary files
remove_temp_files() {
    rm -f /tmp/Steam-*.sh
    rm -f /tmp/steam.cfg
    rm -f /tmp/steam.sh
    write_debug_log "Removed temporary files" "Info"
}

# Main function
main() {
    clear
    echo -e "${GREEN}"
    cat << "EOF"
 ______     ______   ______     ______     __    __           
/\  ___\   /\__  _\ /\  ___\   /\  __ \   /\ "-./  \          
\ \___  \  \/_/\ \/ \ \  __\   \ \  __ \  \ \ \-./\ \         
 \/\_____\    \ \_\  \ \_____\  \ \_\ \_\  \ \_\ \ \_\        
  \/_____/     \/_/   \/_____/   \/_/\/_/   \/_/  \/_/        
                                                              
                __    __     ______     __   __     __  __    
               /\ "-./  \   /\  ___\   /\ "-.\ \   /\ \/\ \   
               \ \ \-./\ \  \ \  __\   \ \ \-.  \  \ \ \_\ \  
                \ \_\ \ \_\  \ \_____\  \ \_\\"\_\  \ \_____\ 
                 \/_/  \/_/   \/_____/   \/_/ \/_/   \/_____/ 
EOF
    echo -e "${NC}"
    
    write_debug_log "$VERSION" "Info"
    
    echo -e "\n${YELLOW}Select optimization mode:${NC}"
    echo "1) Normal"
    echo "2) Lite"
    echo "3) TEST"
    read -r option
    
    case $option in
        1) MODE="Normal";;
        2) MODE="Lite";;
        3) MODE="TEST";;
        *) MODE="Normal";;
    esac
    
    write_debug_log "Starting $TITLE Optimization in $MODE mode" "Info"
    
    if ! check_steam_installation; then
        write_debug_log "Steam is not installed on this system." "Warning"
        echo -e "\n${YELLOW}Steam is not installed. Do you want to install it? (y/n)${NC}"
        read -r response
        if [[ "$response" =~ ^[Ss]$ ]]; then
            if ! install_steam; then
                write_debug_log "Cannot proceed without Steam installation." "Error"
                exit 1
            fi
        else
            write_debug_log "Cannot proceed without Steam installation." "Error"
            exit 1
        fi
    fi
    
    stop_steam_processes
    
    IFS=':' read -r steam_bat_path steam_cfg_path <<< "$(get_required_files "$MODE")"
    move_config_file "$steam_cfg_path"
    move_steam_script "$steam_bat_path"
    remove_temp_files
    
    write_debug_log "Steam Optimization process completed successfully!" "Success"
    write_debug_log "Steam has been updated and configured for optimal performance." "Success"
    write_debug_log "You can contribute to improve the repository at: $GITHUB" "Success"
    
    echo -e "\n${YELLOW}Press Enter to exit${NC}"
    read -r
}

# Initialize log file if debug is enabled
if [ "$DEBUG" = "on" ] && [ -f "$LOG_FILE" ]; then
    > "$LOG_FILE"
    write_debug_log "Debug logging enabled - Log file: $LOG_FILE" "Info"
fi

# Download steam.sh at startup
if ! get_steam_script; then
    write_debug_log "Cannot proceed without steam.sh script." "Error"
    exit 1
fi

# Start the script
main
