#!/usr/bin/env zsh
# poll-wave.sh — Stream live status of dispatched worker jobs.
# Runs as a single foreground Bash call; the harness streams stdout to the user.
# Zero model tokens consumed during the entire polling loop.
#
# NOTE: Uses zsh (not bash) because macOS ships bash 3.2 which lacks
# associative arrays. zsh is the default macOS shell and supports them natively.
#
# Usage:
#   zsh poll-wave.sh [--interval SECS] [--timeout SECS] JOB_SPEC [JOB_SPEC ...]
#
# JOB_SPEC format:  agent:job_id:label
#   agent  = codex | cursor | claude-bg
#   job_id = job identifier returned by dispatch
#   label  = short human-readable task name
#
# Example:
#   zsh poll-wave.sh codex:cdx-abc:UserModel cursor:cur-def:APIEndpoint

setopt pipefail

COMPANION=($(command -v codex-companion 2>/dev/null || find ~/.claude/plugins -name "codex-companion.mjs" 2>/dev/null | head -1))
CURSOR="$(command -v cursor-task 2>/dev/null || find ~/.claude/skills -name "cursor-task.sh" 2>/dev/null | head -1)"
JOB_DIR="${TMPDIR:-/tmp}/cursor-agent-jobs"

INTERVAL=5
TIMEOUT=1200  # 20 minutes
HEARTBEAT=15  # force re-render at least every N seconds when idle
JOBS=()

# ── parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval) INTERVAL="$2"; shift 2 ;;
    --timeout)  TIMEOUT="$2";  shift 2 ;;
    *)          JOBS+=("$1");  shift ;;
  esac
done

