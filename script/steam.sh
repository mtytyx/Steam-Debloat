#!/bin/bash

# Default mode if none specified
SELECTED_MODE="${1:-normal}"

# Steam installation directory for Linux
STEAM_DIR="$HOME/.local/share/Steam"

# Define modes and their parameters
declare -A MODES=(
    ["normal"]="--no-cef-sandbox -nooverlay -nobigpicture -nofriendsui -noshaders -novid -noverifyfiles -nointro -skipstreamingdrivers -norepairfiles -nohltv -nofasthtml -nocrashmonitor -no-shared-textures -cef-single-process -cef-in-process-gpu -single_core -cef-disable-sandbox -cef-disable-breakpad -cef-disable-gpu -cef-disable-hang-timeouts -cef-disable-seccomp-sandbox -cef-disable-extensions -cef-disable-remote-fonts -cef-enable-media-stream -cef-disable-accelerated-video-decode steam://open/library"
    
    ["lite"]="--silent -nooverlay -nofriendsui -nobigpicture -noshaders -novid -noverifyfiles -nointro -skipstreamingdrivers -norepairfiles -nohltv -nofasthtml -nocrashmonitor -no-shared-textures -cef-single-process -cef-in-process-gpu -single_core -cef-disable-sandbox -cef-disable-breakpad -cef-disable-gpu -cef-disable-hang-timeouts -cef-disable-seccomp-sandbox -cef-disable-gpu-compositing -cef-disable-extensions -cef-disable-remote-fonts -cef-enable-media-stream -cef-disable-accelerated-video-decode steam://open/library"
    
    ["test"]="-nooverlay -nofriendsui -nobigpicture -noshaders -novid -noverifyfiles -nointro -skipstreamingdrivers -norepairfiles -nohltv -nofasthtml -nocrashmonitor -no-shared-textures -cef-single-process -cef-in-process-gpu -single_core -cef-disable-sandbox -cef-disable-breakpad -cef-disable-gpu -cef-disable-hang-timeouts -cef-disable-seccomp-sandbox -cef-disable-extensions -cef-disable-remote-fonts -cef-enable-media-stream -cef-disable-accelerated-video-decode steam://open/library"
)

create_steam_script() {
    local mode="$1"
    local temp_dir="/tmp"
    local script_path="$temp_dir/Steam-$mode.sh"

    # Create script content
    cat > "$script_path" << EOF
#!/bin/bash
cd "$STEAM_DIR"
./steam ${MODES[${mode,,}]}
EOF

    # Make script executable
    chmod +x "$script_path"
}

# Convert mode to lowercase for comparison
SELECTED_MODE=$(echo "$SELECTED_MODE" | tr '[:upper:]' '[:lower:]')

# Check if mode is valid and create script
if [ ${MODES[$SELECTED_MODE]+_} ]; then
    create_steam_script "$SELECTED_MODE"
else
    echo "Error: Invalid mode selected. Available modes: normal, lite, test" >&2
    exit 1
fi
