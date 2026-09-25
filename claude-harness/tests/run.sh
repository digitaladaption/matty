#!/usr/bin/env bash
# Exercises every hook with the JSON Claude Code would send. Run: ./tests/run.sh
set -uo pipefail

hooks="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.claude/hooks" && pwd)"
proj=$(mktemp -d)
trap 'rm -rf "$proj"' EXIT
export CLAUDE_PROJECT_DIR="$proj"
git -C "$proj" init -q && git -C "$proj" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init

pass=0 fail=0
check() { # name expected actual
  if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $1 (expected $2, got $3)"; fi
}
run() { # hook json -> prints exit code
  "$hooks/$1" <<<"$2" >/dev/null 2>&1; echo $?
}
bash_cmd() { jq -nc --arg c "$1" '{tool_input:{command:$c}}'; }
edit() { jq -nc --arg f "$1" --arg s "$2" '{tool_input:{file_path:$f, new_string:$s}}'; }
write() { jq -nc --arg f "$1" --arg s "$2" '{tool_input:{file_path:$f, content:$s}}'; }
prompt() { jq -nc --arg p "$1" '{prompt:$p}'; }

# guard-bash
check "guard allows git status" 0 "$(run guard-bash.sh "$(bash_cmd 'git status')")"
check "guard blocks rm -rf /" 2 "$(run guard-bash.sh "$(bash_cmd 'rm -rf /')")"
check "guard blocks force push" 2 "$(run guard-bash.sh "$(bash_cmd 'git push --force origin main')")"
check "guard allows normal push" 0 "$(run guard-bash.sh "$(bash_cmd 'git push -u origin feat')")"

# plan-gate: no plan -> everything allowed
check "gate allows edits with no plan" 0 "$(run plan-gate.sh "$(edit "$proj/app.py" x)")"

printf '# Plan: Demo\nStatus: draft\n\n## Acceptance criteria\n- [ ] a (verify: `true`)\n- [ ] b (verify: `true`)\n' >"$proj/PLAN.md"
check "gate blocks code edit on draft" 2 "$(run plan-gate.sh "$(edit "$proj/app.py" x)")"
check "gate allows editing draft plan" 0 "$(run plan-gate.sh "$(edit "$proj/PLAN.md" '- [ ] c')")"
check "gate allows HANDOFF.md on draft" 0 "$(run plan-gate.sh "$(write "$proj/HANDOFF.md" notes)")"
check "gate blocks self-approval (edit)" 2 "$(run plan-gate.sh "$(edit "$proj/PLAN.md" 'Status: approved')")"
check "gate blocks self-approval (write)" 2 "$(run plan-gate.sh "$(write "$proj/PLAN.md" $'# Plan\nStatus: done\n')")"

# plan-approve
run plan-approve.sh "$(prompt 'I do not approve yet')" >/dev/null
check "non-approval leaves draft" "Status: draft" "$(grep -m1 '^Status:' "$proj/PLAN.md")"
run plan-approve.sh "$(prompt '  Approve plan! ')" >/dev/null
check "approve flips status" "Status: approved" "$(grep -m1 '^Status:' "$proj/PLAN.md")"
check "gate allows code edit once approved" 0 "$(run plan-gate.sh "$(edit "$proj/app.py" x)")"

# memory-log
t="$proj/transcript.jsonl"
{
  echo '{"type":"user","message":{"role":"user","content":"hi"}}'
  echo '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"first reply"}]}}'
  echo '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash"},{"type":"text","text":"Final answer\nwith two lines"}]}}'
  echo '{"truncated'
} >"$t"
sed -i.bak 's/^- \[ \] a/- [x] a/' "$proj/PLAN.md" && rm -f "$proj/PLAN.md.bak"
run memory-log.sh "$(jq -nc --arg t "$t" '{session_id:"abc12345-xyz", transcript_path:$t}')" >/dev/null
entry="$proj/.claude/memory/sessions/abc12345-xyz.md"
check "memory entry written" yes "$([[ -f "$entry" ]] && echo yes || echo no)"
check "memory has last assistant text" 1 "$(grep -c 'Last word: Final answer with two lines' "$entry")"
check "memory has plan progress" 1 "$(grep -c 'approved, 1/2 criteria verified' "$entry")"

for i in $(seq 1 25); do run memory-log.sh "{\"session_id\":\"s$i\"}" >/dev/null; done
check "memory pruned to 20" 20 "$(ls "$proj/.claude/memory/sessions" | wc -l | tr -d ' ')"

# session-start
out=$("$hooks/session-start.sh")
check "session-start shows plan" 1 "$(grep -c '^# Plan: Demo' <<<"$out")"
check "session-start shows 3 recent sessions" 3 "$(grep -c '^### ' <<<"$out")"

echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
