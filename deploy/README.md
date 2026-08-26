# Deploying Gasta

One VM, one application, one public port. This directory is everything that
runs on the server.

## What this is, and what it deliberately is not

```
                      internet
                          │  443 only
                          ▼
   ┌──────────────────────────────────────────────┐
   │  Ampere A1 VM · Ubuntu arm64 · 2 OCPU/12 GB  │
   │                                              │
   │   caddy ──► api ──┬──► mysql                 │
   │   (TLS)           └──► redis                 │
   │                                              │
   │   duckdns (keeps the DNS record honest)      │
   └──────────────────────────────────────────────┘
```

**No OCI Load Balancer.** A load balancer earns its place when it balances
across two or more backends, or terminates TLS somewhere the application cannot
reach. Neither is true here. Adding one drags in a NAT gateway (a private
subnet has no outbound without one), a Bastion for SSH, and OCI Certificates
with manual rotation — three more things to misconfigure, for no benefit today.
Caddy gets and renews Let's Encrypt certificates by itself. When there is a
second VM, the load balancer goes in front then and nothing in
`docker-compose.yml` changes.

**No Kubernetes.** One application on one host.

**Only Caddy publishes a port.** MySQL and Redis have no `ports:` at all — not
bound to localhost, not on a high port, none. They are reachable by service
name on the internal Docker network and nowhere else, so no firewall mistake on
the host can expose them. Verify with `docker compose port mysql 3306`, which
should print nothing.

**TLS is not optional.** `AndroidManifest.xml` declares no
`usesCleartextTraffic`, so Android 9+ blocks plain HTTP outright. An `http://`
deployment installs fine and then fails every request on a real phone, with a
network error that says nothing about why.

## The live server

| | |
|---|---|
| API | **https://yapan.duckdns.org** |
| Health | `curl https://yapan.duckdns.org/api/v1/yapan/common/health` |
| Host | `ubuntu@140.238.248.77` · Ampere A1 · 2 OCPU / 12 GB · Ubuntu 24.04 aarch64 |
| Region | `ap-mumbai-1`, AD-1 |
| SSH key | `~/.ssh/gasta_oci` (created for this; **not** the OCI API key) |
| OCI CLI | `~/.oci/config`, key at `~/.oci/oci_api_key.pem` |
| Stack | `/opt/gasta` on the server |

⚠️ **SSH is restricted to one IP** — the machine this was set up from. A home
connection's address changes, and this has already happened once
(49.36.188.40 → 49.36.188.196, 2026-08-26). **When SSH starts timing out, that
is why — not the server being down.** Check first:

```bash
curl -s https://api.ipify.org
```

Then point the rule at the new address:

```bash
python deploy/allow-my-ip.py $(curl -s https://api.ipify.org)/32
```

It takes effect in seconds; no restart, and nothing on the server changes.

⚠️ **The OCI command-line tool is not installed on this machine** — only
`~/.oci/config` and the API key are. `allow-my-ip.py` uses the OCI Python SDK
(`pip install oci`) against the same config, which is why it is a script rather
than the one-line `oci network security-list update` every guide shows.

The security list is `Default Security List for gasta-vcn`; the script finds the
port-22 rule by its port rather than by position, and refuses rather than
guessing if there is no SSH rule to move.

⚠️ Only the **cloud** side restricts SSH by address. The host's own iptables
allows 22 from anywhere, which is what makes this recoverable — a host-level IP
rule would lock the machine away with no way back in.

## First-time server setup

Ubuntu 24.04 (arm64) on an `VM.Standard.A1.Flex`, 2 OCPU / 12 GB.

```bash
# Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"   # log out and back in

# ⚠️ Oracle's Ubuntu images ship iptables rules that drop everything except
# SSH, in ADDITION to the cloud-side security list. Both have to allow 80 and
# 443 or Let's Encrypt's challenge never arrives — and the symptom is a
# certificate that silently never issues.
#
# ⚠️⚠️ The position is found, not assumed. Every guide on the internet says
# `-I INPUT 6`, which is right for Oracle's older rule set and WRONG for the
# 24.04 image, where the REJECT sits at line 5 — so the new rules land after
# it and are never reached. This was got wrong once here, on this VM, and the
# rules looked perfectly correct in `iptables -L` while doing nothing.
REJ=$(sudo iptables -L INPUT -n --line-numbers | awk '$2=="REJECT"{print $1; exit}')
sudo iptables -I INPUT "$REJ" -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT "$REJ" -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo netfilter-persistent save

# Confirm 80 and 443 appear ABOVE the REJECT line:
sudo iptables -L INPUT -n --line-numbers
```

Then, on this machine:

```bash
./deploy.sh ubuntu@<ip>
```

The first run copies `.env.example` to the server as `.env` and stops. Fill it
in there — `openssl rand -base64 24` for each password — and run it again.

## Deploying a change

```bash
./deploy.sh ubuntu@<ip>
```

Builds the jar, builds an arm64 image, ships it, restarts, and then waits for
the container to report healthy rather than trusting that `up -d` returned.

`.env` on the server is never overwritten. Those passwords are what MySQL's
volume was initialised with; replacing them leaves the API unable to
authenticate against its own database, with no obvious cause.

## Running the same stack on a laptop

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

