#!/usr/bin/env bash
# SessionStart hook: anything printed to stdout is added to Claude's context.
# Keep it short; this runs at the start of every session.

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

echo "## Session context"
echo "- Date: $(date '+%Y-%m-%d %H:%M %Z')"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "- Branch: $(git branch --show-current)"
  changes=$(git status --porcelain | wc -l | tr -d ' ')
  echo "- Uncommitted changes: $changes"
fi

if [[ -f HANDOFF.md ]]; then
  echo
  echo "## Handoff from last session"
  cat HANDOFF.md
fi

exit 0
