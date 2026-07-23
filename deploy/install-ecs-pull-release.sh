#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this installer as root." >&2
  exit 1
fi

readonly SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

for command in flock git node; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command is missing: $command" >&2
    exit 1
  fi
done

install -m 0755 "$SOURCE_DIR/ecs-pull-release.sh" /usr/local/sbin/deploy-blog-2025
install -m 0644 "$SOURCE_DIR/blog-2025.service" /etc/systemd/system/blog-2025.service
install -m 0644 "$SOURCE_DIR/blog-2025-deploy.service" /etc/systemd/system/blog-2025-deploy.service
install -m 0644 "$SOURCE_DIR/blog-2025-deploy.timer" /etc/systemd/system/blog-2025-deploy.timer

systemctl daemon-reload
systemctl enable blog-2025.service
systemctl enable --now blog-2025-deploy.timer

echo "ECS deployment polling is installed."
echo "Run /usr/local/sbin/deploy-blog-2025 after the first cloud build succeeds."
