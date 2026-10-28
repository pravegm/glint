#!/usr/bin/env bash
# The two optional App Store creative assets (the product page header and the search results art, Apple's iOS 27
# placements of 5 Oct 2026), drawn by ci/store-banner.swift from the Duo store pass's REAL inner-display captures.
# Ported from Snapjaw's pipeline (C:\Users\59527\Trap\ci\store-placements.sh):
#
#   bash ci/store-placements.sh <duo dir> <out dir>
#   e.g. bash ci/store-placements.sh raw-duo store-placements
#
# <duo dir> is a `raw-duo` artifact (store-<name>.png at 2853 x 2007, logs/store-<name>*.txt) with that run's
# `store-duo` artifact (the captioned frames and MANIFEST.txt) unpacked into <duo dir>/store/, i.e. the folder
# ci/store-set.sh leaves behind on the assemble runner. store.yml's `placements` job lays it out that way.
#
# Writes <out>/header-3840x1646.png (product page header, 21:9) and <out>/search-3840x2560.png (search results, 3:2),
# both opaque sRGB PNGs, plus <out>/MANIFEST.txt, and for review only <out>/review/: the same art with Apple's template
# safe areas drawn on (*-guides.png), the search art at card size (365 pt wide at 1x and 3x), the header at iPhone
# width (402 pt at 3x), and alternatives (search-side.png: the side layout; search-sweep.png / search-fireflies.png:
# the D02 / D04 frames with their own captions; header-sweep.png). Upload only the two files at the top of <out>.
#
# A capture is used only if it is clean: <dir>/store-<name>.png is 2853 x 2007 (the inner display in book pose, not
# turned, not the cover), its captioned frame passed every ci/store-set.sh check (<dir>/store/<name>.png exists, not
# _flagged/), and its app log shows the folded inner canvas (`GLINT-T canvas <W>x<H> fold=1`). The light side is the
# garden's half (left only for a swap=1 scenario), the book angle the truthful one from the logged band (as
# store-set.sh: θ = 80 + 55 × band, 100–135).
# Hero for both: D01-hero, else D02-sweep (noted as a fallback). The search caption is the hero scenario's own caption
# from ci/duo-store-scenarios.txt, so the words always match the picture; the header has no caption (the wordmark and
# the store line only).
# Never fails the job: always exits 0. Every problem is a MANIFEST line (and a ::warning:: in the Actions log). The
# summary line is `summary: ok <n>  problems <n>`; tools/appstore/asc.swift refuses a folder with problems.
# Env: SOURCE_RUN (the run the captures came from, for the MANIFEST); STORE_BANNER_BIN (compiled renderer cache);
#      HERO_HEADER / HERO_SEARCH (scenario names tried in order, default "D01-hero D02-sweep"); BOOK_ANGLE (degrees,
#      or auto = from the band); BANNER_ARGS: "header=<opts>; search=<opts>; <name>=<opts>; …" — extra
#      ci/store-banner.swift options for the header, the search art, and any other name = a review-only variant
#      (review/variant-<name>.png; give it `--kind header` or `--kind search`, default search). `--from <scenario>`
#      swaps in another clean capture. E.g. BANNER_ARGS="search=--yaw 6; ff=--kind search --from D04-fireflies".
DIR="${1:?usage: store-placements.sh <duo dir> <out dir>}"
OUT="${2:-store-placements}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/store-banner.swift"
SCEN="$HERE/duo-store-scenarios.txt"
CACHE="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
BIN="${STORE_BANNER_BIN:-${CACHE%/}/glint-store-banner}"
BOOK_ANGLE="${BOOK_ANGLE:-auto}"
read -r -a HERO_HEADER_LIST <<< "${HERO_HEADER:-D01-hero D02-sweep}"
read -r -a HERO_SEARCH_LIST <<< "${HERO_SEARCH:-D01-hero D02-sweep}"

