# CLAUDE.md — Project Instructions

## Starting a session

Read `docs/tasks.md`, `docs/architecture.md`, and `docs/plan.md`. Find the next uncomplete
task in the current phase and confirm it with the user before starting.

---

## Development workflow

This is a learning project. Follow this process for every non-trivial implementation task:

1. **User writes a specification** — what the component does, what it needs
2. **Claude corrects the spec** — flag gaps, wrong assumptions, missing cases
3. **User writes implementation details** — fields, types, rough structure
4. **Claude corrects the implementation details**
5. **User writes pseudocode**
6. **Claude corrects the pseudocode** — discuss logic and design issues together
7. **Claude implements** — only after pseudocode is agreed
8. **Design decisions are written up in `docs/architecture.md`** before or during implementation

Do not skip ahead to implementation. Do not write code the user has not yet had a chance to
specify. If the user says "just implement it", that is an explicit override of this workflow.

---

## Output style

- Be concise — lists over sentences where possible
- No filler or preamble
- Don't summarise what you just did
- Keep questions short and direct — e.g. "Do you want to write a spec or should I take over?"
