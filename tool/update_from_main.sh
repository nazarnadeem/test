#!/usr/bin/env bash
# Pull bug fixes and features from the main GCRM repo into this white-label repo.
# Gym ids, app name, Firebase app ids, logo, and launcher icons stay as they are.
#
# One-time setup, from the white-label repo:
#   git remote rename origin upstream
#   git remote add origin <this-white-label-repo-url>
#
# Later, whenever the main app changes:
#   bash tool/update_from_main.sh
#   git push origin HEAD

set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

remote="${1:-upstream}"
branch="${2:-main}"

if ! git remote get-url "$remote" >/dev/null 2>&1; then
  cat <<EOF
This repo does not have a remote named '$remote'.

From the white-label repo, point it at the main GCRM repo once:

  git remote add upstream <main-repo-url>

If 'origin' is still the main repo, rename it first:

  git remote rename origin upstream
  git remote add origin <this-white-label-repo-url>

Then run: bash tool/update_from_main.sh
EOF
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Commit or stash your changes before pulling the main app."
  exit 1
fi

if ! grep -Eq '"WL_MODE"[[:space:]]*:[[:space:]]*"white_label"' white_label/active.json; then
  echo "WL_MODE in white_label/active.json must be white_label. Run this only in a customer repo."
  exit 1
fi

is_main_url() {
  local url="${1%.git}"
  url="$(printf '%s' "$url" | tr '[:upper:]' '[:lower:]')"
  [[ "$url" == *nazarnadeem/gcrmone ]]
}

origin_url="$(git remote get-url origin 2>/dev/null || true)"
upstream_url="$(git remote get-url "$remote" 2>/dev/null || true)"
if [[ -z "$origin_url" ]] || is_main_url "$origin_url"; then
  echo "origin must be the customer repo, not the main GCRM repo. This update was not applied."
  exit 1
fi
if ! is_main_url "$upstream_url"; then
  echo "The '$remote' remote must be the main GCRM repo. This update was not applied."
  exit 1
fi

tracking="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [[ -n "$tracking" ]]; then
  track_remote="${tracking%%/*}"
  track_url="$(git remote get-url "$track_remote" 2>/dev/null || true)"
  if is_main_url "$track_url"; then
    git branch --unset-upstream
    echo "This branch was tracking the main GCRM repo. A plain git push would update the parent app, so that link is removed."
    echo "Push only with: git push origin HEAD"
  fi
fi

backup="$(mktemp -d)"
cleanup() { rm -rf "$backup"; }
trap cleanup EXIT

cp white_label/active.json "$backup/active.json"

save_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    mkdir -p "$backup/tree/$(dirname "$file")"
    cp "$file" "$backup/tree/$file"
  fi
}

save_dir() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    mkdir -p "$backup/tree/$dir"
    cp -R "$dir/." "$backup/tree/$dir/"
  fi
}

save_file assets/images/logo.png
save_file web/favicon.png
save_dir web/icons
save_dir ios/Runner/Assets.xcassets/AppIcon.appiconset
if [[ -d android/app/src/main/res ]]; then
  while IFS= read -r dir; do
    save_dir "$dir"
  done < <(find android/app/src/main/res -type d -name 'mipmap-*')
fi

echo "Fetching $remote/$branch"
git fetch "$remote"

set +e
git merge --no-edit "$remote/$branch"
merge_status=$?
set -e

if git cat-file -e "$remote/$branch:white_label/active.json" 2>/dev/null; then
  git show "$remote/$branch:white_label/active.json" > "$backup/incoming.json"
  dart run tool/merge_white_label_json.dart \
    "$backup/active.json" \
    "$backup/incoming.json" \
    white_label/active.json
else
  cp "$backup/active.json" white_label/active.json
fi

if [[ -d "$backup/tree" ]]; then
  cp -R "$backup/tree/." "$root/"
fi

add_kept() {
  if [[ -e "$1" ]]; then
    git add -- "$1"
  fi
}

if [[ "$merge_status" -ne 0 ]]; then
  add_kept white_label/active.json
  add_kept assets/images/logo.png
  add_kept web/favicon.png
  add_kept web/icons
  add_kept ios/Runner/Assets.xcassets/AppIcon.appiconset
  if [[ -d android/app/src/main/res ]]; then
    while IFS= read -r dir; do
      add_kept "$dir"
    done < <(find android/app/src/main/res -type d -name 'mipmap-*')
  fi

  conflicts="$(git diff --name-only --diff-filter=U || true)"
  if [[ -n "$conflicts" ]]; then
    cat <<EOF

The main app merged, and your gym ids, name, logo, and icons were kept.
These files still conflict and need a decision:

$conflicts

Fix them, then run:

  git add <fixed-files>
  git merge --continue
  dart run tool/apply_white_label.dart

EOF
    exit 1
  fi

  git commit --no-edit
fi

dart run tool/apply_white_label.dart

if [[ -n "$(git status --porcelain)" ]]; then
  cat <<EOF

Main app code is updated. Your gym ids and branding are restored.
Commit the files listed by git status, then push:

  git add -A
  git commit -m "Apply white-label identity on top of the main app update"
  git push origin HEAD

EOF
else
  echo "Main app code is updated. Nothing else to commit."
fi
