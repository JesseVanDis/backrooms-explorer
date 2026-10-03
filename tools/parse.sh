#!/bin/bash

# parse.sh - Parsing tools for backrooms-explorer

TRACKING_FILE="$(dirname "$0")/.parse_sh_latest_changes.txt"

show_help() {
    echo "Usage: parse.sh [OPTION] [ARGS]"
    echo ""
    echo "Options:"
    echo "  --help                                 Show this help message"
    echo "  --flac_to_ogg_for_import [IN] [OUT]    Convert .flac files to .ogg"
    echo "                                         If IN and OUT are not set, searches for all 'voice' folders"
}

check_ffmpeg() {
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo "Error: ffmpeg is not found on the machine. Please install it to continue." >&2
        exit 1
    fi
}

# Function to get mtime in epoch
get_mtime() {
    stat -c %Y "$1"
}

# Function to check if file has changed
has_changed() {
    local file="$1"
    local current_mtime
    current_mtime=$(get_mtime "$file")
    
    if [ ! -f "$TRACKING_FILE" ]; then
        return 0 # Has changed (or rather, no record exists)
    fi
    
    local recorded_mtime
    recorded_mtime=$(grep "^$file:" "$TRACKING_FILE" | cut -d: -f2)
    
    if [ -z "$recorded_mtime" ] || [ "$current_mtime" -gt "$recorded_mtime" ]; then
        return 0 # Changed
    fi
    
    return 1 # Not changed
}

# Function to update tracking file
update_tracking() {
    local file="$1"
    local current_mtime
    current_mtime=$(get_mtime "$file")
    
    # Create tracking file if it doesn't exist
    touch "$TRACKING_FILE"
    
    # Remove old entry if exists and append new one
    # Using a temp file for safety
    grep -v "^$file:" "$TRACKING_FILE" > "${TRACKING_FILE}.tmp" 2>/dev/null || true
    echo "$file:$current_mtime" >> "${TRACKING_FILE}.tmp"
    mv "${TRACKING_FILE}.tmp" "$TRACKING_FILE"
}

convert_flac_to_ogg() {
    local input_folder="$1"
    local output_folder="$2"

    if [ -z "$input_folder" ] || [ -z "$output_folder" ]; then
        # Default behavior: search for 'voice' folders
        find . -type d -name "voice" | while read -r voice_dir; do
            echo "Processing voice folder: $voice_dir"
            local gen_dir="$voice_dir/gen"
            
            mkdir -p "$gen_dir"
            if [ ! -f "$gen_dir/README.txt" ]; then
                echo "This folder contains files converted via tools/parse.sh. Do not edit the .ogg files. instead please change the .flac files, and run the parse.sh" > "$gen_dir/README.txt"
            fi
            
            find "$voice_dir" -maxdepth 1 -name "*.flac" | while read -r flac_file; do
                local filename
                filename=$(basename "$flac_file" .flac)
                local output_file="$gen_dir/$filename.ogg"
                
                if has_changed "$flac_file"; then
                    echo "Converting $flac_file to $output_file"
                    if ffmpeg -i "$flac_file" -y -acodec libvorbis "$output_file" </dev/null >/dev/null 2>&1; then
                        update_tracking "$flac_file"
                    else
                        echo "Error: Failed to convert $flac_file" >&2
                    fi
                else
                    echo "Skipping $flac_file (unchanged)"
                fi
            done
        done
    else
        # Specified folders
        if [ ! -d "$input_folder" ]; then
            echo "Error: Input folder '$input_folder' does not exist." >&2
            exit 1
        fi
        
        mkdir -p "$output_folder"
        if [ ! -f "$output_folder/README.txt" ]; then
            echo "This folder contains files converted via tools/parse.sh" > "$output_folder/README.txt"
        fi
        
        find "$input_folder" -maxdepth 1 -name "*.flac" | while read -r flac_file; do
            local filename
            filename=$(basename "$flac_file" .flac)
            local output_file="$output_folder/$filename.ogg"
            
            if has_changed "$flac_file"; then
                echo "Converting $flac_file to $output_file"
                if ffmpeg -i "$flac_file" -y -acodec libvorbis "$output_file" </dev/null >/dev/null 2>&1; then
                    update_tracking "$flac_file"
                else
                    echo "Error: Failed to convert $flac_file" >&2
                fi
            else
                echo "Skipping $flac_file (unchanged)"
            fi
        done
    fi
}

run_default_tasks() {
    echo "Running default parsing tasks..."
    
    # List of default tasks to execute
    check_ffmpeg
    convert_flac_to_ogg
}

# Main execution
if [ $# -eq 0 ]; then
    run_default_tasks
    exit 0
fi

case "$1" in
    --help)
        show_help
        ;;
    --flac_to_ogg_for_import)
        check_ffmpeg
        convert_flac_to_ogg "$2" "$3"
        ;;
    *)
        show_help
        exit 1
        ;;
esac
