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

## 5. Making it easier to use

The product owner's constraint, in their words: *"we don't need to convert abcd to
xyz, we can only make it ABcd or abCd or abcde"* — and, on a second pass,
*"I'm allowing few changes, it is not like we can't do things"*, with the real
test being that **something important or something which is currently really good
shouldn't be compromised**.

So: this is not a list of tiny edits. §5.6 proposes swapping a tab, which is the
largest change in it. The bar every item has to clear is not "is it small" but
**"does it cost anything that currently works"** — and each one below says what it
protects.

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

### 5.6 The tab bar is worth reopening

Five tabs: **Home · Work · Dashboard · Alerts · Profile**. Five is the right
number and the bar should stay — but one of those five is probably the wrong
occupant.

**The case against Alerts having a tab.** It is a list of machine-written
messages. It earns a permanent quarter-inch of every screen because it is
noisy, not because it is important — and a bell with a badge **already exists**
in the Dashboard app bar, so the tab is partly redundant today. Urban Company,
Yes Madam and every comparable app put notifications behind a bell.

**What deserves the slot instead: Today.** The thing a user opens this app to
find out is *"what do I have today, and what do I do about it"*. Right now that
is Dashboard → "2 jobs today" → My Accepted Tasks: **three taps to the single
most-used screen in the product**, and for an organiser the equivalent path is
worse.

A **Today** tab would be: this day's visits for whichever role you are, with the
one action each needs inline — *On my way* for the earner, *did she come?* for
the organiser — and tomorrow's below it. It is not a new screen so much as a
promotion of one that already exists to where it belongs.

**The change, concretely:**

| Slot | Now | Proposed |
|---|---|---|
| 1 | Home | Home |
| 2 | Work | Work |
| 3 | Dashboard | **Today** |
| 4 | Alerts | Dashboard |
| 5 | Profile | Profile |

Notifications move to the bell in the app bar — put it on every top-level screen,
not just Dashboard, and keep the unread count that §6.2 made correct.

**What this deliberately protects.** Dashboard is genuinely good and is *not*
being removed: its Organiser/Earner split is the only place a dual-role user sees
both halves of their life at once. It moves one slot, it does not go. Home's
catalogue browse stays first — it is the discovery surface and the reason a new
user gets anywhere.

**Also worth considering, with more caution: role-aware tabs.** The app already
asks "what do you use Gasta for" (F-7). Somebody who only works could get *Today ·
Work · Dashboard · Profile*; somebody who only hires could get *Today · Home ·
Dashboard · Profile*. This is a bigger change than the swap above and should be
done **after** it, if at all — a tab bar that differs between two people who are
talking to each other about the app is a support cost.

**One thing to fix regardless of the layout:** `navHome` and `navWork` are
translated; **"Dashboard", "Alerts" and "Profile" are hardcoded English.** Three
of the five permanent labels in a product for Hindi speakers cannot be translated
today. "Dashboard" is also the worst word in the app for this audience — it is
jargon in any language.

### 5.7 Icons and infographics

The register's day-status legend — ✓ Worked, ✗ Did not come, Leave, Left early,
Questioned, To come — is the best thing in the app for a low-literacy reader, and
it is the pattern the rest should follow. Where it does not:

**A real bug, visible in the screenshots.** On Doorstep Services, **three of the
four professions draw a clothes hanger**: Pickup Drop Cloth Wash (correct),
Cylinder and Heavy Item Delivery (wrong), and Water Supply (wrong). Only
Appliance Mechanic has its own. Somebody scanning that grid by picture — which is
the whole point of a picture — sees three laundries. Fix the catalogue icons for
professions 51 and 52.

**Status is still words.** "Scheduled", "PENDING", "DELIVERED", "CANCELLED",
"Assigned" are rendered as text chips. `AppStatus` already owns the colour map;
give it an icon per status and use it everywhere a status appears. Colour alone
is not enough — roughly 1 in 12 men has some colour-vision deficiency, and this
audience skews male on the farm-labour side.

**Where an infographic earns its place** — explaining a *concept* to somebody who
cannot read the paragraph that would otherwise explain it:

1. **First-run: how the register works.** Three panels — she comes, you both see
   the same days, the total adds itself up. This is the product's core idea and it
   is currently explained nowhere.
2. **How advances work.** "Money given early is written down, and shown next to
   the wage — it is never taken off automatically." One picture prevents the
   single most likely misunderstanding about money in the app.
