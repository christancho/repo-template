#!/usr/bin/env bash
# Creates a GitHub Project v2 with the standard field configuration and
# writes .github/project-config.json for use by the automation workflows.
#
# Usage:
#   GH_TOKEN=<pat> bash .github/scripts/create-project.sh <github-username> [project-title]
#
# Requirements:
#   - gh CLI installed and authenticated
#   - GH_TOKEN with scopes: repo, project
#   - jq installed

set -euo pipefail

OWNER=${1:?"Usage: create-project.sh <github-username> [project-title]"}
TITLE=${2:-"Project"}

# ── 1. Owner node ID ────────────────────────────────────────────────────────
OWNER_ID=$(gh api graphql -f query="{user(login:\"$OWNER\"){id}}" --jq '.data.user.id')
echo "Owner: $OWNER ($OWNER_ID)"

# ── 2. Create the project ────────────────────────────────────────────────────
RESULT=$(gh api graphql -f query="
mutation {
  createProjectV2(input: { ownerId: \"$OWNER_ID\", title: \"$TITLE\" }) {
    projectV2 { id number }
  }
}")
PROJECT_ID=$(echo "$RESULT" | jq -r '.data.createProjectV2.projectV2.id')
PROJECT_NUMBER=$(echo "$RESULT" | jq -r '.data.createProjectV2.projectV2.number')
echo "Created project #$PROJECT_NUMBER (id: $PROJECT_ID)"

# ── 3. Update Status field options ───────────────────────────────────────────
STATUS_FIELD_ID=$(gh api graphql -f query="
{
  node(id: \"$PROJECT_ID\") {
    ... on ProjectV2 {
      fields(first: 20) {
        nodes {
          ... on ProjectV2SingleSelectField { id name }
        }
      }
    }
  }
}" --jq '.data.node.fields.nodes[] | select(.name == "Status") | .id')

gh api graphql -f query="
mutation {
  updateProjectV2Field(input: {
    projectId: \"$PROJECT_ID\"
    fieldId:   \"$STATUS_FIELD_ID\"
    singleSelectOptions: [
      { name: \"Backlog\",     color: GRAY,   description: \"\" }
      { name: \"Ready\",       color: BLUE,   description: \"\" }
      { name: \"In Progress\", color: YELLOW, description: \"\" }
      { name: \"In Review\",   color: ORANGE, description: \"\" }
      { name: \"Done\",        color: GREEN,  description: \"\" }
    ]
  }) { projectV2Field { id } }
}" > /dev/null
echo "Status options set"

# ── 4. Priority field ────────────────────────────────────────────────────────
gh api graphql -f query="
mutation {
  createProjectV2Field(input: {
    projectId: \"$PROJECT_ID\"
    dataType: SINGLE_SELECT
    name: \"Priority\"
    singleSelectOptions: [
      { name: \"P0\", color: RED,    description: \"Critical\" }
      { name: \"P1\", color: ORANGE, description: \"High\" }
      { name: \"P2\", color: YELLOW, description: \"Normal\" }
    ]
  }) { projectV2Field { id } }
}" > /dev/null
echo "Priority field created"

# ── 5. Size field ────────────────────────────────────────────────────────────
gh api graphql -f query="
mutation {
  createProjectV2Field(input: {
    projectId: \"$PROJECT_ID\"
    dataType: SINGLE_SELECT
    name: \"Size\"
    singleSelectOptions: [
      { name: \"XS\", color: GRAY,   description: \"\" }
      { name: \"S\",  color: BLUE,   description: \"\" }
      { name: \"M\",  color: GREEN,  description: \"\" }
      { name: \"L\",  color: YELLOW, description: \"\" }
      { name: \"XL\", color: RED,    description: \"\" }
    ]
  }) { projectV2Field { id } }
}" > /dev/null
echo "Size field created"

# ── 6. Estimate field (number) ───────────────────────────────────────────────
gh api graphql -f query="
mutation {
  createProjectV2Field(input: {
    projectId: \"$PROJECT_ID\"
    dataType: NUMBER
    name: \"Estimate\"
  }) { projectV2Field { id } }
}" > /dev/null
echo "Estimate field created"

# ── 7. Technical analysis field ──────────────────────────────────────────────
gh api graphql -f query="
mutation {
  createProjectV2Field(input: {
    projectId: \"$PROJECT_ID\"
    dataType: SINGLE_SELECT
    name: \"Technical analysis\"
    singleSelectOptions: [
      { name: \"Pending\",     color: GRAY,   description: \"\" }
      { name: \"In progress\", color: YELLOW, description: \"\" }
      { name: \"Complete\",    color: GREEN,  description: \"\" }
    ]
  }) { projectV2Field { id } }
}" > /dev/null
echo "Technical analysis field created"

# ── 8. Write project-config.json ─────────────────────────────────────────────
CONFIG=$(gh api graphql -f query="
{
  node(id: \"$PROJECT_ID\") {
    ... on ProjectV2 {
      fields(first: 5) {
        nodes {
          ... on ProjectV2SingleSelectField { id name options { id name } }
        }
      }
    }
  }
}")

STATUS_OPTIONS=$(echo "$CONFIG" | jq '
  .data.node.fields.nodes[]
  | select(.name == "Status")
  | .options
  | map({(.name): .id})
  | add')

mkdir -p .github
cat > .github/project-config.json << EOF
{
  "project_node_id": "$PROJECT_ID",
  "status_field_id": "$STATUS_FIELD_ID",
  "options": $STATUS_OPTIONS
}
EOF

echo ""
echo "✓ .github/project-config.json written"
echo "✓ Project URL: https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
echo ""
echo "Next: add GH_PAT secret to the repo with scopes: repo, project"
