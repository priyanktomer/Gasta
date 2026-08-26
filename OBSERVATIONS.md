# Gasta — things noticed in passing

Defects and questions found while doing something else, written down instead of
mentioned once in conversation and lost.

**This is not a plan and nothing here is scheduled.** Each entry is a thing
somebody looked at, thought "that is not right", and did not stop to fix because
it was not what they were doing. Some are two-minute changes. Some are product
decisions that are not a developer's to make.

Companion to [DEFERRED.md](DEFERRED.md), which is different: that file holds
things **deliberately not built yet**, with the reasoning. This file holds
things nobody has decided about at all.

**Format.** Newest first. Each entry says what was seen, why it matters, and how
much work it looks like. When one is fixed, say so and leave it — "we looked at
this and it was fine" is worth as much as the fix.

---

## Open

### O-20. The home IP changed and locked us out of the server

Mid-session on 2026-08-26 `deploy.sh` began timing out. Not the server — the
broadband address had rotated, 49.36.188.40 → 49.36.188.196, and the OCI
security list allows port 22 from one `/32`.

This was a known gotcha and it still cost time, because a connection timeout
looks identical to a dead host. Two things came out of it:

- **`deploy/allow-my-ip.py`** — points the rule at the current address in one
  command. It finds the SSH rule by port rather than by position (rule order is
  not stable, and an index would eventually move the wrong rule), and refuses
  rather than adding one if there is no port-22 rule to move.
- **The OCI command-line tool is not actually installed here.** The README told
  us to run `oci network security-list update`; only `~/.oci/config` and the API
  key exist. The script uses the Python SDK against the same config.

⚠️ What made this recoverable at all: only the *cloud* side restricts SSH by
address. The host's own iptables allows 22 from anywhere. A host-level IP rule
would have locked the machine away with no way back short of the serial console.
Worth remembering before anybody tightens it.

**Should the rule move to a wider range?** A `/24` covering the ISP pool would
stop this recurring, at the cost of allowing the whole pool to reach a port that
is key-only anyway. Left as-is; the script makes it a ten-second fix.

**Size:** done.

---

### O-19. Two startup warnings looked at; one is deliberate, one is real debt

Cleared three of the four warnings the server logs on boot (2026-08-26).

**Fixed:** the MySQL `TINYINT(1)` display-width deprecation (V18 aligns
`device_token` with the `BIT(1)` every other table uses), and both Hibernate
dialect warnings — `spring.jpa.properties.hibernate.dialect` is gone, because
Hibernate 6 picks the dialect from JDBC metadata including the server version,
which is more than a hardcoded name can do when MySQL is upgraded under us.

**`spring.jpa.open-in-view`** is now set explicitly to `true`, which is not the
right long-term answer and says so in a comment. Open-in-view keeps the
EntityManager open through response rendering, so a lazy association still loads
while Jackson serialises — which several endpoints returning raw entities depend
on. Turning it off is correct for a REST service and would surface those as
`LazyInitializationException`. That belongs with PLAN-6 §G's conversion to
projections, with a pass over every endpoint — not as a side effect of silencing
a warning.

**The Spring Security warning is deliberate and staying.** `Global
AuthenticationManager configured with an AuthenticationProvider bean.
UserDetailsService beans will not be used` — `AccessAppAuthenticationProvider`
calls `accessAppUserDetailsService.loadUserByUsername` itself, so the
`UserDetailsService` *is* used, just not by the path Spring is describing.
Restructuring a shared security library to quiet a message about a configuration
that works is a risk with no gain.

**Size:** the open-in-view change is a day of checking endpoints, and it is
PLAN-6 §G's day.

---

### O-18. 🔴 **The OTP is `000000` for every phone number, in production**

Found while trying to sign in on the emulator to test push, and it is the most
serious thing in this file.

`OtpServiceImpl.generateOtp()` (access-app) reads:

```java
if (appName.equals("Yapan")) {
    otp = new DecimalFormat("000000").format(new SecureRandom().nextInt(999999));
} else {
    otp = "000000";
}
```

`appName` is `@Value("${access-app-otp}")`, and `application.properties` line 89
says `access-app-otp=false`. `"false"` is not `"Yapan"`, so **the else branch is
what runs** — everywhere, including the live server. I signed up a working
account on production with the code `000000` and no SMS.

