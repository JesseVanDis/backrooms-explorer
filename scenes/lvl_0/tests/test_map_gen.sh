#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR/../../../"

godot --headless --path . -s scenes/lvl_0/tests/test_map_gen.gd

xdg-open "scenes/lvl_0/tests/test_maze_custom.png"