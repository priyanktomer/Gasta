# PLAN-5 — Gasta

**This file is the entry point for the next session.** PLAN-4 was the previous
one; everything it listed as outstanding is either done or restated here.

Read in this order:

| File | What it is |
|---|---|
| **PLAN-5.md** (this) | What to do next, and why |
| **PLAN-4.md** | The product thesis (§2), the architecture (§3), the rules learned the hard way (§4). **Still current — read §1–§4 before touching anything.** |
| **PLAN-3.md** | The detailed history: every item's reasoning, every defect found. §20–§27 cover the most recent session. |
| **DESIGN-RULES.md** | Binding UI rules |

---

## 0. The things that will save you an hour each

Repeated from PLAN-4 §1 because they keep being right:

1. **Verify in the emulator, always.** Compiling is not evidence. In the last
   session alone: a repository method that compiled and stopped the app from
   starting, a `COALESCE` that returned a 500 for an entire list, a column name
   that only exists in native SQL, and a field added in three places and
   forgotten in the fourth. None of these are visible from a build log.
2. **There is no "pre-existing" or "unrelated" bug.** Standing instruction from
   the product owner.
3. **Don't stop between phases.** Work through.
4. **A comment that disagrees with its code is worse than no comment.** This has
   now happened five times here, twice by me.
5. **`mvnw -q compile` has reported clean on a build that failed.** Don't use
   `-q` to detect errors.

Two more earned since:

6. **A guard that has never fired is not known to work.** The `Slot` label check
   was verified by deliberately breaking a label and watching it throw. Do that.
7. **Adding a field means finding every place that builds the object.** Not every
   screen uses `fromJson` — the Earning Zone builds `Task` field by field, which
   is why a new flag reached the DTO, the wire and the model and still arrived as
   `false`.

### How to run it

```bash
cd JeevikaService && JAVA_HOME="C:/Program Files/Java/jdk-17" ./mvnw -o spring-boot:run
```

```bash
cd Yapan && flutter run -d emulator-5554 --debug
```

MySQL and Redis (docker) are started by the product owner. Health:
`GET /api/v1/yapan/common/health` returns `{"status":"UP","db":"UP","redis":"UP"}`.

Every response carries `X-Request-Id` and every log line carries the same value.
Grepping the log for the id in a failing response is how two of the last
session's bugs were found in minutes.

---

## 1. State of play

| Phase | State |
|---|---|
| 0–4B | ✅ Complete |
| 5 — Substitution, flexibility, identity | ◐ T5.7 identity recovery **deferred by the product owner** (§3.1) |
| 6 — Correctness, authz, perf, caching | ✅ Complete |
| 7 — Trust & reputation | ◐ T7.1 / T7.5 / T7.6 built but **still unreachable** (§3.2) |
| 8 — Demand & liquidity | ✅ Complete |
| 9 — Accessibility & language | ◐ T9.5 / T9.6 outstanding; **Hindi is 57% translated** (§2.6) |
| 10 — Ops & support | ✅ Complete |
| 11 — Scale & hardening | ◐ T11.8 file storage, T11.11 polish remainder |
| §E — Doorstep | ✅ Complete |
| §F — Design system | ✅ Adopted across all screens |
| §G — Success gaps | ◐ §7.6 blocked, §7.8 handover half outstanding |

**Nothing is half-built.** Every item touched last session was either finished
and verified in the emulator, or deliberately not started with the reason
written down.

---

## 2. Operational readiness — do this first

The product owner's instruction: **operational things first**, and **no paid
services** at this stage. Everything below respects that, and says plainly where
it cannot.

### 2.1 OTP is not real yet ⚠️ **hard launch blocker**

Deferred deliberately, and it is the single thing standing between this and a
real user. The path exists end to end — generation, bcrypt hashing into Redis,
rate limiting (T11.6), verification — but **nothing sends an SMS**. Login works
in development because the code is predictable.

