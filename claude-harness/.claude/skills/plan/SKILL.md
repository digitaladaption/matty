---
name: plan
description: Write PLAN.md with a goal and verifiable acceptance criteria, then stop for the user's approval before any code changes. Use for any task bigger than a one-file fix, or when the user says "plan", "spec" or "let's think this through first".
---

## 1. Write the plan

Investigate first (read code, run read-only commands), then write `PLAN.md` in the
project root using exactly this shape:

```markdown
# Plan: <short title>
Status: draft

## Goal
<one or two sentences: the outcome, not the implementation>

## Acceptance criteria
- [ ] <observable outcome> (verify: `<command>` or <exact manual check>)
- [ ] ...

## Steps
1. ...

## Unknowns
- <anything you could not confirm; leave it here rather than guessing>

## Out of scope
- ...
```

Rules for criteria:
- Each one describes what's true when done, not a task ("`/health` returns 200", not "add health route").
- Each one names how to verify it. If it can't be verified, move it to Unknowns.
- 3 to 7 criteria. More than that means the task should be split.

## 2. Stop for approval

Summarise the plan in chat in a few lines and tell the user to reply **approve**
(or send changes). Do not edit any other file while `Status: draft`; the plan-gate
hook blocks it, and only the user's "approve" reply flips the status.

## 3. While working (Status: approved)

- Tick a criterion (`- [x]`) only after running its verify step and seeing it pass.
  Append the evidence: `- [x] ... (verified: 12 tests pass)`.
- If you learn something that changes the plan, update PLAN.md and tell the user.
- When a Unknown gets resolved, move the answer into the relevant section.
- When every criterion is ticked, set `Status: done`.
