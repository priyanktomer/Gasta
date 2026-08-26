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
| Tests | 77 backend, 27 app, all green |
| App | Signed release build installs on a physical phone |
| Hindi | 780 ARB keys, English and Hindi in exact parity |
| Fonts | Platform face for text, decorative one for the wordmark only |
| Dark mode | **Off.** It was hiding data; light-only until the tokens adapt (§H) |
| iOS | Configuration audited, never built or run — nobody has a Mac (§I) |
| Push | Not built |
| Store listing | Not started |
| Crash reporting | An endpoint on our own service, rate-limited, 90-day retention |

### What PLAN-5 has left open

- **Phase 0** — a lawyer for the legal text, and pointing `GASTA_BACKUP_DIR` at
  somewhere other than the server. *Backups are now off-host to Object Storage,
  so the second half is arguably done; the lawyer is not.*
- **Phase 7** — one illustration, crew all-or-nothing.
- **Phase 10** — push. Blocked on a Firebase project.
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

### A-3. Firebase, for push

Phase 10's FCM half needs a project and a `google-services.json`. Free.

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

### B-2. The Hindi audit nobody has done

Seven screens were translated because somebody happened to be working on them.
**No one has walked the whole app in Hindi with fresh eyes.** That is the single
highest-value thing the next round of feedback can produce, and it needs a
person using the app, not a grep.

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

Still to do: **something has to look at the table.** A weekly `SELECT summary,
COUNT(*) ... GROUP BY summary` is the whole of what is missing, and without it
this is a table nobody reads.

### B-4. No monitoring

`docker compose logs` is the whole story. The health endpoint exists and is
honest — it does a real round trip to MySQL — but nothing watches it. A cron
that curls it and shouts would be a start and is nearly free.

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

1. **Certificate pinning.** *This* is the real answer to the underlying worry.
   It defends against the one MITM that TLS alone does not: a device with a
   rogue CA installed, which is how corporate proxies and analysis tools work.
   Pin to the CA rather than the leaf so a certificate renewal does not brick
   every installed app. ⚠️ Pinning has bricked more apps than it has protected;
   it needs a backup pin and a remote kill switch before it is safe to ship.
2. **Shorter token lifetimes and real refresh-token rotation.** Reduces what a
   captured token is worth, which is the actual damage in most realistic
   attacks.
3. **Certificate transparency monitoring** — cheap, and tells you if somebody
   ever issues a certificate for the domain.
4. **HSTS**, already set in the Caddyfile.

### The one place encryption *would* help

Not the transport — **at rest**. The phone stores tokens in SharedPreferences,
which is readable on a rooted device. `flutter_secure_storage` puts them in the
Android Keystore instead. That is a real improvement against a stolen or rooted
phone, and it is a different threat from MITM. Worth doing; small.

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

### What the code needs

`PushSender` and `LoggingPushSender` already exist and **every call site is
already wired** (T11.3), so the server side is one implementation swapped in
behind a config flag — the smallest part of this.

The app needs: `firebase_core` + `firebase_messaging`, token registration on
login and on refresh, a foreground handler, a background handler (a top-level
function — a common mistake is making it a method and getting silence), and
permission request. ⚠️ **On iOS notification permission must be requested
explicitly**; on Android 13+ so must `POST_NOTIFICATIONS`, which is **not
currently in the manifest**.

### The half that needs none of this

**The WorkManager poll fallback.** On Xiaomi, Oppo, Vivo and Realme a real share
of pushes never arrive — aggressive battery management kills background
services, and this audience is largely on exactly those handsets. The poll needs
no Firebase project, no Apple membership, and no APNs key, and it is arguably the
more important half for Gasta.

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

## Still open for the product owner

1. **Phase 10** — build the WorkManager poll half now without FCM, or keep both
   halves together? (See §F; the poll matters more for this audience than FCM
   does.)
2. **Certificate pinning** (§E) — worth it, but it has bricked more apps than it
   has protected. Only with a backup pin and a kill switch. Now or later?
3. **Secure token storage** (§E, last section) — tokens sit in SharedPreferences,
   readable on a rooted device. Small change, real improvement. Now or later?
