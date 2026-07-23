#!/usr/bin/env bash
set -euo pipefail

readonly REPOSITORY="feiyuu-chen/2025-blog-public"
readonly BUILD_BRANCH="alibaba-build"
readonly REMOTE_URL="https://github.com/$REPOSITORY.git"
readonly APP_ROOT="/opt/2025-blog-public"
readonly RELEASES_DIR="$APP_ROOT/releases"
readonly CURRENT_LINK="$APP_ROOT/current"
readonly STATE_FILE="$APP_ROOT/.deployed-build-sha"

exec 9>"/run/lock/blog-2025-deploy.lock"
flock -n 9 || exit 0

build_sha="$(git ls-remote --heads "$REMOTE_URL" "refs/heads/$BUILD_BRANCH" | awk '{print $1}')"

if [[ -z "$build_sha" ]]; then
  echo "Deployment branch $BUILD_BRANCH does not exist." >&2
  exit 1
fi

if [[ -f "$STATE_FILE" ]] && [[ "$(<"$STATE_FILE")" == "$build_sha" ]]; then
  exit 0
fi

mkdir -p "$RELEASES_DIR"
work_dir="$(mktemp -d "$APP_ROOT/.deploy.XXXXXX")"
trap 'rm -rf -- "$work_dir"' EXIT

git clone --depth 1 --single-branch --branch "$BUILD_BRANCH" "$REMOTE_URL" "$work_dir/app"
test -f "$work_dir/app/.next/BUILD_ID"
test -f "$work_dir/app/package.json"
test -d "$work_dir/app/public"

release_dir="$RELEASES_DIR/$build_sha"
if [[ ! -d "$release_dir" ]]; then
  rm -rf -- "$work_dir/app/.git"
  mv "$work_dir/app" "$release_dir"
fi
ln -sfn "$APP_ROOT/repo/node_modules" "$release_dir/node_modules"

ln -sfn "$release_dir" "$APP_ROOT/current.next"
mv -Tf "$APP_ROOT/current.next" "$CURRENT_LINK"

systemctl restart blog-2025.service
printf '%s\n' "$build_sha" >"$STATE_FILE"
echo "Deployed build $build_sha"
