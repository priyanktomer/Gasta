# Gasta — how to do things

Every routine action, in one place. [deploy/README.md](deploy/README.md) has the
infrastructure detail behind these; this file is the commands.

⚠️ **The "Things that have actually bitten" section at the bottom is not
filler.** Every entry in it cost real time, and most of them fail *silently* —
they do not look like errors, they look like something else being broken.

---

## The three environments

| | Where | Database | Push | Use it for |
|---|---|---|---|---|
| **local** | `http://10.0.2.2:8080` | your machine | logged, not sent | `flutter run` against a laptop |
| **staging** | `https://staging.yapan.duckdns.org` | its own MySQL container | logged, not sent | trying a schema change before it reaches real work records |
| **prod** | `https://yapan.duckdns.org` | the real one | sent via FCM | what people use |

Staging and prod are **two stacks on one VM** — separate containers, separate
databases, separate volumes, one Caddy in front. See [PLAN-7 §C-1](PLAN-7.md)
for why it is not a second machine.

⚠️ **They were not separate until 2026-09-06**, and nothing said so
([O-50](OBSERVATIONS.md)). Both stacks named their services `api`, `mysql` and
`redis`; staging's API is on prod's network so Caddy can reach it; Docker
resolved those names to whichever container it liked. Prod's hostname was
sometimes served by the staging container, and staging could write to prod's
database.

**Check it by writing through one hostname and reading through the other** —
sign an unused number up on staging, then ask *prod* whether it knows that
number. `SIGN_UP` means separate; `SIGN_IN` means staging is writing to
production. ⚠️ Reading the value back through the same hostname proves nothing,
which is how this went unnoticed for ten days.

---

## Pointing the app somewhere

⚠️ **This is a build-time constant, not a setting.** `Constants.baseUrl` is a
`String.fromEnvironment`, so the address is compiled in. There is no way to
change it in the installed app, and forgetting the flag produces an APK that
installs perfectly and then fails every single request.

```bash
flutter build apk --release --dart-define=GASTA_API_BASE=https://yapan.duckdns.org
```

Staging:

```bash
flutter build apk --release --dart-define=GASTA_API_BASE=https://staging.yapan.duckdns.org
```

Local, against a laptop — the default, so nothing to pass:

```bash
flutter run
```

⚠️ The default is `http://10.0.2.2:8080`, which is **the emulator's route to
your machine**. On the emulator it works; on a real phone it reaches nothing.
Since 2026-08-27 a release build with no `https://` base **refuses to start**
and says which flag is missing, rather than looking like a dead backend.

### Installing

```bash
adb devices -l
```

```bash
adb -s <serial> install -r build/app/outputs/flutter-apk/app-release.apk
```

⚠️ `INSTALL_FAILED_VERSION_DOWNGRADE` means the phone has a higher
`versionCode` than the build. Raise `version:` in `pubspec.yaml` — the number
after the `+`.

---

## Deploying the backend

```bash
cd deploy && ./deploy.sh ubuntu@yapan.duckdns.org
```

Staging — the environment has to be named, because the mistake worth preventing
is deploying to production while believing you are on staging:

```bash
cd deploy && ./deploy.sh ubuntu@yapan.duckdns.org staging
```

The script builds the jar locally, cross-builds an **arm64** image (the server
is an Ampere A1), ships it over SSH, and waits for the container to report
healthy. It never overwrites a `.env` that already exists.

⚠️ **A prod deploy is what teaches Caddy about staging.** The Caddyfile carries
both site blocks, so deploying only staging leaves the proxy with no route to
it.

---

## Schema changes

**Add a field to an `@Entity` and restart. Do not write SQL.**

`ddl-auto=update`, Flyway removed. Full reasoning in
[db/README.md](JeevikaService/src/main/resources/db/README.md) and
[O-30](OBSERVATIONS.md).

⚠️ **`update` only ever adds.** A renamed field leaves the old column behind,
still holding the data, with no error anywhere. Rename in three deliberate
steps: add the new field, move the data in `ReferenceDataSeeder`, drop the old
column by hand when you are sure.

Data that needs to exist — flags, reference rows, backfills — goes in
`config/ReferenceDataSeeder.java`: idempotent, every write guarded by a read,
wrapped so it can never stop the app booting.

**Try it on staging first.** That is what staging is for.

---

## Demo data

Five accounts, `9000009000`–`9000009004`, OTP `000000`. Kavita
(`9000009004`) is the fullest — work assigned to her, jobs she posted, quotes
out, notifications.