There is a second half to it. `sendOtp` ends:

```java
storeInRedis(mobNo, hashedOtp);
// TODO Send OTP to user
```

**No SMS is sent by anything.** So the two facts fit together: the fixed code is
what makes the app usable at all right now, and it is the only reason anybody
has been able to log in.

**Why it matters:** anyone who knows a Gasta user's phone number can sign in as
them and see their address, their household, their work record and their
earnings. It is not a weakness in the OTP, it is the absence of one. The rate
limit added this week (5 verify attempts per phone per 15 minutes) does nothing
here — the attacker needs one attempt.

**This is a hard launch blocker.** Not "fix before scale" — fix before the app
is on a phone belonging to anybody who is not us.

**Two things, in order:**

1. Wire an SMS provider (MSG91 and Fast2SMS are the usual Indian choices; both
   need DLT template registration, which takes days of paperwork — start it
   early). `sendOtp` has the seam for it already.
2. Set `access-app-otp=Yapan` so the random branch runs. ⚠️ Doing this *first*
   locks everybody out, including us, because nothing delivers the code. The
   order matters.

**Interim, if SMS is not ready and the app needs to stay usable:** keep the
fixed code but make it work only for an explicit allow-list of test numbers, so
one real user's number is never openable with `000000`.

**Size:** the config change is one line. The SMS integration is a day of code
and a week of DLT paperwork.

---

### O-17. The app fails Android's 16 KB page-size check — Play will reject it

Every launch on the Android 16 emulator opens with a system dialog:

> This app isn't 16 KB compatible. APK alignment check failed.
> • lib/x86_64/libapp.so : Uncompressed library not aligned
> • lib/x86_64/libflutter.so : Uncompressed library not aligned
> • lib/x86_64/libdatastore_shared_counter.so : Unknown error

`libflutter.so` is the engine's own — nothing in our code causes this. Flutter
3.27.1 (December 2024) predates 16 KB alignment; Flutter 3.29 and later produce
aligned engines.

**Why it matters:** Google Play requires 16 KB page-size support for apps
targeting Android 15+, and this is a submission-time rejection rather than a
runtime failure. It also greets every user on a new phone with a system warning
dialog before they have seen the app.

