#!/usr/bin/env bash

input=$(cat)

# --- Parse JSON fields ---
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | jq -r '(.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0) | if . == 0 then empty else . end')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
five_h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_d=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_d_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
worktree=$(echo "$input" | jq -r '.worktree.name // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')

# --- ANSI colors ---
reset='\033[0m'
bold='\033[1m'
dim='\033[2m'

fg_white='\033[97m'
fg_gray='\033[37m'
fg_dark='\033[90m'

fg_green='\033[32m'
fg_red='\033[31m'
fg_yellow='\033[33m'
fg_cyan='\033[36m'
fg_blue='\033[34m'
fg_magenta='\033[35m'

bg_dark='\033[48;5;235m'

# --- Progress bar builder ---
# Usage: make_bar <used_pct> <width> <fill_color>
make_bar() {
  local pct="${1:-0}"
  local width="${2:-12}"
  local fill_col="${3}"
  local filled
  filled=$(echo "$pct $width" | awk '{printf "%d", ($1/100)*$2}')
  local empty=$(( width - filled ))
  local bar=""
  # filled portion: solid block
  for ((i=0; i<filled; i++)); do bar+="▪"; done
  # empty portion: dimmer dot
  for ((i=0; i<empty; i++));  do bar+="·"; done
  printf "${fill_col}%s${fg_dark}%s${reset}" "${bar:0:$filled}" "${bar:$filled}"
}

# Helper to format epoch seconds. fmt_time <epoch> [with_weekday]
fmt_time() {
  local epoch="$1"
  local with_weekday="${2:-}"
  if [ -z "$epoch" ]; then echo ""; return; fi
  if [ -n "$with_weekday" ]; then
    date -r "$epoch" +"%a %H:%M" 2>/dev/null || date -d "@$epoch" +"%a %H:%M" 2>/dev/null || echo ""
  else
    date -r "$epoch" +"%H:%M" 2>/dev/null || date -d "@$epoch" +"%H:%M" 2>/dev/null || echo ""
  fi
}

# --- Context progress bar ---
ctx_section=""
if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
  remaining=$(( 100 - used_int ))
  if   [ "$used_int" -ge 90 ]; then bar_col="$fg_red"
  elif [ "$used_int" -ge 70 ]; then bar_col="$fg_yellow"
  else                               bar_col="$fg_green"
  fi
  # Build bar with correct coloring split
  width=12
  filled=$(echo "$used_int $width" | awk '{printf "%d", ($1/100)*$2}')
  empty=$(( width - filled ))
  filled_str=""
  empty_str=""
  for ((i=0; i<filled; i++)); do filled_str+="▪"; done
  for ((i=0; i<empty; i++));  do empty_str+="·"; done
  bar=$(printf "${bar_col}%s${fg_dark}%s${reset}" "$filled_str" "$empty_str")
  ctx_section=$(printf "${dim}ctx${reset} %s ${bar_col}%s%%${reset}" "$bar" "$used_int")
fi

# --- Token usage ((total_input_tokens + total_output_tokens) / context_window_size) ---
token_section=""
if [ -n "$total_input" ] && [ -n "$ctx_size" ] && [ "$ctx_size" -gt 0 ] 2>/dev/null; then
  # Format numbers with K suffix
  fmt_k() {
    local n="$1"
    if [ "$n" -ge 1000 ] 2>/dev/null; then
      awk -v n="$n" 'BEGIN{printf "%.0fk", n/1000}'
    else
      echo "$n"
    fi
  }
  ti=$(fmt_k "$total_input")
  cs=$(fmt_k "$ctx_size")
  token_section=$(printf "${dim}tokens${reset} ${fg_gray}%s${fg_dark}/%s${reset}" "$ti" "$cs")
fi

# --- Rate limits ---
rate_section=""
if [ -n "$five_h" ]; then
  five_int=$(printf "%.0f" "$five_h")
  if   [ "$five_int" -ge 90 ]; then r5_col="$fg_red"
  elif [ "$five_int" -ge 70 ]; then r5_col="$fg_yellow"
  else                               r5_col="$fg_cyan"
  fi
  r5_time=""
  if [ -n "$five_h_reset" ]; then
    r5_time=$(fmt_time "$five_h_reset")
    [ -n "$r5_time" ] && r5_time=$(printf " ${dim}→ %s${reset}" "$r5_time")
  fi
  rate_section=$(printf "${dim}5h${reset} ${r5_col}%s%%${reset}%b" "$five_int" "$r5_time")