3. **The work record (§7.4) as something you can show someone.** It is currently
   plain text meant to be forwarded on WhatsApp. A card with the profession icons,
   the years, the visit count and the rating — designed to be *read across a bank
   counter* — is worth more than the sentence, and costs one screen.
4. **Crew jobs.** "Needs all 10 together" already has a group icon; the concept of
   all-or-nothing deserves one line of illustration where a crew job is opened.

**Smaller, cheap wins:** a type icon on every notification row (reminders already
have one); an icon in each empty state that says which *kind* of empty this is;
and the ₹ glyph duplication in T11.11 — an icon beside text that already contains
the symbol — fixed once in the shared money component.

### 5.8 What to be careful with

Not a prohibition list — the tab swap above is exactly the kind of change worth
making. The point is only that these are the things currently *working*:

- **Five tabs.** Add a sixth and the labels stop fitting at 720px, in Hindi first.
- **The money screens' locations.** People learn where money lives; moving the
  register or earnings costs more than it gains.
- **The register's icon legend.** Extend the pattern; do not redesign it.
- **Don't add a density setting or a customisable home.** Every preference is a
  question asked of somebody who opened the app to find out what time to arrive.

## 6. What else it needs to be a complete app

### 6.1 Measured against Urban Company and Yes Madam

Most of their feature list is deliberately not Gasta's — they optimise for
matching strangers quickly and taking a cut. But five things they do are things
**any** household-services product needs, and four of them are missing here.

**a) Household reliability is not tracked, and worker reliability is.** ⚠️

`UserReputation` counts `visitsMissed` and `engagementsLeftEarly` — both about
the *worker*. There is no equivalent for the household: no count of last-minute
cancellations, no record of an organiser who books and is repeatedly not there.

This is an asymmetry with real consequences. When an organiser cancels at 6am the
earner has already travelled or already turned down other work, and nothing
anywhere remembers it. A product whose thesis is that the worker is a person with
a livelihood cannot measure only her failures. Add the mirror-image counters and
show them the same way — **counts beside their context, never a score** (T7.7's
rule).

**b) The ID-verified badge exists and nobody sees it.**

`UserReputation.idVerified` is set by ops (T10.2) and carried on `ReputationDto`
— but the profile screen that would show it does not exist (§3.2). A household is
letting a stranger into their home; "ID checked by Gasta" is the single most
valuable thing to display, and it is already computed.

**c) There is no cancellation policy of any kind.**

Both sides can walk away with no stated expectation. UC charges fees; Gasta is
not in the payment path and should not. But it can and should **state** the
expectation and **record** the behaviour — which is (a). Silence here reads as
"nobody minds", and the person it costs is whoever travelled.

**d) No receipt.** Covered by §2.3 — the wage-payment ledger *is* the receipt.

**e) No grievance route with a name on it.** Covered by §7.3 — and it is a legal
requirement, not a nicety.

**What Gasta already does better and should not lose:** the safety alert during a
visit (T5.9), "Tell someone" sharing a visit, the visit code at the door, the
attendance register itself, and advances. None of the comparison apps have the
last two, and they cannot easily — they depend on the relationship being the
unit.

### 6.2 Still missing, product-wide

- **Onboarding.** A language picker and a role question, then the user is alone.
  Nothing explains the register, advances, or how to claim an engagement somebody
  recorded for you. See §5.7 for the infographic that does most of this work.
- **Help that answers real questions.** "Get help" exists and is empty of content.
- **Dispute resolution.** Days can be flagged (§7.1) and advances disputed
  (§7.2), and then nothing happens to them. Ops has a queue and an audit log —
  connect the two ends.
- **Account and data deletion.** Required by Play policy and by the DPDP Act
  (§7.4). Does not exist.
- **Analytics.** Nothing is measured, so nothing about real usage is knowable.
  Self-hosted Plausible or Umami if cost is the objection.
- **e-Shram nudge.** Helping an earner register for the national unorganised-worker
  ID is genuine value, costs nothing, and sits exactly where the work record does.

## 7. Terms, policies, and Indian law

> **This is not legal advice and I am not a lawyer.** It is a map of the
> obligations a platform in this shape has in India, written so the right
> questions get asked. **An Indian lawyer must review the actual documents before
> a single real user signs up** — a labour marketplace is one of the worst places
> to rely on a template.

The exposure here is not theoretical. Gasta connects households with **domestic
and farm workers**, which lands it in labour law, consumer law, data law, and
intermediary law simultaneously.

### 7.1 What Gasta legally *is* — get this right first

