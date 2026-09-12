#!/bin/bash

# Antigravity CLI status line.
# Reads session JSON on stdin and prints one compact status line.

input=$(cat)

# AGY gives us most of what we need directly in the status payload.
#
# AGY has emitted quota remaining values in two formats:
# remaining_fraction (0..1) and remaining_percentage (0..100). This statusline
# displays percentage USED as a whole number.
#
# Bucket names and container shapes can vary, so inspect all bucket metadata.

IFS=$'\t' read -r MODEL DIR SID MODE PCT TOK WIN H5 D7 BRANCH DIRTY <<<"$(
  printf '%s' "$input" | jq -r '
    def quota_buckets:
      (.quota // {})
      | if type == "array" then
          .[] | select(type == "object")
        elif type == "object" then
          to_entries[]
          | select(.value | type == "object")
          | .value + {map_key: .key}
        else empty
        end;

    def quota_label:
      [.map_key, .id, .name, .window, .description]
      | map(select(. != null) | tostring)
      | join(" ");

    def quota_remaining_percentage:
      if .remaining_percentage != null then
        .remaining_percentage
      elif .remaining_fraction != null then
        .remaining_fraction * 100
      else null
      end;

    def model_quota_group($model):
      if $model | test("gemini"; "i") then "gemini"
      elif $model | test("claude|gpt|oss"; "i") then "3p|claude|gpt|oss"
      else null
      end;

    def matching_quota($window; $group):
      [quota_buckets
        | select(quota_label | test($window; "i"))
        | select($group == null or (quota_label | test($group; "i")))
        | quota_remaining_percentage
        | select(. != null)
      ] | first;

    def quota_used($window; $model):
      model_quota_group($model) as $group
      | (matching_quota($window; $group) // matching_quota($window; null)) as $remaining
      | if $remaining == null then -1
        else (100 - $remaining | round)
        end;

    (.model.display_name // .model.id // "?") as $model
    |

    [
      $model,
      (.workspace.current_dir // .cwd // "."),
      (.conversation_id // .session_id // "nosession"),
      (.execution_mode // "-"),
      ((.context_window.used_percentage // 0) | floor),
      (
        (
          (.context_window.total_input_tokens // 0) +
          (.context_window.total_output_tokens // 0)
        ) | floor
      ),
      ((.context_window.context_window_size // 0) | floor),
      quota_used("5h|five.?hour"; $model),
      quota_used("weekly|week|7d|seven.?day"; $model),
      (.vcs.branch // "-"),
      (if (.vcs.dirty // false) then "1" else "0" end)
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
# AGY gives us branch + dirty natively, but not staged/modified counts.
# Only invoke git when we're actually in a repo. Cache the counts for 5s.

STAGED=0
MODIFIED=0

if [ "$BRANCH" != "-" ]; then
  CACHE="/tmp/agy-statusline-git-$SID"

  stale() {
    [ ! -f "$CACHE" ] ||
      [ $(($(date +%s) - $(stat -c %Y "$CACHE" 2>/dev/null ||
        stat -f %m "$CACHE" 2>/dev/null ||
        echo 0))) -gt 5 ]
  }

  if stale; then
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

    printf '%s|%s\n' "$STAGED" "$MODIFIED" >"$CACHE"
  fi

  IFS='|' read -r STAGED MODIFIED <"$CACHE"
fi

# ---- thresholds -----------------------------------------------------------

# Context: green under 50%, yellow through 79%, red at 80%+.

if [ "$PCT" -ge 80 ]; then
  C=$RED
elif [ "$PCT" -ge 50 ]; then
  C=$YEL
else
  C=$GRN
fi

# Quota usage stays dim until it matters.

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

# Model · directory
OUT="${D}${MODEL} · 󰉋 ${DIR##*/}${R}"

# Git branch, staged (+), and modified (~).
if [ "$BRANCH" != "-" ]; then
  OUT="${OUT}${D} ·  ${BRANCH}${R}"

  [ "${STAGED:-0}" -gt 0 ] &&
    OUT="${OUT} ${GRN}+${STAGED}${R}"

  [ "${MODIFIED:-0}" -gt 0 ] &&
    OUT="${OUT} ${YEL}~${MODIFIED}${R}"
fi

# AGY execution mode.
case "$MODE" in
fast)
  OUT="${OUT}  ${D}⚡${R}"
  ;;
planning)
  OUT="${OUT}  ${D}plan${R}"
  ;;
esac

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
