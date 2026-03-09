#!/usr/bin/env bash

set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) is not installed."
  exit 1
fi

if [[ -z "${GH_TOKEN:-}" ]] && ! gh auth status >/dev/null 2>&1; then
  echo "Error: You are not authenticated in GitHub CLI. Run: gh auth login"
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <repo-name> [owner] [private|public]"
  echo "Example: $0 Learn-Github-script nagmanijobs public"
  exit 1
fi

REPO_NAME="$1"
OWNER="${2:-$(gh api user --jq .login)}"
VISIBILITY="${3:-public}"

if [[ "$VISIBILITY" != "public" && "$VISIBILITY" != "private" ]]; then
  echo "Error: visibility must be 'public' or 'private'"
  exit 1
fi

MAIN_BRANCH="main"
DEVELOPMENT_BRANCH="developement"
RELEASE_BRANCH="release"

# Configure git credentials if GH_TOKEN is available (for GitHub Actions)
if [[ -n "${GH_TOKEN:-}" ]]; then
  git config --global credential.helper store
  echo "https://oauth2:${GH_TOKEN}@github.com" > ~/.git-credentials
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR" ~/.git-credentials 2>/dev/null || true' EXIT

pushd "$WORK_DIR" >/dev/null

PRIVATE_FLAG="false"
if [[ "$VISIBILITY" == "private" ]]; then
  PRIVATE_FLAG="true"
fi

OWNER_TYPE="$(gh api "users/$OWNER" --jq .type 2>/dev/null || true)"

if [[ "$OWNER_TYPE" == "Organization" ]]; then
  if ! CREATE_OUTPUT=$(gh api --method POST "orgs/$OWNER/repos" -f name="$REPO_NAME" -F private="$PRIVATE_FLAG" 2>&1); then
    echo "$CREATE_OUTPUT"
    echo "Repository creation failed for organization '$OWNER'. Ensure the GitHub App has Administration (Read/Write) and Contents (Read/Write) permissions and is installed for this org."
    exit 1
  fi
elif [[ "$OWNER_TYPE" == "User" ]]; then
  if ! CREATE_OUTPUT=$(gh api --method POST "user/repos" -f name="$REPO_NAME" -F private="$PRIVATE_FLAG" 2>&1); then
    echo "$CREATE_OUTPUT"
    echo "Repository creation failed for personal account '$OWNER'. GitHub App installation tokens may not be allowed to create user repositories; use an org owner or a PAT/user token for user-owned repo creation."
    exit 1
  fi
else
  echo "Error: Could not determine whether owner '$OWNER' is a User or Organization."
  exit 1
fi

git init
echo "# $REPO_NAME" > README.md
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add README.md
git commit -m "chore: initial commit"
git branch -M "$MAIN_BRANCH"
git remote add origin "https://github.com/$OWNER/$REPO_NAME.git"
git push -u origin "$MAIN_BRANCH"

git checkout -b "$DEVELOPMENT_BRANCH"
git push -u origin "$DEVELOPMENT_BRANCH"

git checkout "$MAIN_BRANCH"
git checkout -b "$RELEASE_BRANCH"
git push -u origin "$RELEASE_BRANCH"

echo "Repository created: https://github.com/$OWNER/$REPO_NAME"
echo "Branches created: $MAIN_BRANCH, $DEVELOPMENT_BRANCH, $RELEASE_BRANCH"

popd >/dev/null
