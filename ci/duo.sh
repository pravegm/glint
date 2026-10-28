#!/usr/bin/env bash
# Glint on a real iPhone Duo simulator (iOS 27.1), hinge driven by the community `hinge` CLI (artemnovichkov/hinge),
# called by .github/workflows/duo.yml. Lean by design (the sister rigs grew to 900 lines; the lessons kept are: every
# simctl/hinge call has a timeout, hinge sets are retried, wait ~2.5 s after a move before a shot, run alone).
#
# One launch: `-glintDemo "screen=play;level=1;duolog=1"` with the real HingeMirrorSource. Checks (from the app's DEBUG
# lines, design/ROUND-1.md + the App addendum):
#   START-CLOSED  open at launch → `GLINT-T prompt close` (a level never starts open)
#   COVER         shut (5°) → `GLINT-T screen cover`
#   OPEN-PROMPT   reopened a little (40°) → `GLINT-T prompt open`, band still < 0 (light pooled in the crease)
#   BAND-MID      112.5° → band ≈ 0.50 (±0.10), phase playing
#   BAND-EDGE     145° → band ≥ 0.92
#   BAND-BACK     95° → band ≈ 0.23 (±0.10): the light follows the phone both ways
#   PAUSE-SHUT    shut mid-level → `GLINT-T paused shut`; reopen to 100° → `GLINT-T resumed`
# Frames: duo-screens/<n>-<what>.png. Results: duo-screens/checks.txt and the job summary. Exit 0 unless STRICT=1.
set -uo pipefail

UDID="${UDID:?UDID required}"
OUT="${OUT:-duo-screens}"
STRICT="${STRICT:-0}"
APP="build/Build/Products/Debug-iphonesimulator/Glint.app"
BUNDLE="com.pravegm.glint"
mkdir -p "$OUT/logs"
OUT_ABS="$(cd "$OUT" && pwd)"
LOG="$OUT_ABS/logs/app.txt"
CHECKS="$OUT_ABS/checks.txt"
: > "$CHECKS"
fails=0

to() { local s="$1"; shift; if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 5 "$s" "$@"; else "$@"; fi; }
log() { echo "== $(date -u +%H:%M:%S) $*"; }

hset() {  # hset <angle>: a confirmed set, 3 tries, then settle
  local a
  for a in 1 2 3; do
    to 15 hinge -d "$UDID" -t 3 "$1" >/dev/null 2>&1 && { sleep 2.5; return 0; }
    sleep 1
  done
  log "WARN hinge set $1 failed"; return 1
}
hsweep() { # hsweep <from> <to> <seconds>
  to $(( ${3%.*} + 12 )) hinge -d "$UDID" sweep "$1" "$2" "$3" >/dev/null 2>&1 || { log "WARN sweep $1→$2 failed; setting"; hset "$2"; return; }
  sleep 2.5
}
shot() { to 60 xcrun simctl io "$UDID" screenshot "$OUT_ABS/$1.png" >/dev/null 2>&1 || log "WARN shot $1 failed"; }
since() { tail -n +"$1" "$LOG" 2>/dev/null; }
mark() { wc -l < "$LOG" 2>/dev/null | tr -d ' '; }
lastband() { since "$1" | grep -oE "GLINT-T band -?[0-9.]+" | tail -1 | awk '{print $3}'; }
verdict() { # verdict <CHECK> <ok 0|1> <detail>
  local v=PASS; [[ "$2" == 1 ]] || { v=FAIL; fails=$((fails + 1)); }
  echo "$1 $v ($3)" | tee -a "$CHECKS"
}
near() { awk -v a="$1" -v b="$2" -v t="$3" 'BEGIN { exit !(a != "" && (a - b < t && b - a < t)) }'; }

to 60 hinge -d "$UDID" get || true
to 300 xcrun simctl install "$UDID" "$APP" || { echo "install failed"; exit 1; }

hset 160
log "launch"
to 30 xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
to 90 xcrun simctl launch --terminate-running-process --stdout="$LOG" --stderr="$LOG" "$UDID" "$BUNDLE" \
  -glintDemo "screen=play;level=1;duolog=1" >/dev/null || log "WARN launch failed"
sleep 8
shot 01-open-at-start
m=0
grep -q "GLINT-T prompt close" "$LOG" && ok=1 || ok=0
verdict START-CLOSED $ok "launched open at 160°: $(grep -oE 'GLINT-T prompt [a-z]+' "$LOG" | tail -1)"

m=$(mark); hsweep 160 5 2.0; sleep 2; shot 02-cover
since "$m" | grep -q "GLINT-T screen cover" && ok=1 || ok=0
verdict COVER $ok "shut to 5°"

m=$(mark); hsweep 5 40 1.5; sleep 1.5; shot 03-crease-glow
b=$(lastband "$m")
since "$m" | grep -q "GLINT-T prompt open" && awk -v b="${b:-1}" 'BEGIN { exit !(b < 0) }' && ok=1 || ok=0
verdict OPEN-PROMPT $ok "40°: band ${b:-none}, $(since "$m" | grep -oE 'GLINT-T prompt [a-z]+' | tail -1)"

m=$(mark); hsweep 40 112 2.0; sleep 2; shot 04-band-mid
b=$(lastband "$m")
near "$b" 0.50 0.10 && since "$m" | grep -q "phase playing" && ok=1 || ok=0
verdict BAND-MID $ok "112°: band ${b:-none}"

m=$(mark); hsweep 112 145 1.5; sleep 2; shot 05-band-edge
b=$(lastband "$m")
awk -v b="${b:-0}" 'BEGIN { exit !(b >= 0.92) }' && ok=1 || ok=0
verdict BAND-EDGE $ok "145°: band ${b:-none}"

m=$(mark); hsweep 145 95 1.5; sleep 2; shot 06-band-back
b=$(lastband "$m")
near "$b" 0.23 0.10 && ok=1 || ok=0
verdict BAND-BACK $ok "95°: band ${b:-none}"

sleep 6; shot 07-playing
m=$(mark); hsweep 95 5 1.5; sleep 2; shot 08-paused-cover
since "$m" | grep -q "GLINT-T paused shut" && p=1 || p=0
m2=$(mark); hsweep 5 100 1.5; sleep 3; shot 09-resumed
since "$m2" | grep -q "GLINT-T resumed" && r=1 || r=0
[[ $p == 1 && $r == 1 ]] && ok=1 || ok=0
verdict PAUSE-SHUT $ok "paused=$p resumed=$r"

sleep 10; shot 10-later
to 30 xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

# UI frames on the inner display (book pose = the Duo's boot orientation), no hinge moves.
for s in "home;progress=mid" "levels;progress=mid" "results;results=won;level=4" "settings"; do
  name="ui-${s%%;*}"
  hset 150
  to 90 xcrun simctl launch --terminate-running-process --stdout="$OUT_ABS/logs/$name.txt" --stderr="$OUT_ABS/logs/$name.txt" \
    "$UDID" "$BUNDLE" -glintDemo "screen=$s" >/dev/null || true
  sleep 7; shot "$name"
  to 30 xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
done

grep -E "GLINT-(H|T)" "$LOG" | tail -60 > "$OUT_ABS/logs/tail.txt" || true
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  { echo "### Duo hinge checks"; echo '```'; cat "$CHECKS"; echo '```'; } >> "$GITHUB_STEP_SUMMARY"
fi
log "$fails check(s) failed"
[[ "$STRICT" == 1 && $fails -gt 0 ]] && exit 1
exit 0
