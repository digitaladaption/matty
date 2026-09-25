#!/usr/bin/env bash
# SessionStart hook: anything printed to stdout is added to Claude's context.
# Keep it short; this runs at the start of every session.

scripts=$(cd "$(dirname "$0")/../scripts" && pwd)
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

echo "## Session context"
echo "- Date: $(date '+%Y-%m-%d %H:%M %Z')"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "- Branch: $(git branch --show-current)"
  changes=$(git status --porcelain | wc -l | tr -d ' ')
  echo "- Uncommitted changes: $changes"
fi

if [[ -f .claude/LESSONS.md ]]; then
  echo
  sed 's/^# Lessons/## Lessons learned in this project (follow these)/' .claude/LESSONS.md
fi

promotions=.claude/memory/promotions.json
if [[ -f "$promotions" ]] && command -v jq >/dev/null 2>&1 \
  && [[ $(jq '.pending | length' "$promotions" 2>/dev/null) -gt 0 ]]; then
  echo
  echo "## Lesson promotions waiting for the user"
  echo "Mention these once. The user replies \"promote <n>\" or \"reject <n>\"; never apply them yourself."
  "$scripts/promote.sh" list . 2>/dev/null
fi

if [[ -f PLAN.md ]]; then
  echo
  echo "## Current plan (PLAN.md)"
  grep -m1 '^# ' PLAN.md
  grep -m1 -E '^Status:' PLAN.md
  grep -E '^- \[[ xX]\]' PLAN.md
fi

mem=.claude/memory/sessions
if ls "$mem"/*.md >/dev/null 2>&1; then
  echo
  echo "## Recent sessions (newest first)"
  ls -t "$mem"/*.md | head -3 | while IFS= read -r f; do cat "$f"; echo; done
fi

if [[ -f HANDOFF.md ]]; then
  echo
  echo "## Handoff from last session"
  cat HANDOFF.md
fi

exit 0