**This is the first place "no paid services" has to bend**, and it bends cheaply:
transactional SMS in India is roughly ₹0.12–0.25 a message, so a thousand logins
is under ₹250. Worth pricing: MSG91, Fast2SMS, or whatever the eventual host
resells. Twilio is the expensive option.

**Start the paperwork before the code.** Indian carriers require sender-ID and
template registration through TRAI's DLT portal, and it takes days to weeks. That
is the long pole, not the integration.

Keep the existing abuse guards — `gasta.otp.max-per-phone-per-hour` and
`max-per-caller-per-hour` were built for exactly this moment.

### 2.2 Push notifications without Firebase

The product owner asked whether there is an alternative. The honest answer is not
the obvious one.

**FCM is free.** There is no paid tier for anything Gasta needs, so "no paid
services" does not rule it out. If the objection is a Google dependency rather
than money, the alternatives are real, but each costs something other than money:

| Option | What it actually costs |
|---|---|
| **FCM** | A Google dependency. Free. Survives Doze and OEM battery killers — which is the entire problem. |
| **ntfy** (self-hosted) | A server, but the backend already needs one, so marginal cost is near zero. Open source, good. The app holds a subscription, so the OEM-killer problem comes back. |
| **Gotify** | As ntfy, smaller ecosystem. |
| **UnifiedPush** | The right idea; almost nobody in this market has a distributor installed. |
| **Persistent WebSocket** | Free, and **the least reliable option on these phones.** Xiaomi / Oppo / Vivo / Realme kill background sockets aggressively. We watched Android's `lowmemorykiller` reap this very app during testing — same mechanism. |
| **Polling** (WorkManager, 15-min floor) | Free, no service, survives everything. Up to 15 minutes late, and costs battery. |

**Recommendation:** FCM as the transport, **plus** a WorkManager poll as the
fallback for the meaningful share of phones where push never arrives.
`PushSender` is already an interface with a logging implementation and every call
site wired (T11.3), so this is one new class and a config flag.

**What must never depend on push:** anything that costs somebody money or a day's
work. The crew-release decision (§7.11), the advance confirmation (§7.2) and the
visit reminder all currently assume the user opens the app. **Keep it that way.**
Push is an accelerator, not the mechanism.

### 2.3 "Did the money actually change hands?" ⚠️ **the biggest product hole**

**`Task.amountPaid` is declared and never written or read.** A dead column from
an older design.

This matters more than it looks. §7.1 gives both sides a register that says
"22 days worked, comes to ₹16,500" — and then **nothing anywhere records whether
₹16,500 was handed over.** The advances ledger (§7.2) is careful and complete
about money *lent*; the wage itself has no record at all. That asymmetry is the
one a worker notices first, and it undercuts the register that is meant to be the
reason she opens the app.

**What to build, and what not to.** Gasta is not in the payment path and must not
become so. This is a *ledger*, exactly like `CashAdvance`:

- A `WagePayment` row per payment: task, month, amount, date, recorded by.
- **Both sides agree** — the same two-stamp pattern as `CashAdvance`, because the
  whole point is settling an argument six months later.
- Shown on the register beside "comes to ₹16,500": "₹16,500 received on the 3rd",
  or "nothing recorded yet".
- **Partial payments are normal here** and must be expressible.
- **Never auto-deduct against the advance balance.** `CashAdvance`'s own comment
  explains why: automating that decision is the fastest way to make a worker
  distrust the app.

Delete `Task.amountPaid` as part of this, or somebody will find it later and wire
it to something.

### 2.4 Secrets and configuration

T11.5 externalised the datasource to `${GASTA_DB_*}` with local defaults, and
`application-prod.properties` removes those defaults so a missing variable fails
startup by name. Two things remain:

- **The dev password `my$ql` is still a literal default** in
  `application.properties`, so it lives in the repository. Fine for a local dev
  database in a private repo; not fine once anything real exists.