Everything else follows from one framing decision, and it must be stated in the
terms and be **true in the product**:

**Gasta is an intermediary. It is not an employer, and not a staffing agency.**

If a court or a labour inspector concludes otherwise, minimum wage, PF, ESI,
gratuity and termination obligations attach to Gasta for every worker on it. The
things that keep that framing honest are mostly already true and worth
protecting:

- Gasta is **not in the payment path** — the money is cash between two people.
  This is the strongest single fact in its favour. §2.3 must stay a *ledger*.
- Gasta does not direct the work, set hours, or supervise.
- The household is the principal; the worker is independent.

**One thing to word carefully: §7.5 rate guidance.** "People nearby pay ₹550–650"
is information. If it reads as instruction, it starts to look like a platform
setting wages — which is an employer-ish act *and* touches competition law. Keep
it descriptive, keep it a range, and never make it a default that fills a field.

**And a hard floor:** the guidance must never suggest below the state-notified
minimum wage for that work. Several states notify minimum wages for domestic
work. That is both the ethical line and the legally protective one.

### 7.2 Child labour — the single biggest exposure ⚠️

Domestic work is a **prohibited occupation for children under 14**, and hazardous
for adolescents 14–18, under the Child and Adolescent Labour (Prohibition and
Regulation) Act. A platform that facilitated the hiring of a minor into a home
would be in serious trouble, and "we didn't know" is not a defence anybody wants
to test.

**What the product needs:**

- **A date of birth or age declaration at signup**, not just a checkbox.
- **A hard block on under-18 earner accounts**, stated in the terms.
- Ops tooling to act on a report, and an audit trail when they do (both exist).
- The prohibition written plainly in the terms *and* surfaced where an organiser
  adds a worker manually (§7.3 add-existing-worker is the risky path — it creates
  a worker record from a phone number with no verification).

### 7.3 Intermediary status and grievance redressal

To keep IT Act §79 safe harbour and comply with the **IT (Intermediary
Guidelines) Rules 2021**:

- Publish **Terms of Use** and **Privacy Policy**, accessible without logging in.
- **Appoint a Grievance Officer** — real name, email, physical address, published
  in the app. **Acknowledge complaints within 24 hours; resolve within 15 days.**
- Act on a valid court or government takedown order within 36 hours.
- Retain registration information for 180 days after account cancellation.

The **Consumer Protection (E-Commerce) Rules 2020** apply on top, since Gasta is
a marketplace e-commerce entity: display legal name and address, customer care
details, and grievance officer; no unfair trade practice; do not misrepresent
ratings. Their clock is **48 hours to acknowledge, one month to redress**.

Practically: one screen with the entity details and the officer's name, one
in-app complaint form that writes to the existing ops queue, and an SLA timer.

### 7.4 Data — the DPDP Act 2023

This is the newest and the least covered. **There is no consent flow anywhere in
the app today**, and Gasta collects phone numbers, precise location, home
addresses and work history.

What it needs:

- **Notice and consent before collection**, itemised by purpose, in plain
  language **and in Hindi** — a consent notice only in English is arguably no
  consent at all for this audience.
- **Purpose limitation and minimisation.** Location is needed by one screen
  (Earning Zone); it should not be collected as though it were needed by all.
- **Rights: access, correction, erasure.** Account deletion must actually delete,
  with the audit log and legally-required records as documented exceptions.
- **Breach notification** to the Data Protection Board and to affected users.
- **Children's data** needs verifiable parental consent — which is another reason
  §7.2's age gate is not optional.
- A **grievance route for data specifically**, which can be the same officer.

### 7.5 Labour and social security, at scale

Not blockers today; they become real as soon as there is volume, and the design
choices are cheaper to make now:

- **Code on Social Security 2020** defines *aggregators* — and the schedule
  explicitly contemplates domestic and other services. Aggregators can owe **1–2%
  of turnover** to a social security fund for gig and platform workers. Gasta has
  no turnover today because it takes no cut; the moment it does, this attaches.
- **POSH Act 2013.** A household is a workplace for a domestic worker. A platform
  connecting them should have a stated anti-harassment policy and a route to
  complain — the safety alert (T5.9) is the mechanism; the policy is missing.
- **e-Shram** registration for unorganised workers: encourage it (§6.2). It helps
  the worker and demonstrates good faith.

### 7.6 The documents themselves

Minimum set, all needed before a public listing:

