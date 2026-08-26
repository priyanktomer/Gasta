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

### O-13. `google_maps_flutter` is a dead dependency

The only `GoogleMap(` in the app is **commented out**
(`new_address_screen_2.dart`), along with its `onTap` handler. What remains is a
`_mapController` that is always null — correctly guarded, so nothing crashes —
and a dependency that still pulls the Google Maps SDK into every build.

**Why it matters:** the Maps SDK is one of the larger things an Android or iOS
app can carry, and this audience is on cheap phones and metered data. There is
also no Maps API key configured on either platform, so the map could not render
even if uncommented.

**Not removed**, because the code around it reads like the map is meant to come
back — there is a careful note about what `_selectLocation` should do when it
does. That is a product call: is the map returning, or is the address form
staying typed?

**Size:** one line of pubspec either way. The decision is the work.

---

### O-12. `POST_NOTIFICATIONS` is not declared

Android 13+ requires it before an app may show a notification. It is absent from
the manifest, so the moment push or any local notification is added, nothing
will appear on a modern phone and nothing will say why.

Not added yet: declaring a permission before anything requests it is how you get
a permission prompt for a feature that does not exist. It goes in with Phase 10.

**Size:** one line, at the right moment.

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
