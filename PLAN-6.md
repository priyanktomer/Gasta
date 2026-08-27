# PLAN-6 — after the first deployment

**Status: a draft, deliberately.** Written 2026-08-26, the night the backend
went live, before anybody had used the app on a real phone for more than a few
minutes. The product owner said they would come back with "a lot of feedback"
after walking the UI properly — and that feedback should shape this file, not
arrive after it has been committed to.

So: **the inventory below is real, the ordering is not.** Nothing here is
scheduled. Read it as "what is known to be outstanding", and expect the first
session that picks it up to reorder it around what the feedback says.

---

## Where things actually stand

The backend is live at **https://yapan.duckdns.org** and the app talks to it
over HTTPS from a real phone. That was the last structural unknown; everything
below is work, not risk.

| | |
|---|---|
| Backend | Live, Ampere A1 in Mumbai, Let's Encrypt, nightly verified backups off-host |
| Schema | Flyway builds it from nothing; `ddl-auto=validate` passes in production |
| Tests | 82 backend, 27 app, all green |
| App | Signed release build installs on a physical phone |
| Hindi | 780 ARB keys, English and Hindi in exact parity |
| Fonts | Platform face for text, decorative one for the wordmark only |
| Dark mode | **Off.** It was hiding data; light-only until the tokens adapt (§H) |
| iOS | Configuration audited, never built or run — nobody has a Mac (§I) |
| Push | FCM plus a WorkManager poll fallback. Poll verified end to end; FCM registration verified, FCM *delivery* not yet seen |
| Sign-in | 🟠 OTP is `000000` for everybody, **deliberately, until SMS lands** — [A-0](#a-0--an-sms-provider-so-the-otp-can-stop-being-000000--see-o-18) |
| Play readiness | ✅ 16 KB check passes on Flutter 3.47; `tool/check_16kb.py` keeps it honest |
| Flutter | 3.47.1 / Dart 3.13.1, upgraded 2026-08-26 from 3.27.1 |
| Store listing | Not started |
| Crash reporting | An endpoint on our own service, rate-limited, 90-day retention |

### What PLAN-5 has left open

- **Phase 0** — a lawyer for the legal text, and pointing `GASTA_BACKUP_DIR` at
  somewhere other than the server. *Backups are now off-host to Object Storage,
  so the second half is arguably done; the lawyer is not.*
- **Phase 7** — one illustration, crew all-or-nothing.
- **Phase 10** — push. ✅ Done 2026-08-26: FCM both directions, plus the
  WorkManager poll fallback for the handsets whose battery managers kill it.
  The poll is verified firing and reaching the server; an FCM push has not been
  watched arriving, because that needs two accounts.
- **Phase 11** — steps 3–6: crash reporting, store assets, Data Safety, target
  SDK. *Signing is done; the privacy policy URL is now possible.*
- **Phase 14** — item 4 (deliberately not done), 7 (a "consider"), 8 and 12
  (blocked on the lawyer and on appointing a Grievance Officer).

Plus everything in [OBSERVATIONS.md](OBSERVATIONS.md), which is the file for
things noticed in passing.

---

## A. Things that block a store release

These are the only items with a hard external dependency. Everything else can be
done in any order.

### A-0. 🟠 An SMS provider, so the OTP can stop being `000000` — see [O-18](OBSERVATIONS.md)

Anybody who knows a user's phone number can sign in as them today. There is no
SMS provider wired at all, which is *why* the fixed code exists — it is the only
thing making the app usable.

**Held deliberately until SMS lands (product owner, 2026-08-26; taking it up the
week of 2026-08-31).** Fine while the only accounts are ours. Not fine the day a
real user has one — so this is the item that gates putting the app on anybody
else's phone, ahead of the lawyer and the store listing.

Two steps, and the order is not optional: wire SMS first (Indian DLT template
registration is days of paperwork, so start that before the code), then set
`access-app-otp=Yapan`. The other way round locks everybody out, us included.

### A-1. A lawyer for the six legal documents ⚠️ the long pole

Phase 2 built the whole mechanism — versioned consent, an age gate, a grievance
route with the statutory SLAs, a deletion path that honours the 180-day
retention rule. Six documents ship with **DRAFT banners** and placeholder text.
The mechanism is real; the text has to come from somebody qualified.

**Send them** PLAN-5 §III.C as the brief, along with
`JeevikaService/src/main/resources/legal/`. A draft to correct is a cheaper
thing to hand a lawyer than a blank page.

### A-2. A named Grievance Officer

`gasta.legal.grievance-*` are blank, so the complaint screen degrades to showing
the SLAs with nobody's name on them. The IT Rules 2021 require a named person
with a contact address. This is an appointment, not a code change.

### A-3. ~~Firebase, for push~~ ✅ done 2026-08-26

Project `gasta-app-4aae1` exists, `google-services.json` is in place, the
service-account key is mounted read-only on the server, and the whole path from
permission prompt to `device_token` row is verified. See [F](#f-firebase--the-exact-steps-both-platforms).

⚠️ The **send** direction has not yet been exercised end to end — every
notification in the product needs two parties, and only one test account exists.
[O-15](OBSERVATIONS.md) tracks it.

**The WorkManager poll fallback needs none of that** and is arguably the more
important half for this audience — a real share of pushes never arrive on
Xiaomi, Oppo, Vivo and Realme. It was deliberately not built ahead of FCM
because the phase's own verification is "disable push at the OS level and
confirm the poll still delivers", which needs both halves to mean anything.
Worth revisiting that judgement if Firebase stalls.

### A-4. A real domain

`yapan.duckdns.org` works and costs nothing. For a store listing it is the
privacy-policy URL and the Data Safety contact, and a duckdns subdomain reads as
temporary because it is. Roughly ₹700–900/year.

---

## B. Known defects and gaps

### B-1. Everything in OBSERVATIONS.md

Thirteen entries, six resolved. The open ones worth pulling forward:

- **O-5** — profession names arrive as English prose. The most visible remaining
  English on otherwise-Hindi screens.
- **O-6** — regenerate the DuckDNS token; it was pasted into a chat log.
- **O-1's wording** — the Gmail/Outlook rule is staying (a policy, not a defect),
  but the message reads like the user's address is invalid rather than like a
  rule. One sentence to fix.
- **O-8** — check whether Actuator resolves now; `HealthController`'s reason for
  existing may have expired.
- **O-11** — Flutter 3.27.1 is from December 2024. Upgrade before a store
  submission, not after.
- **O-12** — `POST_NOTIFICATIONS` is undeclared; push will silently show nothing
  on Android 13+.
- **O-13** — `google_maps_flutter` is dead weight; the only map is commented out.

### B-2. ~~The Hindi audit nobody has done~~ ✅ done 2026-08-27 — and it passes

**The mechanical half is done and clean.** `tool/check_l10n.py` compares the
two ARB files and passes:

```
754 keys checked
English and Hindi agree.
```

It checks three things, none of which break the build when they are wrong:

1. **A key in English and not in Hindi.** Flutter falls back to English
   silently, so a Hindi speaker gets one English sentence mid-screen.
2. **A value copied across untranslated** — same symptom, and it survives a
   key-count check, which is why counting keys is not enough. Detected by
   looking for Devanagari in the Hindi value.
3. **A dropped placeholder.** `"{count} people"` without its `{count}` throws
   at runtime, on one screen, in the language nobody on the team reads.

Two English values in the Hindi file are allowed and listed in the script:
`appName` ("Gasta" is a name) and `languageEnglish` — "English" must read as
English in the picker or somebody who cannot read Hindi cannot find their way
back.

⚠️ **The half a script cannot do is still open.** Nobody has walked the whole
app in Hindi with fresh eyes, and no parity check catches a translation that is
present, grammatical and *wrong for the context* — which is the failure this
audience would actually hit.

The recurring trap, twice now: **text that is composed cannot be translated.**
The posting wizard compared against the English words *on screen* to decide
which form fields to draw. The visits screen glued `"$when"` and `", $slot"`
onto a sentence with adjacent-string concatenation. Both had to be restructured
before a single word could be replaced. Expect more of these.

### B-3. Crash reporting ✅ built 2026-08-26

Neither Sentry nor GlitchTip — an endpoint on the service we already run, at the
product owner's request. `POST /common/report-crash`, a `crash_report` table,
90-day retention on the nightly sweep, and rate limits (see §D).

**What it is not:** no grouping by fault, no regression detection, no alerting,
no symbolication. It answers "is the app crashing, where, and on what", which
previously had no answer at all. When it needs the rest, that is the point to
buy rather than build.

✅ **Something looks at the table now** (2026-08-26). Two readers, one query:
`GET /admin-user/crash-summary?days=7` returns faults ordered by how often they
happened, with the device-model spread and the first and last app version each
was seen on; and a job at 09:00 on Mondays writes the same thing to the log at
WARN.

It says "nothing reported" out loud on a quiet week rather than staying silent,
because "no crashes" and "the job stopped running" look identical in a log that
only speaks up when there is bad news.

Grouped by **summary**, not by stack trace: the same fault reached from two
screens produces two traces and would look like two problems.

⚠️ A log line is a weak channel — it reaches somebody only if they go and look.
It is also the only channel this server has. See B-4.

### B-4. Monitoring ◐ started 2026-08-27

`docker compose logs` was the whole story: the health endpoint does a real
round trip to MySQL and nothing looked at it, so a server that died at 2am
stayed dead until somebody opened the app.

`deploy/health-watch.sh` runs every five minutes from cron on the box and
writes to `/var/log/gasta-health.log`. Installed and probed.

Two decisions in it worth keeping:

- **Two consecutive failures before it says anything.** A single timeout is a
  dropped packet, a certificate renewal, or the API restarting after a deploy.
  Shouting about each of those is how somebody learns to ignore the file — and
  then it has stopped working for the case it exists for.
- **It logs recovery too.** Without that the log shows a server going down and
  never coming back, which is a worse story than the truth.

⚠️ **This is not monitoring, and the gap is the point.** It reaches a person
only if they read the file, and it cannot report the failure that matters most
— the whole host being gone, cron included.

**The thing actually worth doing next is an external pinger** (UptimeRobot's
free tier, Healthchecks.io) that emails when the ping *stops*. It is better
precisely because it does not run on the machine it is watching. Ten minutes
and an account.

---

## C. Deployment work that is worth doing next

### C-1. CI — GitHub Actions building into GHCR

`deploy.sh` ships a **~200 MB tar** on every deploy because there is no
registry. It works and takes under two minutes, which is why it was the first
step rather than this. Actions building the arm64 image into GHCR makes deploys
incremental and removes the laptop from the path.

Deliberately second: the first deploy should not also be the first time CI has
ever run.

### C-2. SSH is pinned to one IP

Correct, and it will lock the product owner out the first time their ISP hands
them a different address. The runbook says how to move it. A better answer is
OCI Bastion (Always Free), which needs no standing rule at all.

### C-3. `ddl-auto` and a second environment

There is one database and it is production. A staging compartment on the same
tenancy would cost nothing in Always Free terms and would let a migration be
tried before it runs against real work records. Worth it the moment there is
real data worth protecting — which is roughly now.

---

## D. Rate limiting — what exists, and what it should cover

**Asked for on 2026-08-26.** There is already a working limiter; the question
is where it is applied, not how to build one.

### What is there now

`RateLimitService` — a Redis counter with a **fixed** window:

```java
boolean allow(String key, int limit, int windowSeconds);
```

Two properties worth knowing before extending it:

- **The window is fixed, not sliding.** The expiry is set only on the first hit,
  so a steady stream of requests cannot keep the key alive forever and stop the
  counter ever resetting. The cost is a burst at a window boundary — up to
  double the limit across two adjacent windows. For flood protection that is
  fine; for anything where the exact number matters it is not.
- **It fails open.** If Redis is unreachable, requests are allowed and the
  failure is logged. A login that stops working because the rate limiter is down
  is a worse outcome than a window of unthrottled requests. ⚠️ That is a
  deliberate availability-over-security trade, and it is the right one *for a
  nuisance limiter*. It would be the wrong one for anything protecting money.

Applied today:

| Endpoint | Limit |
|---|---|
| `otp-request` | 6 per phone per hour, 40 per caller per hour |
| `report-crash` | 20 per address per hour, 10 per account per hour |

### The thing that makes all of this approximate

**Behind carrier-grade NAT a whole village shares one address.** This audience is
on mobile data, so "per IP" is closer to "per cell tower" than "per person". It
is why the OTP limits are per *phone number* first and per caller second, and
why the crash limit is 20 rather than 3.

`X-Forwarded-For` is trusted only for its first entry and only because the app
sits behind our own Caddy. It is client-settable, so it is a nuisance limiter
and **not an authorisation boundary**. Nothing that matters should key on it
alone.

### Where it is missing, in the order I would add it

1. **`login-verify` and `sign-up-verify`.** Currently unlimited. Six OTP requests
   an hour is capped, but *verification attempts* are not — so a six-digit code
   can be brute-forced within its own lifetime. This is the one real hole. Key
   on the phone number, roughly 5 attempts per code, and invalidate the OTP once
   exceeded rather than merely refusing: a limit that resets while the same code
   is still valid buys nothing.
2. **`post-new-job` / `post-instant-job`.** A script could fill the Earning Zone
   with noise, which costs every worker in the area their attention. Per account,
   generous — perhaps 20 an hour.
3. **`add-advance`, `respond-advance`, `record-payment`.** Money paths. Low
   volume by nature, so a tight limit costs nothing and bounds the damage of a
   stolen token.
4. **A global fallback in Caddy.** One line of `rate_limit` in front of
   everything, set high enough never to touch a real user. Catches whatever
   nobody remembered to annotate.

### What I would not do

**Do not put the limiter in a filter that runs on every request.** It becomes a
Redis round trip on the hot path for endpoints that do not need it, and the
first slow day someone disables the whole thing. Per-endpoint, deliberately, is
slower to write and easier to reason about.

---

## E. Encrypting the payload — should we?

**Asked for on 2026-08-26: would encrypting the request or response body prevent
man-in-the-middle attacks?**

### The short answer

**No, and it would make things slightly worse.** TLS already prevents it, and
that is the mechanism designed for exactly this problem. Adding a second,
home-made encryption layer inside TLS buys nothing against MITM and costs real
things.

### Why

A man-in-the-middle attack means somebody sits between the phone and the server
and reads or alters traffic. TLS stops this with **server certificate
verification** — the attacker cannot present a certificate for
`yapan.duckdns.org` that the phone will accept, because they cannot get one from
a CA the phone trusts. That is already in place, and Android will not even allow
plain HTTP for this app.

Now consider encrypting the JSON body as well. The app must hold the key. The
app is on the attacker's phone, and any key shipped inside an APK can be
extracted in minutes. So the attacker who has already defeated TLS also has the
key — the second layer stops nobody it was aimed at.

Meanwhile it costs:

- Every payload becomes opaque, so **`@Valid` cannot run** until after decryption
  and the whole `ApiExceptionHandler` shape has to be rebuilt.
- Debugging goes from "read the request" to "decrypt it first" — on a system
  where the fastest way to find a defect has repeatedly been reading a log line.
- Key rotation becomes an app release.
- Caddy can no longer see request sizes or paths usefully for rate limiting.

### What actually raises the bar, in order

1. ~~**Certificate pinning.**~~ **Decided 2026-08-26: not doing it.** See
   [E-1](#e-1-certificate-pinning--decided-against) below for the reasoning.
2. **Shorter token lifetimes and real refresh-token rotation.** Reduces what a
   captured token is worth, which is the actual damage in most realistic
   attacks.
3. **Certificate transparency monitoring** — cheap, and tells you if somebody
   ever issues a certificate for the domain.
4. **HSTS**, already set in the Caddyfile.

### E-1. Certificate pinning — decided against

The product owner asked me to decide, so: **no pinning, and it is not a close
call at this stage.**

**What it would buy.** Pinning is the answer to exactly one attack TLS does not
already stop: a device that trusts a certificate authority we did not choose —
a corporate proxy, an interception tool, or a CA the user was talked into
installing. Against a passive network attacker, ordinary TLS is already
sufficient and has been for years.

**What it would cost, specifically here:**

- **The certificate rotates every 60 days.** Caddy renews from Let's Encrypt
  automatically, which is the whole reason the deployment is cheap to run. A
  leaf pin therefore breaks the app roughly six times a year, and it breaks it
  in the worst possible way: every installed copy stops working at once, and the
  fix is a store update the user has to accept.
- **Pinning the intermediate is not safer.** Let's Encrypt has changed
  intermediates with weeks of notice — R3 to R10/R11, and the ISRG X1
  cross-sign expiring — and each change would have been an outage.
- **Pinning the root buys almost nothing.** ISRG Root X1 is trusted by every
  device already; pinning it excludes other CAs but not an attacker who can get
  a certificate from Let's Encrypt, which is free and automated. It is the
  version that would not brick us, and also the version that barely defends.
- **A kill switch is a chicken-and-egg problem.** The usual mitigation is a
  remote flag that disables pinning — fetched over the connection that pinning
  just broke.
- **Anyone with the access to install a rogue CA has already lost the game.** A
  rooted phone with an interception proxy can also hook the pin check with
  Frida in about ten minutes. Pinning stops casual inspection, not a determined
  attacker.

**What the actual threat model is.** Gasta carries phone numbers, addresses,
work schedules and wage records for households and workers in small towns. The
realistic attacks are a shared or stolen handset, a compromised account, and
somebody socially engineering their way in — [O-18](OBSERVATIONS.md), the fixed
`000000` OTP, is a hundred times more dangerous than any MITM scenario and costs
nothing to exploit. Pinning defends the one channel that is already the
best-defended thing in the system.

**When to revisit.** If the app ever carries payment instruments or identity
documents, or if a partner's security review requires it. At that point do it
properly: pin the root **plus** a backup key, ship a kill switch, and give it a
staged rollout — that is a week of work and a permanent operational burden, and
it should be bought deliberately rather than added because it sounds prudent.

**What was done instead**, in the same session and for a fraction of the effort:
tokens moved into the Android Keystore / iOS Keychain
(`SecureTokenStore`), OTP verification rate-limited, and the crash endpoint
bounded. Those defend attacks that can actually happen here.

---

### The one place encryption *would* help

Not the transport — **at rest**. ✅ **Done 2026-08-26.** The phone stored tokens
in SharedPreferences, which is readable on a rooted device. `SecureTokenStore`
now puts them in the Android Keystore / iOS Keychain, with a one-time migration
so nobody already signed in gets logged out, and a fall back to preferences on
the handsets where the Keystore is broken — some cheap Android 6/7 devices —
because being unable to store a token must not mean being unable to sign in.

⚠️ It forced `minSdk` from 21 to 23, dropping Android 5.0/5.1. Those devices
cannot run current Play Services anyway.

---

## F. Firebase — the exact steps, both platforms

The project **`gasta-app`** exists. Everything below assumes it.

⚠️ **The iOS half is meaningfully harder than the Android half, and it is not
optional to know that up front.** Android needs a JSON file. iOS needs an Apple
Developer Program membership (₹8,900/year), a signing certificate, and an APNs
key — Firebase does not deliver to iOS at all, it relays through Apple, and
without the APNs key nothing arrives and nothing errors.

### Android — console

1. **Project overview → Add app → Android.**
2. **Package name `com.tomer.yapan`**, exactly. A mismatch is silently rejected
   at runtime rather than at build time.
3. Nickname and SHA-1 can be skipped — SHA-1 is for Google Sign-In and Dynamic
   Links, neither of which this app uses.
4. **Download `google-services.json` → `Yapan/android/app/google-services.json`.**
   ⚠️ Not in git. It is not a secret exactly — it ships inside every APK — but it
   belongs with the other build-time config that stays out of the repository.

### iOS — console and Apple

5. **Add app → iOS.** Bundle ID must match `PRODUCT_BUNDLE_IDENTIFIER` in the
   Xcode project. ⚠️ **Check what that actually is** — the Android package is
   `com.tomer.yapan`, and nobody has verified the iOS one because nobody has
   opened the project.
6. **Download `GoogleService-Info.plist` → `Yapan/ios/Runner/`,** and add it to
   the Xcode target. Dropping it in the folder is not enough — it has to be in
   the project or it will not be in the bundle.
7. **Apple Developer Program membership.** Required before any of the below.
8. **Create an APNs authentication key** (Keys → new key → Apple Push
   Notifications service). Download the `.p8` **once** — Apple does not let you
   download it again.
9. **Firebase → Project settings → Cloud Messaging → iOS app → upload the `.p8`**
   with its Key ID and your Team ID.
10. **Xcode: add the Push Notifications capability**, and Background Modes →
    Remote notifications.

### Server

11. **Project settings → Service accounts → Generate new private key.** That JSON
    **is** a secret: `/opt/gasta/fcm-service-account.json`, never in git, and it
    wants a line in `deploy/.env` pointing at it.
12. Confirm **Firebase Cloud Messaging API (V1)** is enabled. The legacy server
    key is deprecated and the server side should use V1.

### What the code needs ✅ built 2026-08-26

**Server.** `FcmPushSender` posts to FCM's HTTP v1 API, replacing
`LoggingPushSender` whenever `gasta.push.fcm.credentials` points at a key.
Deliberately **not** the Firebase Admin SDK — that is tens of megabytes of
transitive gRPC and Firestore for one HTTPS POST, and the only thing we could
not do ourselves was mint an OAuth token, so `google-auth-library-oauth2-http`
is the only dependency taken.

Sends happen on a small bounded worker pool, never on the caller's thread: the
notification is written inside a transaction, and a ten-second call to Google in
there holds a database connection for ten seconds. A token FCM reports as dead
is deleted rather than retried forever. `device_token` (V17/V18) is unique on
the token and **reassigns** its user when somebody else signs in on the same
handset — shared phones are normal in this audience, and pushing the previous
user's job alerts to whoever holds the phone now is a privacy failure rather
than a delivery bug.

**App.** `PushService` — `firebase_core`, `firebase_messaging`, and
`flutter_local_notifications` for the foreground case (FCM draws nothing while
the app is in front on Android, which reads as "notifications do not work").
Registration goes through `evaluateResponse`, the one method both sign-in and
sign-up pass through, and again on every launch because FCM rotates tokens.
`POST_NOTIFICATIONS` is asked for **after sign-in**, never on first launch.

**iOS needed no separate code.** The `apns` block is in the message from day
one and `firebase_messaging` hands off to APNs, so the remaining iOS work is
console configuration — see below — not development.

**What is not built:** per-type deep links. Every push opens the notifications
list, which is one tap from everything and always correct. Routing per type
wants a type in the payload; worth doing when the payload carries one.

### F-1. The poll fallback ✅ built and verified 2026-08-26

**Asked 2026-08-26: "WorkManager u need for what? notifications or data
refresh?" — notifications. Not data refresh.**

Nothing in the app depends on background data. Every screen loads what it needs
when it opens and falls back to its last good contents when there is no signal
(§6.2). Refreshing in the background would spend the user's data and battery on
a screen they are not looking at, which for a metered connection is a real cost
for no benefit.

**What it *is* for:** on Xiaomi, Oppo, Vivo and Realme, aggressive battery
management kills the process holding FCM's socket, and pushes then silently
never arrive. There is no way for the app to know this has happened. A periodic
job asks the server "is there anything unread?" and raises the notification
locally if there is — so a job offer still surfaces on a handset where Google's
own transport has been shut off.

That is most of this audience's phones, which is why it matters at least as much
as FCM does.

**The shape of it:**

- `workmanager` with a periodic task. ⚠️ **Android's floor is 15 minutes** and
  the OS will stretch it further under Doze. That is fine — this is a safety
  net under a real-time channel, not a replacement for one.
- It calls `get-unread-notification-count`, which already exists and is one
  indexed query. Nothing new server-side.
- It compares against the last count it saw and only raises a local
  notification when that number has gone **up**. Without that, every poll
  re-notifies about the same thing and the user turns notifications off.
- It does nothing while the app is in the foreground — the user is already
  looking at it.
- ⚠️ Same OEM battery managers can kill WorkManager too. This narrows the gap;
  it does not close it. The only thing that closes it is the user opening the
  app, which is why the rule below still stands.

**Verified on a device**, which matters more than usual here because the way
this package fails is silent: the dispatcher must be a top-level
`@pragma('vm:entry-point')` function or release tree-shaking removes it, the job
then fires, finds nothing to run, and the poll simply never happens.

The Android job scheduler started `dev.fluttercommunity.workmanager
.BackgroundWorker` at 19:49:29 and it returned `SUCCESS`; the authenticated
`get-unread-notification-count` reached the server at 19:50:02 as
`200 OK | 9000000001`. Dart entry point, HTTP client and stored session all
work from the background isolate.

⚠️ `adb shell cmd jobscheduler run -f` does **not** work for this — WorkManager
sees the initial delay has not elapsed and reschedules instead of running
("Delaying execution ... because it is being executed before schedule").
Force-stopping the app also cancels the job until next launch. The way to test
it is to background the app and wait the fifteen minutes.

**iOS needs none of this.** APNs delivery through FCM is reliable and iOS has no
equivalent of the OEM battery managers. `BGAppRefreshTask` exists but iOS
schedules it on its own judgement, sometimes not for days — so the poll would be
Android-only, guarded by `Platform.isAndroid`.

⚠️ **Whatever happens with push, nothing that costs somebody money or a day's
work may depend on it** — the crew-release decision, the advance confirmation and
the visit reminder all assume the user opens the app. Push is an accelerator, not
the mechanism. That was PLAN-5 Phase 10's rule and it still holds.

---

## G. Query shape on listing endpoints

**Asked for on 2026-08-26:** listing endpoints should hit the database with
minimal joins; detail endpoints may carry more.

### The measurement

One call to `get-my-posted-tasks` on the dev database, before any change:

| | statements | tables |
|---|---|---|
| Before | **15** | 9 — `profession` ×3, `app_users` ×3, `sub_profession` ×2 … |
| After LAZY on unread relations | 13 | `sub_profession` gone |
| After `@EntityGraph` on the list query | **9** | `profession` gone |

Forty percent fewer round trips for a DTO of about twenty scalar fields.

### The cause, which is systemic

**JPA defaults `@ManyToOne` and `@OneToOne` to EAGER**, and there are **97 of
them in this codebase with no fetch type declared**. `Task` alone has ten, and
`Task.address` drags in two more. So every query that loads a Task loads a graph,
and a list loads that graph once per row unless something stops it.

`getUpdatedBy()` is the clearest case: **zero callers anywhere**, fetched on
every Task query including every list. An audit column nobody reads, costing a
join on the hottest path in the product.

### The pattern, for the endpoints not yet converted

1. **Make relations LAZY where nothing reads them.** Check for callers first —
   `grep -rn "\.getThing()"` — and remember that a LAZY proxy is safe to *assign*
   without initialising it.
2. **`@EntityGraph(attributePaths = {…})` on the list query** for the relations
   the DTO genuinely reads. They still have to be loaded; the graph makes it one
   join instead of one SELECT each.
3. **Name only what the list renders.** That is the principle. A fuller graph
   belongs on detail endpoints, where one row justifies it.

### ⚠️ The order matters, and getting it wrong breaks serialisation

Several endpoints still return **raw entities** — `get-user-address` is one. If
a relation on a raw-returned entity is made LAZY, Jackson meets an uninitialised
proxy outside the session and either throws or emits nonsense. **DTO first, then
LAZY.** `AppUserAddress.state` is deliberately still eager for exactly this
reason.

### Not yet done

Every other list endpoint: the earner's task list, quotes, doorstep orders,
notifications. Same two steps each, and each wants its own before/after count
rather than a guess — turn on `spring.jpa.show-sql` and count.

---

## H. Dark mode

**Off as of 2026-08-26**, and this is worth reading before someone turns it back
on.

`ThemeMode.system` was set and a `darkTheme` existed, so a phone in dark mode
got one — and it hid data rather than merely looking wrong. On the profile
screen the user's own name and every field value were invisible.

The mechanism is systemic:

- `AppText.title/body/label/…` carry **no colour**, so text inherits the theme's
  foreground: near-black in light, near-white in dark.
- `AppSemanticColors.surface` is `static const Color(0xFFFFFFFF)`. Every card,
  sheet and tile is painted with it **in both modes**, because a `const` cannot
  know the brightness.

White text on a white card, everywhere those two meet — which is most screens.
The strings that survived are the ones that happened to set a colour explicitly,
which is why the username showed and the name above it did not.

### What real dark support needs

1. **Brightness-aware tokens.** A `ThemeExtension<GastaColors>` registered on
   both themes, with `AppSemanticColors.of(context).surface` replacing the
   statics. Roughly 200 call sites.
2. **The 107 hardcoded `Colors.white` / `Colors.black`.**
3. **A dark palette that is designed**, not derived. `muted` (#5F6368) is tuned
   for contrast on a light background and fails on a dark one; the status colours
   need checking at both brightnesses.
4. **Every screen checked twice.** That is the part that takes the time.

Until then, a user in dark mode gets the light theme, which is designed, tested
and legible. One line in `main.dart` reverses it.

---

## I. iOS

**Never built, never run.** There is no Mac in this project, so everything below
is a configuration audit — real findings, but not a substitute for someone
opening Xcode.

### Fixed 2026-08-26

- **Landscape was allowed.** `main.dart` locks portrait, but on iOS
  `SystemChrome` can only choose among what `Info.plist` permits, so the plist
  was undoing it. An iPhone would have rotated into the broken layout Android is
  protected from.
- **Generic purpose strings.** "Your app needs access to your location." is close
  to the example in Apple's own guidance of what not to write, and Apple rejects
  them.
- **Two `NSLocationAlways*` keys** for background location the app never uses.
- **`NSBiometricUsageDescription`**, which is not a real key — Apple only reads
  `NSFaceIDUsageDescription`.
- **Missing `LSApplicationQueriesSchemes`.** Without `tel`, `canLaunchUrl`
  answers false and the call button does nothing — including on the safety
  screen.

### Still open, and only a Mac can close most of it

1. **Build it once.** `flutter build ios` will generate the Podfile and reveal
   whatever the plugin set does not like. Nothing below can be trusted until
   this has happened.
2. **`permission_handler` needs Podfile macros.** Without them it compiles in
   *every* permission it supports, and the App Store asks why an app that shows
   nearby work wants the microphone. This is a known rejection cause and the fix
   is a `GCC_PREPROCESSOR_DEFINITIONS` block in the Podfile.
3. **Signing.** No provisioning profile, no certificate, no App Store Connect
   record.
4. **The launch storyboard and icons** are Flutter's defaults.
5. **`CFBundleName` is `yapan`** while the display name is `Gasta`. Harmless —
   the home screen uses the display name — but worth aligning.
6. **Hindi on iOS.** The platform font change (2026-08-26) means text now uses
   San Francisco, whose Devanagari coverage is good; worth confirming on a real
   device that the clamps in `AppText` still read well.
7. **`IPHONEOS_DEPLOYMENT_TARGET` is 12.0**, which is correct for Flutter 3.27.1.
   Do not raise it without also upgrading Flutter — it looks like an easy win
   and is not one.

### One thing that is not iOS-specific

**Flutter is 3.27.1, from December 2024.** Everything here is pinned to it,
including the iOS minimum. An upgrade is its own piece of work and wants doing
before a store submission rather than after.

---

## J. Product work, unranked

Nothing here has been agreed. It is written down so it is not re-derived.

- **Phase 7's last illustration** — crew all-or-nothing, one line of drawing.
- **The two remaining Phase 5 gaps** — a declined consent still does not stop
  the app using the data (Phase 14 item 8), which needs the lawyer's text to say
  which features depend on it.
- **`OrganiserServiceImpl` is ~2,400 lines** (Phase 14 item 7). Not a defect.
  Three of one session's bugs lived there.
- **The `Slot` enum has 38 values for about four in use** (Phase 14 item 4).
  Deliberately not trimmed: doing it would delete `SlotLabelTest`, which
  documents three real 16-hour label defects, for cosmetic gain.

---

## K. On retiring PLAN 1–5

The product owner asked whether the old plan files can be removed now that the
main development phase is over.

**Recommendation: mark them historical, do not delete them.** Two reasons.

The plans are not only task lists — they carry the *reasoning*, and several
decisions in this codebase are only defensible because the argument is written
down somewhere. PLAN-4 holds the product thesis and the rules learned the hard
way. DEFERRED.md holds what was consciously not built, which is the file that
stops a future session cheerfully rebuilding something that was rejected for a
good reason. AUDIT.md is the provenance of a great many small fixes.

And the cost of keeping them is close to zero: a line in the README saying which
file is current. The cost of deleting them is discovering in four months that
nobody remembers why `ddl-auto` is what it is, why the Slot enum was not
trimmed, or why there is no load balancer.

**What is worth doing** is making the entry point unambiguous, so a fresh
session reads *this* file and not a finished one. That is a README change, and
it is the only part of this recommendation that should happen without
discussion.

---

## L. The first UI feedback round (2026-08-26)

The product owner and friends used the app and reported nine things. Three were
fixed the same day and are marked below; the rest are here with what each one
actually requires, because most are product decisions with code attached rather
than bugs.

**Ranked by what they cost a real user**, not by effort.

---

### L-1. "How many people do you need?" is asked of everyone, and promises work that may not exist

> *"I hope we ask user at some point what if only 2 of 5 got hired, then we
> can't give fake hope of employment to earner even for a min. And why how many
> people u need being asked for every profession, while calling makeup artist
> for bride how can bride decide how many people needed, the makeup artist will
> come with team we have nothing to do with that."*

**This is the most important item on the page**, and it is two separate problems
that happen to share a control.

#### The question is asked where it has no meaning

`_workersNeededRow()` renders unconditionally on step 1. For a makeup artist, a
tractor operator or an appliance mechanic, headcount is **the provider's
business, not the customer's** — a bride booking makeup does not know or care
whether two people arrive, and asking her to pick a number invites a wrong
answer that then filters the earners who see the job.

⚠️ It is not cosmetic. `NearbyJobRepo` hides a job once
`SUM(crew_size) >= WORKERS_NEEDED`, so a number the organiser guessed decides
who is shown the work.

**The shape of the fix.** `ProfessionRuleDto` already carries per-profession
rules — `allowedSlots`, `multiSelectSlots`, `baseUnit`, the price band — and the
app already branches on them. One more flag, `asksHeadcount`, on `profession`
and in that DTO, and the row draws only when it is true.

Which professions get it is the part that needs a person, not a developer.
The rule of thumb that fits the market: **ask when the customer is buying
hours of labour and the count is theirs to choose** — farm labour, construction
majdoors, loading, harvest crews. **Do not ask when they are buying an outcome**
— makeup, mechanic, carpenter, electrician, tailor, machinery hire. Default the
new column to false and switch on the handful that need it, so a profession
added later does not inherit a question nobody meant to ask.

**Size:** a migration, one DTO field, one `if` in the app. Half a day, plus the
list.

#### Partial fill quietly promises work

Today a job for five with two taken stays open, and both earners are assigned.
Nothing tells either of them the job may not run at the size advertised.

The product owner's phrasing is the right test: **do not give fake hope of
employment, even for a minute.** Three options, and this is the decision:

1. ~~**Show the fill state to the earner.**~~ ✅ **Already built** — checked
   before writing any of it. `workersBadge` in `worksheet_screen.dart` draws
   "Needs 5 people · 3 places left", "last place", or "Needs all 5 together ·
   3 left" for the crew case, whenever `workersNeeded > 1`. So an earner
   browsing already knows how full a job is.
   ⚠️ What they are *not* told is anything after they are assigned: nothing
   says "this still needs two more and may not run". That is (2), not (1).
2. **Make partial fill an explicit organiser decision.** At the deadline, if 2 of
   5 came, ask the organiser: run with two, or cancel. The crew all-or-nothing
   flag (`CREW_ALL_OR_NOTHING`) is the same idea already built for crews — this
   would extend it to headcount.
3. **All-or-nothing by default.** Cleanest promise, worst outcome: a job that
   needed five and found four does not happen, and four people lose a day.

**Recommended: (2), since (1) turns out to be done.** It is the real answer and
needs a sweep, a notification and a screen. (3) should not be the default in a
market where four out of five is a normal Tuesday.

⚠️ The gap (1) does not close: the badge is a *browse-time* signal. Once a quote
is accepted the earner has planned a day around it, and nothing tells them the
job is still short. That is the moment the promise is made, and it is where (2)
belongs.

**Size:** (2) is two or three days.

---

### L-2. Laundry ◐ listed again 2026-08-27; the garment menu is still open

> *"yeah laundry is main in doorstep and this only should be enabled with proper
> menu for wash and iron separately cloth wise like shirt, kurti, saree,
> trouser"*

Two problems.

#### It does not appear at all

Doorstep Services currently lists **Cylinder and Heavy Item Delivery** and
**Water Supply**, both "Coming soon". Laundry and Appliance Mechanic are absent,
though `V5__service_variants.sql` sets `SUPPORTS_PICKUP_DROP = TRUE` on all
four.

⚠️ The likely cause: V5 matches laundry by the exact name
`'Pickup Drop Cloth Wash and Ironing'`, and **professions were never seeded by a
migration** — the table was populated some other way, so that name may not
match what production holds. The banner icon on the screen is a washing machine,
which is a leftover from when this screen was laundry-only and is now the only
laundry on it.

✅ **Fixed by V20.** The flag had simply never been set — the row exists under
exactly the name V5 looked for. V20 matches on what the row is *about* rather
than one spelling, and re-adds the wash/iron variants if they were missed too.

It shows as **Coming soon** because no provider has registered nearby, which is
the honest state rather than a bug. Testing the booking flow needs somebody
registered as a laundry provider first. See [O-23](OBSERVATIONS.md).

#### The menu is one dimension short

The catalog has `WASH`, `IRON` and `WASH_AND_IRON`, priced `PIECE`. What is
missing is **the garment**: a saree is not a shirt to wash, and it is certainly
not a shirt to iron. Today one price covers everything, which is either
unprofitable for the provider or unfair to the customer.

**The shape of the fix.** A `garment_type` catalog (`SHIRT`, `KURTI`, `SAREE`,
`TROUSER`, `BEDSHEET`, …) with labels in both languages, and
`doorstep_service_rate` keyed on **(provider, variant, garment)** instead of
(provider, variant). The order item gains a garment too. The booking screen
becomes a grid — garment down, wash/iron/both across — with a quantity stepper,
which is also the form a customer recognises from a laundry receipt.

⚠️ **The rate table grows multiplicatively.** Six garments times three services
is eighteen prices for a provider to enter before they can take an order, and
this audience will not fill in eighteen fields. It needs a default price per
service with per-garment overrides only where the provider cares — a shirt price
that covers everything, and a saree that costs more.

**Size:** a migration, a rate screen for the provider, and a rebuild of the
booking screen. Two to three days, and the provider-side pricing UX is the hard
half.

---

### L-3. The distance filter measures a straight line and does not say so

> *"in earning zone screen we have distance filter which is not good currently
> as that doesn't measure distance as per roads, streets but that is streight
> line distance between two points, since we now have implemented free map, can
> we improve this feature too?"*

Correct diagnosis. `NearbyJobRepo` computes haversine — great-circle distance —
in SQL. A job 3 km away across a river can be 15 km by road.

**⚠️ The free map does not help.** `flutter_map` renders OpenStreetMap tiles and
does no routing. Road distance needs a routing engine, and the options are worse
than they look:

| | |
|---|---|
| OSRM demo server | Free, but its terms forbid production use and it has no SLA |
| OpenRouteService | Free tier, 2,000 requests/day, needs a key |
| Self-hosted OSRM/Valhalla | Free forever, but preprocessing an India extract needs more RAM than the whole 12 GB box |
| Google Distance Matrix | Accurate, and the cost we moved off Maps to avoid |

**There is also a structural problem.** The distance filter is a `WHERE` clause
over every open job. Routing cannot run in SQL, so it would mean: filter by
straight line, route the survivors, re-filter and re-sort — N HTTP calls per
browse, on a screen an earner opens repeatedly.

**Recommendation, in order:**

1. **Say what the number is.** The cheapest correct fix is to stop implying road
   distance — "2 km away (direct)" or a short note on the filter. The number is
   not wrong; the label is. **Do this now; it is an afternoon.**
2. **Road distance on the job detail screen, not the list.** One route lookup
   for the one job somebody is considering, cached against the task. That is
   within OpenRouteService's free tier at any volume this product will see for
   a year, and it fails gracefully — no route, show the direct distance.
3. **Never put routing in the list query.** If road distance ever has to drive
   the *filter*, the answer is a precomputed distance matrix over a small set of
   village centroids, not per-request routing.

⚠️ Straight-line distance is always **less** than road distance, so the current
filter is a superset — it never wrongly hides a job, it only shows some that are
further than they look. That is the right direction for the error to run.

**Size:** (1) an afternoon. (2) two days including the key, the cache and the
failure path.

---

### L-4. ~~"What should they know" should be profession-specific~~ ✅ done 2026-08-27

> *"While posting a job, step 3 u made what should they know that is really
> really good thing u added, just need to make it profession/subprofession
> specific to make it perfect."*

Agreed, and it is a small change with a good return.

The eight note chips — `BRING_TOOLS`, `TOOLS_HERE`, `HEAVY_LIFTING`,
`UPSTAIRS`, `OUTDOOR`, `DOG`, `FOOD_PROVIDED`, `RING_BELL` — are a **hardcoded
list in `new_task_page.dart`**, shown identically to everyone. "Bring your own
tools" is meaningless to a makeup artist; "is there a dog" matters enormously to
a maid and not at all to a tractor operator.

**The shape of the fix.** A `note_option` table mapping a code to a profession
(and optionally a sub-profession), plus a set with no profession that everybody
gets. `ProfessionRuleDto` returns the codes that apply; the app keeps its
existing ARB labels and just renders whichever codes it is given.

⚠️ **Codes, not text, over the wire.** The server sending labels would mean the
server owning translations, and §F-5's whole approach is code-plus-label so that
Hindi is a client concern. A new code needs an ARB entry — which is the cost of
adding one, and it is the right cost.

**Size:** a migration, one DTO field, and deleting a hardcoded list. A day,
mostly spent deciding which notes belong to which profession — again the part
that needs a person.

**Built 2026-08-27** — V21 `profession_note_option`, deployed and verified live.
A Maid is now offered `FOOD_PROVIDED, UPSTAIRS, OUTDOOR, DOG, RING_BELL`; a
Mistri/Mason gets the tool chips and heavy lifting and no longer gets food; a
Farm Laborer gets both sets.

Three decisions worth keeping:

- **A null `PROFESSION_ID` means everybody.** The ordinary notes — upstairs,
  outdoor, dog, ring the bell — are four rows, not four rows per profession, so
  adding a profession cannot mean forgetting to give it them.
- **⚠️ Two fallbacks, both deliberate.** An empty list from the server makes the
  app show all eight rather than an empty step, so a server older than this
  still works; and a code the app has no label for is *dropped*, not rendered,
  so a code added on the server never reaches a user as `SOMETHING_NEW`.
- **⚠️ The seeding matches profession names with `LIKE`** — `'%mistri%'`,
  `'%harvest%'`. That is a symptom of [O-23](OBSERVATIONS.md): professions have
  no stable code, only a display name, so every piece of data that needs to
  refer to one has to guess. It works today and it breaks the day somebody
  renames a profession.

Sub-professions were left out. The table has room for the join and nothing
asked for it yet — a maid's notes do not change between "cooking" and
"cleaning", and the chips that would differ are the ones L-2's garment menu
covers properly.

---

### L-5. ~~The loading spinner draws as an oval~~ ✅ fixed 2026-08-26

> *"there comes a circular loader for 1-2 seconds or few millisconds that is
> coming as oval rather remove that. Wherever possible and needed we can use
> shimmer UI."*

A `CircularProgressIndicator` has no intrinsic size — it fills the box its
parent gives it. Returned as the only child of a stretching `Column`, or as an
`ElevatedButton`'s child, it is handed a wide short box and draws as an ellipse.

It was happening on the four post-a-job steps **and on all three OTP buttons**,
which is the first thing anybody sees. The buttons now use a sized 18×18
spinner, matching what `AppButton` already did correctly — those three auth
screens hand-roll their button and did not. The form steps use a shimmer
skeleton instead, which also stops the screen jumping when content arrives.

---

### L-6. ~~The country dropdown has one hardcoded option~~ ✅ fixed 2026-08-26

> *"country list should come from db but only enabled countries should show up
> in drop down check this and enable india only for now."*

Done exactly that. V19 adds `IS_ENABLED` and `DIAL_CODE` to `location_country`,
India is the only country enabled, and `GET /common/countries` returns the
enabled rows.

⚠️ Public endpoint, because the picker is on the login screen and has to work
before there is a session. ⚠️ `IS_ENABLED` defaults false and `addCountry`
cannot set it — a row existing is not a decision to serve that country.

While there is one country the control is **disabled** rather than offering a
menu with a single item, which is what [O-22](OBSERVATIONS.md) was about.

---

### L-7. ~~A strip appears between the header and the content on scroll~~ ✅ fixed 2026-08-26

> *"When we click reserve or schedule tile, a ui opens where all professions
> tiles are listed, there is some small strip showing on scroll between header
> and main content."*

Reproduced on Post New Task, and it was `scrolledUnderElevation`. Material 3
tints an AppBar's surface the moment anything scrolls beneath it, and against
this scaffold background that lands as a grey band with a hard edge between the
title and the content.

⚠️ **Not a bug in that screen** — every screen with a scrolling body had it.
Fixed on the theme's `AppBarTheme` so it is fixed once: zero elevation, and
`surfaceTintColor: transparent` as well, because on some versions the tint is
applied independently of the elevation value.

The same screenshot showed something else, now [O-24](OBSERVATIONS.md):
"Construction Laborer" breaks **mid-word** into "Constructio / n Laborer".

---

### L-8. Slots may be the wrong shape for farm and construction work

> *"Step 2 of post new job asks for slot, i hope that is relvant for farming and
> constrruction labour (Majdoors), is there something better we can do, but
> doesn't mean we necessarily need to change something."*

The instinct is right and the answer is **probably not yet**.

Slots — morning, afternoon, evening — fit domestic work, which is what the model
was built around: a maid comes at a time, and the household plans around it.
Farm and construction labour does not work that way. A majdoor's day is
**dawn to dusk, or half a day**, and the thing being agreed is a day's work at a
day's rate, not a window.

`profession.allowedSlots` and `multiSelectSlots` already exist per profession,
so the machinery to offer a different set is there. What would fit better:

- **`FULL_DAY` and `HALF_DAY` as the slot set** for agricultural and
  construction professions, which is how the wage is actually quoted.
- ⚠️ **Not a start time.** "Reach by 6am" is a real instruction but it belongs
  in the notes ([L-4](#l-4-what-should-they-know-should-be-profession-specific)),
  not in a picker that implies the day ends when the slot does.

**But it is not urgent**, and here is why: nobody has posted a farm job on this
product yet. Changing the slot vocabulary before a single real majdoor job has
been posted is designing against an imagined user. The right moment is the first
time somebody actually tries to hire farm labour and the form fights them —
that conversation will say more than this paragraph can.

**Recommendation: leave it, and watch the first real farm posting.**

---

### L-9. ~~Dummy data for testing on a real phone~~ ✅ done 2026-08-26

> *"Since m testing on phone can u plz add some dummy data for all screens?"*

Every screen is empty on the live server, so most of the app cannot be judged.
`deploy/demo-data.sql` seeds a plausible set around Bijnor and
`deploy/demo-data-teardown.sql` removes it.

⚠️ **This writes to the production database.** Every row is tagged so it can be
found and removed, and the teardown is written before the seed is run. Names are
obviously fictional. It is safe today because the only accounts are ours; it
must be torn down before anybody real signs up.

---

## M. The second UI feedback round (2026-08-26)

Five more from the product owner and friends, offered as suggestions rather than
instructions — *"if u think something shouldn't be done then skip that"*. So one
below is marked as needing no work, and two are recommended in a narrower form
than asked, with the reasoning.

---

### M-1. ~~The Dashboard should follow the mode the user chose~~ ✅ done 2026-08-27

> *"When i use gasta just as earner, only work i do should show in dashboard and
> vice versa for organiser only view."*

**Agreed, with one refinement that matters.**

The Dashboard always renders both halves — "Work I have posted" and "Work I do"
— whichever mode the user picked at first launch. An earner therefore reads a
green card saying "Jobs posted 0 / Open 0 / Given 0 / Done 0" before reaching
anything about them. `AppModeService` already stores the answer, and nothing on
this screen consults it.

**⚠️ The refinement: hide the irrelevant half only when it is empty.**

Mode is a *presentation preference*, not a permission — an earner can still post
a job, and the mode picker says "You can change this any time". So a rule of
"earner mode hides posted work" would hide **real data** from somebody who
posted something and then forgot which mode they were in. That is a worse
failure than the noise it fixes, and it would be invisible: nothing on screen
would say a section had been withheld.

The rule that gets the benefit without the risk:

> Hide a section when the mode says it is not wanted **and** it has no rows.
> Show it whenever it has anything in it, whatever the mode.

In practice an earner-only user has nothing posted, so they see exactly what was
asked for — and the day they post something, it appears.

**How:** `AppModeService.current()` in the dashboard's build, and the counts are
already in the payload (`totalPosted`, `tasksAccepted`), so "is it empty" needs
no extra call.

**Size:** half a day, including both modes and the both-modes case.

---

### M-2. ~~Hide Earning Zone for organisers~~ ✅ done 2026-08-27 (Home deliberately kept)

> *"Home tab can be hidden for earner and eanring zone tab can be hiddden for
> organiser only view."*

**Agreed for Earning Zone. Recommended against for Home — see below.**

**Earning Zone (the Work tab) for an organiser-only user:** hide it. It is a job
board for people looking for work; somebody who only hires has no use for it,
and it is the tab that currently sits second from the left where they will hit
it by accident.

**Home for an earner: ⚠️ this one should not be hidden, and here is why.**

Home is not a "hiring" screen. It is the app's **entry point** — the wordmark,
search, the profession catalog, Doorstep Services, and the notification bell.
Removing it from an earner:

- takes away **search**, which is the only way to find anything by name;
- takes away **Doorstep Services**, which an earner is as likely to *use* as
  anybody — a laundry worker still needs a cylinder delivered;
- leaves the app opening on a job list with no home to return to, which for an
  audience navigating by position rather than by reading is a real loss.

⚠️ And a five-tab bar becoming four **moves every remaining tab**. DESIGN-RULES
§1 is about controls staying where the user learned them; a bar that reshapes
itself when a preference changes is the opposite of that.

**What to do instead:** for an earner, make Work the tab the app *opens on*, and
leave Home in place. That answers the real complaint — "I keep landing on a
screen that is not mine" — without removing a route. `BottomNavigation` already
takes an initial index.

**Size:** the Earning Zone hide is an hour. The default-tab change is an hour.

---

### M-3. ~~Earners should not see other earners' quotations~~ ✅ already true

> *"Earners should not be able to view quotations done by other earners."*

**Checked, and it does not happen.** No work needed.

Two endpoints could have leaked it and neither does:

- `GET /earner/get-task-quotation/{taskId}` reads
  `findByTask_IdAndEarner_Id(taskId, currentUser)` — scoped to the caller, so an
  earner sees only their own quotes on a task.
- `GET /organiser/get-quotes-for-task/{taskId}` calls `ownedTask(taskId, user)`
  first. Verified live: a demo earner calling it on somebody else's job gets
  **400 "Not authorized to access this task."**

⚠️ Worth keeping in mind for anything added here later. The nearby-jobs
projection carries `openQuoteLimit` and `workersTaken` — *how many* and *how
full*, never *what anybody offered*. That line is the right one and new fields
should stay on this side of it.

---

### M-4. ~~Task Details and Dashboard need a redesign~~ ✅ done 2026-08-27

> *"Me and my friends did not like Task details UI and Dashboard UI. Though the
> instagram story like feature (swipe or tap) to view next is cool think if
> redesign can be done without removing that feature."*

**Agreed, and the story paging should stay** — it is the right interaction for
this audience: one thing at a time, advanced by tapping anywhere, no scrolling
to discover that there was more. It is also the thing that makes a dense screen
survivable on a small phone.

**Done.** I asked which of three things was wrong instead of redesigning, and
the answer was "layout, design, colour combination etc etc" — i.e. all of it.
That was the right answer to a question I should not have asked.

**The diagnosis, once looked at properly:** these were the only two screens in
the app that did not follow its own design system. Everywhere else is a **white
card on the #F4F6F6 ground with dark text** — profession tiles, job cards,
profile rows, quote cards. Task Details was a navy-to-white gradient with a
translucent grey card and a pink heading; the Dashboard was saturated gradient
blocks with white text. That is *why* both read as a different app, and it is
the same failure as the wordmark font on three screens earlier.

Both now use `AppText`, `AppSpacing`, `AppRadii` and `AppSemanticColors` like
everything else. Colour survives as an **accent** — a 5px rail and a tinted
icon — not as a fill.

**What changed, and the faults each fix addresses:**

**Task Details**
- **"Must Offer:" has nothing after it.** A label with no value reads as a
  loading failure.
- **"Organiser Rating: 0.0"** on a new user. Zero is a *bad* rating, not an
  absent one; "No ratings yet" is the true thing.
- **The card behind the quote sheet is greyed almost to illegibility.** The
  details a person needs in order to name a price are the ones dimmed while
  they name it.
- **The sheet covers most of the card**, so deciding requires dismissing it.
- Profession and description disagreed — that was the demo data, since fixed,
  not the screen.

**Dashboard**
- **White-on-mid-green counts** inside green cards. "Jobs posted 7" is the
  largest number on the screen and the lowest contrast on it.
- **One card per screenful.** Two gradient blocks and a red one consume the
  whole viewport; the "Work I do" heading is cut off at the fold.
- **Colour carries meaning that is never explained** — green for posted, red for
  taken. A red block reads as an error before it reads as a category.
- ⚠️ The red/green pairing is the single worst choice for a **red-green
  colour-blind** user, who is roughly one man in twelve. DESIGN-RULES §5 already
  says colour must not be the only carrier.

**And one thing added rather than fixed: story progress bars.** Tap-to-advance
was the interaction they liked, and its weakness was that nothing said it was
there or how far through the deck you were. Instagram solves that with segment
bars at the top, so Task Details has them — borrowing the part that makes the
interaction legible without changing the interaction. Above twelve tasks the
bars are thinner than the gaps and stop meaning anything, so it falls back to
"3 / 40".

⚠️ **Three layout attempts before the card was right**, all found by looking at
it on a device rather than by reasoning:

1. `Row(crossAxisAlignment: stretch)` for the accent rail — inside a scroll view
   the Row's height is unbounded, so the rail got infinite constraints and the
   cards laid out on top of one another.
2. `IntrinsicHeight` around it — cannot measure the `GridView` of chips, so it
   under-reported the height and the next-action row spilled out below the
   card's own background.
3. A `Stack` with a `Positioned(top, bottom)` rail — sizes to the content, no
   intrinsic pass, nothing to get wrong. (A left border on the decoration would
   be simpler still, but Flutter refuses a borderRadius with a non-uniform
   border.)

**Size:** done.

---

### M-5. ~~Tapping a notification should open the thing it is about~~ ✅ done 2026-08-27

> *"Tapping on a notification tile in notification just marks that as read but
> it should take me to respective screen i think?"*

**Agreed, and the data to do it already exists.**

`Notification` carries `notificationType` and `referenceId` — written at every
call site, and `referenceId` is the task, quote or notice id. The push payload
carries the same thing as `deepLinkId`. Nothing reads either: the list marks the
row read and stops.

⚠️ **This is why push currently opens the notifications list rather than the
job** — `PushService._open` has the id and no route table to use it with. The
two are the same missing piece, and fixing it fixes both.

**How:** one mapping from `NotificationType` to a destination, used by the list
*and* by the push handler. Roughly:

| Type | Destination |
|---|---|
| Quote received / accepted / rejected | the task's detail screen |
| Work started / done / missed | the task's visit screen |
| Handover notice given / withdrawn | the notice sheet for that engagement |
| Added to a household | the household screen |
| Anything unrecognised | the notifications list, as now |

⚠️ **The fallback is the important half.** A notification type added later, or
one whose target has since been deleted, must land somewhere rather than
crashing or opening an empty screen. Unrecognised goes to the list — which is
where it goes today, so nothing regresses.

⚠️ The tap must still mark it read. Navigating away without doing so leaves a
badge counting messages the user has read.

**Size:** a day, most of it deciding the table and checking each destination
takes the id it is given.

---

## Where to start

The order below is by what a real user loses, not by effort.

1. **[M-5](#m-5-tapping-a-notification-should-open-the-thing-it-is-about) —
   notifications that go somewhere.** Every notification in the product is
   currently a dead end, and the same missing piece is why a push opens a list
   instead of the job. One mapping fixes both.
2. **[M-1](#m-1-the-dashboard-should-follow-the-mode-the-user-chose) — the
   Dashboard follows the chosen mode.** Half a day, and it is the first screen
   an earner reads.
3. **[M-2](#m-2-hide-home-for-earners-and-earning-zone-for-organisers) — hide
   Earning Zone for organisers, open earners on Work.** An hour each.
4. **[M-4](#m-4-task-details-and-dashboard-need-a-redesign-keeping-the-story-style-paging)
   contrast and empty labels** — an afternoon, and worth doing whatever the
   redesign turns out to be.
5. **[L-1](#l-1-how-many-people-do-you-need-is-asked-of-everyone-and-promises-work-that-may-not-exist)
   part two — tell an assigned earner the job is still short.** Browse-time
   honesty already exists; this is the half that is missing.

Everything above this line is agreed. Below it is a decision waiting on
somebody.

---

## Decisions taken, 2026-08-26

Recorded so they are not re-litigated:

- **The Gmail/Outlook restriction stays.** It is deliberate: those are what
  ordinary people use, and the long tail of other providers is where the
  scam signups come from. Not a defect — a policy. Worth revisiting only if real
  users start being turned away, and the message could be softened to say it is
  a policy rather than reading as "your address is invalid".
- **`ddl-auto=validate` in development too.** Done. Entities must match the
  schema; write the migration first.
- **DuckDNS for now.** A real domain when a store submission is close.
- **Crash reporting on our own service**, not Sentry or GlitchTip. Done — an
  endpoint, a table, and rate limits. See §B-3.
- **Delete means soft delete**, everywhere it can. Done for addresses.
- **No account switching.** One signed-in user per phone. Simpler for push —
  one token, one owner — and cleaner if a dispute ever needs to establish who
  was using a handset. `account_switch_service.dart` is gone.
- **No certificate pinning** (§E-1), decided by me on request. The certificate
  rotates every 60 days, a kill switch would travel over the connection pinning
  just broke, and it defends the one channel that is already best defended.
  Revisit if the app ever carries payments or identity documents.
- **Secure token storage: yes.** Done — Android Keystore / iOS Keychain, with a
  migration so nobody signed in gets logged out.
- **Maps: OpenStreetMap, not Google.** Free, no API key, no billing account. The
  map is back on the address screen.
- **Light theme only for now.** Dark mode was hiding data, not merely looking
  wrong. §H has what real support needs.

## Still open for the product owner

1. **SMS provider for the OTP** ([A-0](#a-0--an-sms-provider-so-the-otp-can-stop-being-000000--see-o-18))
   — which one, and who starts the DLT registration? Agreed to be taken up the
   week of 2026-08-31. The paperwork is the long pole, not the code.
2. **Watching a push actually arrive.** FCM registration is proven end to end
   and the poll fallback is proven to fire; what nobody has seen is a
   notification travelling between two people. Every notification in the
   product needs two parties and only one test account exists — worth ten
   minutes together on two handsets.
3. **What exactly is wrong with Task Details and the Dashboard**
   ([M-4](#m-4-task-details-and-dashboard-need-a-redesign-keeping-the-story-style-paging)).
   Three questions decide the redesign, and they have different answers: is it
   *too much on one screen*, *the colours*, or *not knowing what to tap*?
   Drawing before that is answered means drawing twice.
4. **Which professions should ask "how many people?"**
   ([L-1](#l-1-how-many-people-do-you-need-is-asked-of-everyone-and-promises-work-that-may-not-exist)).
   The code is a flag and an `if`; the list is a judgement about the market.
5. **Is 25 km the right ceiling?** ([O-26](OBSERVATIONS.md)) A reasonable daily
   commute for domestic work, and probably wrong for a harvest crew that
   travels for a season.