- **`ddl-auto=validate` in the prod profile will fail today**, deliberately. It
  needs every existing table's DDL captured as Flyway migrations first (V1 is an
  empty baseline). That is the gate for a reproducible schema and it is real work.

### 2.5 No crash reporting, no backups

- **Crash reporting: none.** A crash on a user's phone is invisible to us.
  Sentry's free tier covers this; self-hosted GlitchTip is the no-account option.
- **Database backups: none.** A `mysqldump` on a cron is enough to start. The
  data that matters — the work records §7.4 exists to protect — is
  irreplaceable, and this is the cheapest high-value item on this page.
- Observability has request ids, structured logging and a health endpoint
  (T11.4). **Actuator was deliberately not added**: the only cached artifact is
  3.1.2 against a 3.3.3 app and the build runs offline. Swap it in when
  dependencies resolve properly.

### 2.6 Hindi is 57% translated

`app_en.arb` has 183 strings; `app_hi.arb` has 104. **Every screen built in the
last two sessions is English-only** — the register, advances, earnings, work
record, household, crew. For a product whose audience "may read nothing at all",
shipping the *money* screens in English only is not a polish item.

Also outstanding from T9.1: several server-side strings are prose rather than
codes, so they cannot be translated at all (DESIGN-RULES §5).

### 2.7 Play Store readiness

None of this exists, and all of it blocks a listing:

- **Privacy policy and terms** — required, and there is no consent flow anywhere
  in the app.
- **Data Safety declaration** — the app collects location, phone numbers and
  addresses.
- App icon, feature graphic, screenshots, description.
- Target SDK compliance, signing key, versioning.
- **Location permission justification** — Google scrutinises this, and Earning
  Zone needs location to work at all.

---

## 3. On hold, deferred, and skipped

### 3.1 Deferred by the product owner (do not re-litigate)

| Item | Decision | Exposure if left |
|---|---|---|
| **T5.7 identity recovery** | Keep deferred (re-asked 2026-08-17) | **An earner who loses their phone loses everything** — work record, ratings, engagements — with no route back. Ops can rescue one user by hand; it does not scale. The cheap half (phone change verified through the old number) is still worth taking. |
| **T11.7 `access-app` changes** | Leave it | Anything Gasta wants *on a user* goes in a side table. Normal pattern, already used twice. Cost paid slowly in joins. |
| **T11.3 push / T11.12 masked calling** | Stubbed behind interfaces | See §2.2. |
| **D-2 TaskChat** | Stays deferred | T4.9 phone reveal covers the need. **Delete the placeholder class** — a `@Table` with no `@Entity` is a trap for the next reader. |
| **D-3 in-app payments** | Correctly out of scope | Not the same as §2.3, which is a *record*, not a payment. |
| **D-6 multi-tenancy** | Inert by choice | — |
| **Random OTP** | Still deferred | This is §2.1. It is the launch blocker. |

### 3.2 Built and still unreachable ⚠️

**T7.1 / T7.5 / T7.6 are marked ✅ and no screen reaches them.** Four endpoints —
`earner-profile`, `organiser-profile`, `set-earner-connection`, `my-favourites` —
would all be served by **one screen**: a worker's profile page showing her work
record, her ratings, and a favourite/block control.

This is the largest remaining piece of the §6.7 audit and the last of that class.
Everything else it found has been wired, removed, or explicitly triaged
(PLAN-3 §20).

Two endpoints remain recommended for **deletion** rather than wiring:
`get-statements` (the register already shows the month, and month arrows reach
the rest) and `pause-task` (`skip-visits` already pauses by date range; two ways
to pause is how they drift).

### 3.3 Feature work not started

