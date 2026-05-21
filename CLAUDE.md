# Agent Instructions

Read this entire file before starting any task.

---

## What this project does

<!-- Describe your project here. What problem does it solve? What are the main inputs and outputs? -->

---

## Stack

<!-- Fill in your stack after setup -->

| Layer | Tech |
|---|---|
| Frontend | |
| Backend | |
| Database | |
| Deploy | |

---

## Key files

<!-- List the most important files and what they do, so the agent knows where to look -->

---

## Coding preferences

- **No hardcoded numeric values** — only text labels may be hardcoded. All scores, thresholds, and numeric outputs must be computed from real data. If a value can't be computed yet, return `null` rather than a magic number.

---

## Task Management

All tasks and features are tracked in **GitHub Projects**:
- Use `gh issue create` to create new issues
- Use `gh project item-add` to add issues to the board
- Do NOT use TodoWrite, task files, or in-session task lists as a substitute — GitHub Issues is the source of truth
- Group related tasks under a single parent issue with a checklist when possible

---

## Git workflow

- All feature work branches from `dev` using the naming convention `feature/{issue-number}-{short-description}`
- Feature branches always PR into `dev`, never into `stg` or `main`
- Every PR body must include `Closes #N` for each issue the PR resolves — this drives the project board automation
- Before starting work on an existing branch, always run `git merge dev` first to pick up anything merged since the branch was cut

---

## Self-Correcting Rules Engine

This file contains a growing ruleset that improves over time. **At session start, read the entire "Learned Rules" section before doing anything.**

### How it works

1. When the user corrects you or you make a mistake, **immediately append a new rule** to the "Learned Rules" section at the bottom of this file.
2. Rules are numbered sequentially and written as clear, imperative instructions.
3. Format: `N. [CATEGORY] Never/Always do X — because Y.`
4. Categories: `[STYLE]`, `[CODE]`, `[ARCH]`, `[TOOL]`, `[PROCESS]`, `[DATA]`, `[UX]`, `[OTHER]`
5. Before starting any task, scan all rules below for relevant constraints.
6. If two rules conflict, the higher-numbered (newer) rule wins.
7. Never delete rules. If a rule becomes obsolete, append a new rule that supersedes it.

### When to add a rule

- User explicitly corrects your output ("no, do it this way")
- User rejects a file, approach, or pattern
- You hit a bug caused by a wrong assumption about this codebase
- User states a preference ("always use X", "never do Y")

### Rule format example

```
14. [CODE] Always use `bun` instead of `npm` — user preference, bun is installed globally.
15. [STYLE] Never add emojis to commit messages — project convention.
16. [ARCH] API routes live in `src/server/routes/`, not `src/api/` — existing codebase pattern.
```

---

## Learned Rules

<!-- New rules are appended below this line. Do not edit above this section. -->

1. [PROCESS] Never commit and push code that contains non-trivial logic (geometry, math, algorithms) without first running a test or verifying it against real output.
2. [PROCESS] Always use GitHub Issues (gh CLI) for task tracking — never TodoWrite, task files, or in-session task lists. GitHub Issues is the source of truth.
3. [PROCESS] GitHub Issues are the source of truth for requirement tracking. Each requirement maps to one issue. Each milestone maps to a phase of work. When a milestone completes, close its issues with a verification reference.
4. [CODE] Never write empty, silent, or "non-fatal" catch blocks — every catch must either re-throw, push to a failures array with `{ source, message, ts }`, or log with explicit source attribution. `catch {}` and `catch (e) {}` (no body) are forbidden. If an error is genuinely safe to ignore, add a comment explaining why.
5. [PROCESS] Feature branches always PR into `dev`, never into `main` or `stg` — three-environment pipeline: dev → stg → main.
6. [PROCESS] Every PR must include `Closes #N` in the body for each issue it resolves. This is what drives the GitHub Projects board automation.
7. [CODE] Never suppress or ignore deprecation warnings — always fix the root cause. Suppressing with `NODE_OPTIONS=--no-deprecation` or `--no-warnings` is forbidden.
8. [PROCESS] Always create feature branches from the latest `dev`: `git checkout dev && git pull && git checkout -b feature/123-slug`. Never branch from whatever HEAD happens to be — it may be behind dev.
9. [CODE] Never fire-and-forget async operations that can fail — background tasks must persist their result (success or error) somewhere visible. `.catch(err => console.error(...))` alone is forbidden for user-facing operations.
