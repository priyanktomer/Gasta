#!/usr/bin/env bash
#
# Build here, run there (PLAN-5 Phase 11).
#
#   ./deploy.sh ubuntu@<ip>
#
# Ships an ARM64 image and the compose stack to the server and restarts it.
# Nothing about this needs a container registry, which is the point: the first
# deploy should not also be the first time GitHub Actions has ever run.
#
# ⚠️ **The `.env` on the server is never overwritten.** It holds the generated
# passwords; copying the local one over would replace the credentials MySQL's
# volume was initialised with, and the API would then fail to authenticate
# against its own database with no obvious cause. The file is copied only if it
# is not already there.
#
# The image goes over as a tar — around 250 MB, a few minutes on a home
# connection. That is the cost of not having a registry yet, and the reason
# GitHub Actions + GHCR is the next step rather than the first one.

set -euo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
	echo "usage: $0 user@host [tag]" >&2
	exit 2
fi
TAG="${2:-$(git -C .. rev-parse --short HEAD 2>/dev/null || echo latest)}"

HERE="$(cd "$(dirname "$0")" && pwd)"
SERVICE="$HERE/../JeevikaService"
REMOTE_DIR="/opt/gasta"

echo "==> tag: $TAG"

# ── 1. the jar ───────────────────────────────────────────────────────────
# Built here rather than in the image: pom.xml pulls three libraries from
# GitHub Packages and the token for that lives in ~/.m2/settings.xml. See the
# comment at the top of JeevikaService/Dockerfile.
echo "==> building the jar"
(cd "$SERVICE" && ./mvnw -o -B -DskipTests package)

# ── 2. the ARM64 image ───────────────────────────────────────────────────
# Oracle's Always Free tier is Ampere A1, so this is arm64 whatever this
# machine is. buildx emulates; the jar itself is architecture-independent, so
# only the base image actually differs.
echo "==> building the arm64 image"
docker buildx build --platform linux/arm64 \
	-t "gasta-api:$TAG" \
	--output "type=docker,dest=$HERE/gasta-api-$TAG.tar" \
	"$SERVICE"

# ── 3. ship ──────────────────────────────────────────────────────────────
echo "==> copying to $TARGET:$REMOTE_DIR"
ssh "$TARGET" "sudo mkdir -p $REMOTE_DIR && sudo chown \$(id -u):\$(id -g) $REMOTE_DIR"
scp "$HERE/docker-compose.yml" "$HERE/Caddyfile" "$TARGET:$REMOTE_DIR/"
scp "$HERE/gasta-api-$TAG.tar" "$TARGET:$REMOTE_DIR/"

# Only if absent — see the warning at the top.
ssh "$TARGET" "test -f $REMOTE_DIR/.env" \
	&& echo "==> .env already on the server, left alone" \
	|| { echo "==> no .env on the server; copying the template — FILL IT IN THEN RE-RUN"; \
	     scp "$HERE/.env.example" "$TARGET:$REMOTE_DIR/.env"; exit 1; }

# ── 4. load and restart ──────────────────────────────────────────────────
echo "==> loading and restarting"
ssh "$TARGET" "cd $REMOTE_DIR \
	&& docker load -i gasta-api-$TAG.tar \
	&& rm -f gasta-api-$TAG.tar \
	&& GASTA_TAG=$TAG docker compose up -d --remove-orphans \
	&& docker image prune -f"

rm -f "$HERE/gasta-api-$TAG.tar"

# ── 5. did it actually come up? ──────────────────────────────────────────
# Asking the server rather than trusting `up -d`, which returns as soon as the
# containers are *created*.
echo "==> waiting for health"
ssh "$TARGET" "cd $REMOTE_DIR && for i in \$(seq 1 40); do \
	s=\$(docker inspect --format '{{.State.Health.Status}}' gasta-api-1 2>/dev/null || echo none); \
	echo -n \"\$s \"; \
	[ \"\$s\" = healthy ] && { echo; exit 0; }; \
	sleep 10; done; echo; echo 'never became healthy — docker compose logs api'; exit 1"

echo "==> deployed: $TAG"
