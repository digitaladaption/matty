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
  echo '{"type":"user","message":{"role":"user","content":"<command-name>/plan</command-name>"}}'
  echo '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"ok"}]}}'
  echo '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"no, use   pnpm\nnot npm"}]}}'
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
check "memory keeps user corrections" 1 "$(grep -c '^  - no, use pnpm not npm$' "$entry")"
check "memory skips tool results and tags" 2 "$(grep -c '^  - ' "$entry")"
HARNESS_NO_MEMORY=1 run memory-log.sh '{"session_id":"skipme"}' >/dev/null
check "memory skipped when HARNESS_NO_MEMORY set" no "$([[ -f "$proj/.claude/memory/sessions/skipme.md" ]] && echo yes || echo no)"

for i in $(seq 1 25); do run memory-log.sh "{\"session_id\":\"s$i\"}" >/dev/null; done
check "memory pruned to 20" 20 "$(ls "$proj/.claude/memory/sessions" | wc -l | tr -d ' ')"

# session-start
out=$("$hooks/session-start.sh")
check "session-start shows plan" 1 "$(grep -c '^# Plan: Demo' <<<"$out")"
check "session-start shows 3 recent sessions" 3 "$(grep -c '^### ' <<<"$out")"

# session-start loads lessons
printf '# Lessons\n- Use pnpm (evidence: corrected; seen 2x, last 2026-09-25)\n' >"$proj/.claude/LESSONS.md"
check "session-start shows lessons" 1 "$("$hooks/session-start.sh" | grep -c 'Use pnpm')"

# lessons.sh, with a stub claude that records how it was called
scripts="$hooks/../scripts"
stub="$proj/stub-claude"
cat >"$stub" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$STUB_DIR/args"; pwd >"$STUB_DIR/pwd"; cat >"$STUB_DIR/prompt"
cat "$STUB_DIR/reply"
STUB
chmod +x "$stub"
export CLAUDE_BIN="$stub" STUB_DIR="$proj"
printf '```\n# Lessons\n- Use pnpm (seen 3x)\n- Run tests before pushing (seen 2x)\n```\n' >"$proj/reply"
lessons_run() { "$scripts/lessons.sh" "$proj" "$@" >/dev/null 2>&1; echo $?; }
# The pruning test above evicted the session with the correction; log it again.
run memory-log.sh "$(jq -nc --arg t "$t" '{session_id:"abc12345-xyz", transcript_path:$t}')" >/dev/null

check "lessons dry-run succeeds" 0 "$(lessons_run --dry-run)"
check "dry-run leaves file alone" 1 "$(grep -c 'Use pnpm (evidence' "$proj/.claude/LESSONS.md")"
check "prompt includes session memory" 1 "$(grep -c '^  - no, use pnpm not npm$' "$proj/prompt")"
check "prompt includes current lessons" 1 "$(grep -c 'Use pnpm (evidence' "$proj/prompt")"
check "claude runs with no tools" 1 "$(grep -cx -- '--tools' "$proj/args")"
check "claude runs outside the project" no "$([[ "$(cat "$proj/pwd")" == "$proj" ]] && echo yes || echo no)"
check "lessons run succeeds" 0 "$(lessons_run)"
check "lessons file rewritten, fences stripped" "# Lessons|- Use pnpm (seen 3x)" "$(head -2 "$proj/.claude/LESSONS.md" | paste -sd '|' -)"
check "previous lessons backed up" 1 "$(grep -c 'Use pnpm (evidence' "$proj/.claude/memory/LESSONS.prev.md")"
echo "Sorry, I can't help with that." >"$proj/reply"
check "bad output rejected" 1 "$(lessons_run)"
check "bad output leaves file alone" "# Lessons" "$(head -1 "$proj/.claude/LESSONS.md")"
empty=$(mktemp -d)
check "no sessions is a no-op" 0 "$("$scripts/lessons.sh" "$empty" >/dev/null 2>&1; echo $?)"
rm -rf "$empty"

# install-cron.sh, with a stub crontab backed by a file
ctab="$proj/crontab.txt"
printf '# my jobs\n\n0 9 * * * echo hi\n' >"$ctab"
cat >"$proj/stub-crontab" <<STUB
#!/usr/bin/env bash
if [[ "\$1" == "-l" ]]; then cat "$ctab"; else cat >"$ctab"; fi
STUB
chmod +x "$proj/stub-crontab"
export CRONTAB_BIN="$proj/stub-crontab"
"$scripts/install-cron.sh" "$proj" >/dev/null && "$scripts/install-cron.sh" "$proj" --schedule "0 20 * * 0" >/dev/null
check "cron job installed once" 1 "$(grep -c 'claude-harness-lessons' "$ctab")"
check "cron schedule updated" 1 "$(grep -c '^0 20 \* \* 0 cd' "$ctab")"
check "existing cron lines kept" "# my jobs||0 9 * * * echo hi" "$(head -3 "$ctab" | paste -sd '|' -)"
"$scripts/install-cron.sh" "$proj" --remove >/dev/null
check "cron job removed" 0 "$(grep -c 'claude-harness-lessons' "$ctab")"
check "other cron lines survive removal" 1 "$(grep -c 'echo hi' "$ctab")"

echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
