#!/bin/bash

# Claude Code status line.
# Reads session JSON on stdin and prints one compact status line.

input=$(cat)

# Single jq pass. "-" / -1 sentinels stand in for absent fields, since an empty
# field would collapse under IFS=tab and shift every value after it.

IFS=$'\t' read -r MODEL DIR SID EFFORT FAST PCT TOK WIN H5 D7 <<<"$(
  printf '%s' "$input" | jq -r '
    [
      (.model.display_name // "?"),
      (.workspace.current_dir // "."),
      (.session_id // "nosession"),
      (.effort.level // "-"),
      (if .fast_mode then "1" else "0" end),
      ((.context_window.used_percentage // 0) | floor),
      (
        (
          (.context_window.total_input_tokens // 0) +
          (.context_window.total_output_tokens // 0)
        ) | floor
      ),
      ((.context_window.context_window_size // 0) | floor),
      ((.rate_limits.five_hour.used_percentage // -1) | round),
      ((.rate_limits.seven_day.used_percentage // -1) | round)
    ] | @tsv
  '
)"

R=$'\033[0m'
D=$'\033[2m'
RED=$'\033[31m'
YEL=$'\033[33m'
GRN=$'\033[32m'

# ---- git ------------------------------------------------------------------
#
# Git calls are the one real latency risk here, so results are cached for 5s.
#
# The cache key is session_id: stable for the session and unique per session,
# so concurrent sessions in different repos never read each other's state.

CACHE="/tmp/claude-statusline-git-$SID"

stale() {
  [ ! -f "$CACHE" ] ||
    [ $(($(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null ||
      stat -f %m "$CACHE" 2>/dev/null ||
      echo 0))) -gt 5 ]
}

if stale; then
  if git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)

    # Detached HEAD has no branch name; fall back to the short SHA.
    [ -z "$BRANCH" ] &&
      BRANCH=$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)

    STAGED=$(
      git -C "$DIR" diff --cached --numstat 2>/dev/null |
        wc -l |
        tr -d ' '
    )

    MODIFIED=$(
      git -C "$DIR" diff --numstat 2>/dev/null |
        wc -l |
        tr -d ' '
    )

    printf '%s|%s|%s\n' "$BRANCH" "$STAGED" "$MODIFIED" >"$CACHE"
  else
    printf '||\n' >"$CACHE"
  fi
fi

IFS='|' read -r BRANCH STAGED MODIFIED <"$CACHE"

# ---- thresholds -----------------------------------------------------------

# Context: green under 50%, yellow through 79%, red at 80%+.

if [ "$PCT" -ge 80 ]; then
  C=$RED
elif [ "$PCT" -ge 50 ]; then
  C=$YEL
else
  C=$GRN
fi

# Rate limits stay dim until they matter.

lim() {
  if [ "$1" -ge 90 ]; then
    printf '%s' "$RED"
  elif [ "$1" -ge 75 ]; then
    printf '%s' "$YEL"
  else
    printf '%s' "$D"
  fi
}

hum() {
  if [ "$1" -ge 1000000 ]; then
    awk -v n="$1" 'BEGIN {
      v = n / 1000000
      if (v >= 10 || v == int(v))
        printf "%.0fM", v
      else
        printf "%.1fM", v
    }'
  elif [ "$1" -ge 1000 ]; then
    echo "$(($1 / 1000))k"
  else
    echo "$1"
  fi
}

# ---- render ---------------------------------------------------------------

# Model · effort/fast mode · directory
OUT="${D}${MODEL}${R}"

MODE=""
[ "$FAST" = "1" ] && MODE="⚡"
[ "$EFFORT" != "-" ] && MODE="${MODE}${MODE:+ }${EFFORT}"

[ -n "$MODE" ] &&
  OUT="${OUT} ${D}${MODE}${R}"

OUT="${OUT}${D} · 󰉋 ${DIR##*/}${R}"

# Git branch, staged (+), and modified (~).
if [ -n "$BRANCH" ]; then
  OUT="${OUT}${D} ·  ${BRANCH}${R}"

  [ "${STAGED:-0}" -gt 0 ] &&
    OUT="${OUT} ${GRN}+${STAGED}${R}"

  [ "${MODIFIED:-0}" -gt 0 ] &&
    OUT="${OUT} ${YEL}~${MODIFIED}${R}"
fi

# Context usage.
if [ "$WIN" -gt 0 ]; then
  OUT="${OUT}  ${C}$(hum "$TOK") (${PCT}%)${R}"
else
  OUT="${OUT}  ${D}context —${R}"
fi

# Rate limits.
LIMS=""

if [ "$H5" -ge 0 ]; then
  LIMS="$(lim "$H5")5h ${H5}%${R}"
fi

if [ "$D7" -ge 0 ]; then
  [ -n "$LIMS" ] &&
    LIMS="${LIMS}${D} · ${R}"

  LIMS="${LIMS}$(lim "$D7")7d ${D7}%${R}"
fi

[ -n "$LIMS" ] &&
  OUT="${OUT}  ${LIMS}"

printf '%s' "$OUT"
