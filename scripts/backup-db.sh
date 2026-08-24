#!/usr/bin/env bash
#
# PLAN-5 Phase 0 — the database backup that did not exist.
#
# What this protects is not the code. It is the work record: every visit an
# earner has completed, every advance two people agreed on, every rate change
# they settled months ago. §7.4 exists to give a domestic worker the documented
# history nobody else holds — and until this script, one disk failure took it.
#
# Deliberately boring. mysqldump, gzip, a dated file, delete the old ones. No
# service, no account, no dependency beyond what MySQL already ships. A backup
# nobody can run without reading a manual is a backup nobody runs.
#
#   scripts/backup-db.sh                  # write one, prune old ones
#   scripts/backup-db.sh --verify         # write one, then prove it restores
#
# Configuration comes from the environment so this file carries no password:
#
#   GASTA_DB_HOST      default 127.0.0.1
#   GASTA_DB_PORT      default 3306
#   GASTA_DB_NAME      default gasta
#   GASTA_DB_USERNAME  default root
#   GASTA_DB_PASSWORD  no default — required
#   GASTA_BACKUP_DIR   default ./backups   ** put this on another disk **
#   GASTA_BACKUP_KEEP  default 14
#
# ── OFF-MACHINE IS THE POINT ────────────────────────────────────────────────
# A backup on the same disk as the database survives a dropped table and not a
# dead drive, which is the failure it is really for. Point GASTA_BACKUP_DIR at
# a different physical disk, a mounted share, or a synced folder. That is the
# difference between this being useful and being theatre.
set -euo pipefail

HOST="${GASTA_DB_HOST:-127.0.0.1}"
PORT="${GASTA_DB_PORT:-3306}"
NAME="${GASTA_DB_NAME:-gasta}"
USER="${GASTA_DB_USERNAME:-root}"
KEEP="${GASTA_BACKUP_KEEP:-14}"
DIR="${GASTA_BACKUP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backups}"

if [[ -z "${GASTA_DB_PASSWORD:-}" ]]; then
  echo "GASTA_DB_PASSWORD is not set. Refusing to guess." >&2
  exit 1
fi

# Windows/Git Bash: the MySQL client is usually not on PATH.
MYSQLDUMP="${MYSQLDUMP:-mysqldump}"
MYSQL="${MYSQL:-mysql}"
if ! command -v "$MYSQLDUMP" >/dev/null 2>&1; then
  for candidate in "/c/Program Files/MySQL/MySQL Server 8.0/bin"; do
    if [[ -x "$candidate/mysqldump.exe" ]]; then
      MYSQLDUMP="$candidate/mysqldump.exe"
      MYSQL="$candidate/mysql.exe"
      break
    fi
  done
fi

mkdir -p "$DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$DIR/${NAME}-${STAMP}.sql.gz"

echo "→ backing up ${NAME} to ${OUT}"

# --single-transaction so the dump is consistent without locking the tables
#   the app is using; every table here is InnoDB.
# --routines --triggers --events so a restore is the whole database, not just
#   the rows. A restore that silently drops a trigger is worse than no restore,
#   because it looks like it worked.
# --set-gtid-purged=OFF keeps the dump replayable into an ordinary local
#   database rather than only into a replica.
# A half-written backup must not survive this script.
#
# The first version relied on `set -e` and left a **20-byte gzip header** in the
# backup directory when the password was wrong: a file with a plausible name and
# a plausible timestamp that restores to nothing. That is worse than no backup,
# because the directory looks healthy right up to the moment you need it.
trap '[[ -n "${OUT:-}" && ! -s "${OUT:-}" ]] && rm -f "$OUT"' EXIT

# Handled explicitly rather than by `set -e`, so the guards below are actually
# reached on failure instead of being skipped.
set +e
"$MYSQLDUMP" \
  --host="$HOST" --port="$PORT" --user="$USER" --password="$GASTA_DB_PASSWORD" \
  --single-transaction --quick --routines --triggers --events \
  --set-gtid-purged=OFF \
  --databases "$NAME" 2>"$DIR/.last-error" | gzip -9 > "$OUT"
DUMP_STATUS=${PIPESTATUS[0]}
set -e

SIZE=$(wc -c < "$OUT")

# Two independent guards, because they catch different failures: a non-zero exit
# (bad credentials, host unreachable) and a suspiciously small file (a dump that
# "succeeded" but produced nothing). A gzip header alone is about 20 bytes.
if (( DUMP_STATUS != 0 )) || (( SIZE < 1000 )); then
  echo "✗ backup failed — removing the partial file" >&2
  if [[ -s "$DIR/.last-error" ]]; then
    sed 's/^/    /' "$DIR/.last-error" >&2
  fi
  rm -f "$OUT" "$DIR/.last-error"
  exit 1
fi
rm -f "$DIR/.last-error"
echo "✓ wrote $(( SIZE / 1024 )) KB"

if [[ "${1:-}" == "--verify" ]]; then
  # ── Prove it restores, into a scratch schema ──────────────────────────────
  #
  # PLAN-5 rule 6: a guard that has never fired is not known to work. The same
  # is true of a backup that has never been restored — an untested backup is a
  # belief, not a backup. This restores into gasta_restore_check and compares a
  # table count, then drops it. It never touches the real database.
  CHECK="${NAME}_restore_check"
  echo "→ verifying by restoring into ${CHECK}"

  run_sql() {
    "$MYSQL" --host="$HOST" --port="$PORT" --user="$USER" \
      --password="$GASTA_DB_PASSWORD" --batch --skip-column-names -e "$1" 2>/dev/null
  }

  run_sql "DROP DATABASE IF EXISTS \`${CHECK}\`; CREATE DATABASE \`${CHECK}\`;"
  # The dump carries CREATE DATABASE/USE for the original name, so it is
  # rewritten on the way in rather than restored over the live database.
  gunzip -c "$OUT" \
    | sed "s/\`${NAME}\`/\`${CHECK}\`/g" \
    | "$MYSQL" --host="$HOST" --port="$PORT" --user="$USER" \
        --password="$GASTA_DB_PASSWORD" "$CHECK" 2>/dev/null

  SRC=$(run_sql "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${NAME}';")
  DST=$(run_sql "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='${CHECK}';")
  run_sql "DROP DATABASE \`${CHECK}\`;"

  if [[ "$SRC" != "$DST" ]]; then
    echo "✗ restore produced ${DST} tables, the database has ${SRC}" >&2
    exit 1
  fi
  echo "✓ restored ${DST} tables and dropped the scratch schema"
fi

# ── Rotation ────────────────────────────────────────────────────────────────
# Keeps the newest $KEEP. Deliberately after the verify, so a run that fails
# verification does not also delete the older backups that might still be good.
mapfile -t OLD < <(ls -1t "$DIR"/${NAME}-*.sql.gz 2>/dev/null | tail -n +$((KEEP + 1)) || true)
if (( ${#OLD[@]} > 0 )); then
  printf '→ pruning %d old backup(s)\n' "${#OLD[@]}"
  rm -f "${OLD[@]}"
fi

echo "done."
