#!/usr/bin/env bash
# PreToolUse hook for Bash: blocks commands that are hard to undo, plus any patterns
# promoted from lessons into .claude/guard-patterns.txt.
# Claude Code sends the tool call as JSON on stdin. Exit 2 blocks the call
# and feeds stderr back to Claude so it can pick a safer approach.

if ! command -v jq >/dev/null 2>&1; then
  echo "guard-bash: jq not installed, skipping checks" >&2
  exit 0
fi

cmd=$(jq -r '.tool_input.command // empty')

patterns=(
  'rm -rf /( |$)'
  'rm -rf ~'
  'git push .*--force( |$)'
  'git push .*-f( |$)'
  'git reset --hard'
  'mkfs\.'
  'dd if=.* of=/dev/'
  ':\(\)\{ *:\|:& *\};:'
  'curl .*\| *(ba)?sh'
  'promote\.sh[[:space:]]+(apply|reject)'
)

for p in "${patterns[@]}"; do
  if [[ "$cmd" =~ $p ]]; then
    echo "Blocked by harness guard (matched: $p). Ask the user or use a safer alternative." >&2
    exit 2
  fi
done

# One promoted rule per line: <ERE><TAB><message>. Lines starting with # are comments.
promoted="${CLAUDE_PROJECT_DIR:-.}/.claude/guard-patterns.txt"
if [[ -f "$promoted" ]]; then
  while IFS=$'\t' read -r p msg; do
    [[ -z "$p" || "$p" == \#* ]] && continue
    if [[ "$cmd" =~ $p ]]; then
      echo "Blocked by a rule promoted from this project's lessons: ${msg:-matched $p}" >&2
      exit 2
    fi
  done <"$promoted"
fi

exit 0
