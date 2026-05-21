# Setup

After creating a repo from this template, run one command:

```bash
GH_TOKEN=<your-pat> bash setup.sh
```

It will prompt for your GitHub username, repo name, and project title, then:

- Create `dev` and `stg` branches
- Create the GitHub Project board with all fields and Status columns
- Write `.github/project-config.json`
- Set `PROJECT_NUMBER` as a GitHub Actions repo variable
- Apply branch protection to `main`, `stg`, and `dev`

**One manual step** — add the PAT as a secret after the script finishes:

> GitHub → Settings → Secrets → Actions → New secret
> Name: `GH_PAT`
> Scopes needed: `repo`, `project`

---

That's it. See `docs/git-strategy.md` for the full branching and workflow conventions.
