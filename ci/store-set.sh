#!/usr/bin/env bash
# Assemble one Glint App Store screenshot set from a capture folder (ci/store-capture.sh → ci/screenshots.sh or
# ci/duo-store.sh output): frame every scenario of <scenarios> that matches <filter> under its caption
# (ci/store-frame.swift) and write <dir>/store/<name>.png, <dir>/store/MANIFEST.txt and <dir>/store/MANIFEST.tsv.
# Ported from Snapjaw's store pipeline (C:\Users\59527\Trap\ci\store-set.sh), with Glint's log lines, glossary and
# portrait phone slots.
#
#   bash ci/store-set.sh <dir> <label> "<slot sizes>" [scenarios] [filter] [raw prefix]
#   e.g. BOOK_DIR=raw-duo bash ci/store-set.sh raw-69 'iPhone 6.9-inch' "1320x2868" ci/store-scenarios.txt '^P[0-9]'
#        REQUIRE_LOG='GLINT-T canvas [0-9]+x[0-9]+ fold=1' \
#          bash ci/store-set.sh raw-duo 'iPhone Duo inner' "2853x2007" ci/duo-store-scenarios.txt '^D[0-9]' store-
#
#  <slot sizes>  the WxH sizes App Store Connect accepts for this slot (Glint: portrait 1320x2868 for 6.9", 1206x2622
#                and 1179x2556 for 6.3"; the Duo inner display in book pose, 2853x2007), space separated, the set's own
#                device size first. A raw capture of any other size (wrong simulator, the Duo's cover display) is
#                FLAGGED and not framed.
#  raw prefix    ci/duo-store.sh names captures store-<name>.png (logs/store-<name>.txt); ci/screenshots.sh uses none.
#
# Scenario lines: name|demo args|wait|caption|expect|frame[|hinge]   (capture scripts ignore the frame column;
#   ci/duo-store.sh reads the hinge column)
#   frame = flat (default) | book | book:<duo scenario name>
#     book            this set's own raw (a Duo inner capture) drawn as the book-pose composite (store-frame --book).
#     book:<name>     the composite made from another set's Duo capture: $BOOK_DIR/$BOOK_PREFIX<name>.png. The iPhone
#                     sets use this for frame 1 (D01's Duo capture). If that capture is missing or not $BOOK_SOURCE_SIZE,
#                     the frame falls back to this set's own flat capture and is FLAGGED.
#
# Checks per frame, against the app log snapshotted at capture (logs/<prefix><name>.at-capture.txt, else .txt; for a
# book:<name> frame, the source capture's log): "GLINT-T demo '…' starts"; "GLINT-T freeze <tag>" for freezeOn=<tag>;
# any "GLINT-T freeze" line for t= or freezeAfter=; the expect regex (5th column); $REQUIRE_LOG; and for every book
# source $BOOK_REQUIRE (default: the Duo's folded canvas). Captions are linted (docs/appstore/screenshots.md "Caption
# style"): headline ≤ 30 characters without the asterisks and ≤ 7 words, exactly one *highlight*; never "flat",
# "shut", "quick", "fast", "free", a price or "#1". Output size and alpha are read back with sips. A frame that fails a
# check is still framed but goes to store/_flagged/, so store/ holds only clean frames. A caption with a banned word
# (store-frame.swift: kill, die, burn, zap, smash, squish, splat, slam, "Fold to", lid, a competitor's name) is
# REJECTED: no frame at all.
# The book angle is TRUTHFUL to the light: the angle at which the app puts the band where the capture shows it,
# θ = 80 + 55 × band (design/ROUND-2.md R2 addendum: the flower edge at 135°; the last "GLINT-T band <b> …" line before the capture), because in store frames
# a pilot (t=/skill=) drives the light, not the simulator's hinge. Kept to 100–135° (the play range the composite reads
# well in); a band outside it is noted (and FLAGGED if the drawn phone would be off by more than 8°).
# The light side (--light) is the garden's half: right, or left when the scenario has swap=1.
# Never fails the job: always exits 0; every problem is a MANIFEST line and a ::warning::.
# Env: STORE_RADIUS (flat capture corner radius, a fraction of its shorter side; default 0.06), STORE_LAYOUT
#      (auto|top|side, default auto: portrait slots get the portrait layout), REQUIRE_LOG, BOOK_DIR, BOOK_PREFIX
#      (default store-), BOOK_SOURCE_SIZE (default 2853x2007), BOOK_REQUIRE, BOOK_ANGLE (degrees, or auto = from the
#      band as above, else 115), STORE_ROTATE (90|270: rotate a capture whose size is a slot size turned sideways
#      before framing; default off = FLAGGED), STORE_FRAME_BIN (compiled compositor cache).
set -uo pipefail

