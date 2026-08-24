# scripts

| File | What |
|---|---|
| `seed.sql` | A full dataset in one command — the fixture PLAN-5 Phase 1 step 3 asks for. |
| `reset.sql` | Removes exactly what `seed.sql` created, and nothing else. |
| `check-no-bom.sh` | Fails if any Java/Dart source carries a UTF-8 BOM. Now also run by CI in each code repository. |
| `check-endpoint-callers.py` | Endpoints the backend serves that nothing in the app calls (PLAN-5 III.D.2). |
| `backup-db.sh` | The database backup (PLAN-5 Phase 0). `--verify` proves it restores. |

## check-endpoint-callers.py

```bash
python3 scripts/check-endpoint-callers.py            # report
python3 scripts/check-endpoint-callers.py --fail-on-orphans
```

III.D.2 asks for this by name — "a meta-test that fails when an endpoint has no
caller in the app; §6.7's audit was manual and the drift will recur". Drift here
is not tidiness: three of §7's features were built, verified, and reachable from
no screen (T7.1 / T7.5 / T7.6), which is work paid for and not delivered. A
server has no way to notice that nobody is calling.

It is a script rather than a test because it needs both repositories at once and
neither suite can see the other. Run it from the folder holding them as siblings.

Endpoints under `/admin-user/`, `/super-user/` and `/common/health` are reported
separately: the app is not their client, so "no caller" is the expected answer
there and mixing them in is how a report becomes one nobody reads.

**It cannot see a path the app assembles at runtime**, and it cannot know about a
caller that is not this app. Treat a name in the output as a question.

## seed.sql / reset.sql

```bash
mysql -u root -p gasta < scripts/seed.sql     # load
mysql -u root -p gasta < scripts/reset.sql    # remove
```

Both are safe to run twice, and `seed.sql` removes its own previous load before
inserting, so loading twice is a no-op rather than a duplicate.

**What it makes.** One organiser, three earners, a household with members, tasks
in every state (open · running · quoted · ended · partly-filled crew), a
half-filled crew job at 6 of 10, a doorstep provider on a non-laundry profession
with a null `SERVICE_TYPE` rate, and an advance neither side has agreed to. The
running engagement has visits before, on, and after today — the dates are the
point, because earnings once counted past-dated visits as future income and a
fixture with only future visits cannot catch that coming back.

Addresses sit at 29.60, 78.18 — a little north of `adb emu geo fix 78.18 29.59`
(PLAN-5 §I.2), deliberately not on top of it: the nearby-jobs query ends
`HAVING distanceKm > :minDistance` and the widest band's floor is 0, so a job at
exactly the searched coordinates is excluded by `0 > 0`.

**Every row is prefixed `seed:`**, which is what lets `reset.sql` delete by
ownership rather than dropping the schema. That matters more than it looks: the
base catalog — professions, sub-professions, service variants, states — exists in
no migration and no file, only in databases that have been in use. A reset that
took it out could not put it back. `reset.sql` leaves the catalog, the location
reference rows, and the `system-migration` audit actor alone.

**Sign-in.** Seeded users have `PASSWORD = '!'` and no row in `users`, so none can
be logged into with a password. Sign in as them the way the app does — OTP on the
phone number, which is the same string as the username (`9999000001` and up).

## Ordering, if you are writing more

Foreign keys force it, and getting it wrong fails with a constraint name that
does not obviously belong to the row you were deleting:

1. Children of `task` — `task_job`, `task_schedule`, `task_quote`,
   `task_assignment`, `cash_advance` — then `task`.
2. Doorstep: `pickup_drop_order_item` → `pickup_drop_order`;
   `doorstep_service_rate` → `doorstep_provider`.
3. Per-user rows: `household_member`, `earner_connection`, `user_reputation`,
   `notification`, `app_user_address`.
4. `app_users` last. Twelve tables reference it.

Two traps worth knowing before you hit them:

- **`app_user_address.STATE` is a foreign key to `location_state.CODE`.** Not
  visible from the column's name or its type. Insert the country and state first.
- **Reference data must not be attributed to a user the script later deletes.**
  `location_state.UPDATED_BY` is NOT NULL and points at `app_users`; pointing it
  at a seeded user makes the reset fail on a constraint naming a table it never
  touches. It is attributed to the `system-migration` actor instead.
- **A `TEMPORARY` table cannot be referenced twice in one statement** — MySQL
  answers `ERROR 1137: Can't reopen table`. Both of the two-column deletes here
  do exactly that, which is why these scripts use a repeated subquery over
  `app_users` rather than the tidier temporary table.

## backup-db.sh

```bash
GASTA_DB_PASSWORD='...' GASTA_BACKUP_DIR=/some/other/disk scripts/backup-db.sh --verify
```

PLAN-5 Phase 0 calls this "the cheapest high-value item in this plan", and what
it protects is not the code. It is the work record — every visit completed,
every advance two people agreed on, every rate change settled months ago. §7.4
exists to give a domestic worker the documented history nobody else holds, and
until this script one disk failure took it.

**Put `GASTA_BACKUP_DIR` on a different disk.** A backup beside the database
survives a dropped table and not a dead drive, which is the failure it is really
for.

**`--verify` restores into a scratch schema** (`gasta_restore_check`), compares
the table count, and drops it. It never touches the live database. Rule 6 says a
guard that has never fired is not known to work; an untested backup is a belief,
not a backup.

**Both failure guards were tested by breaking them.** With a wrong password the
first version left a **20-byte gzip header** in the backup directory — a file
with a plausible name and timestamp that restores to nothing, which is worse
than no backup because the directory looks healthy until you need it. It now
prints the MySQL error, deletes the partial file, and exits non-zero.

### Running it on a schedule

Nothing here is a service. On Windows, Task Scheduler → daily → run
`"C:/Program Files/Git/bin/bash.exe" -lc "GASTA_DB_PASSWORD=... /path/to/backup-db.sh"`.
On a Linux host, one crontab line. Keep `--verify` on at least a weekly run.