Same image, same prod profile, same `ddl-auto=validate`, same Flyway chain
against an empty database. Only two things change: Caddy is dropped (it would
ask Let's Encrypt for a domain that does not point at a laptop, and retry into
a per-domain rate limit), and the API publishes 8080 so the emulator can reach
it. MySQL and Redis still publish nothing.

Point the app at it with nothing — `flutter run` already defaults to
`http://10.0.2.2:8080`, which is the emulator's route to the host.

## Building the app against the server

```bash
flutter build apk --release   --dart-define=GASTA_API_BASE=https://yapan.duckdns.org   --dart-define=GASTA_APP_VERSION=1.0.0+1
```

⚠️ **`https://` is not optional.** See the TLS note above — an `http://` build
installs fine and fails every request on a real phone.

⚠️ **`GASTA_APP_VERSION` matters more than it looks.** Crash reports carry it,
and without it every report says `unknown` — so a crash you fixed keeps arriving
from old installs and reads as a live regression. Keep it in step with
`pubspec.yaml`'s `version:`.

Install it with `adb install -r build/app/outputs/flutter-apk/app-release.apk`.
It upgrades in place because it is signed with the same key; app data survives.

### ⚠️ Check the 16 KB alignment before any store upload

```bash
python tool/check_16kb.py build/app/outputs/flutter-apk/app-release.apk
```

Play requires 16 KB page-size support for apps targeting Android 15+. It is a
**submission-time rejection**, so nothing in a normal build or test run tells
you — Flutter 3.27 shipped an unaligned `libflutter.so` and this app carried the
fault for months. Fixed by the 3.47 upgrade; the script is there so it stays
fixed.

### For Play: an App Bundle, not this APK

```bash
flutter build appbundle --release   --dart-define=GASTA_API_BASE=https://yapan.duckdns.org   --dart-define=GASTA_APP_VERSION=1.0.0+1
```

The APK above is a **fat** one — 65 MB carrying arm64, armv7 and x86_64 at
once. Play splits a bundle at *install* time and hands each device only its own
ABI, density and language: roughly 25 MB delivered, one install, and **nothing
fetched afterwards**. Play requires AAB for new apps in any case.

⚠️ Not to be confused with dynamic feature modules, which *do* download later.
This app has none and should not.

### For sideloading: per-ABI APKs

```bash
flutter build apk --release --split-per-abi   --dart-define=GASTA_API_BASE=https://yapan.duckdns.org   --dart-define=GASTA_APP_VERSION=1.0.0+1
```

Gives `app-arm64-v8a-release.apk` (~25 MB) among others. **arm64-v8a is the one
for any real phone**; armeabi-v7a only for something very old, x86_64 only for
an emulator. On a metered connection this is the difference between a download
somebody accepts and one they think about.

## Certificates

Caddy handles issuance and renewal. Two things can break it, and both are
silent:

- **The DNS record does not point here.** The `duckdns` container re-asserts it
  every five minutes; `docker compose logs duckdns` should show `OK`.
- **Port 80 is closed.** Let's Encrypt's HTTP-01 challenge arrives on 80 even
  though nothing else uses it. Check the NSG *and* the host iptables.

While getting DNS right, uncomment `acme_ca` in the `Caddyfile` to use Let's
Encrypt's staging environment. It issues untrusted certificates but does not
count against the rate limits, which are per registered domain and unforgiving.

## Backups ✅ running

Nightly at **02:17**, via `/opt/gasta/nightly-backup.sh` (committed as
`deploy/nightly-backup.sh`). Each run: dumps, **proves the dump restores** into
a scratch schema, prunes to 14 local copies, and uploads the newest to Oracle
Object Storage.

```bash
ssh ubuntu@<ip> /opt/gasta/nightly-backup.sh      # run one now
ssh ubuntu@<ip> tail -20 /opt/gasta/backups/backup.log
```

It reuses `scripts/backup-db.sh` rather than reimplementing it. That script
gained one variable for this — `GASTA_DB_EXEC`, a prefix its client runs
behind — so on the server it becomes `docker compose exec -T mysql mysqldump`
and **no MySQL port has to be published**. The rotation, the partial-file guard
and the restore check are the same code in both places, which is the point.

Two things that were only discovered by running it:

- **The verify needs root.** The MySQL image grants the app user rights on its
  own database and nothing else, so it cannot `CREATE DATABASE` for the scratch
  schema. The dump succeeded while the verify failed — which is the failure
  most likely to be mistaken for "backups are fine".
- **Uploads use instance principals**, so there are no OCI credentials on the
  server. The instance authenticates as itself through the `gasta-instances`
  dynamic group, whose policy allows writing objects to `gasta-backups` and
  nothing else. Copying an API key up would also have worked, and would have
  put a tenancy-wide credential on the internet-facing host.

To restore, off-host:

```bash
oci os object get --namespace bmozt1ajpknb --bucket-name gasta-backups   --name db/<file>.sql.gz --file restore.sql.gz
gunzip -c restore.sql.gz | docker compose exec -T mysql mysql -u root -p<pw>
```

## What is not here yet

- **CI.** `deploy.sh` ships a ~250 MB tar each time because there is no
  registry. GitHub Actions building an arm64 image into GHCR makes deploys
  incremental, and is the natural next step — not the first one.
- **Crash reporting** (Phase 11 step 3). A crash on a user's phone is invisible.
- **Monitoring.** `docker compose logs` is the whole story today.
