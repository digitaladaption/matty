#!/usr/bin/env bash
# Stop hook: keeps one memory entry per session in .claude/memory/sessions/, rewritten
# after every turn so it always reflects the latest state. session-start.sh loads the
# most recent entries into the next session.

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$input")
transcript=$(jq -r '.transcript_path // empty' <<<"$input")
[[ -n "$sid" ]] || exit 0

cd "${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "."' <<<"$input")}" || exit 0
dir=.claude/memory/sessions
mkdir -p "$dir" || exit 0
keep=20

last_text=""
if [[ -f "$transcript" ]]; then
  last_text=$(tail -n 300 "$transcript" | jq -nrR '
    [inputs | fromjson? | select(.type == "assistant")
     | .message.content[]? | select(.type? == "text") | .text] | last // empty' 2>/dev/null \
    | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g' | cut -c1-500)
fi

{
  echo "### $(date '+%Y-%m-%d %H:%M %Z') (session ${sid:0:8})"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "- Branch: $(git branch --show-current)"
    commit=$(git log -1 --format='%h %s' 2>/dev/null)
    [[ -n "$commit" ]] && echo "- Last commit: $commit"
    changed=$(git status --porcelain | cut -c4- | grep -v '^\.claude/memory' | head -10 \
      | paste -sd ',' - | sed 's/,/, /g')
    [[ -n "$changed" ]] && echo "- Uncommitted: $changed"
  fi
  if [[ -f PLAN.md ]]; then
    title=$(grep -m1 '^# ' PLAN.md | sed -E 's/^# (Plan: )?//')
    status=$(grep -m1 -E '^Status:' PLAN.md | sed -E 's/^Status:[[:space:]]*//')
    done_n=$(grep -cE '^- \[[xX]\]' PLAN.md)
    total_n=$(grep -cE '^- \[[ xX]\]' PLAN.md)
    echo "- Plan: $title ($status, $done_n/$total_n criteria verified)"
  fi
  [[ -n "$last_text" ]] && echo "- Last word: $last_text"
} >"$dir/$sid.md"

ls -t "$dir"/*.md 2>/dev/null | tail -n +$((keep + 1)) | while IFS= read -r f; do rm -f "$f"; done

exit 0
