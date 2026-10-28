#!/usr/bin/env bash
# The App Store iPhone Duo set (docs/appstore/screenshots.md §B) on a real iPhone Duo simulator (iOS 27.1), called by
# ci/store-capture.sh duo (from .github/workflows/store.yml). Lean, in the style of ci/duo.sh (which stays the hinge
# check rig and is not touched): every simctl/hinge call has a timeout, hinge sets are retried, ~2.5 s settle after a
# move. Lessons kept from Snapjaw's store pass (C:\Users\59527\Trap\ci\duo.sh, "pass: the App Store Duo set"):
#  - `simctl io screenshot` needs --display on the Duo, and the names vary (LCD-1 / primary-1 / 3 / internal for the
#    inner display): probe once, then shoot the inner display; a capture that isn't 2853x2007 is retried once.
#  - The phone must be OPEN at a playing angle before the launch: a Glint level never starts open on a Duo when the
#    hinge drives the light ("Close the phone to start"), so every store line uses t= / skill= (the pilot drives the
#    light, DemoMode.forcesPilot) and the hinge is only there to keep the inner display up and the layout folded.
#
#   UDID=<booted Duo> OUT=raw-duo STORE_LIST=ci/duo-store-scenarios.txt STORE_FILTER='^D[0-9]' bash ci/duo-store.sh
#
# Lines: name|demo args|wait|caption|expect|frame|hinge   (hinge = degrees to hold the phone at, a playing angle
#   90–130; default STORE_ANGLE, 125; the flower edge is at 135°, the hinge holds ~15–145°). The book composite's angle is NOT this one: ci/store-set.sh derives it from the band the capture shows.
# A line with freezeOn=<tag> waits (up to max(wait, 30) s) for "GLINT-T freeze <tag>", one with t= or freezeAfter= for
# any "GLINT-T freeze" line, then 2 s; others wait `wait` s.
# Writes $OUT/store-<name>.png, $OUT/logs/store-<name>.txt and logs/store-<name>.at-capture.txt (the log at capture),
# $OUT/duo-store-report.txt. Always exits 0 (ci/store-capture.sh retries what's missing; ci/store-set.sh judges).
set -uo pipefail

UDID="${UDID:?UDID required}"
OUT="${OUT:-raw-duo}"
LIST="${STORE_LIST:-ci/duo-store-scenarios.txt}"
FILTER="${STORE_FILTER:-.}"
SANGLE="${STORE_ANGLE:-125}"
APP="build/Build/Products/Debug-iphonesimulator/Glint.app"
BUNDLE="com.pravegm.glint"
mkdir -p "$OUT/logs" "$OUT/raw"
OUT_ABS="$(cd "$OUT" && pwd)"
REPORT="$OUT_ABS/duo-store-report.txt"
: > "$REPORT"

to() {
  local s="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 5 "$s" "$@"
  elif command -v timeout >/dev/null 2>&1; then timeout -k 5 "$s" "$@"
  else perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$s" "$@"; fi
}
log() { echo "== $(date -u +%H:%M:%S) $*"; }
dims() {
  local out w h
  out=$(to 20 sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null || true)
  w=$(awk '/pixelWidth/ {print $2}' <<< "$out"); h=$(awk '/pixelHeight/ {print $2}' <<< "$out")
  if [[ -n "$w" && -n "$h" ]]; then echo "${w}x${h}"; else echo "?"; fi
}
HAVE_HINGE=0; command -v hinge >/dev/null 2>&1 && HAVE_HINGE=1
(( HAVE_HINGE )) || log "WARN no hinge tool: the Duo stays at its boot angle"
hset() {   # hset <angle>: a confirmed set, 3 tries, then settle
  (( HAVE_HINGE )) || return 1
  local a
  for a in 1 2 3; do
    to 15 hinge -d "$UDID" -t 3 "$1" >/dev/null 2>&1 && { sleep 2.5; return 0; }
    sleep 1
  done
  log "WARN hinge set $1 failed"; return 1
}
wait_for() {   # wait_for <file> <regex> <seconds>
  local t=0
  while (( t < $3 )); do grep -qE "$2" "$1" 2>/dev/null && return 0; sleep 1; t=$((t + 1)); done
  grep -qE "$2" "$1" 2>/dev/null
}

