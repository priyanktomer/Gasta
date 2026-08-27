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
	echo "usage: $0 user@host [staging|prod] [tag]" >&2
	exit 2
fi

# ⚠️ **Which stack.** `prod` is the default, so an existing habit of typing
# `./deploy.sh ubuntu@host` keeps meaning exactly what it always meant. Staging
# has to be asked for by name — the failure worth preventing is deploying to
# production while believing you are on staging, not the reverse.
ENVIRONMENT="prod"
case "${2:-}" in
	staging|prod) ENVIRONMENT="$2"; shift ;;
esac

TAG="${2:-$(git -C .. rev-parse --short HEAD 2>/dev/null || echo latest)}"

if [[ "$ENVIRONMENT" == "staging" ]]; then
	COMPOSE_FILE="docker-compose.staging.yml"
	ENV_FILE=".env.staging"
	API_CONTAINER="gasta-staging-api-1"
else
	COMPOSE_FILE="docker-compose.yml"
	ENV_FILE=".env"
	API_CONTAINER="gasta-api-1"
fi
echo "==> environment: $ENVIRONMENT"

# Overridable, so a second deployment elsewhere needs no edit here.
STAGING_DOMAIN="${GASTA_STAGING_DOMAIN:-staging.yapan.duckdns.org}"

# The instance key, not the default identity. Overridable for a second server.
SSH_KEY="${GASTA_SSH_KEY:-$HOME/.ssh/gasta_oci}"
SSH_OPTS=(-i "$SSH_KEY" -o StrictHostKeyChecking=accept-new)

HERE="$(cd "$(dirname "$0")" && pwd)"
SERVICE="$HERE/../JeevikaService"
REMOTE_DIR="/opt/gasta"

echo "==> tag: $TAG"

# ⚠️ JDK 17, explicitly. The build's enforcer plugin refuses anything else
# because Lombok 1.18.42 stops generating getters on a newer JDK *without
# saying so* — which surfaces as hundreds of "cannot find symbol" errors in
# files nobody touched. This script hit exactly that on its first run, because
# a login shell's default JDK is not necessarily the project's.
#
# An already-correct JAVA_HOME wins, so a machine with a different layout does
# not need this edited.
if [[ -z "${JAVA_HOME:-}" || ! -x "${JAVA_HOME}/bin/javac" ]]; then
	for candidate in "/c/Program Files/Java/jdk-17" "/usr/lib/jvm/java-17-openjdk-arm64"; do
		[[ -x "$candidate/bin/javac" ]] && { export JAVA_HOME="$candidate"; break; }
	done
fi
echo "==> JAVA_HOME: ${JAVA_HOME:-<unset — the enforcer will say so>}"

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
ssh "${SSH_OPTS[@]}" "$TARGET" "sudo mkdir -p $REMOTE_DIR && sudo chown \$(id -u):\$(id -g) $REMOTE_DIR"
# Both compose files and the Caddyfile go every time, whichever stack is being
# deployed. ⚠️ The Caddyfile carries the staging site block, so a prod deploy
# is what teaches prod’s Caddy about staging — deploying staging alone would
# leave the proxy with no route to it.
scp "${SSH_OPTS[@]}" "$HERE/docker-compose.yml" "$HERE/docker-compose.staging.yml" \
	"$HERE/Caddyfile" "$TARGET:$REMOTE_DIR/"
scp "${SSH_OPTS[@]}" "$HERE/gasta-api-$TAG.tar" "$TARGET:$REMOTE_DIR/"

# Only if absent — see the warning at the top.
#
# ⚠️ Staging generates its own passwords **on the server** rather than asking
# for them. They protect a throwaway database, nobody needs to know them, and a
# secret that has to be typed is a secret that ends up in a chat log — which has
# already happened once on this project (O-6).
if [[ "$ENVIRONMENT" == "staging" ]]; then
	ssh "${SSH_OPTS[@]}" "$TARGET" "test -f $REMOTE_DIR/$ENV_FILE" \
		&& echo "==> $ENV_FILE already on the server, left alone" \
		|| { echo "==> generating $ENV_FILE on the server"; \
		     ssh "${SSH_OPTS[@]}" "$TARGET" "cd $REMOTE_DIR && umask 077 && printf \
		       'GASTA_STAGING_DOMAIN=%s\\nMYSQL_DATABASE=gasta\\nMYSQL_USER=gasta\\nMYSQL_PASSWORD=%s\\nMYSQL_ROOT_PASSWORD=%s\\nREDIS_PASSWORD=%s\\n' \
		       \"$STAGING_DOMAIN\" \
		       \"\$(openssl rand -hex 24)\" \
		       \"\$(openssl rand -hex 24)\" \
		       \"\$(openssl rand -hex 24)\" > $ENV_FILE"; }
else
	ssh "${SSH_OPTS[@]}" "$TARGET" "test -f $REMOTE_DIR/.env" \
		&& echo "==> .env already on the server, left alone" \
		|| { echo "==> no .env on the server; copying the template — FILL IT IN THEN RE-RUN"; \
		     scp "${SSH_OPTS[@]}" "$HERE/.env.example" "$TARGET:$REMOTE_DIR/.env"; exit 1; }
fi

# ── 4. load and restart ──────────────────────────────────────────────────
echo "==> loading and restarting"
ssh "${SSH_OPTS[@]}" "$TARGET" "cd $REMOTE_DIR \
	&& docker load -i gasta-api-$TAG.tar \
	&& rm -f gasta-api-$TAG.tar \
	&& GASTA_TAG=$TAG docker compose --env-file $ENV_FILE -f $COMPOSE_FILE up -d --remove-orphans \
	&& docker image prune -f"

rm -f "$HERE/gasta-api-$TAG.tar"

# ── 5. did it actually come up? ──────────────────────────────────────────
# Asking the server rather than trusting `up -d`, which returns as soon as the
# containers are *created*.
echo "==> waiting for health"
ssh "${SSH_OPTS[@]}" "$TARGET" "cd $REMOTE_DIR && for i in \$(seq 1 40); do \
	s=\$(docker inspect --format '{{.State.Health.Status}}' $API_CONTAINER 2>/dev/null || echo none); \
	echo -n \"\$s \"; \
	[ \"\$s\" = healthy ] && { echo; exit 0; }; \
	sleep 10; done; echo; echo 'never became healthy — docker compose logs api'; exit 1"

echo "==> deployed: $TAG to $ENVIRONMENT"
