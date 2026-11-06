#!/bin/bash
# Screenshots every look of the real app window into dist/looks (for the picker).
cd "$(dirname "$0")/.."; mkdir -p dist/looks
BIN="dist/G's Avengers.app/Contents/MacOS/GsAvengers"
for i in 0 1 2 3 4 5 6 7; do
  for mode in pair plain; do
    rm -f /tmp/gsav-demo-window
    if [ $mode = pair ]; then "$BIN" --demo-look $i --pair & else "$BIN" --demo-look $i & fi; P=$!
    for t in $(seq 1 15); do sleep 0.3; [ -f /tmp/gsav-demo-window ] && break; done
    sleep 1.8; screencapture -x -l"$(cat /tmp/gsav-demo-window)" "dist/looks/look${i}_$mode.png"; kill $P; wait $P 2>/dev/null
  done
done