```bash
cd deploy && python demo-data.py --extra-jobs 6
```

Near a particular place, so jobs show up on a phone that is actually there:

```bash
cd deploy && python demo-data.py --near 28.5692,77.4077 --city "Demo Nagar"
```

Remove it:

```bash
cd deploy && python demo-data.py --teardown
```

⚠️ **Do not sign in as a demo account from a script while testing that same
account on a device.** Every `login-verify` invalidates the previous session, so
the device starts getting 401s and falls back to cached data — which looks
exactly like a broken backend. Use a different account for scripts than the one
on the phone.

---

## Rebuilding a database from nothing

Everything the catalog needs is in code, so this is safe. It is also the only
way to prove that stays true.

1. Stop the API, drop and recreate the schema.
2. Deploy — Hibernate builds every table from the entities.
3. Sign up **`8191910695`**. That account triggers `initialSetupForIndia`,
   which creates 50 professions, 104 sub-professions, 36 states and the
   countries, and then calls `ReferenceDataSeeder` for the per-profession rules.
4. Seed demo data if you want any.

A correct rebuild ends with **52 professions, 104 sub-professions, 36 states,
10 service variants, 3 doorstep professions, 4 that ask a headcount.**
`SchemaBuiltFromEntitiesTest` asserts exactly those numbers, so if you change
the catalog, change them in the same commit.

⚠️ Use the email domain **gmail.com or outlook.com**. Sign-up rejects anything
else ([O-1](OBSERVATIONS.md)) and `example.com` fails with a message that reads
like the address is malformed.

### Repairing a catalog rather than rebuilding it

A database that is half-built — a first run that failed partway, a column added
after the rows, a profession missing its `code` — is fixed by running the same
setup again, signed in as `8191910695`:

```bash
curl -s -X POST https://staging.yapan.duckdns.org/api/v1/yapan/super-user/initial-setup \
  -H "Authorization: $ACCESS_TOKEN" -H "atsh: $ACCESS_HASH"
```

Every seeder matches on its natural key and updates in place, so this is safe on
a full database, an empty one and everything in between. It also enables India
and gives it the `+91` dial code, which is what `/common/countries` reads.

⚠️ **This was not true before 2026-09-06** and it is the reason both live
catalogs drifted ([O-44](OBSERVATIONS.md)). The seeders inserted blindly: two of
them failed on a unique constraint and aborted everything after them, and the
third — `sub_profession` has no unique constraint — silently added a second copy
of all 104 rows every time it ran.

⚠️ **A profession that somebody deliberately disabled stays disabled.** The seed
refreshes the catalog, not the decision about what to show.

---

## Looking at things

