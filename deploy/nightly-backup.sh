#!/usr/bin/env bash
#
# Nightly backup of the live database (PLAN-5 Phase 11). Lives at
# /opt/gasta/nightly-backup.sh on the server; run from cron at 02:17.
#
# Two halves, and the second is the one that matters. A backup on the same disk
# as the database survives a dropped table and not a dead drive, which is the
# failure it is really for — so every dump is also copied to Oracle Object
# Storage, Always Free up to 20 GB.
#
# ⚠️ Runs the MySQL client as **root**, not as the application user. The MySQL
# image grants the app user rights on its own database and nothing else, so it
# cannot CREATE DATABASE — which `--verify` needs for its scratch schema. This
# was found by the verify failing while the dump itself succeeded, which is
# precisely the failure most likely to be mistaken for "backups are fine".
#
# ⚠️ Uploads using **instance principals**, so there are no OCI credentials on
# this machine at all. The instance authenticates as itself through the
# `gasta-instances` dynamic group, whose policy allows writing objects to this
# one bucket and nothing else. Copying an API key here would also have worked,
# and would have put a tenancy-wide credential on the internet-facing host.

set -euo pipefail

BUCKET_NAMESPACE="${GASTA_OS_NAMESPACE:-bmozt1ajpknb}"
BUCKET="${GASTA_OS_BUCKET:-gasta-backups}"

cd /opt/gasta
set -a
. ./.env
set +a

export GASTA_DB_EXEC="docker compose -f /opt/gasta/docker-compose.yml exec -T mysql"
export GASTA_DB_USERNAME=root
export GASTA_DB_PASSWORD="$MYSQL_ROOT_PASSWORD"
export GASTA_BACKUP_DIR=/opt/gasta/backups
export GASTA_BACKUP_KEEP=14

# `--verify` every night. An untested backup is a belief, not a backup, and the
# cost of proving it here is a few seconds.
/opt/gasta/backup-db.sh --verify

# The newest dump goes off the host.
#
# Nothing local is deleted here even if the upload fails — the local copy is
# the fallback, and a script that tidied up before confirming the remote copy
# would give you the worst of both.
LATEST="$(ls -1t "$GASTA_BACKUP_DIR"/gasta-*.sql.gz 2>/dev/null | head -1 || true)"
if [[ -n "$LATEST" ]]; then
	if OCI_CLI_AUTH=instance_principal oci os object put \
		--namespace "$BUCKET_NAMESPACE" --bucket-name "$BUCKET" \
		--name "db/$(basename "$LATEST")" --file "$LATEST" --force >/dev/null 2>&1; then
		echo "✓ uploaded $(basename "$LATEST") to $BUCKET"
	else
		# Loud, and a non-zero exit, so cron mails it and the log shows it.
		# A silent upload failure is how you discover months later that the
		# only copies were on the disk that died.
		echo "✗ upload to object storage FAILED — the local copy is all there is" >&2
		exit 1
	fi
else
	echo "✗ no dump found to upload" >&2
	exit 1
fi
