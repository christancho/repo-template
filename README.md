# repo-template

A personal project template that comes pre-wired with:

- A **three-branch pipeline**: `main` (production) → `stg` (staging) → `dev` (integration)
- **GitHub Actions** that automatically move issues across the project board as code progresses
- A **GitHub Project board** with Status, Priority, Size, Estimate, and Technical analysis fields
- **Branch protection** so nobody (including you) can accidentally push directly to `main`, `stg`, or `dev`
- A **setup script** that configures everything in one shot

---

## What you'll need before starting

1. **GitHub CLI (`gh`)** installed on your machine.
   Check with: `gh --version`
   Install from: https://cli.github.com

2. **A Personal Access Token (PAT)** from GitHub with two scopes: `repo` and `project`.

   How to create one:
   - Go to https://github.com/settings/tokens
   - Click **Generate new token (classic)**
   - Give it a name like `automation`
   - Check `repo` (full repo access) and `project` (project board access)
   - Click **Generate token** and copy it — you won't see it again

3. **`jq`** installed (a command-line JSON tool).
   Check with: `jq --version`
   Install with: `brew install jq`

---

## Creating a new project from this template

### Step 1 — Create the repo

Run this command, replacing `your-username` and `new-project-name` with your values:

```bash
gh repo create your-username/new-project-name \
  --template christancho/repo-template \
  --private \
  --clone
```

- `--template christancho/repo-template` copies all files from this template into your new repo
- `--private` makes the repo private (remove this flag if you want it public)
- `--clone` automatically downloads the repo to your computer after creating it

### Step 2 — Enter the new repo folder

```bash
cd new-project-name
```

### Step 3 — Run the setup script

```bash
GH_TOKEN=<your-pat> bash setup.sh
```

Replace `<your-pat>` with the token you created earlier. For example:

```bash
GH_TOKEN=ghp_abc123xyz bash setup.sh
```

The script will ask you three questions:

- **GitHub username or org** — your GitHub username, e.g. `christancho`
- **Repo name** — the name you just created, e.g. `new-project-name` (it tries to detect this automatically)
- **Project board title** — what to call the board, e.g. `My App` (defaults to the repo name)

Then it will automatically:

1. Create the `dev` and `stg` branches and push them to GitHub
2. Create the GitHub Project board with all columns and fields
3. Write `.github/project-config.json` (stores the board's internal IDs — don't edit this manually)
4. Set `PROJECT_NUMBER` as a GitHub Actions variable so the automation workflows know which board to use
5. Apply branch protection rules to `main`, `stg`, and `dev`

### Step 4 — Add the PAT as a secret (one manual step)

The GitHub Actions workflows need your PAT to move issues and create PRs. You need to add it as a repository secret:

1. Go to your new repo on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `GH_PAT`
5. Value: paste your PAT
6. Click **Add secret**

That's it — your repo is fully set up.

---

## How it works day to day

### Branches

There are three permanent branches:

| Branch | Purpose |
|---|---|
| `main` | Production — what's live |
| `stg` | Staging — tested, waiting to go live |
| `dev` | Integration — where finished features land |

You never commit directly to any of these. All work happens on feature branches.

### Starting work on an issue

1. Create a GitHub issue for the work you're about to do
2. Note the issue number (e.g. `#42`)
3. Create a branch named after it:

```bash
git checkout dev
git pull
git checkout -b feature/42-short-description
```

For example:
```bash
git checkout -b feature/42-add-login-page
```

As soon as you push this branch, GitHub Actions automatically moves issue #42 to **In Progress** on the board.

### When you're done with the work

Push your branch and open a pull request targeting `dev`:

```bash
git push -u origin feature/42-add-login-page
gh pr create --base dev --title "feat: add login page" --body "Closes #42"
```

The `Closes #42` in the PR body is important — it's what tells GitHub Actions which issue to move. When you open the PR, issue #42 moves to **In Review**. When the PR is merged, it moves to **Done**.

### Deploying to staging

After merging a PR to `dev`, GitHub Actions automatically creates a `dev → stg` PR for you. When you merge that PR, all **Done** issues move to **In Staging**.

### Deploying to production

After merging to `stg`, GitHub Actions automatically creates a `stg → main` PR. When you merge that, all **In Staging** issues move to **Released**.

---

## Project board columns

| Column | When an issue moves here |
|---|---|
| Backlog | Issue created |
| Ready | Planned and ready to work on |
| In Progress | Feature branch `feature/123-*` pushed |
| In Review | PR opened targeting `dev` |
| Done | PR merged to `dev` |
| In Staging | `dev → stg` PR opened |
| Released | PR merged to `main` |

---

## Files in this template

```
setup.sh                          — Run once after creating the repo
README.md                         — This file
docs/git-strategy.md              — Full reference for the branching strategy
.github/
  project-config.json             — Board IDs written by setup.sh (don't edit)
  scripts/
    create-project.sh             — Creates the GitHub Project board
    move-issue.sh                 — Moves a single issue to a given status
  workflows/
    branch-to-in-progress.yml     — Triggers when feature/* branch is pushed
    pr-to-in-review.yml           — Triggers when PR is opened → dev
    dev-merged.yml                — Triggers when PR is merged → dev
    stg-pr-opened.yml             — Triggers when PR is opened → stg
    stg-merged.yml                — Triggers when PR is merged → stg
    main-merged.yml               — Triggers when PR is merged → main
```
