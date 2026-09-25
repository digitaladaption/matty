# claude-harness

A portable `.claude/` kit that gives any project the same Claude Code guardrails, context and workflows.

## What's inside

```
claude-harness/
├── install.sh                  # copy the harness into a project
├── CLAUDE.md                   # template project instructions
├── tests/run.sh                # feeds each hook the JSON Claude Code sends
└── .claude/
    ├── settings.json           # permissions + hook wiring
    ├── hooks/
    │   ├── guard-bash.sh       # PreToolUse: blocks destructive shell commands
    │   ├── plan-gate.sh        # PreToolUse: no code edits while PLAN.md is a draft
    │   ├── plan-approve.sh     # UserPromptSubmit: your "approve" reply approves the plan
    │   ├── memory-log.sh       # Stop: writes a per-session memory entry
    │   └── session-start.sh    # SessionStart: git state, plan, recent memory, HANDOFF.md
    ├── scripts/
    │   ├── lessons.sh          # weekly: session memory → LESSONS.md, via headless claude
    │   └── install-cron.sh     # schedules lessons.sh in your crontab
    ├── agents/
    │   └── reviewer.md         # reviews the diff and re-checks plan criteria
    └── skills/
        ├── plan/SKILL.md       # /plan writes PLAN.md with verifiable acceptance criteria
        └── handoff/SKILL.md    # /handoff writes HANDOFF.md for the next session
```

## Install

```bash
./install.sh ~/code/my-project          # skips files that already exist
./install.sh ~/code/my-project --force  # overwrites them
```

Requires `jq` (without it, the hooks skip their checks rather than block everything).
The installer also adds `.claude/memory/` to the project's `.gitignore`.

Run `./tests/run.sh` after changing any hook.

## How the pieces fit

- **Session start**: `session-start.sh` prints the branch, uncommitted changes, `LESSONS.md`, the current plan's criteria, the last 3 session memories and any `HANDOFF.md`.
- **Every Bash call**: `guard-bash.sh` checks the command against a denylist (`rm -rf /`, force push, `reset --hard`, `curl | sh`…) and blocks it with exit code 2.
- **After every turn**: `memory-log.sh` rewrites this session's entry in `.claude/memory/sessions/`: branch, last commit, uncommitted files, plan progress, your last 5 messages and Claude's last reply. It keeps the 20 newest.
- **End of session**: `/handoff` is still there for when you want a deliberate, written summary on top of the automatic log.
- **Before committing**: ask Claude to use the `reviewer` subagent.

### The lessons loop

Once a week, `lessons.sh` sends the week's session memory, recent commits and the current
`.claude/LESSONS.md` to `claude -p`, and gets back a rewritten lessons file: at most 25 rules like
`- Use pnpm, not npm (evidence: user corrected npm usage; seen 2x, last 2026-09-23)`.
It only keeps rules backed by a correction, a repeated instruction or a decision. One-off tasks are dropped.

```bash
.claude/scripts/lessons.sh --dry-run          # see what it would write
.claude/scripts/install-cron.sh               # schedule it: Fridays 17:50
.claude/scripts/install-cron.sh --schedule "0 21 * * 0"
.claude/scripts/install-cron.sh --remove
```

- Claude runs from a temp directory with `--tools ""` and user settings only, so it can only return text and the project's hooks don't log the run as a session.
- Output that doesn't start with `# Lessons` (or is over 80 lines) is rejected, and the old file stays.
- The previous version is saved to `.claude/memory/LESSONS.prev.md`. `LESSONS.md` itself isn't gitignored, so you can commit it and share it.
- Runs log to `.claude/memory/lessons.log`. Each run is one headless Claude call, billed like any other.
- Cron needs your machine awake and `claude` logged in. On macOS, cron may need Full Disk Access to reach the project. If you already schedule jobs through Clawdbot, point it at `lessons.sh` instead.

### The plan gate

1. `/plan` has Claude investigate, then write `PLAN.md` with `Status: draft` and acceptance criteria that each name a verify step.
2. While it's a draft, `plan-gate.sh` blocks Edit/Write on every file except `PLAN.md` and `HANDOFF.md`, and blocks Claude from changing the status itself.
3. You reply `approve` (or `approved`, `approve plan`, `lgtm`). `plan-approve.sh` flips the status before Claude sees your message. Anything else, such as "I don't approve", leaves it a draft.
4. Claude ticks a criterion only after its verify step passes, and sets `Status: done` at the end.

No `PLAN.md` means no gate, so small fixes aren't slowed down.

**Limits:** the gate covers Claude's edit tools, not shell commands. A `sed -i` or `echo >` through Bash can still write files or flip the status. It catches an agent that rushes ahead, not one that's trying to get around it.

## Extending

| Want to add… | Put it in |
|---|---|
| A new workflow / slash command | `.claude/skills/<name>/SKILL.md` |
| A specialist subagent | `.claude/agents/<name>.md` |
| An automatic behaviour | a script in `.claude/hooks/` + an entry in `settings.json` |
| Auto-approved or blocked tools | `permissions` in `settings.json` |