| Item | Size | Note |
|---|---|---|
| **§7.8 handover** | M | "She is leaving on the 30th" — notice, post the replacement with an overlap, outgoing worker shows the incoming one the ropes. The trial-check-in half is done. This is the moment a household is most likely to leave the platform to replace her the old way. |
| **§7.6 voice notes + spoken alerts** | M / L | **Blocked twice:** no TTS plugin is cached and adding one needs network plus a Gradle sync; voice notes additionally need T11.8. The highest-value accessibility feature for this audience — revisit when the toolchain allows. |
| **T9.6 replace typing with choosing** | S–M | The posting wizard still asks for free text where a picker would do. Directly serves the low-literacy goal and needs no new dependency. |
| **T9.5 voice input** | M | Same plugin blocker as §7.6. |
| **T11.8 file/image storage** | M | Blocks voice notes, ID photos, before/after pictures. |
| **T11.11 polish remainder** | S | Three wrong `Slot` labels are fixed and guarded. Still open: the enum has 38 values for ~4 used, and the duplicated ₹ glyph (an icon beside text that already contains the symbol). |

---

## 4. Known issues found and not fixed

Everything found last session was fixed except these, which are recorded rather
than done:

1. **`Task.amountPaid` is dead** — see §2.3.
2. **The `Slot` enum is 38 values for about 4 real ones**, with two naming schemes
   (`A_0600_0730` vs `E_1`) that mean different things. The new label/name guard
   stops them lying; the bloat that made the lie possible remains.
3. **`OrganiserServiceImpl` is ~2,400 lines.** Not a defect, but three of last
   session's bugs lived there and it makes "grep every caller before you edit"
   harder than it should be.
4. **Some services still concatenate `e.getMessage()` into user-facing text.**
   Fixed on the paths verified to reach users (`registerAsProvider`, the search
   and worksheet snackbars). `errorResponse` already takes the technical detail as
   a separate argument, so the remaining fix is mechanical.
5. **The phone-side cache has no eviction.** `CacheService` entries grow without
   bound. T11.10 covers the server; the device has nothing.

---

## 5. Making it easier to use — without turning it into a different app

The product owner's constraint, in their words: *"we don't need to convert abcd to
xyz, we can only make it ABcd or abCd or abcde"*. Every item below is a change to
**one screen's disclosure**, not a re-architecture. No new navigation model, no
renamed concepts, no moved tabs.

### The principle

**Show the least that lets someone decide, and put the rest one tap away — but
never two.** Two failures to avoid, and this app currently has one of each:

- **A single list item filling the screen**, so the list stops being a list.
- **Screens nested so deep** that getting back to something takes four taps.

### 5.1 My Accepted Tasks — one card carries eight actions ⚠️ **worst offender**

Verified on the emulator. A single visit card shows: *call*, *Attendance and
pay*, *On my way*, *Tell someone*, *I feel unsafe*, *Take leave*, *Leave this
job*, *Ask to move this visit*. One card is taller than the screen, so **a worker
with three jobs today cannot see her second job without scrolling past eight
buttons.**

**The change (abcd → ABcd):** collapsed by default — profession, date, slot,
household, address, pay. One primary action inline: **On my way** (or *Attendance
and pay* once the visit is done). Everything else behind a single **More**
that expands *in place*. Keep the card, keep the actions, keep the order; change
only what is visible before the tap.

`I feel unsafe` is the one judgement call: it is the most urgent and least used.
It should stay reachable in one tap from the expanded state, not be buried — but
it does not need to occupy list space on a normal day.

### 5.2 Earning Zone job tiles — the product owner's own example

Today: a tile with a **View** button that pushes a full-screen viewer.

**The change:** tap the tile to expand it in place — description, schedule, and
the primary action (*Take this job* / *Apply / Make Quote*). Keep the full-screen
viewer for swiping between jobs; it is good and people use it. This removes a
navigation level for the common case (glance, decide, act) without removing the
screen for the browsing case.

Collapsed should show what decides it: profession, distance, pay, and the crew
badge when it applies.

### 5.3 Profile is a flat list of twelve

