# claude-harness

A portable `.claude/` kit that gives any project the same Claude Code guardrails, context and workflows.

## What's inside

```
claude-harness/
├── install.sh                  # copy the harness into a project
├── CLAUDE.md                   # template project instructions
└── .claude/
    ├── settings.json           # permissions + hook wiring
    ├── hooks/
    │   ├── guard-bash.sh       # PreToolUse: blocks destructive shell commands
    │   └── session-start.sh    # SessionStart: injects git state + HANDOFF.md
    ├── agents/
    │   └── reviewer.md         # subagent that reviews the diff before commit
    └── skills/
        └── handoff/SKILL.md    # /handoff writes HANDOFF.md for the next session
```

## Install

```bash
./install.sh ~/code/my-project          # skips files that already exist
./install.sh ~/code/my-project --force  # overwrites them
```

Requires `jq` for the Bash guard (without it, the guard warns and lets commands through).

## How the pieces fit

- **Session start**: `session-start.sh` prints the branch, the count of uncommitted changes and any `HANDOFF.md`, so Claude starts each session with that context.
- **Every Bash call**: `guard-bash.sh` checks the command against a denylist (`rm -rf /`, force push, `reset --hard`, `curl | sh`…) and blocks it with exit code 2.
- **End of session**: run `/handoff`, and the next session picks up the notes automatically.
- **Before committing**: ask Claude to use the `reviewer` subagent.

## Extending

| Want to add… | Put it in |
|---|---|
| A new workflow / slash command | `.claude/skills/<name>/SKILL.md` |
| A specialist subagent | `.claude/agents/<name>.md` |
| An automatic behaviour | a script in `.claude/hooks/` + an entry in `settings.json` |
| Auto-approved or blocked tools | `permissions` in `settings.json` |