**This is the concrete reason [O-11](#o-11-flutter-is-3271-from-december-2024)
has to happen before a store submission**, rather than a general "we are behind"
feeling. The upgrade is the fix; there is no flag that makes 3.27 emit an
aligned engine.

**Size:** the Flutter upgrade in O-11, plus a regression pass.

---

### O-16. The release APK is 60 MB

Measured after adding Firebase: `app-release.apk` is 60.3 MB, a single fat APK
carrying arm64, armv7 and x86_64 native libraries at once.

**Why it matters:** this audience is on metered mobile data and on phones with
little free storage. 60 MB is a download somebody thinks about, and thinking
about it is where installs are lost.

**The fix is nearly free.** An Android App Bundle (`flutter build appbundle`)
lets Play ship each phone only its own ABI — roughly 25 MB delivered instead of
60. Play requires AAB for new apps anyway, so this is on the path regardless.
`--split-per-abi` does the same for APKs distributed by hand.

**Size:** a different build command, and updating `deploy/README.md`.

---

### O-15. Nothing has verified that a push actually arrives

The registration half is proven end to end: the app requests
`POST_NOTIFICATIONS`, gets an FCM token, posts it, and the server logged
`register-device | 200 OK | Success | 9000000001`. The row is in `device_token`.

The **send** half — `FcmPushSender` minting an OAuth token from the mounted
service-account key and posting to FCM — is deployed with its key readable
inside the container, and has never run. Every notification in the product needs
a second party to trigger it (a job offer, a confirmation, a notice), and the
test account is alone on the system.

It is not silent if it fails: a refusal logs `FCM refused a push (<status>)`
with Google's reason, and a dead token is deleted rather than retried.

**How to close it:** the first real notification between two accounts confirms
it. If nothing appears, `sudo docker logs gasta-api-1 | grep -i fcm` says why.

**Size:** none — it needs two accounts doing something, not code.

---

### O-14. A test account sits on the production database

`9000000001` / "PushTest" / `gastapushtest@gmail.com`, created on 2026-08-26 to
verify push registration end to end, because there was no other way to obtain a
signed-in session on the live server.

Harmless, and worth deleting before real users exist so it never becomes a row
somebody wonders about. Deleting it also exercises the account-deletion path,
which is not a bad thing to have run once.

**Size:** one delete, whenever.

---

### O-10. ~~"Set as home address" and "Delete address" did nothing at all~~ ✅ fixed 2026-08-26

Found while translating `address_screen.dart`. Both menu items ran a handler
that called **`GET /get-user-address`** — the *list* endpoint — and then showed
`"Address marked as home."` or `"Address deleted."` regardless of what came
back. One of them still carried a `// Optional: Refresh address list` note, so
the list did not even reload to reveal that nothing had changed.

**There are no such endpoints.** The server's only address routes are
`add-address`, `get-user-address` and `get-user-address/{id}`. Nothing on the
backend can set a home address or delete one.

So the app confirmed, twice, work that nobody did — including a **delete**, the
one action where a false confirmation is worst, because the user stops looking
for the thing they think they removed.

**Fixed.** `PATCH /set-home-address/{id}` and `DELETE /delete-address/{id}`
(V15), and the menu is back against them.

**Delete is soft**, at the product owner's instruction — `IS_ENABLED = false`.
That was the open design question and it is the right answer: addresses are
referenced by tasks, visits and doorstep orders, so a hard delete would be
refused by a foreign key or orphan the history. A worker's evidence that she
went to a particular house for three years must not depend on the household
never having tidied up its address list.

`IS_HOME_ADDRESS` had never been written by anything, so every row held NULL —
and NULL is neither TRUE nor FALSE, meaning a query for "the home address" and a
query for "not the home address" would *both* have found nothing. Both columns
are NOT NULL with a default now.

Verified against production: the row survives a delete with `IS_ENABLED=0`,
moving home clears the previous one, and another account gets a 400.

---

### O-13. ~~`google_maps_flutter` is a dead dependency~~ ✅ fixed 2026-08-26

The only `GoogleMap(` in the app is **commented out**
(`new_address_screen_2.dart`), along with its `onTap` handler. What remains is a
`_mapController` that is always null — correctly guarded, so nothing crashes —
and a dependency that still pulls the Google Maps SDK into every build.

**Why it matters:** the Maps SDK is one of the larger things an Android or iOS
app can carry, and this audience is on cheap phones and metered data. There is
also no Maps API key configured on either platform, so the map could not render
even if uncommented.

**Answered 2026-08-26 — the map is back, on OpenStreetMap.** The product owner
asked for a free alternative rather than paying for the Maps SDK, and
`flutter_map` + OSM tiles needs no API key, no billing account and no per-load
charge. `google_maps_flutter` is gone from the pubspec, `_selectLocation` does
what its note said it should, and the pin drops and reverse-geocodes.

⚠️ OSM's public tile server is a volunteer service with a usage policy — fine
at this scale, and something to move off (a paid tile host, or self-hosting)
before the app has real traffic. Noted in PLAN-6.

---

### O-12. ~~`POST_NOTIFICATIONS` is not declared~~ ✅ fixed 2026-08-26

Android 13+ requires it before an app may show a notification. It is absent from
the manifest, so the moment push or any local notification is added, nothing
will appear on a modern phone and nothing will say why.

**Fixed 2026-08-26**, with the feature rather than ahead of it. Declared in the
manifest, and `PushService.registerWithBackend` asks for it **after sign-in** —
not on first launch, because a prompt before the user knows what the app is for
is how an app gets a permanent no, and a denied notification permission can only
be reversed in system settings.

Verified on the emulator: the prompt appears once after sign-in, and granting it
is followed by `register-device | 200 OK`.

---

### O-11. Flutter is 3.27.1, from December 2024

Everything is pinned to it, including the iOS minimum deployment target of 12.0
— which is why raising that target would break the build rather than modernise
it.

An upgrade wants doing **before** a store submission rather than after: target
SDK requirements, plugin compatibility and the iOS minimum all move together,
and discovering that during a release is the expensive time to discover it.

**Size:** a day, and a full regression pass.

---

### O-1. Sign-up rejects every email except Gmail and Outlook

**Answered 2026-08-26 — deliberate, and staying.** Those are what ordinary
people use; the long tail of other providers is where scam signups come from. So
this is a policy, not a defect.

The rule is **server-side**: `SignUpDto.java:27` carries
`@Pattern(regexp = "^[a-zA-Z0-9._%+-]+@(gmail\.com|outlook\.com)$")`, and the
app only shows the message the server sends back.

**One thing still worth changing:** the message reads like the address is
*invalid* rather than like a rule. "Please use a Gmail or Outlook address —
those are the ones we can verify" costs nothing and stops a legitimate user
thinking they mistyped.

**Why it matters.** The audience is rural and semi-urban India. Plenty of people
have a Yahoo address, a Rediff address, an address their employer or college
gave them, or one their nephew made on whatever was open at the time. This turns
them away at the second screen with a message that reads like their address is
invalid rather than like a policy.

Worth asking what the rule is *for*. If it is to block disposable domains, a
denylist does that without also blocking Rediff. If it is because only those two
providers are trusted to deliver, that reasoning disappears the moment email
stops being used for anything (nothing is sent to it today — OTP is SMS).

**Size:** the check is one condition. The decision is the work.

---

### O-2. ~~An expired session returns 500, not 401~~ ✅ fixed 2026-08-26

Seen in the container logs on first launch with a stale token:

```
refresh-token | 500 INTERNAL_SERVER_ERROR | Could not refresh token.
payload: "Failure, exception occured: Invalid Session"
```

**Why it matters.** Three separate things:

- A session that has expired is the most ordinary thing that can happen to a
  token. It is a **401**. Returning 500 says the server broke.
- Any monitoring added later will treat this as an error rate. Every user who
  leaves the app for a week will generate one.
- `"Failure, exception occured: Invalid Session"` reaches the client. Besides
  the typo, PLAN.md T6.3 was a whole pass to stop internal text escaping into
  responses, and this one survived it.

PLAN.md T6.3 already corrected exactly this shape once — a wrong OTP returned
500 because the access library reports bad credentials that way, and it was
mapped to 401 in `LoginServiceImpl`. This is the same defect one endpoint over.

**Fixed** in `LoginServiceImpl.refreshToken`, the same way and for the same
reason as the wrong-OTP branch a few methods above: access-app *throws* for this
rather than returning a non-200, so it landed in the catch-all. Matched narrowly
on the message — the only signal the library gives — so a genuine fault is still
a 500, and anything unmatched is now logged with its stack trace instead of
disappearing. Deployed.

---

### O-3. ~~`ddl-auto=update` in development is a loaded gun~~ ✅ fixed 2026-08-26

Production is on `validate` and starts clean. Development is still on `update`,
so Hibernate will silently create a column for a new `@Entity` field.

**Why it matters.** This has already gone off once. In PLAN-5 Phase 9 Hibernate
created the columns before Flyway ran, the migration then failed on a duplicate
column, wrote `success=0` into `flyway_schema_history`, and took down **every**
`@SpringBootTest` in the suite. The V14 comment says "write the migration before
the entity, deliberately" — which is the discipline `validate` would enforce for
free.

**The argument against** is real: `update` means adding a field does not stop you
mid-thought. But the migration has to be written before the change can ship
anyway, and `SchemaBuiltByFlywayOnlyTest` only catches it at test time, which is
later than the moment you would rather know.

**Fixed** at the product owner's instruction — *"I always want the Spring Boot
entities to match the actual DB schema."* Development is on `validate` now.

Day to day: **write the migration first, then the entity.** Add a field without
one and the application will not start, naming the column it cannot find — ten
seconds after the change rather than on a deploy weeks later. Both V15 and V16
were written that way.

---

### O-4. ◐ Whole screens were still English — mostly fixed 2026-08-26

PLAN-5 Phase 4 was "Hindi where the money is" and reached the money screens. It
did not reach these, and the gap is most visible exactly where it hurts most —
the **sign-up screen**, which is the second thing a brand-new user ever sees, is
entirely English: *Full Name · Email · Date of birth · OTP · Proceed · Hi,
Welcome to Gasta · Login to your account*.

Others found while working nearby:

| Screen | State |
|---|---|
| `signup_screen.dart` | ✅ done |
| `user_account_screen.dart` | ✅ done — 31 strings |
| `job_sheet_screen.dart` | ✅ done — 33 strings, and the hand-rolled `_plural` replaced with ICU forms |
| `task_visits_screen.dart` | ✅ done — 59 strings |
| `posted_tasks_screen.dart` | ✅ done |
| `grievance_screen.dart` | ✅ done |
| login screen | ✅ done — and three copies of the legal-document labels became one shared lookup |
| **everything else** | **not audited.** These were the screens noticed in passing; nobody has walked the whole app counting. |

The ARB files went from 467 keys to **720**, English and Hindi in exact parity.

**Why it matters.** A half-translated app is arguably worse than an English one:
it looks like it speaks Hindi, so somebody commits to it, and then the screen
where they have to type their name does not.

**What is left** is an audit rather than a task: no one has walked every screen
with fresh eyes to see what was missed. That is a job for somebody using the app
in Hindi and writing down what jumps out — which is exactly what the next round
of feedback will be.

**The recurring trap**, worth restating because it caught two screens: text that
is *composed* cannot be translated. The posting wizard compared against the
English words on screen to decide which fields to draw; the visits screen glued
`"$when"` and `", $slot"` onto a sentence with adjacent-string concatenation.
Both had to be restructured before a single word could be replaced.

---

### O-5. Profession names reach the app as English prose

`Maid`, `Chef/Cook`, `Agricultural Machinery`, `Sweep-Mop` — the `profession`
table has `NAME` and no code, so there is nothing for the app to translate
against. This is **PLAN-5 Phase 14 item 11**, half of which is now done (`Slot`
labels), and it is listed here because it is the most visible remaining English
on otherwise-Hindi screens: the home grid, the wizard's first step, and the work
record card.

**Not purely mechanical.** For several the Hindi *is* the common word (मिस्त्री),
and for others the English is what people actually say. Inventing fifty
translations without somebody who knows local usage would produce a worse
result than leaving them.

**Size:** a migration and a map, plus a content decision.

---

### O-6. The DuckDNS token was pasted into a chat log

`efea25dc-…` was shared in conversation on 2026-08-26 to configure the deploy.
It is in `deploy/.env` (gitignored) and works, but a DuckDNS token can repoint
the domain at anybody's server, and it now exists somewhere other than the
places secrets are supposed to live.

**Size:** one click. Regenerate it at duckdns.org and update `deploy/.env` on the
server. Worth doing before the domain points at anything real.

---

### O-7. ~~The clock picker reads "PM 11:25"~~ — looked at, and it is not a bug

`digitalClockPicker` renders `selectedTime.format(context)`, which asks
`MaterialLocalizations` for the pattern. **Hindi genuinely puts the meridiem
first** — so the order is the locale doing its job, not the widget getting it
backwards, and forcing English ordering onto a Hindi screen would be the actual
defect.

What is worth a second look is that the marker rendered as the English "PM"
rather than अपराह्न. That is a localisation-data question, not a layout one.
Left here because "we looked at this and it was fine" is worth writing down.

---

### O-8. `HealthController` explains itself with a reason that may have expired

Its comment says Actuator was not used because "the cached artifact on this
machine is 3.1.2 against a 3.3.3 application, and the build runs offline". That
was true when written. If the dependency resolves now, Actuator would give
readiness/liveness probes properly — which matters more once this is a container
that an orchestrator restarts.

Not urgent: the hand-written endpoint does a real database round trip and is the
one the container healthcheck uses, so it is doing its job. But the comment is a
`TODO` wearing an explanation, and somebody should check whether the reason
still holds.

**Size:** check the dependency; then either delete the paragraph or keep it.

---

### O-9. A stale build artifact sits in `target/`

`gasta-api-0.1.0-SNAPSHOT.jar`, dated 2026-07-19, beside the current
`Yapan-0.0.1-SNAPSHOT.jar`. Harmless — `Dockerfile` names the jar explicitly —
but a `target/` with two fat jars in it is a directory where somebody eventually
ships the wrong one.

**Size:** `mvn clean` once.
