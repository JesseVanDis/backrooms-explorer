#!/bin/bash

cd "$(dirname "$0")/.."

tmp1=$(mktemp)
tmp2=$(mktemp)
tmp3=$(mktemp)

cp ./project.godot ${tmp1}
{
    sed -n '/^\[debug\]$/,/^\[/p' project.godot | sed '$d'
    godot --headless --path . --script res://assets/scripts/utils/static_analysis.gd
} | grep -E '= ?[12]$' | sort -u | sed 's/=[12]$/=2/' > ${tmp2}

awk -v tmp="$tmp2" '
    /^\[debug\]$/ {
        print
        print ""
        while ((getline line < tmp) > 0)
            print line
        print ""
        in_debug = 1
        next
    }

    /^\[/ {
        in_debug = 0
    }

    !in_debug {
        print
    }
' project.godot > ${tmp3} && mv ${tmp3} project.godot

find . -name "*.gd" -print0 | while IFS= read -r -d '' file; do
  echo "checking file: '${file}'"
  godot --headless --path . --check-only --script "$file"
done

mv ${tmp1} ./project.godot
