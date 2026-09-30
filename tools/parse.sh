#!/bin/bash

# parse.sh - Parsing tools for backrooms-explorer

show_help() {
    echo "Usage: parse.sh [OPTION] [ARGS]"
    echo ""
    echo "Options:"
    echo "  --help                                 Show this help message"
    echo "  --flac_to_ogg_for_import [IN] [OUT]    Convert .flac files to .ogg"
    echo "                                         If IN and OUT are not set, searches for all 'lossless' folders"
}

check_ffmpeg() {
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo "Error: ffmpeg is not found on the machine. Please install it to continue." >&2
        exit 1
    fi
}

convert_flac_to_ogg() {
    local input_folder="$1"
    local output_folder="$2"

    if [ -z "$input_folder" ] || [ -z "$output_folder" ]; then
        # Default behavior: search for 'lossless' folders
        find . -type d -name "lossless" | while read -r lossless_dir; do
            echo "Processing lossless folder: $lossless_dir"
            local parent_dir
            parent_dir=$(dirname "$lossless_dir")
            
            find "$lossless_dir" -maxdepth 1 -name "*.flac" | while read -r flac_file; do
                local filename
                filename=$(basename "$flac_file" .flac)
                local output_file="$parent_dir/$filename.ogg"
                
                echo "Converting $flac_file to $output_file"
                ffmpeg -i "$flac_file" -y -acodec libvorbis "$output_file" </dev/null
            done
        done
    else
        # Specified folders
        if [ ! -d "$input_folder" ]; then
            echo "Error: Input folder '$input_folder' does not exist." >&2
            exit 1
        fi
        
        mkdir -p "$output_folder"
        
        find "$input_folder" -maxdepth 1 -name "*.flac" | while read -r flac_file; do
            local filename
            filename=$(basename "$flac_file" .flac)
            local output_file="$output_folder/$filename.ogg"
            
            echo "Converting $flac_file to $output_file"
            ffmpeg -i "$flac_file" -y -acodec libvorbis "$output_file" </dev/null
        done
    fi
}

# Main execution
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
