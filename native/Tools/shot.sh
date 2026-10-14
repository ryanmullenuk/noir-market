#!/bin/bash
# Usage: Tools/shot.sh NAME [launch args...]  — relaunches the app with args and saves a screenshot.
UDID=${UDID:-860528FD-6E85-4774-BD48-EEB184315418}
OUT=${OUT:-/tmp/noir-shots}
mkdir -p "$OUT"
name=$1; shift
xcrun simctl terminate $UDID games.redhead.noirmarket >/dev/null 2>&1
xcrun simctl launch $UDID games.redhead.noirmarket "$@" >/dev/null
sleep ${WAIT:-4}
xcrun simctl io $UDID screenshot "$OUT/$name.png" >/dev/null 2>&1 && sips -Z 1100 "$OUT/$name.png" >/dev/null && echo "$OUT/$name.png"
