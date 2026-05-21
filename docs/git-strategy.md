# Git Strategy

Three-environment trunk-based flow with automated GitHub Projects lifecycle. Each unit of work is a phase branch → PR → `dev` → staging → production.

---

## Branch Model

```
main   ← production (protected)
stg    ← staging  (protected)
dev    ← integration (protected)
  └── feature/123-slug  ← all feature work
```

**Rules:**
- All feature work branches from `dev`, targets `dev`
- Never branch from `stg` or `main`
- Never PR directly into `stg` or `main` — promotion is automated
- Never commit directly to `dev`, `stg`, or `main`

---

## Branch Naming

```
feature/{issue-number}-{slug}
```

Examples:
- `feature/42-add-login`
- `feature/103-ndvi-confidence`
- `feature/18-admin-dashboard`

The number is the GitHub issue number for the work being done. The slug is a short description — kebab-case, 2–4 words.

---

## Starting a Phase Branch

```bash
git checkout dev
git pull
git checkout -b feature/123-slug
```

At the start of any resumed work session on an existing branch:

```bash
git merge dev
```

Always merge latest `dev` before doing anything — features merged to `dev` after your branch was cut are otherwise invisible.

---

## Commit Conventions

Conventional commits, no emojis:

```
feat: add NDVI confidence layer
fix: handle null lot polygon in cadastre lookup
chore: upgrade sharp to 0.34
docs: document LiDAR CRS requirement
refactor: extract snapshot compositing into its own module
```

---

## Pull Requests

### Target

Always target `dev`. Never `stg` or `main`.

### Body (required)

Every PR must include:

1. **Summary** — bullet list of what changed
2. **Test plan** — what was verified
3. **Closes lines** — one per requirement issue associated with the phase

```markdown
## Summary
- Added Sentinel-2 NDVI confidence scoring
- Stores confidence band in raw_response.ndvi_analysis

## Test plan
- [x] Verified against 8 Montreal test addresses
- [x] Confirmed null safety when GEE returns no result

Closes #18
Closes #19
```

The `Closes #N` lines drive GitHub Projects automation — do not omit them.

### Title

Short, imperative, under 70 characters:

```
feat: add NDVI confidence layer (phase 3)
```

---

## Promotion Pipeline (Automated)

Once a phase PR merges to `dev`, GitHub Actions handles the rest:

```
phase branch → dev   (manual PR, human review)
dev → stg            (auto-created PR, merge when ready to test)
stg → main           (auto-created PR, merge when ready to release)
```

The `dev→stg` PR is created automatically on every merge to `dev`. The `stg→main` PR is created automatically on every merge to `stg`. Both are titled `promote: {from} -> {to}` with a commit log in the body.

---

## GitHub Projects Status Flow

Issue status tracks the code's progress through the pipeline. Transitions are fully automated via GitHub Actions:

| Status | Trigger |
|---|---|
| **Backlog** | Issue created |
| **Ready** | Phase planned and issues triaged |
| **In Progress** | Phase branch `feature/phase-N-*` created |
| **In Review** | PR opened targeting `dev` |
| **Done** | PR merged to `dev` |
| **In Staging** | `dev→stg` PR opened |
| **Released** | PR merged to `main` |

No manual status changes needed — as long as `Closes #N` is in the PR body, everything moves automatically.

---

## GitHub Actions Workflows

Five workflows wire up the automation. Each reads `.github/project-config.json` for node IDs and uses `GH_PAT` (a personal access token with `project` scope) as `GH_TOKEN`.

| File | Trigger | Action |
|---|---|---|
| `branch-phase-created.yml` | `feature/*` branch push | Issues → In Progress |
| `pr-to-dev-opened.yml` | PR opened → `dev` | Issues → In Review |
| `on-dev-merge.yml` | PR merged → `dev` | Issues → Done + create `dev→stg` PR |
| `on-stg-pr-opened.yml` | PR opened → `stg` | Issues → In Staging |
| `on-stg-merge.yml` | PR merged → `stg` | Create `stg→main` PR |
| `on-main-merge.yml` | PR merged → `main` | All In Staging issues → Released |

The helper script `.github/scripts/move-issue.sh <issue_number> "<Status Name>"` handles the GraphQL mutation. Workflows call it in a loop over extracted issue numbers.

---

## Project Config File

`.github/project-config.json` stores the GitHub Projects node IDs so workflows don't hardcode them. Structure:

```json
{
  "project_node_id": "PVT_...",
  "status_field_id": "PVTSSF_...",
  "options": {
    "Backlog": "...",
    "Ready": "...",
    "In Progress": "...",
    "In Review": "...",
    "Done": "...",
    "In Staging": "...",
    "Released": "..."
  }
}
```