Manage Addresses, My household, My earnings, My working hours, Become a Provider,
Orders for me, What I use Gasta for, Switch account, Get help, Language, Tell a
friend, Someone invited me, Logout.

**The change:** three labelled groups, same items, same order within each —
**Money & work** (earnings, working hours, household), **Doing business**
(provider, orders, addresses), **Account & help** (the rest). One divider and
three small headings; nothing moves screens.

### 5.4 Depth check — this is mostly fine, keep it that way

The deepest real path is Home → Doorstep → service → booking (3 steps) → order.
The register is two taps from anywhere. Nothing needs flattening today. **The rule
to hold:** if a new feature would sit four levels deep, it belongs on the
register, the visit card, or Profile instead — not at the end of a new chain.

### 5.5 Smaller ones, in the same spirit

- **Provider registration** asks for bio, max orders, location and prices on one
  scrolling form. Fine, but the price rows should collapse once filled.
- **The filter sheet** in Earning Zone has a two-pane Category/Profession picker
  where the left pane is 30% of the width. Now legible after the overflow fix,
  but it is the most cramped surface in the app.
- **The notifications list** shows every alert at full height. A read alert could
  be one line.

### 5.6 What *not* to do

- Don't add a tab. Five is right.
- Don't introduce a card/list toggle, a density setting, or a customisable home.
  Every one of those is a question asked of a user who came here to find out what
  time to arrive tomorrow.
- Don't move the money screens. People have learned where they are.

---

## 6. What else it needs to be a complete app

Beyond the operational list in §2:

- **Onboarding.** There is a language picker and a "what do you use Gasta for"
  question, and then the user is on their own. No first-run explanation of the
  register, advances, or how to claim an engagement somebody recorded for them.
- **Help that answers real questions.** "Get help" exists; it needs the eight
  questions support will actually receive.
- **Dispute resolution.** Days can be flagged (§7.1) and advances disputed
  (§7.2), and then nothing happens. Ops has a queue and an audit log — connect
  them.
- **Analytics.** Nothing is measured, so nothing about how the product is
  actually used is knowable. Self-hosted Plausible or Umami if the objection is
  cost.
- **Empty states with a next step.** Several exist; several still say only that
  the list is empty.
- **A way to delete an account and its data.** Required by Play policy, and by
  anyone who asks.

---

## 7. Suggested order

**First — the things that block a real user:**

1. **§2.1 OTP.** Start DLT registration today; it is measured in weeks.
2. **§2.5 backups.** An hour of work against irreversible loss.
3. **§2.3 wage payment ledger.** The largest product hole and squarely in the
   thesis.
4. **§2.6 Hindi for the money screens.** The register and advances in English is
   the wrong way round for this audience.

**Then — the things that make it usable:**

5. **§5.1 the eight-button card.** Highest ratio of relief to risk in the app.
6. **§5.2 job tiles**, **§5.3 Profile grouping**.
7. **§3.2 the one profile screen** that makes four built endpoints reachable.

**Then — the rest:**

8. §2.2 push, §2.7 store readiness, §7.8 handover, T9.6, and the §4 issues.

**Deliberately last:** §7.6 / T9.5 (blocked on the toolchain), T11.8, T5.7
(deferred by the owner).

---

## 8. A note on how the last session went

Twelve items were delivered and verified on the emulator. The pattern worth
carrying forward: **almost every real defect was found by looking at the screen
with real data in it**, not by reading code or trusting a build.

- "Still to come: 67 days, ₹35,100" included 31 days that had already passed.
- Registering any non-laundry doorstep provider had **never been possible** — two
  `NOT NULL` columns the code had stopped honouring.
- An auto-assigned order could be placed and then accepted by nobody.
- Losing signal at launch **logged users out** of an app they then could not log
  back into.
- Three `Slot` labels said times that were four to sixteen hours wrong.

Every one of those compiled cleanly and passed the analyzer. The emulator found
them all.
