#!/usr/bin/env bash
# Schedules lessons.sh for this project in your crontab. Safe to re-run.
#
#   .claude/scripts/install-cron.sh [project-dir] [--schedule "50 17 * * 5"] [--remove]
#
# Default schedule: Fridays at 17:50 (machine's local time).
set -euo pipefail

proj=. schedule="50 17 * * 5" remove=""
while (($#)); do
  case "$1" in
    --schedule) schedule="$2"; shift ;;
    --remove) remove=1 ;;
    *) proj="$1" ;;
  esac
  shift
done
proj=$(cd "$proj" && pwd)
crontab_bin=${CRONTAB_BIN:-crontab}
tag="# claude-harness-lessons $proj"

current=$("$crontab_bin" -l 2>/dev/null | grep -vF "$tag" || true)

if [[ -n "$remove" ]]; then
  printf '%s\n' "$current" | "$crontab_bin" -
  echo "Removed lessons job for $proj"
  exit 0
fi

claude_path=$(command -v "${CLAUDE_BIN:-claude}" || true)
if [[ -z "$claude_path" ]]; then
  echo "claude not found on PATH; install Claude Code first (or set CLAUDE_BIN)" >&2
  exit 1
fi

mkdir -p "$proj/.claude/memory"
# cron starts with a bare PATH, so bake in the one that can find claude and jq.
line="$schedule cd \"$proj\" && PATH=\"$(dirname "$claude_path"):$PATH\" CLAUDE_BIN=\"$claude_path\" .claude/scripts/lessons.sh . >> .claude/memory/lessons.log 2>&1 $tag"

{ if [[ -n "$current" ]]; then printf '%s\n' "$current"; fi; printf '%s\n' "$line"; } | "$crontab_bin" -
echo "Scheduled: $schedule"
echo "Log: $proj/.claude/memory/lessons.log"
echo "Try it now: .claude/scripts/lessons.sh --dry-run"
