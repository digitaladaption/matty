#!/usr/bin/env bash
# UserPromptSubmit hook: when the user replies "promote 1", "promote 1 3", "promote all"
# or "reject 2", apply that lesson promotion. This runs outside the model, so promotions
# always come from the user (guard-bash.sh stops Claude running promote.sh apply itself).

scripts=$(cd "$(dirname "$0")/../scripts" && pwd)
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cd "${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "."' <<<"$input")}" || exit 0
[[ -f .claude/memory/promotions.json ]] || exit 0

prompt=$(jq -r '.prompt // empty' <<<"$input" | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')

if [[ "$prompt" =~ ^(promote|reject)[[:space:]]+(all|[0-9]+([[:space:],]+[0-9]+)*)[.!]*$ ]]; then
  action=${BASH_REMATCH[1]}
  ids=${BASH_REMATCH[2]}
  [[ "$action" == promote ]] && action=apply
  echo "The user replied \"$prompt\" to the pending lesson promotions. The harness already ran it:"
  "$scripts/promote.sh" "$action" "$ids" . 2>&1
  echo "Tell the user what changed in one or two lines."
fi

exit 0