if [[ ${#JOBS[@]} -eq 0 ]]; then
  echo "Usage: poll-wave.sh [--interval N] [--timeout N] agent:job_id:label ..."
  exit 1
fi

# ── state maps ────────────────────────────────────────────────────────────────
typeset -A STATUS_MAP   # job_id -> status
typeset -A LABEL_MAP    # job_id -> label
typeset -A AGENT_MAP    # job_id -> agent
typeset -A DONE_MAP     # job_id -> 1 when terminal
typeset -A ACTIVITY_MAP # job_id -> last activity hint
typeset -A LINES_MAP    # job_id -> last known log line count (cursor)
typeset -A START_MAP    # job_id -> SECONDS when first observed running
typeset -A ELAPSED_MAP  # job_id -> final elapsed seconds when terminal

for spec in "${JOBS[@]}"; do
  IFS=: read -r agent job_id label <<< "$spec"
  AGENT_MAP[$job_id]="$agent"
  LABEL_MAP[$job_id]="${label:-$job_id}"
  STATUS_MAP[$job_id]="pending"
  DONE_MAP[$job_id]=0
  ACTIVITY_MAP[$job_id]=""
  LINES_MAP[$job_id]=0
done

# ── agent-specific polling ────────────────────────────────────────────────────

poll_codex() {
  local job_id="$1"
  local json job_status activity

  json=$("${COMPANION[@]}" status --all --json 2>/dev/null || echo '{}')

  local is_running
  is_running=$(echo "$json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
running = d.get('running', [])
for r in running:
    if r.get('id','') == '$job_id':
        print('yes')
        sys.exit()
print('no')
" 2>/dev/null || echo "no")

  if [[ "$is_running" == "yes" ]]; then
    job_status="running"
    activity=$(echo "$json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for r in d.get('running', []):
    if r.get('id','') == '$job_id':
        msg = r.get('lastMessage', r.get('job_status', ''))
        if msg:
            print(msg[:60])
        break
" 2>/dev/null || echo "")
  else
    local fin_status
    fin_status=$(echo "$json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
lf = d.get('latestFinished') or {}
if lf.get('id','') == '$job_id':
    print(lf.get('status','done'))
else:
    for r in d.get('recent', []):
        if r.get('id','') == '$job_id':
            print(r.get('status','done'))
            sys.exit()
    print('running')
" 2>/dev/null || echo "running")
    job_status="$fin_status"
    [[ "$job_status" == "completed" ]] && job_status="done"
    activity=""
  fi

  STATUS_MAP[$job_id]="$job_status"
  ACTIVITY_MAP[$job_id]="$activity"
}

poll_cursor() {
  local job_id="$1"
  local log="$JOB_DIR/$job_id.log"
  local pid_file="$JOB_DIR/$job_id.pid"

  if [[ ! -f "$log" ]]; then
    STATUS_MAP[$job_id]="not_found"
    ACTIVITY_MAP[$job_id]=""
    return
  fi

  local pid job_status
  pid=$(cat "$pid_file" 2>/dev/null || echo "")
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    job_status="running"
  else
    job_status="done"
  fi

  local cur_lines last_line
  cur_lines=$(wc -l < "$log" 2>/dev/null | tr -d ' ')
  local prev_lines="${LINES_MAP[$job_id]}"
  LINES_MAP[$job_id]="$cur_lines"

  last_line=$(tail -5 "$log" 2>/dev/null \
    | grep -v '^[[:space:]]*$' \
    | grep -v '^---' \
    | tail -1 \
    | sed 's/^[#*`|]*//' \
    | sed 's/^[[:space:]]*//' \
    | cut -c1-55)

  local activity=""
  if [[ "$job_status" == "running" ]]; then
    local delta=$(( cur_lines - prev_lines ))
    if [[ $delta -gt 0 ]]; then
      activity="${last_line} (+${delta}L)"
    else
      activity="${last_line}"
    fi
  fi

  STATUS_MAP[$job_id]="$job_status"
  ACTIVITY_MAP[$job_id]="$activity"
}

poll_claude_bg() {
  local job_id="$1"
  local sentinel="${TMPDIR:-/tmp}/claude-bg-${job_id}.status"

  if [[ -f "$sentinel" ]]; then
    local content
    content=$(cat "$sentinel" 2>/dev/null)
    if echo "$content" | grep -qi "done\|completed\|finished"; then
      STATUS_MAP[$job_id]="done"
    elif echo "$content" | grep -qi "failed\|error"; then
      STATUS_MAP[$job_id]="failed"
    else
      STATUS_MAP[$job_id]="running"
    fi
    ACTIVITY_MAP[$job_id]=$(tail -1 "$sentinel" | cut -c1-55)
  else
    STATUS_MAP[$job_id]="running"
    ACTIVITY_MAP[$job_id]="(awaiting agent callback)"
  fi
}

poll_job() {
  local agent="$1" job_id="$2"
  case "$agent" in
    codex)     poll_codex "$job_id" ;;
    cursor)    poll_cursor "$job_id" ;;
    claude-bg) poll_claude_bg "$job_id" ;;
    *)         STATUS_MAP[$job_id]="unknown"; ACTIVITY_MAP[$job_id]="" ;;
  esac
}

is_terminal() {
  case "$1" in
    done|completed|finished|failed|error|cancelled|not_found) return 0 ;;
    *) return 1 ;;
  esac
}

# ── ANSI colors ──────────────────────────────────────────────────────────────
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_DIM="\033[2m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_RED="\033[31m"
C_CYAN="\033[36m"
C_MAGENTA="\033[35m"
C_WHITE="\033[97m"
C_BG_GREEN="\033[42m"
C_BG_YELLOW="\033[43m"
C_BG_RED="\033[41m"

# ── display helpers ──────────────────────────────────────────────────────────

# Status glyph + color
styled_status() {
  case "$1" in
    pending)                printf "${C_DIM}◻ pending${C_RESET}" ;;
    running)                printf "${C_YELLOW}⏳ running${C_RESET}" ;;
    done|completed|finished) printf "${C_GREEN}✓ done${C_RESET}" ;;
    failed|error)           printf "${C_RED}✗ failed${C_RESET}" ;;
    not_found)              printf "${C_RED}? not found${C_RESET}" ;;
    cancelled)              printf "${C_DIM}⊘ cancelled${C_RESET}" ;;
    *)                      printf "${C_DIM}? unknown${C_RESET}" ;;
  esac
}

# Agent badge with color
styled_agent() {
  case "$1" in
    codex)     printf "${C_MAGENTA}codex${C_RESET}" ;;
    cursor)    printf "${C_CYAN}cursor${C_RESET}" ;;
    claude-bg) printf "${C_WHITE}claude${C_RESET}" ;;
    *)         printf "${C_DIM}$1${C_RESET}" ;;
  esac
}

