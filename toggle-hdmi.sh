#!/bin/bash
# Toggle external monitor between horizontal (right) and vertical (left)

# Get all output info in one call
OUTPUT_JSON=$(niri msg --json outputs)

# Parse everything with one python call
read -r EXT TRANSFORM LAPTOP_W EXT_H <<< $(echo "$OUTPUT_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)

ext_name = ''
transform = ''
laptop_w = 1867
ext_h = 1080

for name, info in data.items():
    l = info.get('logical')
    if not l:
        continue
    if name == 'eDP-1':
        laptop_w = l['width']
    else:
        ext_name = name
        transform = l['transform']
        mode = info['modes'][info['current_mode']]
        scale = l['scale']
        ext_h = int(mode['height'] / scale)

print(ext_name, transform, laptop_w, ext_h)
")

if [ -z "$EXT" ]; then
    notify-send "Monitor Toggle" "No external monitor found"
    exit 1
fi

if [ "$TRANSFORM" = "Normal" ]; then
    # Horizontal → Vertical, move to left
    niri msg output "$EXT" transform 90
    POS_X=$(( -EXT_H ))
    niri msg output "$EXT" position set -- "$POS_X" 0
    notify-send -t 2000 "Monitor: $EXT" "↕ Vertical (left)"
else
    # Vertical → Horizontal, move to right
    niri msg output "$EXT" transform normal
    niri msg output "$EXT" position set -- "$LAPTOP_W" 0
    notify-send -t 2000 "Monitor: $EXT" "↔ Horizontal (right)"
fi
