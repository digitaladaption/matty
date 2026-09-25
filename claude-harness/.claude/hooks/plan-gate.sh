#!/usr/bin/env bash
# PreToolUse hook for Edit/Write: while PLAN.md says "Status: draft", block edits to
# anything except PLAN.md itself, and stop Claude from moving the plan out of draft.
# Only the user can approve (see plan-approve.sh).

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
root="${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "."' <<<"$input")}"
plan="$root/PLAN.md"
[[ -f "$plan" ]] || exit 0

status_of() { grep -m1 -E '^Status:' | sed -E 's/^Status:[[:space:]]*//; s/[[:space:]]*$//'; }

current=$(status_of <"$plan")
[[ "$current" == draft ]] || exit 0

target=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")

if [[ "$(basename "$target")" == PLAN.md ]]; then
  new=$(jq -r '[.tool_input.content, .tool_input.new_string, (.tool_input.edits[]?.new_string)]
               | map(select(. != null)) | join("\n")' <<<"$input" | status_of)
  if [[ -n "$new" && "$new" != draft ]]; then
    echo "Only the user can approve the plan. Leave 'Status: draft' and ask them to reply \"approve\"." >&2
    exit 2
  fi
  exit 0
fi

[[ "$(basename "$target")" == HANDOFF.md ]] && exit 0

echo "PLAN.md is still a draft. Summarise it for the user and wait for them to reply \"approve\" before editing $target." >&2
exit 2
