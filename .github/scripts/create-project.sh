#!/usr/bin/env bash
# Creates a GitHub Project v2 with the standard field configuration and
# writes .github/project-config.json for use by the automation workflows.
#
# Note: this script is called by setup.sh. Run setup.sh for full project setup.
#
# Usage:
#   GH_TOKEN=<pat> bash .github/scripts/create-project.sh <github-username> [project-title]
#
# Requirements: gh CLI, jq

set -euo pipefail

OWNER=${1:?"Usage: create-project.sh <github-username> [project-title]"}
TITLE=${2:-"Project"}

# ── 1. Owner node ID ─────────────────────────────────────────────────────────
OWNER_ID=$(gh api graphql -f query="{user(login:\"$OWNER\"){id}}" --jq '.data.user.id')
echo "Owner: $OWNER ($OWNER_ID)"

# ── 2. Create the project ─────────────────────────────────────────────────────
RESULT=$(gh api graphql -f query="
mutation {
  createProjectV2(input: { ownerId: \"$OWNER_ID\", title: \"$TITLE\" }) {
    projectV2 { id number }
  }
}")
PROJECT_ID=$(echo "$RESULT" | jq -r '.data.createProjectV2.projectV2.id')
PROJECT_NUMBER=$(echo "$RESULT" | jq -r '.data.createProjectV2.projectV2.number')
echo "Created project #$PROJECT_NUMBER (id: $PROJECT_ID)"

# ── 3. Get Status field ID ────────────────────────────────────────────────────
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

# ── 4. Set Status options ─────────────────────────────────────────────────────
# Note: projectId is NOT part of UpdateProjectV2FieldInput; fieldId alone identifies the field.
gh api graphql -f query="
mutation {
  updateProjectV2Field(input: {
    fieldId: \"$STATUS_FIELD_ID\"
    singleSelectOptions: [
      { name: \"Backlog\",     color: GRAY,   description: \"\" }
      { name: \"Ready\",       color: BLUE,   description: \"\" }
      { name: \"In Progress\", color: YELLOW, description: \"\" }
      { name: \"In Review\",   color: ORANGE, description: \"\" }
      { name: \"Done\",        color: GREEN,  description: \"\" }
    ]
  }) { projectV2Field { ... on ProjectV2SingleSelectField { id } } }
}" > /dev/null
echo "Status options set"

# ── 5. Priority field ─────────────────────────────────────────────────────────
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
  }) { projectV2Field { __typename } }
}" > /dev/null
echo "Priority field created"

# ── 6. Size field ─────────────────────────────────────────────────────────────
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
  }) { projectV2Field { __typename } }
}" > /dev/null
echo "Size field created"

# ── 7. Estimate field (number) ────────────────────────────────────────────────
gh api graphql -f query="
mutation {
  createProjectV2Field(input: {
    projectId: \"$PROJECT_ID\"
    dataType: NUMBER
    name: \"Estimate\"
  }) { projectV2Field { __typename } }
}" > /dev/null
echo "Estimate field created"

# ── 8. Technical analysis field ───────────────────────────────────────────────
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
  }) { projectV2Field { __typename } }
}" > /dev/null
echo "Technical analysis field created"

# ── 9. Write project-config.json ─────────────────────────────────────────────
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