DIR="${1:?usage: store-set.sh <dir> <label> <slot sizes> [scenarios] [filter] [raw prefix]}"
LABEL="${2:-store}"
SIZES="${3:?slot sizes, e.g. 1320x2868}"
SCEN="${4:-ci/store-scenarios.txt}"
FILTER="${5:-.}"
PREFIX="${6:-}"
RADIUS="${STORE_RADIUS:-0.06}"
LAYOUT="${STORE_LAYOUT:-auto}"
REQUIRE_LOG="${REQUIRE_LOG:-}"
BOOK_DIR="${BOOK_DIR:-}"
BOOK_PREFIX="${BOOK_PREFIX:-store-}"
BOOK_SOURCE_SIZE="${BOOK_SOURCE_SIZE:-2853x2007}"
BOOK_REQUIRE="${BOOK_REQUIRE:-GLINT-T canvas [0-9]+x[0-9]+ fold=1}"
BOOK_ANGLE="${BOOK_ANGLE:-auto}"
STORE_ROTATE="${STORE_ROTATE:-}"
FIRST_SIZE="${SIZES%% *}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/store-frame.swift"
CACHE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
BIN="${STORE_FRAME_BIN:-${CACHE%/}/glint-store-frame}"

if [[ ! -d "$DIR" ]]; then
  echo "::warning::$LABEL: no capture folder $DIR (its capture job was skipped or failed); no set made"
  exit 0