| Document | Notes |
|---|---|
| **Terms of Use** | The intermediary framing (§7.1), prohibited uses, the under-18 rule, account termination, limitation of liability, indemnity, governing law and a named Indian jurisdiction, arbitration if wanted. |
| **Privacy Policy** | DPDP-shaped: what, why, how long, who it is shared with, rights, officer. |
| **Worker terms** | Separate and *shorter*. The person with the least reading ability should not be handed the longest document. |
| **Community / conduct rules** | Harassment, discrimination, safety, and what gets an account removed. |
| **Cancellation expectations** | §6.1(c). Not a fee — a stated expectation and a recorded behaviour. |
| **Grievance page** | Officer name, address, email, SLA. |

**Two drafting cautions.** Indian consumer courts routinely read down one-sided
terms, so an over-reaching limitation of liability protects less than a
reasonable one. And every one of these must exist **in Hindi** to mean anything
here — an English-only consent screen in front of a user who cannot read English
is the kind of thing that looks worst in hindsight.

### 7.7 Consent, in the product

The engineering half of all of the above is small and specific:

1. A first-run **consent screen** — plain language, Hindi, itemised, with a real
   "no" that does not simply exit.
2. **Consent stored with a version and timestamp**, so it can be shown later that
   this user agreed to *that* text on *that* day. Re-prompt when the text changes.
3. Terms/Privacy reachable **from the login screen**, not only from inside.
4. **Account deletion** that works, with a stated retention exception list.
5. An **age gate** at signup (§7.2).

---

## 8. Testing

**There are two test files in the entire product**
(`ScheduleExpansionServiceImplTest.java`, `widget_test.dart`). Everything else
has been verified by hand, in the emulator, once — which found a great deal, and
guarantees nothing about tomorrow.

### 8.1 Build the suite out of the bugs that actually happened

Before writing a coverage target, write a test for each defect this project has
already produced. They are real, they are documented in PLAN-3, and every one of
them **passed both compilers**:

| Bug | Test that would have caught it | Layer |
|---|---|---|
| `SERVICE_TYPE` NOT NULL vs a null-writing entity (×2 tables) | Save a non-laundry rate / order item against a real schema | Integration |
| `COALESCE` on a BIT column → `BigDecimal` projection failure | Call `get-nearby-jobs` and assert 200 | Integration |
| `t.INSTANT_HIRE` — column does not exist | Any execution of that native query | Integration |
| `findByActive...AndCrewAllOrNothing` — Spring reads `Or` as a keyword | Context loads | Integration |
| Three `Slot` labels 4–16 hours wrong | Label derived from the constant name | Unit *(now a runtime guard — keep both)* |
| `givenOn` serialised as `[2026,8,10]` | Assert the JSON shape of every date field | Contract |
| Earnings counted past-dated visits as future income | Fixed clock, seeded visits either side of today | Unit |
| Unread badge counted one page, not the total | 40 unread, assert 40 | Contract |
| `crewAllOrNothing` lost because a screen built `Task` by hand | Parse a payload through *every* constructor | Widget |
| Auto-assigned order acceptable by nobody | State machine: assigned + PENDING → accept succeeds | Integration |
| Network failure cleared the session | `refreshAuthToken` with an unreachable host | Unit |
| Household member confirming a visit | Authorisation matrix (§8.4) | Integration |

That table is the first sprint. It is worth more than any percentage.

### 8.2 The layers, and what each is actually for

**a) Backend integration tests — start here, highest value by far.**

`@SpringBootTest` + **Testcontainers** (MySQL and Redis). This is the layer that
catches the entire class of bug that hurt most: native SQL against a real schema,
Flyway migrations actually applying, entity/column disagreements, and projections.
Mocked repositories would have caught **none** of the twelve above.

Run migrations from V1 on a clean container every time — that also continuously
verifies the migration chain, which is the gate for `ddl-auto=validate` (§2.4).

**b) API contract tests — one per endpoint, five cases each.**

There are roughly 90 endpoints. For each: happy path · wrong user (403/404) ·
invalid input (400) · not found · and the **date/enum shape of the response**.
The date-array bug and the raw-code-shown-to-users bug are both contract bugs.

Add one meta-test that fails when an endpoint has **no caller in the app** —
§6.7's audit was done by hand and the drift will recur.

**c) Backend unit tests** for the logic worth isolating: occurrence generation,
the register's payable/unrecorded split, advance balance arithmetic, crew
counting, rate guidance banding, retention cutoffs. Inject a fixed clock — half
of these are date logic and "today" is not a constant.

