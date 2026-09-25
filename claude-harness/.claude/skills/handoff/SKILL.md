---
name: handoff
description: Write HANDOFF.md summarising the current session so the next session can pick up where this one left off. Use when the user says "handoff", "wrap up", or is ending a session mid-task.
---

Write (or overwrite) `HANDOFF.md` in the project root with these sections:

## Goal
One or two sentences on what we're trying to achieve.

## Done
Bullet list of what was completed this session, with file paths.

## Next
The very next concrete step, then any others in order.

## Open questions / gotchas
Anything the next session must know: decisions made, dead ends, things that looked
right but weren't.

Keep it under 40 lines. The SessionStart hook loads this file into context automatically.