mkdir -p "$OUT/review"
OUT="$(cd "$OUT" && pwd)"
rm -f "$OUT"/*.png "$OUT"/review/*.png
MANIFEST="$OUT/MANIFEST.txt"
: > "$MANIFEST"

to() {
  local s="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 5 "$s" "$@"
  elif command -v timeout >/dev/null 2>&1; then timeout -k 5 "$s" "$@"
  else perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$s" "$@"; fi
}
note() { echo "$*" | tee -a "$MANIFEST"; }
warn() { echo "::warning::store placements: $*"; }
summary_out() {
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    { echo "### Store placements (header, search results)"; echo '```'; cat "$MANIFEST"; echo '```'; } >> "$GITHUB_STEP_SUMMARY" 2>/dev/null || true
  fi
}

png_info() {
  local out w h a
  out=$(to 20 sips -g pixelWidth -g pixelHeight -g hasAlpha "$1" 2>/dev/null || true)
  w=$(awk '/pixelWidth/ {print $2}' <<< "$out")
  h=$(awk '/pixelHeight/ {print $2}' <<< "$out")
  a=$(awk '/hasAlpha/ {print $2}' <<< "$out")
  if [[ -n "$w" && -n "$h" ]]; then echo "${w}x${h} alpha=${a:-?}"; else echo "? alpha=?"; fi
}

note "Glint App Store creative assets (product page header, search results)"
note "built: $(date -u '+%Y-%m-%d %H:%M UTC')  commit: ${GITHUB_SHA:-local}  run: ${GITHUB_RUN_ID:-local}  captures from run: ${SOURCE_RUN:-${GITHUB_RUN_ID:-local}}"
note "upload: the two PNGs at the top of this folder only. review/ = guides, thumbnails and alternatives."
note ""

if [[ ! -d "$DIR" ]] || ! ls "$DIR"/store-*.png >/dev/null 2>&1; then
  note "no Duo captures in $DIR (the raw-duo artifact is missing: that run reused another run's Duo with duo_from_run,"
  note "or its Duo job failed). Nothing rendered. Use the run that captured the Duo as placements_from."
  warn "no Duo captures in $DIR; nothing rendered"
  note ""
  note "summary: ok 0  problems 1"
  summary_out
  exit 0
fi
DIR="$(cd "$DIR" && pwd)"
[[ -d "$DIR/store" ]] || warn "no $DIR/store (the store-duo artifact): no capture counts as clean"

# The renderer: compiled once, else interpreted with `xcrun swift`.
if [[ ! -x "$BIN" || "$SRC" -nt "$BIN" ]]; then
  built=0
  for attempt in 1 2; do
    if to 600 xcrun swiftc -O -swift-version 5 -module-name StoreBanner "$SRC" -o "$BIN" > "$OUT/review/store-banner-build.log" 2>&1; then
      built=1; echo "compiled ci/store-banner.swift -> $BIN"; break
    fi
    echo "warning: compile attempt $attempt of ci/store-banner.swift failed"; sleep 3
  done
  if (( ! built )); then
    tail -40 "$OUT/review/store-banner-build.log" || true
    warn "could not compile ci/store-banner.swift (see review/store-banner-build.log); falling back to xcrun swift"
    BIN=""
  fi
fi
render() {
  if [[ -n "$BIN" ]]; then to 300 "$BIN" "$@"; else to 900 xcrun swift "$SRC" "$@"; fi
}

# caption_of <name>: the scenario's caption (4th column of ci/duo-store-scenarios.txt).
caption_of() {
  tr -d '\r' < "$SCEN" | awk -F'|' -v n="$1" '$1 == n { print $4; exit }'
}
# log_of <name>: the app log snapshotted at capture, else the whole log.
log_of() {
  local f="$DIR/logs/store-$1.at-capture.txt"
  [[ -f "$f" ]] || f="$DIR/logs/store-$1.txt"
  echo "$f"
}
args_of() {    # the scenario's demo args (2nd column of ci/duo-store-scenarios.txt)
  tr -d '\r' < "$SCEN" | awk -F'|' -v n="$1" '$1 == n { print $2; exit }'
}
light_of() {   # the garden's half: right by default, left for a swap=1 scenario (as store-set.sh)
  if [[ "$(args_of "$1")" =~ (^|;)swap=(1|on|true|yes)(;|$) ]]; then echo left; else echo right; fi
}
angle_of() {   # store-set.sh's book_angle: θ = 80 + 55 × the logged band, kept to 100–135
  local b=""
  if [[ "$BOOK_ANGLE" != auto ]]; then echo "$BOOK_ANGLE"; return; fi
  [[ -f "$1" ]] && b=$(sed -nE 's/.*GLINT-T band (-?[0-9.]+) .*/\1/p' "$1" | tail -1)
  [[ -z "$b" ]] && { echo 115; return; }
  awk -v b="$b" 'BEGIN { a = 80 + 55 * b; if (a < 100) a = 100; if (a > 135) a = 135; printf "%d\n", a + 0.5 }'
}

