run_test() {
    echo "Running Godot test..."

    if godot --headless --path . -s scenes/lvl_0/tests/test_map_gen.gd; then
        xdg-open "scenes/lvl_0/tests/result.png"
    else
        echo "Godot failed"
    fi
}

run_test

if command -v inotifywait >/dev/null 2>&1; then
    echo "Watching for changes in scenes/lvl_0/map_generator.gd..."

    while true; do
        echo "Starting file watcher..."

        inotifywait -e modify scenes/lvl_0/map_generator.gd

        status=$?

        if [ "$status" -ne 0 ]; then
            echo "inotifywait exited with status $status. Restarting watcher..."
            run_test
            sleep 1
            continue
        fi

        echo "Change found! Regenerating..."
        run_test
    done
else
    echo "Install 'inotifywait' (usually part of inotify-tools) to automatically run tests on changes."
fi