**d) Flutter widget tests — cheap now that `ApiState` exists.**

Every converted screen has exactly four states. Test all four per screen:
loading · ready · **stale** (the offline banner) · failed. That is ~60 small
tests and it locks in the §6.2 work, which is otherwise invisible until somebody
loses signal.

Plus the specific things that broke: a `Column` overflow at **720×1280** with the
keyboard up, and text at `textScaler` 1.6 (the clamp in `main.dart`).

**e) Flutter integration tests** (`integration_test`) for the golden flows only —
they are slow, so keep them few and load-bearing:

1. Sign in → today's visit → *On my way* → mark done.
2. Post a job → receive a quote → accept → visits appear.
3. Register a provider → book doorstep → through to DELIVERED.
4. Open the register → record an advance → other side agrees.
5. Take a crew job with a group size → organiser answers the partial fill.
6. **Go offline → cold start → today's visit still readable.**

**f) A manual checklist for what automation cannot see.** Contrast, icon
correctness (§5.7), Hindi truncation, and whether a sentence actually makes sense
to somebody who reads slowly. Keep it short and run it before each release.

### 8.3 Test data has to stop being hand-written SQL

Every verification in the last session started with hand-written `INSERT`s, and
each one had to be cleaned up afterwards. That is slow and it is why some
scenarios never got tested.

Build a **seed profile**: an organiser, three earners, a household with members,
tasks in each state, a half-filled crew, a doorstep provider, an advance awaiting
agreement. One command to load, one to reset. Every test and every manual check
starts from it.

### 8.4 The scenario matrix

Test the axes that actually interact, not the cross product of everything:

- **Role** — organiser · earner · both · household member · ops
- **Engagement state** — open · quoted · assigned · running · trial · ended ·
  expired · partly-filled crew
- **Network** — online · offline-with-cache · offline-cold · slow
- **Data** — empty · one · many · long strings · Hindi
- **Time** — before/during/after a visit; month boundaries (the register); a
  deadline passing (the crew sweep)

**The authorisation matrix deserves its own table** and is the one place to be
exhaustive: for every endpoint, assert what a *non-party* gets. §7.10 widened
exactly one organiser check out of 27 — a test should fail loudly if a twenty-
eighth ever quietly opens.

### 8.5 CI

GitHub Actions on push: `flutter analyze` + `flutter test`, and `mvnw verify`
with Testcontainers. Free for these repositories at this size. Add the migration
run as its own step so a broken migration fails the build rather than the next
person's morning.

**One rule worth adopting now:** a bug found by hand gets a test in the same
change that fixes it. Every entry in §8.1 exists because that was not the rule.

---

## 9. Suggested order

Three things run on wall-clock time rather than developer time. **Start them on
day one and let them run in the background**, because nothing else can finish
without them:

- **DLT / sender-ID registration** for OTP (§2.1) — weeks.
- **A lawyer engaged** for §7 — the documents cannot be the last thing.
- **Database backups** (§2.5) — an hour of work against irreversible loss.

**Then, in order:**

1. **§2.1 OTP delivery.** The hard launch blocker.
2. **§8.1 the regression suite from bugs that already happened**, and §8.2(a)
   Testcontainers. Do this *before* the next feature, not after — every entry in
   that table cost real time to find by hand once.
3. **§2.3 the wage-payment ledger.** The biggest product hole, and the receipt
   half of §6.1(d).
4. **§7.7 consent + §7.2 age gate + §7.3 grievance officer.** Small engineering,
   large exposure, and the age gate is the one with teeth.
5. **§2.6 Hindi for the money screens**, and the three hardcoded tab labels.

**Then the usability work, which is cheap and immediately felt:**

6. **§5.1 the eight-button card** — highest ratio of relief to risk in the app.
7. **§5.6 the tab swap** (Today in, Alerts to a bell) and **§5.7's wrong icons** —
   three doorstep professions currently draw a clothes hanger.
8. **§5.2 job tiles**, **§5.3 Profile grouping**, **§5.7's onboarding
   infographics**.
9. **§3.2 the one profile screen** — makes four built endpoints reachable and
   surfaces the ID-verified badge (§6.1(b)).

**Then:**

10. §6.1(a) household reliability counters, §2.2 push, §2.7 store readiness,
    §7.8 handover, T9.6, and the §4 issues.

**Deliberately last:** §7.6 / T9.5 (blocked on the toolchain), T11.8, T5.7
(deferred by the owner).

---

## 10. A note on how the last session went

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