INNER=""
probe_inner() {
  local c d
  for c in LCD-1 primary-1 3 internal; do
    if to 30 xcrun simctl io "$UDID" screenshot --display="$c" "$OUT_ABS/raw/_p.png" >/dev/null 2>&1; then
      d=$(dims "$OUT_ABS/raw/_p.png")
      if [[ "$d" == 2853x2007 || "$d" == 2007x2853 ]]; then INNER="$c"; break; fi
      [[ -z "$INNER" ]] && INNER="$c"   # a display that answers; kept unless a better one is found
    fi
  done
  rm -f "$OUT_ABS/raw/_p.png"
  log "inner display: ${INNER:-default}"
}
shoot() {   # shoot <file>
  if [[ -n "$INNER" ]]; then to 60 xcrun simctl io "$UDID" screenshot --display="$INNER" "$1" >/dev/null 2>&1 && return 0; fi
  to 60 xcrun simctl io "$UDID" screenshot "$1" >/dev/null 2>&1
}

to 60 xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 2>/dev/null || true
(( HAVE_HINGE )) && { to 60 hinge -d "$UDID" get || true; }
to 300 xcrun simctl install "$UDID" "$APP" || { log "install failed, retrying"; sleep 5; to 300 xcrun simctl install "$UDID" "$APP" || log "install failed"; }
hset "$SANGLE" || true
probe_inner

[[ -f "$LIST" ]] || { log "WARN store list $LIST not found"; exit 0; }
while IFS='|' read -r -u 3 name args wait _caption _expect _frame hinge _rest; do
  name="${name%$'\r'}"; args="${args%$'\r'}"; wait="${wait%$'\r'}"; hinge="${hinge%$'\r'}"; hinge="${hinge//[[:space:]]/}"
  [[ -z "$name" || "$name" == \#* ]] && continue
  [[ "$name" =~ $FILTER ]] || continue
  wait="${wait%%.*}"; [[ "$wait" =~ ^[0-9]+$ ]] || wait=8
  [[ "$hinge" =~ ^[0-9]+$ ]] || hinge="$SANGLE"
  (( hinge < 90 || hinge > 130 )) && { log "WARN $name: hinge $hinge outside the playing range 90–130, using $SANGLE"; hinge="$SANGLE"; }
  png="$OUT_ABS/store-$name.png"
  applog="$OUT_ABS/logs/store-$name.txt"
  rm -f "$png"; : > "$applog"
  log "store-$name ($args) hinge ${hinge}°"
  hset "$hinge" || true
  to 30 xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  launched=0
  for attempt in 1 2; do
    if to 90 xcrun simctl launch --terminate-running-process --stdout="$applog" --stderr="$applog" \
         "$UDID" "$BUNDLE" -glintDemo "$args" >/dev/null; then launched=1; break; fi
    log "launch attempt $attempt failed: $name"; sleep 3
  done
  if (( ! launched )); then printf '%s\tlaunch-failed\n' "$name" >> "$REPORT"; continue; fi

  lim=$(( wait > 30 ? wait : 30 ))
  if [[ "$args" =~ freezeOn=([A-Za-z]+) ]]; then
    wait_for "$applog" "GLINT-T freeze ${BASH_REMATCH[1]}( |\$)" "$lim" && sleep 2 || log "WARN $name: no 'GLINT-T freeze ${BASH_REMATCH[1]}' in ${lim} s (shooting anyway)"
  elif [[ "$args" =~ (^|;)(t|freezeAfter)= ]]; then
    wait_for "$applog" "GLINT-T freeze" "$lim" && sleep 2 || log "WARN $name: no 'GLINT-T freeze' in ${lim} s (shooting anyway)"
  else
    sleep "$wait"
  fi

  shoot "$png" || true
  d=$( [[ -f "$png" ]] && dims "$png" || echo - )
  if [[ "$d" != 2853x2007 ]]; then
    log "WARN $name: capture is $d, not the inner display 2853x2007; re-opening to ${hinge}° and shooting again"
    hset "$hinge" || true; sleep 2; probe_inner; shoot "$png" || true
    d=$( [[ -f "$png" ]] && dims "$png" || echo - )
  fi
  cp "$applog" "$OUT_ABS/logs/store-$name.at-capture.txt" 2>/dev/null || : > "$OUT_ABS/logs/store-$name.at-capture.txt"
  printf '%s\t%s\thinge=%s\n' "$name" "$d" "$hinge" >> "$REPORT"
  grep -E "GLINT-T (canvas|freeze|band)" "$applog" | tail -3 || true
  to 30 xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
done 3< "$LIST"

log "report:"; cat "$REPORT"
exit 0