fi
mkdir -p "$DIR/store/_flagged" "$DIR/logs" "$DIR/store/.work"
DIR="$(cd "$DIR" && pwd)"
STORE="$DIR/store"
WORK="$STORE/.work"
rm -f "$STORE"/*.png "$STORE"/_flagged/*.png "$WORK"/*
MANIFEST="$STORE/MANIFEST.txt"
TSV="$STORE/MANIFEST.tsv"
: > "$MANIFEST"
printf 'file\tsize\tstatus\tframe\tcaption\tnotes\n' > "$TSV"
BOOK_DIR_ABS=""
if [[ -n "$BOOK_DIR" && -d "$BOOK_DIR" ]]; then BOOK_DIR_ABS="$(cd "$BOOK_DIR" && pwd)"; fi

to() {
  local s="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 5 "$s" "$@"
  elif command -v timeout >/dev/null 2>&1; then timeout -k 5 "$s" "$@"
  else perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$s" "$@"; fi
}

note() { echo "$*" | tee -a "$MANIFEST"; }
warn() { echo "::warning::$LABEL: $*"; }
row() {   # row <file> <size> <slot> <alpha> <status> <frame> <caption> <notes>
  note "$(printf '%-26s %-10s %-5s %-6s %-8s %-5s %s' "$1" "$2" "$3" "$4" "$5" "$6" "$8")"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$5" "$6" "$7" "$8" >> "$TSV"
}

# png_info <file>: "WxH alpha=<yes|no|?>" via sips, or "? alpha=?".
png_info() {
  local out w h a
  out=$(to 20 sips -g pixelWidth -g pixelHeight -g hasAlpha "$1" 2>/dev/null || true)
  w=$(awk '/pixelWidth/ {print $2}' <<< "$out")
  h=$(awk '/pixelHeight/ {print $2}' <<< "$out")
  a=$(awk '/hasAlpha/ {print $2}' <<< "$out")
  if [[ -n "$w" && -n "$h" ]]; then echo "${w}x${h} alpha=${a:-?}"; else echo "? alpha=?"; fi
}
is_slot() { [[ " $SIZES " == *" $1 "* ]]; }
turned() { local w="${1%x*}" h="${1#*x}"; echo "${h}x${w}"; }

# The compositor: compiled once (cached across sets in one job), else interpreted with `xcrun swift`.
if [[ ! -x "$BIN" || "$SRC" -nt "$BIN" ]]; then
  built=0
  for attempt in 1 2; do
    if to 600 xcrun swiftc -O -swift-version 5 -module-name StoreFrame "$SRC" -o "$BIN" > "$DIR/logs/store-frame-build.log" 2>&1; then
      built=1; echo "compiled ci/store-frame.swift -> $BIN"; break
    fi
    echo "warning: compile attempt $attempt of ci/store-frame.swift failed"; sleep 3
  done
  if (( ! built )); then
    tail -40 "$DIR/logs/store-frame-build.log" || true
    warn "could not compile ci/store-frame.swift (see logs/store-frame-build.log); falling back to xcrun swift"
    BIN=""
  fi
fi
compose() {
  local status
  for attempt in 1 2; do
    if [[ -n "$BIN" ]]; then to 180 "$BIN" "$@"; else to 600 xcrun swift "$SRC" "$@"; fi
    status=$?
    (( status == 0 )) && return 0
    (( status == 1 || status == 2 )) && return "$status"   # its own error / a rejected caption: no retry
    sleep 2                                 # a timeout or a crash: one more try
  done
  return "$status"
}

problems=()
# check_log <log> <demo args> <expect regex> <require regex…>: append every failed check to problems.
check_log() {
  local f="$1" a="$2" e="$3" fz wave r
  shift 3
  if [[ ! -f "$f" ]]; then problems+=("no app log for this capture"); return 0; fi
  grep -q "GLINT-T demo '.*' starts" "$f" || problems+=("no \"GLINT-T demo '…' starts\" line (demo args not applied?)")
  # freezeOn=<tag> (DemoMode.Stop: started|pop|sweep|split|hop|firefly|scorch|eaten|sunrise|night|wave|hint).
  if [[ "$a" =~ freezeOn=([A-Za-z]+) ]]; then
    fz="${BASH_REMATCH[1]}"
    grep -qE "GLINT-T freeze $fz( |\$)" "$f" || problems+=("never froze on $fz before the capture")
  elif [[ "$a" == *freezeAfter=* || "$a" =~ (^|;)t= ]]; then
    grep -q "GLINT-T freeze" "$f" || problems+=("never froze (t= / freezeAfter=) before the capture")
  fi
  # stage=<name> (design/notes/app-R5.md R5c): the freeze line must be there, and a stage that gave up (its moment never
  # came) says reason=timeout. Checked for this frame's args and, for a book:<name> source, for any stage in its log.
  if [[ "$a" =~ (^|;)stage=([A-Za-z]+) ]]; then
    st="${BASH_REMATCH[2]}"
    grep -qE "GLINT-T freeze stage-$st( |\$)" "$f" || problems+=("never froze on stage $st before the capture")
  fi
  if grep -qE "GLINT-T stage [A-Za-z]+ reason=timeout" "$f"; then
    problems+=("stage timed out ($(grep -oE 'GLINT-T stage [A-Za-z]+ reason=timeout' "$f" | tail -1 | sed 's/GLINT-T //')): the moment never came; eyeball or re-run")
  fi
  if [[ -n "$e" ]] && ! grep -qE -- "$e" "$f"; then problems+=("log has no line matching '$e'"); fi
  for r in "$@"; do
    if [[ -n "$r" ]] && ! grep -qE -- "$r" "$f"; then problems+=("log has no line matching '$r'"); fi
  done
  return 0
}

# lint_caption <caption>
lint_caption() {
  local c="$1" head words w plain stars
  [[ -z "${c// /}" ]] && { problems+=("empty caption"); return 0; }
  shopt -s nocasematch
  # docs/appstore/screenshots.md "Caption style": never "flat", "shut", a speed word (gentle on the hinge: never rush
  # it), "free", a price or "#1" (Guideline 2.3.7). store-frame.swift rejects the harder words outright.
  plain="$c"
  for w in flat shut quick quickly fast faster free; do
    [[ "$plain" =~ (^|[^a-z])$w([^a-z]|$) ]] && problems+=("caption uses '$w' (screenshots.md caption rules)")
  done
  [[ "$c" == *"£"* || "$c" == *'$'* || "$c" == *"€"* || "$c" == *"#1"* ]] && problems+=("caption has a price or '#1' (Guideline 2.3.7)")
  shopt -u nocasematch
  head="${c%% / *}"
  stars="${head//[^*]/}"
  (( ${#stars} == 2 )) || problems+=("headline needs exactly one *highlight* (it has ${#stars} asterisks)")
  head="${head//\*/}"
  words=$(wc -w <<< "$head" | tr -d ' ')
  (( words > 7 )) && problems+=("headline has $words words (max 7)")
  (( ${#head} > 30 )) && problems+=("headline has ${#head} characters (max 30)")
  return 0
}

# book_angle <source log>: the truthful angle for the composite (see the header): θ = 80 + 55 × band, 100–135.
# Prints "<angle> <note>"; the note is empty, or says how far the light's own angle is from the drawn one.
book_angle() {
  local b=""
  if [[ "$BOOK_ANGLE" != auto ]]; then echo "$BOOK_ANGLE"; return; fi
  [[ -f "$1" ]] && b=$(sed -nE 's/.*GLINT-T band (-?[0-9.]+) .*/\1/p' "$1" | tail -1)
  if [[ -z "$b" ]]; then echo "115 no-band-line"; return; fi
  awk -v b="$b" 'BEGIN { a = 80 + 55 * b; c = a; if (c < 100) c = 100; if (c > 135) c = 135;
    d = a - c; if (d < 0) d = -d; printf "%d %s\n", c + 0.5, (d > 8 ? "off-by-" int(d + 0.5) : (d > 0 ? "clamped" : "")) }'
}

device="(see the capture log)"
if [[ -f "$DIR/device.txt" ]]; then
  device="$(sed -n 's/^name=//p' "$DIR/device.txt") [$(sed -n 's/^resolved=//p' "$DIR/device.txt")]"
fi
note "Glint App Store set: $LABEL"
note "slot sizes: $SIZES   device: $device   book source: ${BOOK_DIR_ABS:-this set}"
note "built: $(date -u '+%Y-%m-%d %H:%M UTC')  commit: ${GITHUB_SHA:-local}  run: ${GITHUB_RUN_ID:-local}"
note "upload: store/*.png only, in name order. store/_flagged/ = framed but a check failed: fix or eyeball first."
note ""
note "$(printf '%-26s %-10s %-5s %-6s %-8s %-5s %s' frame size slot alpha status mode notes)"

ok=0; flagged=0; missing=0
while IFS= read -r -u 3 line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ -z "${line// /}" || "$line" == \#* ]] && continue
  IFS='|' read -r name args wait caption expect frame <<< "$line"
  frame="${frame//[[:space:]]/}"; frame="${frame%%|*}"
  [[ -n "$name" && "$name" =~ $FILTER ]] || continue
  raw="$DIR/$PREFIX$name.png"
  applog="$DIR/logs/$PREFIX$name.at-capture.txt"
  [[ -f "$applog" ]] || applog="$DIR/logs/$PREFIX$name.txt"
  problems=()
  notes=()
  lint_caption "$caption"

  # Which picture, which mode.
  mode=flat; src="$raw"; srclog="$applog"; srcargs="$args"
  if [[ "$frame" == book || "$frame" == book:* ]]; then
    bsrc="$raw"; blog="$applog"; bargs="$args"
    if [[ "$frame" == book:* ]]; then
      bname="${frame#book:}"; bargs=""
      if [[ -n "$BOOK_DIR_ABS" ]]; then
        bsrc="$BOOK_DIR_ABS/$BOOK_PREFIX$bname.png"
        blog="$BOOK_DIR_ABS/logs/$BOOK_PREFIX$bname.at-capture.txt"
        [[ -f "$blog" ]] || blog="$BOOK_DIR_ABS/logs/$BOOK_PREFIX$bname.txt"
      else
        bsrc=""
      fi
    fi
    bdims="-"
    [[ -n "$bsrc" && -f "$bsrc" ]] && { binfo=$(png_info "$bsrc"); bdims="${binfo%% *}"; }
    if [[ "$bdims" == "$BOOK_SOURCE_SIZE" ]]; then
      mode=book; src="$bsrc"; srclog="$blog"; srcargs="$bargs"
    elif [[ -z "$bsrc" || ! -f "$bsrc" ]]; then
      problems+=("book source ${frame#book:} missing (no Duo capture${BOOK_DIR:+ in $BOOK_DIR}): flat fallback; frame 1 must be the book")
    else
      problems+=("book source is $bdims, not the Duo inner $BOOK_SOURCE_SIZE: flat fallback")
    fi
  fi

  if [[ "$mode" == flat && ! -f "$raw" ]]; then
    row "$name.png" - no - MISSING "$mode" "$caption" "no capture $PREFIX$name.png (launch or screenshot failed; see the capture log)"
    warn "$name MISSING (no capture)"
    missing=$((missing + 1))
    continue
  fi

  # Content checks against the log of the picture actually shown.
  # A book:<name> source is another set's Duo capture: this set's REQUIRE_LOG (e.g. the iPhone's unfolded canvas)
  # doesn't apply to it, only BOOK_REQUIRE does.
  if [[ "$mode" == book && "$frame" == book:* ]]; then check_log "$srclog" "$srcargs" "$expect" "$BOOK_REQUIRE"
  elif [[ "$mode" == book ]]; then check_log "$srclog" "$srcargs" "$expect" "$REQUIRE_LOG" "$BOOK_REQUIRE"
  else check_log "$srclog" "$srcargs" "$expect" "$REQUIRE_LOG"; fi

  # The light falls on the garden's page: the right half by default, the left one with Swap halves (swap=1).
  light=right
  [[ "$srcargs" =~ (^|;)swap=(1|on|true|yes)(;|$) || "$args" =~ (^|;)swap=(1|on|true|yes)(;|$) ]] && { light=left; notes+=("swap=1: light from the left"); }

  # Output size.
  if [[ "$mode" == book ]]; then
    outsize="$FIRST_SIZE"
    if [[ -f "$raw" ]]; then rinfo=$(png_info "$raw"); is_slot "${rinfo%% *}" && outsize="${rinfo%% *}"; fi
    read -r angle anote <<< "$(book_angle "$srclog")"
    notes+=("book from $(basename "$src") at ${angle}° (from the band)")
    [[ "$anote" == off-by-* ]] && problems+=("the light needs ${anote#off-by-}° more or less than the drawn ${angle}° phone: pick a capture with the band between 0.22 and 1")
    [[ "$anote" == no-band-line ]] && problems+=("no GLINT-T band line in the source log: the book angle is a guess (115°)")
    [[ "$anote" == clamped ]] && notes+=("angle clamped to the composite range")
  else
    rinfo=$(png_info "$raw"); rawdims="${rinfo%% *}"
    if ! is_slot "$rawdims"; then
      if [[ -n "$STORE_ROTATE" ]] && is_slot "$(turned "$rawdims")"; then
        if to 30 sips -r "$STORE_ROTATE" "$raw" --out "$WORK/$name.png" >/dev/null 2>&1; then
          src="$WORK/$name.png"; rawdims="$(turned "$rawdims")"; notes+=("raw turned ${STORE_ROTATE}°: eyeball the orientation")
        fi
      fi
    fi
    if ! is_slot "$rawdims"; then
      why="raw capture is $rawdims, not a slot size ($SIZES): not framed"
      [[ "$rawdims" != "?" ]] && is_slot "$(turned "$rawdims")" && why="raw capture is $rawdims, a slot size turned sideways (unrotated framebuffer?); set STORE_ROTATE=90|270 or recapture: not framed"
      row "$name.png" "$rawdims" no - FLAGGED "$mode" "$caption" "$why"
      warn "$name: $why"
      flagged=$((flagged + 1))
      continue
    fi
    outsize="$rawdims"
  fi

  dest="$STORE/$name.png"
  (( ${#problems[@]} > 0 )) && dest="$STORE/_flagged/$name.png"
  cargs=(--in "$src" --out "$dest" --size "$outsize" --radius "$RADIUS" --layout "$LAYOUT" --light "$light"
         --caption "$caption")
  [[ "$mode" == book ]] && cargs+=(--book --angle "$angle")
  report=$(compose "${cargs[@]}" 2>&1)
  status=$?
  if (( status == 2 )); then
    row "$name.png" - no - REJECTED "$mode" "$caption" "$(tail -1 <<< "$report")"
    warn "$name: caption REJECTED ($(tail -1 <<< "$report"))"
    missing=$((missing + 1))
    continue
  fi
  if (( status != 0 )) || [[ ! -f "$dest" ]]; then
    row "$name.png" - no - FAILED "$mode" "$caption" "store-frame exit $status: $(tail -1 <<< "$report")"
    warn "$name: store-frame failed ($(tail -1 <<< "$report"))"
    missing=$((missing + 1))
    continue
  fi
  outinfo=$(png_info "$dest")
  outdims="${outinfo%% *}"
  alpha="${outinfo##*alpha=}"
  match=no
  is_slot "$outdims" && match=yes
  [[ "$match" == yes ]] || problems+=("output is $outdims, not a slot size")
  [[ "$alpha" == no ]] || problems+=("output alpha=$alpha (App Store Connect rejects alpha)")
  [[ "$report" == *"extent=mismatch"* ]] && problems+=("book warp extent mismatch: eyeball the screen mapping")
  summary=$(grep -oE '(layout|cap|lines|rounded|warp)=[^ ]+' <<< "$report" | tr '\n' ' ' | sed 's/ $//')
  if (( ${#problems[@]} > 0 )); then
    if [[ "$dest" == "$STORE/$name.png" ]]; then mv -f "$dest" "$STORE/_flagged/$name.png"; fi
    joined=$(printf '%s; ' "${problems[@]}" ${notes[@]+"${notes[@]}"}); joined="${joined%; }"
    row "_flagged/$name.png" "$outdims" "$match" "$alpha" FLAGGED "$mode" "$caption" "$joined"
    warn "$name FLAGGED: $joined"
    flagged=$((flagged + 1))
  else
    joined=$(printf '%s; ' ${notes[@]+"${notes[@]}"} "$summary"); joined="${joined%; }"
    row "$name.png" "$outdims" "$match" "$alpha" OK "$mode" "$caption" "$joined"
    ok=$((ok + 1))
  fi
  note "    caption: $caption"
  facts=$(grep -oE "GLINT-T (freeze|canvas|event (swept|popped|fireflyDelivered|flowerEaten)|result) .*" "$srclog" 2>/dev/null | sed 's/^GLINT-T //' | sort -u | head -6 | tr '\n' ';' | sed 's/;$//; s/;/; /g')
  [[ -n "$facts" ]] && note "    app log: $facts"
done 3< "$SCEN"

rm -rf "$WORK"
note ""
note "summary: ok $ok  flagged $flagged  missing $missing"
note "before upload (docs/appstore/screenshots.md): eyeball every frame. The checks read the app log, not the picture:"
note "the caption must be true of the frame, no stale hint text, nothing important in the crease band, no prices."

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  { echo "### $LABEL"; echo '```'; cat "$MANIFEST"; echo '```'; } >> "$GITHUB_STEP_SUMMARY" 2>/dev/null || true
fi
ls -la "$STORE" "$STORE/_flagged" 2>/dev/null || true
exit 0
