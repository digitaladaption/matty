#!/usr/bin/env bash
# UserPromptSubmit hook: when the user replies "approve" (or "approved", "approve plan",
# "lgtm") and PLAN.md is a draft, flip it to approved. This runs outside the model,
# so approval always comes from the user.

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cd "${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "."' <<<"$input")}" || exit 0
[[ -f PLAN.md ]] && grep -qE '^Status:[[:space:]]*draft[[:space:]]*$' PLAN.md || exit 0

prompt=$(jq -r '.prompt // empty' <<<"$input" | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')

if [[ "$prompt" =~ ^(approve|approved|lgtm)([[:space:]]+(the[[:space:]]+)?plan)?[.!]*$ ]]; then
  sed -i.bak -E 's/^Status:[[:space:]]*draft[[:space:]]*$/Status: approved/' PLAN.md && rm -f PLAN.md.bak
  echo "The user approved PLAN.md (Status is now approved). Start implementing it."
fi

exit 0