To set this up in a new project: create the GitHub Project with a `Status` single-select field using the same column names, then query the GraphQL API to get the IDs.

---

## Branch Protection Rules

Apply these via **Settings → Branches → Add rule** for each protected branch, or via the `gh` CLI:

```bash
gh api repos/{owner}/{repo}/branches/{branch}/protection \
  --method PUT \
  --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  --field enforce_admins=true \
  --field restrictions=null \
  --field required_status_checks=null
```

### Current rules (all three branches: `main`, `stg`, `dev`)

| Rule | Value | Effect |
|---|---|---|
| `enforce_admins` | `true` | Rules apply to repo admins too — no bypass |
| `allow_force_pushes` | `false` | `git push --force` is rejected |
| `allow_deletions` | `false` | Branch cannot be deleted via push |

### Recommended additions for `main` and `stg`

These are not yet enforced on this repo but should be set on any team project:

| Rule | Recommended value | Why |
|---|---|---|
| `required_pull_request_reviews` | 1 approving review, dismiss stale | Prevents direct pushes |
| `dismiss_stale_reviews` | `true` | New commits invalidate existing approval |
| `required_conversation_resolution` | `true` | All review threads must be resolved before merge |

`dev` can be left without required reviews if you are the sole developer — direct pushes to `dev` are low risk since it is never deployed to production directly.

---

## Required Secrets

| Secret | Scope | Used for |
|---|---|---|
| `GH_PAT` | `repo`, `project` | All GitHub Actions — moves issues, creates PRs |

---

## GitHub Project Fields

The project board uses these fields:

| Field | Type | Options |
|---|---|---|
| **Status** | Single select | Won't do, Backlog, Ready, In Progress, In Review, Done, In Staging, Released |
| **Priority** | Single select | P0 (critical), P1 (high), P2 (normal) |
| **Size** | Single select | XS, S, M, L, XL |
| **Estimate** | Number | Story points or hours |
| **Technical analysis** | Single select | Pending, In progress, Complete |

Plus GitHub's built-in fields: Assignees, Labels, Milestone, Linked pull requests, Reviewers, Parent issue.

---

## Setting Up in a New Project

### 1. Create branches

```bash
git checkout -b dev && git push -u origin dev
git checkout -b stg && git push -u origin stg
# main already exists
```

Apply branch protection rules (see section above) via GitHub Settings → Branches.

### 2. Create the GitHub Project and write project-config.json

```bash
GH_TOKEN=<pat> bash .github/scripts/create-project.sh <github-username> "My Project"
```

This creates the project, sets all fields and Status options, and writes `.github/project-config.json` automatically.

### 3. Copy the automation files

```bash
# From an existing repo using this strategy:
cp .github/workflows/*.yml            /path/to/new-repo/.github/workflows/
cp .github/scripts/move-issue.sh      /path/to/new-repo/.github/scripts/
cp .github/scripts/create-project.sh  /path/to/new-repo/.github/scripts/
```

Then update the three hardcoded values in the copied files:

| Value | Files | Replace with |
|---|---|---|
| `christancho/g3s` (repo slug) | `dev-merged.yml`, `stg-merged.yml`, `branch-to-in-progress.yml`, `move-issue.sh` | `owner/new-repo` |
| `christancho` (owner login) | `main-merged.yml`, `stg-pr-opened.yml` | new owner login |
| `projectV2(number: 1)` and `project.number == 1` | `main-merged.yml`, `stg-pr-opened.yml`, `move-issue.sh` | new project number (printed by `create-project.sh`) |

Quick one-liner to do all three at once (run from the new repo root):

```bash
OWNER=myname REPO=my-repo PROJECT_NUM=2

sed -i '' \
  -e "s|<old-owner>/<old-repo>|$OWNER/$REPO|g" \
  -e "s|\"<old-owner>\"|\"$OWNER\"|g" \
  -e "s|number: <old-project-num>)|number: $PROJECT_NUM)|g" \
  -e "s|number == <old-project-num>|number == $PROJECT_NUM|g" \
  .github/workflows/*.yml .github/scripts/move-issue.sh
```

### 4. Add the secret

In GitHub → Settings → Secrets → Actions, add:

| Secret | Value |
|---|---|
| `GH_PAT` | Personal access token with `repo` + `project` scopes |

### 5. Create milestones and issues

```bash
# Create a milestone per phase
gh milestone create --repo <owner>/<repo> --title "Phase 1 — Auth" --due-date 2026-06-01

# Create requirement issues and assign to milestone
gh issue create --repo <owner>/<repo> --title "REQ-01: User login" --milestone 1

# Add issues to the project board
gh project item-add <project-number> --owner <owner> --url <issue-url>
```
