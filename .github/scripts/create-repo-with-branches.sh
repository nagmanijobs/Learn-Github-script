#!/usr/bin/env bash

set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) is not installed."
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
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

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

pushd "$WORK_DIR" >/dev/null

if [[ "$VISIBILITY" == "private" ]]; then
  gh repo create "$OWNER/$REPO_NAME" --private --confirm
else
  gh repo create "$OWNER/$REPO_NAME" --public --confirm
fi

git init
echo "# $REPO_NAME" > README.md
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
