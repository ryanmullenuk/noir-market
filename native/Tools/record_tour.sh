#!/bin/zsh
# Records the guided tour from the simulator as an MP4, plus a timeline of when each scene starts.
#   Tools/record_tour.sh            → walkthrough with captions: AppStore/video/walkthrough-raw.mp4
#   Tools/record_tour.sh clean      → no captions, for trailers: AppStore/video/tour-clean.mp4
#   UDID=<duo> REC_DISPLAY=3 OUT_NAME=tour-duo Tools/record_tour.sh clean   → the iPhone Duo's inner screen
# Needs a Debug build installed on the simulator (UDID below; defaults to the 6.9" iPhone).
set -e
cd "${0:A:h}/.."
[[ "$DEVELOPER_DIR" == */Xcode*.app/* ]] || export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
UDID=${UDID:-409E00A9-BAE1-4A00-9A10-AACEFD31D49C}
BUNDLE=games.redhead.noirmarket
OUT=AppStore/video; mkdir -p $OUT
NAME=walkthrough-raw; EXTRA=()
if [[ "$1" == clean ]]; then NAME=tour-clean; EXTRA=(-tourClean); fi
[[ -n "$OUT_NAME" ]] && NAME=$OUT_NAME
DISP=(); [[ -n "$REC_DISPLAY" ]] && DISP=(--display=$REC_DISPLAY)

xcrun simctl boot $UDID 2>/dev/null || true
xcrun simctl status_bar $UDID override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
DATA=$(xcrun simctl get_app_container $UDID $BUNDLE data)
rm -f "$DATA/Documents/tour-timeline.json"
xcrun simctl terminate $UDID $BUNDLE 2>/dev/null || true
sleep 1

xcrun simctl io $UDID recordVideo $DISP --codec h264 --force $OUT/$NAME.mp4 &
REC=$!
sleep 1
python3 -c 'import time; print(time.time())' > $OUT/$NAME.start
xcrun simctl launch $UDID $BUNDLE -musicOff -noGameCenter -palette classic -tourRecord $EXTRA >/dev/null

for i in {1..180}; do
  [[ -f "$DATA/Documents/tour-timeline.json" ]] && break
  sleep 1
done
sleep 1.5
kill -INT $REC; wait $REC 2>/dev/null || true
cp "$DATA/Documents/tour-timeline.json" $OUT/$NAME.timeline.json
echo "Recorded $OUT/$NAME.mp4"
