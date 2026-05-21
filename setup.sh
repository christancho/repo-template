#!/usr/bin/env bash
# One-shot setup after: gh repo create --template <owner>/repo-template
#
# What it does:
#   1. Creates dev and stg branches
#   2. Creates the GitHub Project board with all fields and Status options
#   3. Writes .github/project-config.json
#   4. Sets PROJECT_NUMBER as a GitHub Actions repo variable
#   5. Applies branch protection to main, stg, dev
#
# Usage:
#   GH_TOKEN=<pat> bash setup.sh
#
# Requirements: gh CLI, jq

set -euo pipefail

# ── Detect owner/repo from git remote ────────────────────────────────────────
REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$REMOTE" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
  DEFAULT_OWNER="${BASH_REMATCH[1]}"
  DEFAULT_REPO="${BASH_REMATCH[2]}"
else
  DEFAULT_OWNER=""
  DEFAULT_REPO=""
fi

echo "=== Repo setup ==="
read -rp "GitHub username or org [$DEFAULT_OWNER]: " OWNER
OWNER="${OWNER:-$DEFAULT_OWNER}"
[ -z "$OWNER" ] && { echo "Owner required"; exit 1; }

read -rp "Repo name [$DEFAULT_REPO]: " REPO
REPO="${REPO:-$DEFAULT_REPO}"
[ -z "$REPO" ] && { echo "Repo name required"; exit 1; }

read -rp "Project board title [$REPO]: " PROJECT_TITLE
PROJECT_TITLE="${PROJECT_TITLE:-$REPO}"

echo ""

# ── 1. Create dev and stg branches ───────────────────────────────────────────
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

for BRANCH in dev stg; do
  if git ls-remote --exit-code --heads origin "$BRANCH" > /dev/null 2>&1; then
    echo "Branch already exists: $BRANCH"
  else
    git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"
    git push -u origin "$BRANCH"
    echo "Created branch: $BRANCH"
  fi
done

git checkout "$CURRENT_BRANCH"

# ── 2. Create GitHub Project ──────────────────────────────────────────────────
echo ""
echo "Creating GitHub Project..."
bash .github/scripts/create-project.sh "$OWNER" "$PROJECT_TITLE"

# ── 3. Read project number and set as repo variable ──────────────────────────
PROJECT_NODE_ID=$(jq -r '.project_node_id' .github/project-config.json)

PROJECT_NUMBER=$(gh api graphql -f query="
{
  node(id: \"$PROJECT_NODE_ID\") {
    ... on ProjectV2 { number }
  }
}" --jq '.data.node.number')

gh variable set PROJECT_NUMBER --repo "$OWNER/$REPO" --body "$PROJECT_NUMBER"
echo "Set Actions variable: PROJECT_NUMBER=$PROJECT_NUMBER"

# ── 4. Apply branch protection ────────────────────────────────────────────────
echo ""
echo "Applying branch protection..."
for BRANCH in main stg dev; do
  gh api "repos/$OWNER/$REPO/branches/$BRANCH/protection" \
    --method PUT \
    --input - <<EOF 2>/dev/null && echo "Protected: $BRANCH" || echo "Skipped $BRANCH (branch may not exist yet)"
{
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "required_status_checks": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
done

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo "=== Setup complete ==="
echo ""
echo "One manual step remaining:"
echo "  Add GH_PAT secret with scopes: repo, project"
echo "  https://github.com/$OWNER/$REPO/settings/secrets/actions"
echo ""
echo "Project board:"
echo "  https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
