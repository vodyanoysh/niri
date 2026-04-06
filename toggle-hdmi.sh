#!/bin/bash
# Toggle external monitor: horizontal right → vertical left → horizontal left → horizontal right

# Get all output info in one call
OUTPUT_JSON=$(niri msg --json outputs)

# Parse everything with one python call
read -r EXT TRANSFORM POS_X LAPTOP_W EXT_W EXT_H <<< $(echo "$OUTPUT_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)

ext_name = ''
transform = ''
pos_x = 0
laptop_w = 1867
ext_w = 1920
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
        pos_x = l['x']
        mode = info['modes'][info['current_mode']]
        scale = l['scale']
        ext_w = int(mode['width'] / scale)
        ext_h = int(mode['height'] / scale)

print(ext_name, transform, pos_x, laptop_w, ext_w, ext_h)
")

if [ -z "$EXT" ]; then
    notify-send "Monitor Toggle" "No external monitor found"
    exit 1
fi

if [ "$TRANSFORM" = "Normal" ] && [ "$POS_X" -ge 0 ]; then
    # Horizontal right → Vertical left (90°)
    niri msg output "$EXT" transform 90
    niri msg output "$EXT" position set -- "$(( -EXT_H ))" 0
    notify-send -t 2000 "Monitor: $EXT" "↕ Вертикально (слева)"
elif [ "$TRANSFORM" != "Normal" ]; then
    # Vertical → Horizontal left
    niri msg output "$EXT" transform normal
    niri msg output "$EXT" position set -- "$(( -EXT_W ))" 0
    notify-send -t 2000 "Monitor: $EXT" "↔ Горизонтально (слева)"
else
    # Horizontal left → Horizontal right
    niri msg output "$EXT" transform normal
    niri msg output "$EXT" position set -- "$LAPTOP_W" 0
    notify-send -t 2000 "Monitor: $EXT" "↔ Горизонтально (справа)"
fi
