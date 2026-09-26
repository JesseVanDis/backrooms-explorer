#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR/../../../"

run_test() {
    if godot --headless --path . -s scenes/lvl_0/tests/test_map_gen.gd; then
        xdg-open "scenes/lvl_0/tests/result.png"
    else
        echo "Test failed, skipping open."
    fi
}

run_test

if command -v inotifywait >/dev/null 2>&1; then
    echo "Watching for changes in scenes/lvl_0/map_generator.gd..."
    while inotifywait -e modify scenes/lvl_0/map_generator.gd; do
        echo "Change found!. Regenerating"
        run_test
    done
else
    echo "Install 'inotifywait' (usually part of inotify-tools) to automatically run tests on changes."
fi