# Progress bar: filled/total using block chars
progress_bar() {
  local done_count=$1 total=$2 width=${3:-20}
  local filled=$(( total > 0 ? done_count * width / total : 0 ))
  local empty=$(( width - filled ))
  local bar=""
  local i
  for (( i=0; i<filled; i++ )); do bar+="█"; done
  for (( i=0; i<empty; i++ ));  do bar+="░"; done

  local color="$C_YELLOW"
  [[ $done_count -eq $total ]] && color="$C_GREEN"
  printf "${color}%s${C_RESET}" "$bar"
}

# Box-drawing frame line
box_top()    { printf "${C_DIM}╭─${C_RESET} %s ${C_DIM}%s─╮${C_RESET}\n" "$1" "$(printf '─%.0s' {1..$(( $2 - ${#1} - 4 ))})" ; }
box_bottom() { printf "${C_DIM}╰%s╯${C_RESET}\n" "$(printf '─%.0s' {1..$(( $1 - 2 ))})" ; }
box_sep()    { printf "${C_DIM}│${C_RESET}%*s${C_DIM}│${C_RESET}\n" "$(( $1 - 2 ))" "" ; }

# Spinner frames advance each render so the header visibly ticks
SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
SPIN_IDX=0

# Format seconds as m:ss (compact) or mm:ss
fmt_mmss() {
  local s=$1
  printf "%d:%02d" $(( s / 60 )) $(( s % 60 ))
}

