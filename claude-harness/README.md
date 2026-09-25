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

- **Session start**: `session-start.sh` prints the branch, uncommitted changes, the current plan's criteria, the last 3 session memories and any `HANDOFF.md`.
- **Every Bash call**: `guard-bash.sh` checks the command against a denylist (`rm -rf /`, force push, `reset --hard`, `curl | sh`…) and blocks it with exit code 2.
- **After every turn**: `memory-log.sh` rewrites this session's entry in `.claude/memory/sessions/`: branch, last commit, uncommitted files, plan progress and Claude's last message. It keeps the 20 newest.
- **End of session**: `/handoff` is still there for when you want a deliberate, written summary on top of the automatic log.
- **Before committing**: ask Claude to use the `reviewer` subagent.

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
