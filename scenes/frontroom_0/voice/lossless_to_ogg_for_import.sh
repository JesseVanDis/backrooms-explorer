#!/bin/bash

# This script invokes the parse.sh tool to convert lossless files to ogg for import.

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(readlink -f "$SCRIPT_DIR/../../..")

"$PROJECT_ROOT/tools/parse.sh" --flac_to_ogg_for_import "$SCRIPT_DIR/lossless" "$SCRIPT_DIR"
