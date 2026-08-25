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

## First-time server setup

Ubuntu 24.04 (arm64) on an `VM.Standard.A1.Flex`, 2 OCPU / 12 GB.

```bash
# Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker "$USER"   # log out and back in

# ⚠️ Oracle's Ubuntu images ship iptables rules that drop everything except
# SSH, in ADDITION to the cloud-side Network Security Group. Both have to
# allow 80 and 443 or Let's Encrypt's challenge never arrives — and the
# symptom is a certificate that silently never issues.
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
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
flutter build apk --release --dart-define=GASTA_API_BASE=https://gasta.duckdns.org
```

⚠️ It must be `https://`. See the TLS note above.

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

## Backups

`scripts/backup-db.sh` in the repo root runs `mysqldump` and verifies the dump
by restoring it. On the server the database is in a container, so it needs to
run through `docker compose exec`. Set `GASTA_BACKUP_DIR` to somewhere that is
not this host — a backup beside the database survives a dropped table and not a
dead disk, which is the failure it is really for.

## What is not here yet

- **CI.** `deploy.sh` ships a ~250 MB tar each time because there is no
  registry. GitHub Actions building an arm64 image into GHCR makes deploys
  incremental, and is the natural next step — not the first one.
- **Crash reporting** (Phase 11 step 3). A crash on a user's phone is invisible.
- **Monitoring.** `docker compose logs` is the whole story today.