print_table() {
  local elapsed=$(( SECONDS - START ))
  local mins=$(( elapsed / 60 ))
  local secs=$(( elapsed % 60 ))

  # Advance spinner
  local spin="${SPINNER_FRAMES[$(( SPIN_IDX % ${#SPINNER_FRAMES[@]} + 1 ))]}"
  (( SPIN_IDX++ ))

  # Count states
  local n_done=0 n_running=0 n_failed=0 n_pending=0 n_total=${#JOBS[@]}
  for spec in "${JOBS[@]}"; do
    IFS=: read -r _a jid _l <<< "$spec"
    case "${STATUS_MAP[$jid]}" in
      done|completed|finished) (( n_done++ )) ;;
      running)                 (( n_running++ )) ;;
      failed|error)            (( n_failed++ )) ;;
      *)                       (( n_pending++ )) ;;
    esac
  done

  local W=72  # frame width
  local time_str
  printf -v time_str "%02d:%02d" "$mins" "$secs"

  # Header
  printf "\n"
  printf "${C_DIM}╭─${C_RESET} ${C_CYAN}${spin}${C_RESET} ${C_BOLD}Orchestration${C_RESET} ${C_DIM}─"
  local pad_header=$(( W - 22 - ${#time_str} - 3 ))
  printf '%0.s─' $(seq 1 $pad_header)
  printf " ${C_WHITE}${time_str}${C_RESET} ${C_DIM}─╮${C_RESET}\n"

  # Progress summary line
  printf "${C_DIM}│${C_RESET}  "
  progress_bar $n_done $n_total 20
  printf "  ${C_BOLD}%d${C_RESET}/${C_DIM}%d${C_RESET}" "$n_done" "$n_total"
  if [[ $n_running -gt 0 ]]; then
    printf "  ${C_YELLOW}▸ %d active${C_RESET}" "$n_running"
  fi
  if [[ $n_failed -gt 0 ]]; then
    printf "  ${C_RED}▸ %d failed${C_RESET}" "$n_failed"
  fi
  # Right-pad to frame width
  local summary_visible=$(( 2 + 20 + 2 + ${#n_done} + 1 + ${#n_total} ))
  [[ $n_running -gt 0 ]] && (( summary_visible += 4 + ${#n_running} + 7 ))
  [[ $n_failed -gt 0 ]]  && (( summary_visible += 4 + ${#n_failed} + 7 ))
  local rpad=$(( W - 2 - summary_visible ))
  (( rpad > 0 )) && printf "%*s" "$rpad" ""
  printf "${C_DIM}│${C_RESET}\n"

  # Separator
  printf "${C_DIM}│${C_RESET}%*s${C_DIM}│${C_RESET}\n" "$(( W - 2 ))" ""

  # Task rows
  for spec in "${JOBS[@]}"; do
    IFS=: read -r agent job_id label <<< "$spec"
    local lbl="${LABEL_MAP[$job_id]}"
    local act="${ACTIVITY_MAP[$job_id]}"

    printf "${C_DIM}│${C_RESET}  "
    styled_status "${STATUS_MAP[$job_id]}"
    printf "  "

    # Task label (truncated to 24 chars)
    printf "%-24s" "${lbl[1,24]}"
    printf "  "

    # Agent badge
    styled_agent "$agent"

    # Per-job elapsed timer — ticks every render even when nothing else changes
    local job_secs=""
    if [[ "${STATUS_MAP[$job_id]}" == "running" && -n "${START_MAP[$job_id]}" ]]; then
      job_secs=$(( SECONDS - START_MAP[$job_id] ))
      printf "  ${C_YELLOW}%s${C_RESET}" "$(fmt_mmss $job_secs)"
    elif [[ -n "${ELAPSED_MAP[$job_id]}" ]]; then
      printf "  ${C_DIM}%s${C_RESET}" "$(fmt_mmss ${ELAPSED_MAP[$job_id]})"
    fi

    # Activity hint (dim, right-aligned)
    if [[ -n "$act" ]]; then
      local act_trunc="${act[1,28]}"
      printf "  ${C_DIM}%s${C_RESET}" "$act_trunc"
    fi

    printf "\n"
  done

  # Footer
  printf "${C_DIM}╰"
  local agents_str="${n_running} agents active"
  local footer_pad=$(( W - 2 - ${#n_done} - 1 - ${#n_total} - 9 - ${#agents_str} - 5 ))
  printf '%0.s─' $(seq 1 $(( footer_pad > 0 ? footer_pad : 1 )))
  printf " ${C_DIM}%d/%d tasks · %s${C_RESET} " "$n_done" "$n_total" "$agents_str"
  printf "${C_DIM}─╯${C_RESET}\n\n"
}

# ── main loop ─────────────────────────────────────────────────────────────────
START=$SECONDS

echo "Polling ${#JOBS[@]} jobs every ${INTERVAL}s (timeout ${TIMEOUT}s)..."
print_table

while true; do
  sleep "$INTERVAL"

  all_done=true
  changed=false
  for spec in "${JOBS[@]}"; do
    IFS=: read -r agent job_id label <<< "$spec"
    [[ "${DONE_MAP[$job_id]}" == "1" ]] && continue

    prev_status="${STATUS_MAP[$job_id]}"
    prev_activity="${ACTIVITY_MAP[$job_id]}"
    poll_job "$agent" "$job_id"

    # Stamp job start time the first time we observe it running
    if [[ "${STATUS_MAP[$job_id]}" == "running" && -z "${START_MAP[$job_id]}" ]]; then
      START_MAP[$job_id]=$SECONDS
    fi

    if [[ "${STATUS_MAP[$job_id]}" != "$prev_status" ]] || \
       [[ "${ACTIVITY_MAP[$job_id]}" != "$prev_activity" ]]; then
      changed=true
    fi

    if is_terminal "${STATUS_MAP[$job_id]}"; then
      # Freeze elapsed time on terminal so completed rows show final duration
      if [[ -z "${ELAPSED_MAP[$job_id]}" && -n "${START_MAP[$job_id]}" ]]; then
        ELAPSED_MAP[$job_id]=$(( SECONDS - START_MAP[$job_id] ))
      fi
      DONE_MAP[$job_id]=1
    else
      all_done=false
    fi
  done

  # Always redraw while any job is running — per-job timers + spinner give motion.
  # When idle (all terminal but not all_done, e.g. pending), redraw every HEARTBEAT.
  elapsed=$(( SECONDS - START ))
  any_running=false
  for spec in "${JOBS[@]}"; do
    IFS=: read -r _a jid _l <<< "$spec"
    [[ "${STATUS_MAP[$jid]}" == "running" ]] && any_running=true && break
  done
  if $changed || $any_running || (( elapsed % HEARTBEAT < INTERVAL )); then
    print_table
  fi

  if $all_done; then
    echo "All jobs complete."
    print_table
    exit 0
  fi

  if (( elapsed >= TIMEOUT )); then
    echo "TIMEOUT: ${TIMEOUT}s exceeded. Incomplete jobs remain."
    print_table
    exit 1
  fi
done