fi
if [ -n "$seven_d" ]; then
  seven_int=$(printf "%.0f" "$seven_d")
  if   [ "$seven_int" -ge 90 ]; then r7_col="$fg_red"
  elif [ "$seven_int" -ge 70 ]; then r7_col="$fg_yellow"
  else                               r7_col="$fg_magenta"
  fi
  r7_time=""
  if [ -n "$seven_d_reset" ]; then
    r7_time=$(fmt_time "$seven_d_reset" "weekday")
    [ -n "$r7_time" ] && r7_time=$(printf " ${dim}→ %s${reset}" "$r7_time")
  fi
  r7_part=$(printf "${dim}7d${reset} ${r7_col}%s%%${reset}%b" "$seven_int" "$r7_time")
  if [ -n "$rate_section" ]; then
    rate_section=$(printf "%b${fg_dark} · ${reset}%b" "$rate_section" "$r7_part")
  else
    rate_section="$r7_part"
  fi
fi

# --- Worktree ---
worktree_section=""
if [ -n "$worktree" ]; then
  worktree_section=$(printf "${fg_yellow}⎇ %s${reset}" "$worktree")
fi

# --- Git diff stats (added/removed lines) ---
git_section=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  stats=$(git -C "$cwd" diff --no-lock-index --shortstat 2>/dev/null)
  staged=$(git -C "$cwd" diff --cached --no-lock-index --shortstat 2>/dev/null)

  added=0
  removed=0

  parse_stat() {
    local s="$1"
    local a r
    a=$(echo "$s" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
    r=$(echo "$s" | grep -oE '[0-9]+ deletion'  | grep -oE '[0-9]+' || echo 0)
    echo "${a:-0} ${r:-0}"
  }

  read wa wr <<< $(parse_stat "$stats")
  read sa sr <<< $(parse_stat "$staged")

  added=$(( ${wa:-0} + ${sa:-0} ))
  removed=$(( ${wr:-0} + ${sr:-0} ))

  if [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
    git_section=""
    [ "$added"   -gt 0 ] && git_section=$(printf "${fg_green}+%d${reset}" "$added")
    if [ "$removed" -gt 0 ]; then
      r_part=$(printf "${fg_red}-%d${reset}" "$removed")
      if [ -n "$git_section" ]; then
        git_section="$git_section ${r_part}"
      else
        git_section="$r_part"
      fi
    fi
  fi
fi

# --- Model name ---
model_section=$(printf "${bold}${fg_white}%s${reset}" "$model")

# --- Caveman mode ---
caveman_section=""
caveman_flag="$HOME/.claude/.caveman-active"
if [ -f "$caveman_flag" ]; then
  caveman_mode=$(cat "$caveman_flag" 2>/dev/null)
  if [ "$caveman_mode" = "full" ] || [ -z "$caveman_mode" ]; then
    caveman_section=$'\033[38;5;172m[CAVEMAN]\033[0m'
  else
    caveman_suffix=$(echo "$caveman_mode" | tr '[:lower:]' '[:upper:]')
    caveman_section=$'\033[38;5;172m[CAVEMAN:'"${caveman_suffix}"$']\033[0m'
  fi
fi

# --- Assemble line ---
sep=$(printf "${fg_dark} · ${reset}")

parts=()
parts+=("$model_section")
[ -n "$ctx_section"      ] && parts+=("$ctx_section")
[ -n "$token_section"    ] && parts+=("$token_section")
[ -n "$rate_section"     ] && parts+=("$rate_section")
[ -n "$worktree_section" ] && parts+=("$worktree_section")
[ -n "$git_section"      ] && parts+=("$git_section")
[ -n "$caveman_section"  ] && parts+=("$caveman_section")

line=""
for i in "${!parts[@]}"; do
  if [ "$i" -eq 0 ]; then
    line="${parts[$i]}"
  else
    line="${line}${sep}${parts[$i]}"
  fi
done

printf "%b\n" "$line"
