#!/usr/bin/env bash
set -euo pipefail

readonly REPOSITORY="feiyuu-chen/2025-blog-public"
readonly APP_ROOT="/opt/2025-blog-public"
readonly RELEASES_DIR="$APP_ROOT/releases"
readonly CURRENT_LINK="$APP_ROOT/current"
readonly STATE_FILE="$APP_ROOT/.deployed-release-id"
readonly ASSET_NAME="blog-2025.tar.gz"

exec 9>"/run/lock/blog-2025-deploy.lock"
flock -n 9 || exit 0

release_json="$(curl -fsSL --retry 3 \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$REPOSITORY/releases/latest")"

release_id="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' <<<"$release_json")"
release_tag="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])' <<<"$release_json")"
asset_url="$(python3 -c '
import json, sys
data = json.load(sys.stdin)
name = sys.argv[1]
print(next((asset["browser_download_url"] for asset in data["assets"] if asset["name"] == name), ""))
' "$ASSET_NAME" <<<"$release_json")"

if [[ -f "$STATE_FILE" ]] && [[ "$(<"$STATE_FILE")" == "$release_id" ]]; then
  exit 0
fi

if [[ "$release_tag" != deploy-* ]] || [[ -z "$asset_url" ]]; then
  echo "Latest GitHub release is not a valid deployment release." >&2
  exit 1
fi

mkdir -p "$RELEASES_DIR"
work_dir="$(mktemp -d "$APP_ROOT/.deploy.XXXXXX")"
trap 'rm -rf -- "$work_dir"' EXIT

curl -fL --retry 3 "$asset_url" -o "$work_dir/$ASSET_NAME"
mkdir "$work_dir/app"
tar -xzf "$work_dir/$ASSET_NAME" -C "$work_dir/app"
test -f "$work_dir/app/server.js"

release_dir="$RELEASES_DIR/$release_tag"
if [[ ! -d "$release_dir" ]]; then
  mv "$work_dir/app" "$release_dir"
fi

ln -sfn "$release_dir" "$APP_ROOT/current.next"
mv -Tf "$APP_ROOT/current.next" "$CURRENT_LINK"

systemctl restart blog-2025.service
printf '%s\n' "$release_id" >"$STATE_FILE"
echo "Deployed $release_tag"