WHY=""
CLEAN=""
# clean <name>: CLEAN = the path of a clean 2853x2007 capture and status 0, or status 1 with the reason in WHY.
# (Called directly, never in $(…), so WHY survives.)
clean() {
  local name="$1" raw log info
  WHY=""; CLEAN=""
  raw="$DIR/store-$name.png"
  [[ -f "$raw" ]] || { WHY="no capture store-$name.png"; return 1; }
  info=$(png_info "$raw")
  [[ "${info%% *}" == "2853x2007" ]] || { WHY="store-$name.png is ${info%% *}, not the 2853x2007 inner display"; return 1; }
  [[ -f "$DIR/store/$name.png" ]] || { WHY="its store frame is not clean (not in store-duo; see its MANIFEST.txt)"; return 1; }
  log=$(log_of "$name")
  [[ -f "$log" ]] || { WHY="no app log for store-$name"; return 1; }
  grep -qE "GLINT-T canvas [0-9]+x[0-9]+ fold=1" "$log" || { WHY="its log has no folded inner canvas (GLINT-T canvas <W>x<H> fold=1)"; return 1; }
  CLEAN="$raw"
  return 0
}

# split_args <string>: SPLIT = the words of a shell-like option string (quotes honoured, nothing evaluated).
SPLIT=()
split_args() {
  SPLIT=()
  local s="$1" t words
  [[ -z "${s//[[:space:]]/}" ]] && return 0
  if words=$(python3 -c 'import shlex, sys
for t in shlex.split(sys.argv[1]): print(t)' "$s" 2>/dev/null) && [[ -n "$words" ]]; then
    while IFS= read -r t; do SPLIT+=("$t"); done <<< "$words"
  else
    warn "could not split options like a shell line (python3 missing or unbalanced quotes): split on spaces: $s"
    read -r -a SPLIT <<< "$s"
  fi
  return 0
}

# hero_args <name> <kind>: HA = --hero/--light/--angle (and --caption for search) for a clean capture; 1 if unusable.
HA=()
hero_args() {
  local name="$1" k="$2" log
  HA=()
  clean "$name" || return 1
  log=$(log_of "$name")
  HA=(--hero "$CLEAN" --light "$(light_of "$name")" --angle "$(angle_of "$log")")
  [[ "$k" == search ]] && HA+=(--caption "$(caption_of "$name")")
  return 0
}

# expand <kind> <option string>: EXP = the options with every `--from <name>` replaced by that capture's hero_args.
EXP=()
EXPAND_ERR=""
expand() {
  local k="$1" i=0 n
  EXP=(); EXPAND_ERR=""
  split_args "$2"
  while (( i < ${#SPLIT[@]} )); do
    if [[ "${SPLIT[$i]}" == --from && $((i + 1)) -lt ${#SPLIT[@]} ]]; then
      n="${SPLIT[$((i + 1))]}"
      if hero_args "$n" "$k"; then EXP+=("${HA[@]}"); else EXPAND_ERR="--from $n: $WHY"; fi
      i=$((i + 2))
    else
      EXP+=("${SPLIT[$i]}"); i=$((i + 1))
    fi
  done
  return 0
}

# BANNER_ARGS / BANNER_VARIANTS entries: header=…, search=…, anything else is a review variant.
EXTRA_HEADER="${BANNER_ARGS_HEADER:-}"
EXTRA_SEARCH="${BANNER_ARGS_SEARCH:-}"
VARIANT_NAMES=(); VARIANT_ARGS=()
entries=()
IFS=';' read -r -a entries <<< "${BANNER_ARGS:-};${BANNER_VARIANTS:-}"
for e in ${entries[@]+"${entries[@]}"}; do
  [[ "$e" == *=* ]] || continue
  ename=$(sed 's/=.*//; s/[^A-Za-z0-9_-]//g' <<< "$e"); eargs="${e#*=}"
  [[ -n "$ename" ]] || continue
  case "$ename" in
    header) EXTRA_HEADER="$EXTRA_HEADER $eargs" ;;
    search) EXTRA_SEARCH="$EXTRA_SEARCH $eargs" ;;
    *) VARIANT_NAMES+=("$ename"); VARIANT_ARGS+=("$eargs") ;;
  esac
done

# pick <kind> <names…>: PICKED = the first clean capture's name (HA set for it), or empty.
PICKED=""
pick() {
  local k="$1" n reasons=""
  shift
  PICKED=""
  for n in "$@"; do
    if hero_args "$n" "$k"; then PICKED="$n"; return 0; fi
    reasons="$reasons $n: $WHY;"
  done
  WHY="${reasons%;}"
  return 1
}

ok=0; bad=0
note "$(printf '%-26s %-10s %-6s %-7s %s' file size alpha status notes)"

# one <file> <WxH> <args…>: render, check size, alpha and the renderer's report, write a MANIFEST line.
one() {
  local file="$1" want="$2"; shift 2
  local report status info dims alpha
  report=$(render "$@" --out "$OUT/$file" 2>&1); status=$?
  if (( status != 0 )) || [[ ! -f "$OUT/$file" ]]; then
    note "$(printf '%-26s %-10s %-6s %-7s %s' "$file" - - FAILED "store-banner exit $status: $(tail -3 <<< "$report" | tr '\n' ' ')")"
    warn "$file: store-banner failed: $(tail -1 <<< "$report")"
    bad=$((bad + 1)); return
  fi
  info=$(png_info "$OUT/$file"); dims="${info%% *}"; alpha="${info##*alpha=}"
  local problems=()
  [[ "$dims" == "$want" ]] || problems+=("is $dims, not $want")
  [[ "$alpha" == no ]] || problems+=("alpha=$alpha (App Store Connect rejects alpha)")
  grep -q "text-iphone=yes" <<< "$report" || problems+=("text reaches outside the area an iPhone shows")
  grep -q "device-iphone=yes" <<< "$report" || problems+=("the device reaches outside the area an iPhone shows")
  grep -q "overlap=no" <<< "$report" || problems+=("text touches the device")
  grep -q "extent=ok" <<< "$report" || problems+=("book warp extent mismatch: eyeball the screen mapping")
  grep -q "warp=ok" <<< "$report" || grep -q "warp=flip" <<< "$report" || problems+=("no warp report")
  if (( ${#problems[@]} > 0 )); then
    local joined; joined=$(printf '%s; ' "${problems[@]}"); joined="${joined%; }"
    note "$(printf '%-26s %-10s %-6s %-7s %s' "$file" "$dims" "$alpha" FLAGGED "$joined")"
    warn "$file FLAGGED: $joined"; bad=$((bad + 1))
  else
    note "$(printf '%-26s %-10s %-6s %-7s %s' "$file" "$dims" "$alpha" OK "$(du -k "$OUT/$file" | cut -f1) KB")"
    ok=$((ok + 1))
  fi
  note "    $(grep -m1 '^store-banner:' <<< "$report" | sed "s#$OUT/##")"
}

# review <file> <args…>: a review-only render (never counted, never in the summary).
review() {
  local file="$1"; shift
  local rep
  if rep=$(render "$@" --out "$OUT/review/$file" 2>&1); then
    note "review/$file: $(grep -m1 '^store-banner:' <<< "$rep" | grep -oE '(layout|cap|text-iphone|overlap|angle|light)=[^ ]+' | tr '\n' ' ')"
  else
    note "review/$file: not rendered ($(tail -1 <<< "$rep"))"
    warn "review/$file not rendered: $(tail -1 <<< "$rep")"
  fi
}

for k in header search; do
  if [[ "$k" == header ]]; then names=("${HERO_HEADER_LIST[@]}"); extra="$EXTRA_HEADER"; file=header-3840x1646.png; want=3840x1646
  else names=("${HERO_SEARCH_LIST[@]}"); extra="$EXTRA_SEARCH"; file=search-3840x2560.png; want=3840x2560; fi
  if ! pick "$k" "${names[@]}"; then
    note "$(printf '%-26s %-10s %-6s %-7s %s' "$file" - - FAILED "no clean hero capture:$WHY")"
    warn "$file: no clean hero capture:$WHY"
    bad=$((bad + 1)); continue
  fi
  base=(--kind "$k" "${HA[@]}" --guides "$OUT/review/$k-guides.png")
  expand "$k" "$extra"
  if [[ -n "$EXPAND_ERR" ]]; then
    note "$(printf '%-26s %-10s %-6s %-7s %s' "$file" - - FAILED "banner args: $EXPAND_ERR")"
    warn "$file: banner args: $EXPAND_ERR"; bad=$((bad + 1)); continue
  fi
  if [[ "$extra" =~ --from[[:space:]]+([A-Za-z0-9_-]+) ]]; then PICKED="${BASH_REMATCH[1]}"; hero_note="hero store-$PICKED.png (banner_args --from)"
  else
    hero_note="hero store-$PICKED.png"
    [[ "$PICKED" != "${names[0]}" ]] && { hero_note="$hero_note (FALLBACK: ${names[0]} was not clean)"; warn "$file uses the fallback hero $PICKED"; }
  fi
  [[ -n "${extra//[[:space:]]/}" ]] && hero_note="$hero_note; extra options: $extra"
  note "$file: $hero_note"
  if [[ "$k" == search ]]; then
    if [[ "$extra" == *--caption* ]]; then note "    caption: from banner_args (see extra options)"
    else note "    caption (from ci/duo-store-scenarios.txt): $(caption_of "$PICKED")"; fi
  fi
  one "$file" "$want" "${base[@]}" ${EXP[@]+"${EXP[@]}"}
done

# Review only: alternatives to compare at full size and at card size.
note ""
if hero_args D01-hero search; then review search-side.png --kind search --layout side "${HA[@]}"; fi
if hero_args D02-sweep search; then review search-sweep.png --kind search "${HA[@]}"; fi
if hero_args D04-fireflies search; then review search-fireflies.png --kind search "${HA[@]}"; fi
if hero_args D02-sweep header; then review header-sweep.png --kind header "${HA[@]}"; fi
i=0
while (( i < ${#VARIANT_NAMES[@]} )); do
  vname="${VARIANT_NAMES[$i]}"; vargs="${VARIANT_ARGS[$i]}"; i=$((i + 1))
  vkind=search
  [[ "$vargs" =~ --kind[[:space:]]+header ]] && vkind=header
  if ! hero_args "${HERO_SEARCH_LIST[0]}" "$vkind"; then note "variant $vname: no clean default hero ($WHY)"; continue; fi
  vbase=("${HA[@]}")
  expand "$vkind" "$vargs"
  if [[ -n "$EXPAND_ERR" ]]; then note "variant $vname: $EXPAND_ERR"; continue; fi
  note "variant $vname: $vargs"
  review "variant-$vname.png" --kind "$vkind" "${vbase[@]}" ${EXP[@]+"${EXP[@]}"}
done

thumb() { [[ -f "$1" ]] && to 30 sips --resampleWidth "$2" "$1" --out "$3" > /dev/null 2>&1; }
thumb "$OUT/search-3840x2560.png" 365 "$OUT/review/search-365pt@1x.png"
thumb "$OUT/search-3840x2560.png" 1095 "$OUT/review/search-365pt@3x.png"
thumb "$OUT/review/search-side.png" 365 "$OUT/review/search-side-365pt@1x.png"
thumb "$OUT/header-3840x1646.png" 1206 "$OUT/review/header-402pt@3x.png"
for v in "$OUT"/review/variant-*.png; do
  [[ -f "$v" && "$v" != *-1206.png ]] && thumb "$v" 1206 "${v%.png}-1206.png"
done

note ""
note "summary: ok $ok  problems $bad"
note "before upload: eyeball both at full size and at review/ thumbnail size (docs/appstore/screenshots.md truthfulness rules), then check"
note "them in App Store Connect's product page preview (crops differ by device). No prices, URLs, awards or badges."

summary_out
ls -la "$OUT" "$OUT/review" 2>/dev/null || true
exit 0