Health, from anywhere:

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://yapan.duckdns.org/api/v1/yapan/common/health
```

Application logs:

```bash
ssh -i ~/.ssh/gasta_oci ubuntu@yapan.duckdns.org 'cd /opt/gasta && sudo docker compose logs api --tail 100'
```

Staging logs — the compose file has to be named:

```bash
ssh -i ~/.ssh/gasta_oci ubuntu@yapan.duckdns.org 'cd /opt/gasta && sudo docker compose --env-file .env.staging -f docker-compose.staging.yml logs api --tail 100'
```

Caddy's access log is where request-level truth lives — status codes per
endpoint, which is how a 401 storm gets spotted:

```bash
ssh -i ~/.ssh/gasta_oci ubuntu@yapan.duckdns.org 'cd /opt/gasta && sudo docker compose logs caddy --since 10m | grep api/v1'
```

⚠️ The access log records paths and status codes and **must never record
bodies** — OTPs and phone numbers travel in them.

There is also a cron watcher writing to `/var/log/gasta-health.log`. It notices
outages and cannot tell anybody about them; see [PLAN-7](PLAN-7.md) §C-4.

---

## Road distance (PLAN-7 §B-2)

Distances are a straight line unless a router is running. Valhalla is
self-hosted because Google bills per request and OpenRouteService's free tier is
aimed at non-commercial use — neither fits a product with paying users.

⚠️ **It is off until you turn it on, and off is safe.** The container sits
behind a compose profile, `gasta.routing.valhalla-url` defaults to empty, and
every caller falls back to the straight line and the existing "(direct)"
wording. A deployment with no router behaves exactly as the product always has.

### 1. Build the tiles — somewhere else

⚠️ **Not on the server.** Tile building is hours of CPU and tens of gigabytes of
scratch, on the machine serving users. Build on a laptop or a throwaway VM.

⚠️ **Take a regional extract, not all of India.** The product serves one area;
Uttar Pradesh alone is a fraction of the size and of the build time. Geofabrik
publishes per-state extracts.

```bash
mkdir -p valhalla_tiles && cd valhalla_tiles && curl -O https://download.geofabrik.de/asia/india/uttar-pradesh-latest.osm.pbf
```

```bash
docker run --rm -v "$PWD:/custom_files" -e build_tar=False ghcr.io/valhalla/valhalla:latest
```

### 2. Copy them onto the server

```bash
tar czf tiles.tgz -C valhalla_tiles . && scp -i ~/.ssh/gasta_oci tiles.tgz ubuntu@yapan.duckdns.org:/tmp/
```

### 3. Start it, capped

```bash
cd /opt/gasta && docker volume create gasta_valhalla_tiles && docker run --rm -v gasta_valhalla_tiles:/dst -v /tmp:/src alpine tar xzf /src/tiles.tgz -C /dst && docker compose --profile routing up -d valhalla
```

⚠️ **Memory is capped at 1g and that number is not arbitrary.** Prod already
commits 6.5g and staging 2.75g of 12g. 1g is what is genuinely spare, and the
cap is the protection: a routing engine that grew without bound would take
production with it, and no job-search feature is worth that.

⚠️ Healthy means the tiles loaded. `docker compose ps valhalla` reporting
healthy is the check — a container with no tiles starts fine and answers
nothing.

### 4. Point the API at it

Add to `/opt/gasta/.env`, then redeploy:

```bash
GASTA_VALHALLA_URL=http://valhalla:8002
```

⚠️ **A job outside the extract keeps the straight line**, silently and
correctly. That is why a regional build is safe to start with: it improves the
area you serve and changes nothing elsewhere.

## Tests

```bash
cd JeevikaService && ./mvnw clean test
```

⚠️ **`clean` matters.** A stale `target/` produced eighteen
`NoClassDefFoundError` failures in files nobody had touched
([O-9](OBSERVATIONS.md)) — they look like real defects and are not.

Testcontainers starts a real MySQL 8 and Redis, so Docker must be running.

App side:

```bash
cd Yapan && flutter analyze lib && flutter test
```

```bash
cd Yapan && python tool/check_l10n.py
```

English and Hindi must agree — a missing key falls back silently and a dropped
placeholder is a runtime crash in the one language nobody on the team reads.

---

## Getting back in

The OCI security list pins SSH to a single address, so a home IP change locks
you out:

```bash
cd deploy && python allow-my-ip.py
```

⚠️ The `oci` CLI is **not** installed; this uses the Python SDK. Symptom of
needing it: SSH hangs rather than refusing.

---

## CI

Two workflows, one per repository. The backend one runs the schema-from-nothing
test as its own step, then the full suite, then publishes an arm64 image to
GHCR on `main`.

⚠️ **The backend workflow has never passed**, and will not until
`GH_PACKAGES_TOKEN` — a classic PAT with `read:packages` — is added as a
repository secret. The three `com.actually` libraries live in GitHub Packages
under other repositories and `GITHUB_TOKEN` cannot read them. See
[PLAN-7 §A-5](PLAN-7.md).

---

## Things that have actually bitten

Each of these cost hours, and every one of them fails quietly.

**An APK built without `--dart-define`.** Installs, opens, and every request
fails. Reported as "backend not working"; the server was healthy throughout.
Now guarded — a release build with no https base refuses to start.

**Signing in as the same demo account from two places.** The second login
invalidates the first, the device 401s, screens fall back to cache and show
stale data with an "11 hours ago" banner. Looks like a caching bug. Is not.

**`ALTER TABLE ... ADD COLUMN IF NOT EXISTS`.** MariaDB syntax; MySQL rejects
it. Flyway recorded the failure and then refused to start *including on the
previous image*, because the blocking record was in the database rather than the
build. Two-hour outage ([O-28](OBSERVATIONS.md)). Flyway is gone now, but the
lesson is that a schema failure can be un-rollback-able.

**A stale `target/`.** Eighteen test failures in untouched files. `mvn clean`.

**Blind `adb input tap` during a UI check.** On a fresh install the location
permission dialog comes first, so taps aimed at the login screen land on it and
the app appears to behave impossibly. Screenshot after every step.

**Matching a profession by name.** `LIKE '%mistri%'` silently matched nothing
after a rename, and matching nothing reports success. Every one of these is gone
— `profession.CODE` exists now — and new code must use it.
