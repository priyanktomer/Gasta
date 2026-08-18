# PLAN-4 — Gasta

**This file is the entry point for a new session.** It carries the product
thesis, the architecture, the rules learned the hard way, what is done, what
remains, and a proposed set of features that are missing from the product
today.

PLAN-3.md remains the detailed history — every item's reasoning, every defect
found, every decision and why. Read it when you need the *why* behind something
specific. Read this file to know *what to do next*.

---

## 1. Read this first

Five things that will save an hour each:

1. **Verify in the emulator, always.** Compiling is not evidence. Roughly a
   third of the defects found in this project passed `flutter analyze` and
   `mvnw compile` cleanly — blank cards, invisible buttons, alerts that matched
   nobody, features silently absent because a payload omitted one field.
2. **There is no "pre-existing" or "unrelated" bug.** Every defect found in
   this codebase is ours to fix, including analyzer warnings. This is a standing
   instruction from the product owner.
3. **Don't stop between phases.** Work through. Ask a question only when
   proceeding under either answer would be unsafe or wasteful; otherwise state
   the assumption and keep going.
4. **A comment that disagrees with its code is worse than no comment.** This
   has happened four times here — a guard described in a doc-comment that the
   code did not implement, a "VARCHAR not ENUM" note over a column that was an
   ENUM. When you write the reasoning, check the code does it.
5. **`mvnw -q compile` has reported clean on a build that failed.** Don't use
   `-q` to detect errors.

---

## 2. What Gasta is — and what it is not

### The thesis

Gasta connects households and small farms with the people who work for them:
maids, cooks, farm labour, drivers, plumbers, mechanics. The market is rural and
semi-urban India; the first cluster is around Pundri Kalan.

**The unit of the product is the *relationship*, not the transaction.** A maid
comes every morning for three years. Farm labour comes for a harvest. That is
the opposite of a one-off booking, and almost every design decision follows from
it.

### Why we are not Urban Company or Yes Madam

| | Urban Company / Yes Madam | Gasta |
|---|---|---|
| Unit | One booking | One ongoing engagement |
| Relationship | Anonymous, interchangeable professional | The *same person*, known by name, for years |
| Geography | Metro, dense | Rural / semi-urban, sparse supply |
| Money | In-app, commissioned | **Cash, between two people.** We are not in the payment path |
| Worker | Effectively a gig supplier | A person with a household relationship and a livelihood |
| Literacy assumption | Reads English fluently | May read nothing at all |

**Copying their feature list would be a mistake.** Their product optimises for
matching strangers quickly and taking a cut. Ours has to optimise for *keeping a
relationship working for years* — attendance, leave, wages, trust, and the small
frictions that end an engagement.

Where we can be plainly better:

- **Continuity.** They churn workers by design; we make the same person bookable
  again in one tap.
- **The money conversation.** They avoid it by taking payment; we can make cash
  *unambiguous*, which is the actual daily friction.
- **Dignity and record.** A domestic worker has no documented work history
  anywhere. We hold one.
- **Wage fairness.** No competitor tells an employer their wage is now below the
  local rate. We can, and it costs us nothing.
- **Reachability.** Rural connectivity is intermittent by default. We have built
  for that; they have not had to.

### Who the app is for, concretely

- **Organiser** — the household or farm. Often the one who reads best in the
  family, often not the one who is home during the day.
- **Earner** — the worker. Often a woman travelling alone to a stranger's house.
  May share a phone. May not read.
- **Ops** — a small support desk. Trained, literate, works a queue. The
  low-literacy design rules explicitly **do not** apply to their screens.

---

## 3. How it is built

### Stack

- **Backend** — `JeevikaService`, Spring Boot 3 / Java 17 / MySQL 8, package
  `com.actually.yapan`. Auth via the in-house `access-app` library: requests need
  both `Authorization` and `atsh` headers. Redis holds OTPs (bcrypt-hashed) and
  rate-limit counters.
- **App** — `Yapan`, Flutter. `com.tomer.yapan` is *our* build; `in.gasta.app.dev`
  on the same emulator is a different build — don't debug the wrong one.
- **Local** — MySQL and Redis (docker) are started by the product owner. Backend
  is `./mvnw -o spring-boot:run`. Emulator AVD is `Small_Phone` at 720×1280.

### Where things live

| Concern | Backend | App |
|---|---|---|
| Occurrences (visits from schedule patterns) | `OccurrenceService`, `ScheduleExpansionService` | — |
| Reputation | `ReputationService`, `user_reputation` | `ReputationChips` |
| Safety | `ContactService.raiseSafetyAlert` | `safety_actions.dart` |
| Ops desk | `AdminOpsService` | `ops_queue_screen.dart` |
| Serviceability | `ServiceabilityService` | `serviceability_service.dart` |
| Alerts | `JobAlertService` + `PushSender` (stub) | notification list |
| Design system | — | `lib/design/tokens.dart`, `app_button.dart` |
| Fetch/state | — | `lib/service/api_state.dart` (`ApiState`, `fetchInto`) |
| i18n | — | `lib/l10n/*.arb`, generated class `L` |
| Migrations | `src/main/resources/db/migration/V*.sql` | — |

### Conventions that are load-bearing

- **DESIGN-RULES.md is binding.** §1 fixed control positions, §2 total sort
  order on every list, §3 one primary action full-width at the bottom, §4
  dismissible confirms, §5 send codes + labels never prose, §6 nothing overflows
  at 720×1280, §7 Latin numerals always.
- **T6.2: no N+1.** Batch with `findBy…In(...)`. Several endpoints were fixed for
  this; don't reintroduce it.
- **Schema changes go in `db/migration/` as Flyway files, idempotent.** Never
  edit an applied migration. `ddl-auto=update` is still on for new columns during
  the transition; Flyway owns what Hibernate cannot do.

---

## 4. Rules learned the hard way

These are not style preferences. Each cost real time or shipped a real bug.

1. **Enum columns must be VARCHAR, never native MySQL `ENUM`.** A native ENUM
   rejects any value outside its list at insert with "Data truncated". Fixed at
   the root with `hibernate.type.preferred_enum_jdbc_type=VARCHAR` — but check
   `information_schema` after adding an entity, because this recurred twice.
2. **Fail open on anything advisory.** Serviceability, rate limiting, the icon
   cache, reputation — every one returns "allow / show / proceed" when it cannot
   evaluate. A check that blocks the product because it could not reach the
   server is worse than no check.
3. **An empty configuration table means "no restriction".** `serviceable_area`
   being empty means everywhere is served. The opposite default would have
   blocked every posting in the country on first deploy, and it would have looked
   like a bug in task creation.
4. **Never let a secondary concern fail a primary one.** Push cannot fail the
   notification row. Alerts cannot fail the posting. A reputation update cannot
   roll back the rating. The one exception is the **admin audit log**, which is
   deliberately in-transaction: an untraceable admin action is worse than the
   action not happening.
5. **Silent absence is the worst failure mode.** A dispute payload omitted two
   ids and the history button simply *wasn't there* — the rows looked complete.
   An alert matcher joined a table earners don't have rows in and matched nobody.
   When a feature "doesn't appear", suspect the data before the layout.
6. **`BoxDecoration` forbids a `borderRadius` with a non-uniform `Border`** and
   does not tell you — it paints the box and drops the children.
   `CrossAxisAlignment.stretch` in an unbounded Row collapses to zero height.
   Both produced blank UI with nothing in logcat.
7. **Global `ThemeData` changes are dangerous.** Adding
   `elevatedButtonTheme`/`inputDecorationTheme` globally once grew the Proceed
   button enough to squeeze the OTP scroll view to nothing — **nobody could log
   in.** `themes.dart` is deliberately narrow and says why.
8. **Lombok's `@AllArgsConstructor` grows when you add a field**, breaking every
   positional call site. Add an explicit constructor for the old shape.
9. **`CustomException` is checked.** Declare it. And give every service method a
   `catch (CustomException)` branch returning 400 — without one, client mistakes
   report as 500s with Java messages shown to users.
10. **Dev-loop hazards.** Repeated `spring-boot:run` leaks MySQL pools → "Too
    many connections" (pool size is now 8; kill stray `java.exe`). The emulator
    framebuffer wedges → `adb emu kill` and relaunch. `adb shell input text`
    splits on spaces.

---

## 5. State of play

| Phase | State |
|---|---|
| 0 — Foundations | ✅ Complete |
| 1 — Occurrences | ✅ Complete |
| 2 — Visit lifecycle | ✅ Complete |
| 3 — Leave / skip / scheduler | ✅ Complete |
| 4A — Exits, corrections, reachability | ✅ Complete |
| 4B — Doorstep reliability | ✅ Complete |
| 5 — Substitution, flexibility, identity | ◐ T5.0–T5.6, T5.8, T5.9 done. **T5.7 not built — see §6.9** |
| 6 — Correctness, authz, perf, caching | ✅ **T6.12 `ApiState` adoption complete (§6.2)** |
| 7 — Trust & reputation | ◐ T7.8 done; T7.1, T7.5, T7.6 built but **unreachable in the app** (§6.7); T7.7 partial |
| 8 — Demand & liquidity | ✅ **Complete — T8.3 instant hire wired into the app (§7.11)** |
| 9 — Accessibility & language | ◐ T9.0, T9.1, T9.3, T9.7 done |
| 10 — Ops & support | ✅ Complete |
| 11 — Scale & hardening | ◐ T11.1, T11.2, T11.4, T11.5, T11.6, T11.9, T11.10, T11.13 done. **T11.3/T11.12 stubbed (decided), T11.7 left (decided), T11.8 outstanding; T11.11 partly done (slot labels fixed + guarded)** |
| §E — Doorstep beyond laundry | ✅ **Complete — Water Supply booked end to end (§6.6)** |
| §F — Design system | ✅ **Adopted across all 15 screens (§6.1)** |
| §G — Success gaps | ◐ **§7.1–§7.5, §7.9, §7.10, §7.11 built and verified. §7.6 (blocked — no cached TTS plugin) and §7.8's handover half outstanding** |

**Section 7 as built.** §7.1 the attendance and wage register · §7.2 advances,
including the ledger both sides can answer · §7.3 add the maid you already have ·
§7.4 my earnings and work record · §7.5 wage increments against the local rate ·
§7.9 "she hasn't come today". §7.8's trial-period half is in; the handover half
is not. §7.11 is now *decided* but not built — the design is written down in that
section.

**Orphan endpoints.** `get-advances` / `respond-advance`, `get-unread-notification-count`
and `get-terms-history` are wired. The rest are triaged one by one in PLAN-3 §20,
including two — `get-statements` and `pause-task` — recommended for **deletion**
rather than wiring, because a second route to a state that already has one is how
the two drift apart.

### Decisions already taken (do not re-litigate)

| Question | Answer |
|---|---|
| File/image storage (T11.8) | **Deferred.** Profiles ship text-only. |
| Push (T11.3) / masked calling (T11.12) | **Stubbed behind interfaces.** `PushSender`, `CallMasker`, both `@ConditionalOnMissingBean`. Needs Firebase / a telephony account. |
| Regional languages (T9.2) | **Hindi only for now.** |
| One app or two | **One app**, with a HIRE/WORK/BOTH mode preference. |
| Serviceability granularity | **Centre + radius**, not `location_state.IS_ENABLED` — the plan's A-4 recommendation was the wrong granularity for a village cluster. |
| Referral reward | **None.** A bonus is a payments feature; there is no payments system. |

---

## 6. What remains from PLAN-3

### 6.1 §F-1–F-5 — design system adoption ⚠️ **largest item**

The system exists (`tokens.dart`, `app_button.dart`, `AppStatus`) and every
screen built recently uses it. **About fifteen older screens do not.** They carry
five button widgets, three font stacks, five corner radii and hand-rolled
`width * 0.045` padding.

**Do this before any further UI work** — new screens built against the old
inconsistency have to be redone.

Method, per screen, one at a time:
1. Replace the screen-level primary action with `AppButton.primary` (48dp, full
   width, bottom).
2. Replace ad-hoc text styles with `AppText.*`, raw colours with
   `AppSemanticColors`, raw radii with `AppRadii`.
3. **Build, install, and look at it** — then at 1.3× and 1.6× system font scale.
4. Never touch global `ThemeData` (rule 7).

All fifteen screens are converted. `flutter analyze` reports no issues, and no
`GoogleFonts.*` call remains in any of them.

**Size:** L. **Risk:** medium — this is where the login regression happened.

> ### ✅ Done — 15 of 15 converted, 13 verified on screen
>
> **Order was deliberate:** the shared `visit_action_sheet` first (its dialogs
> belong to the three busiest screens, so one pass fixed all of them), then the
> small self-contained screens, and `worksheet_screen` (1,967 lines) last.
> `ThemeData` was never touched (rule 7) — the login screen and the whole
> first-run flow were walked from a clean install and are unchanged.
>
> **Twelve** Rows of two half-width buttons — every one on a consequential tap,
> all colliding at 1.6× font scale — now stack full-width at 48dp. Also fixed: a
> status chip duplicated byte-for-byte across the two screens showing the same
> quotes from opposite sides; **the brand wordmark face on three screen titles**,
> which tokens.dart explicitly forbids; **a raw database id ("ID: 42") printed
> beside every search result**; an error state showing raw exception text; and
> six private accent palettes.
>
> Six controls are deliberate exceptions to "everything is an AppButton", each
> commented in place — including the earner's safety pair, which stays a Row
> because "I feel unsafe" must be findable *by position*.
>
> **Outstanding:** `quotes_for_task_screen` and `provider_orders_screen` are
> converted and analyzer-clean but have not been seen on screen — both need
> fixture data that does not exist (a pending quote; a doorstep order assigned to
> the logged-in provider). Worth ten minutes when that data exists.
>
> Full notes, including four comments of mine that disagreed with their code:
> **PLAN-3.md §17**.

### 6.2 T6.12 — `ApiState` adoption

> ### ✅ Done — 15 of 16 converted, 1 deliberately not
>
> The first pass did six; the remaining ten are now finished. Full write-up in
> **PLAN-3.md §21**, including two stated reasons in the old table that turned
> out to be wrong once the code was read.
>
> **The one that stays as it is: `search_screen`.** `fetchInto` is network-first
> with a cache fallback; that screen is cache-*first*, which is correct for the
> whole searchable profession list on this network. Converting would have traded
> a right caching policy for a uniform one. The reasoning now sits on its
> `_loadData`.
>
> **What it turned up.** `CategoryService` passed `false` as its "did this fail"
> flag on all nine call sites, so a dropped connection was indistinguishable from
> an empty catalogue — headings over nothing, no retry. Three screens were
> assigning that constant to a *loading* flag and only worked by accident.
> `address_screen` could hang forever on a 200 without a `payload` key.
> `worksheet_screen` put raw `SocketException` text in front of users.
>
> Verified offline on the emulator: pull-to-refresh on the notifications list now
> shows "Showing saved information from 1 min ago" over the full list, where it
> used to replace everything with an error page.

### 6.2b The offline cache is gated behind the splash — **new, worth its own item**

Found while verifying §6.2. Fifteen screens now fall back to their last good
contents when the network is gone, and **a cold start with no signal never
reaches any of them**: the app stops at "Could not connect to our Servers,
please check your internet connection" with a Retry and no way through.

So the offline work covers *losing* signal during a session — walking out of
range mid-shift, which is real and common here. It does not cover the other real
case: opening the app somewhere with no signal to check what time you are due
tomorrow. **That data is already on the phone and the app refuses to show it.**

Fixing it means letting a user with a valid stored session reach the app shell
offline and letting each screen fall back as it now knows how to. The risk is
entirely in the auth path, which is why it was not done as part of a state
management pass — rule 7, never casually change what gates login.

**Size:** M · **Value:** doubles what §6.2 is worth

> ### ✅ Done — and it was hiding a logout
>
> The gate now stops only users with **no stored token**. Anyone already signed
> in goes straight in and every screen falls back to its cache.
>
> Underneath it was something worse: `refreshAuthToken()` returned `false` for a
> dead socket and a rejected token alike, so the caller cleared the session.
> **Losing signal at launch logged people out**, onto a login screen that needs
> an OTP — i.e. needs the network that had just gone. Now a tri-state, and only
> a genuine refusal ends a session. Same fix applied to the mid-session 412 path.
>
> Verified offline from a cold start: home, dashboard ("2 jobs today"), and
> today's visit with its landmark, all behind an honest "saved 8 hours ago"
> banner. See **PLAN-3.md §24**.

### 6.3 Phase 11 remainder

- **T11.4 observability** — structured logging, request ids, a health/metrics
  surface. Currently a failure is a stack trace in a console.
- **T11.5 config/environments** — one `application.properties` with a hard-coded
  password. Needs profiles and externalised secrets before any deploy.
- **T11.7 library items** — ~~needs product-owner approval per PLAN-3~~ →
  **asked and left alone, 2026-08-17.**

  "Library items" was never explained anywhere in PLAN-3, which is why it had to
  be asked about. It means changes to **`access-app`, the in-house authentication
  library** Gasta depends on as a compiled artifact — the thing behind
  `accessService.getUser()`, the `Authorization` + `atsh` header pair, and OTP
  login. It is shared with other products, so a change to it is a version bump
  and a release for everyone using it, not an edit in this repo.

  What sits behind the flag: `UserData` is the library's entity, and Gasta hangs
  every domain relationship off it. Anything Gasta wants *on a user* — a
  verification flag, a display preference — either goes in the library (and ships
  to unrelated products) or gets bolted alongside in a Gasta-owned table.

  **Decision: leave it.** Correct — the bolt-on side table is a normal pattern and
  Gasta already uses it (`UserReputation`, `EarnerPreference`). The risk to state
  plainly is that each new one is another join and another row that can go
  missing, so the cost is paid slowly rather than avoided. Worth revisiting only
  if a change is needed to the *authentication* behaviour itself, which no
  side table can reach.
- **T11.10 retention** — nothing is ever deleted. Notifications, occurrences and
  audit rows grow without bound. Decide a policy; audit rows should be exempt.
- **T11.11 polish** — the residual list in PLAN-3.

### 6.4 Phase 9 remainder

- **T9.5 voice input and read-back** — see also §7.6, which proposes something
  larger and more useful.
- **T9.6 replace typing with choosing** — the posting wizard still asks for free
  text in places where a picker would do.
- **T9.2** — deferred by decision.

### 6.5 T7.7 — remaining reliability signals

`jobsCompleted` and `engagementsLeftEarly` are counted. Still missing: no-show
rate, and lateness. Show them as *counts beside their context*, never as a score
— a composite invites a threshold, and a threshold on this market's supply side
ends somebody's ability to earn after one bad fortnight.

> ### ◐ No-shows done; lateness deliberately not built
>
> `UserReputation.visitsMissed`, counted from the overnight sweep — the only
> place a visit becomes MISSED without a human deciding it. Drawn as
> **"4 missed of 210"**, hidden below three, never as a rate.
>
> **Lateness needs a real start time first.** `Slot` carries only a display
> string ("06:00 AM - 07:30 AM"). Parsing that back into a time to decide
> whether somebody was late — and holding it against their ability to earn — is
> not a thing to build on a label. Give `Slot` a start time and it becomes easy.
>
> See **PLAN-3.md §19**.

### 6.6 §E — one end-to-end doorstep booking

The model, catalog, API and copy are done. A non-laundry service has never been
booked end to end because no provider is registered against one of the three new
professions. Register one, book it, watch it through to delivery.

> ### ✅ Done — Water Supply, registered → ordered → **DELIVERED**
>
> **Eight defects, two of which made it impossible.** Full write-up in
> **PLAN-3.md §23**.
>
> - **Two `NOT NULL` columns the code had already stopped honouring.**
>   `doorstep_service_rate.SERVICE_TYPE` and `pickup_drop_order_item.SERVICE_TYPE`
>   are the legacy laundry axis, set to null for every non-laundry variant. Both
>   entities said "nullable"; neither column was ever altered, because
>   `ddl-auto=update` adds but never relaxes. Migrations **V8** and **V9**. An
>   audit across all 182 NOT NULL columns confirms these were the only two.
> - **An order that could be placed and never accepted.** `place-order`
>   auto-assigns the nearest provider, so the order never appears under
>   "Available" — and the accept button was gated on that tab. Not
>   profession-specific: a laundry order was sitting in the same dead state.
> - **Laundry words everywhere.** "What needs to be cleaned?" for drinking water,
>   garment dropdowns on both the provider and customer sides, "e.g. Use gentle
>   wash for silk sarees", "1 piece", and raw codes (`WASH_AND_IRON`, `CAN_20L`)
>   shown to users. All now driven by the catalog's `pricingUnit`, not hardcoded.
>
> The pattern across all of them: §E-1 made the *service* list catalog-driven and
> left the *item* list, the wording and the schema behind it. Each was invisible
> because no non-laundry provider had ever existed.

### 6.7 Built-but-unreachable audit ⚠️

Two features have now been found fully implemented server-side with **no caller
in the app**: `cancelTask` (fixed — an organiser could post a service and never
withdraw it) and the **monthly statement** (still unreachable — see §7.1).

Both were invisible because nothing errors: the endpoint simply is never called.
Worth one deliberate pass — walk `Constants` in the app and every
`@PostMapping`/`@GetMapping` in the backend, and list anything with no counterpart.
An hour of grep, and on this evidence it will find more.

**Size:** S · **Do this early** — it may retire items elsewhere in this plan.

> ### ✅ Done — and it found more than expected
>
> **19 constants in the app have no caller**, and the features behind them
> include whole items this file marked ✅: **T8.3 instant hire** (Phase 8,
> "Complete"), **T7.1/T7.6 profiles**, **T7.5 favourites and blocking**, the
> **change-of-terms** flow, `confirm-arrival`, `pause-task`, `update-schedule`,
> `get-my-leaves`, the unread-notification badge, and four T10.2 ops endpoints.
>
> Full table, method and reasoning: **PLAN-3.md §13**. Three of them
> (`get-statements`, `agree-statement`, `propose-terms`) are now wired as part
> of §7.1/§7.5; the rest are outstanding and the §5 tracker above has been
> corrected.
>
> **The lesson for the tracker:** it was measuring *server* completeness. An item
> is not done until something calls it — re-run the two greps in §13 whenever a
> phase is closed.

### 6.8 §G — success gaps

G-1..G-8 in PLAN-3, but **smaller than "not started" suggests**:

- **G-1 (earner safety) is done** — it was delivered as T7.8.
- **G-2 (proof of work for the earner)** is the same thing as §7.4 below. Build
  it once.
- G-3 (onboarding walkthrough), G-4 (cancellation expectations shown at accept
  time), G-5 (notification grouping and action buttons), G-6 (record searches
  that returned nothing — the roadmap for which professions to add next, one
  table), G-7, G-8 remain.

Review the rest against §7 before spending on them; there is overlap.

### 6.9 T5.7 — identity recovery ⚠️ **not built, and now unblocked**

Phone change, and recovering an account from a **lost** phone.

PLAN-3 deferred this out of Phase 5 because the half that matters needs an admin
who can verify a person against their work history — and that tooling was T10.2.
**T10.2 is now done** (`lookup-user`, `set-id-verified`, the ops queue, the audit
log), so the dependency is satisfied and nothing blocks this.

It was separately deferred once by the product owner during Phase 5, when the
tooling did not exist. That reason has now gone; it is worth re-asking rather
than assuming either way.

**Why it matters.** An earner's phone is their account. Losing it today means
losing their entire work history, their reputation, and every engagement — with
no path back. That is the single most damaging thing that can happen to a user of
this product, and it happens constantly in this market: shared phones, lost
phones, changed numbers.

**What it needs.**
- Phone change verified via the old number while it is still reachable — the easy
  half, and it can ship alone.
- Lost-phone recovery through ops: the person proves who they are using their
  work history (which households, which visits, what dates — facts an impostor
  would not know). Every step must write an `AdminAuditLog` row; this is the most
  impersonation-attractive flow in the product.
- **Never let a recovery silently merge two accounts.** If the claimed identity is
  wrong, an impostor inherits somebody's livelihood.

**Size:** M · **Depends on:** nothing now

**Re-asked and deferred again, 2026-08-17.** Put back to the product owner now
that T10.2 has removed the original blocker; the answer was **keep it deferred**.
That is the owner's call and it stands.

Recording the exposure so the decision is a decision and not a gap nobody
remembers: **an earner who loses their phone today loses everything and has no
route back.** No self-service path, no ops path. Every visit, every rating, every
standing engagement is gone, and the person it happens to is the least able to
absorb it. The ops tooling to fix a case by hand now exists (`lookup-user`,
`set-id-verified`, the audit log), so a single stranded user can be rescued
manually — that is the mitigation, and it does not scale past a handful.

The cheap half is still worth taking whenever this is picked up: **phone change
verified through the old number**, while it is still reachable. It is small, it
carries almost no impersonation risk, and it removes the most common cause of
the expensive case — people who change numbers on purpose and never think to
migrate the account first.

---

## 7. What is missing from the product

Everything above is *finishing what was planned*. This section is different:
these are gaps I believe exist when you look at the product against how people
actually behave in this market. They are proposals, not decisions.

Ordered by what I would build first.

---

### 7.1 The attendance and wage register ⭐ **build this first**

**The gap.** For a daily maid, the interaction that matters is not booking — it
is *"did she come today, and what do I owe at month end?"* Today that lives in a
diary on the fridge, or in nobody's memory, and it is the single largest source
of friction in this relationship. Both sides remember differently and both
believe themselves.

We already generate a `TaskJob` per visit with a status. **We have the data and
do not present it as the artifact people actually want.**

**What to build.**
- A **monthly attendance grid** per engagement — a calendar, one cell per day,
  green/absent/leave/holiday. Readable without reading: this is the one screen
  that must work for someone who reads nothing.
- A **running total**: days worked × rate, minus advances, plus extras.
- **Both sides see the same grid**, and either can flag a disagreement on a
  specific day rather than on the month.
- A **month-end summary** both parties confirm. Not a payment — a shared
  statement of fact.

**Why it beats the competition.** Urban Company never has this conversation
because it takes the payment. We are not in the payment path and never will be —
so the honest, and more valuable, thing is to make the cash conversation
unambiguous. No competitor does this for recurring domestic work.

> ### ⚠️ Half of this is already built and unreachable
>
> Checked while writing this plan. `MonthlyStatement` already holds
> `totalScheduled`, `completedCount`, `leaveCount`, `skippedCount`,
> `missedCount`, `abandonedCount`, `disputedCount`, `agreedAmount`,
> `agreedPayUnit`, **and `organiserAgreedAt` / `earnerAgreedAt`** — both sides'
> confirmation. `MiscServiceImpl.buildStatement` populates it and two endpoints
> exist: `POST /agree-statement` and `GET /get-statements`.
>
> **The app has `Constants.agreeStatement` and `Constants.getStatements` and no
> screen calls either.** This is the same defect class as `Constants.cancelTask`
> having no caller anywhere (found and fixed earlier): a complete, working
> feature that no user can reach.
>
> So §7.1 is much smaller than it looks. Build the **daily attendance grid** and
> wire up the **existing** monthly statement. Do that first and check what it
> looks like before designing anything new.

**Revised size:** M, not L · **Touches:** `TaskJob` (grid), the existing
`MonthlyStatement` endpoints, one screen each side

> ### ✅ Built and verified in the emulator
>
> `GET /authenticated/get-register` (both parties, one payload) +
> `attendance_register_screen.dart`: weekday calendar, colour and pictogram per
> day, month arrows, running total, per-day "This day is wrong", and the
> previously-unreachable "Agree this month".
>
> **Checked on both accounts.** Logged in as `9000000001` and confirmed the
> earner sees the identical grid and the identical total, with the wording turned
> round ("you have taken this and not yet paid it back") and no rate banner.
> Flagging a day was run end to end: it sets DISPUTED, keeps `PREVIOUS_STATUS`,
> notifies the other side and lands in the T10.7 ops queue.
>
> Five defects were found only by looking at it — two colours that meant opposite
> things and looked identical; a locked month showing live totals under "these
> numbers will not change"; a dead forward arrow hiding nine real visits; a button
> that could only ever error; and two advance labels written from two different
> people's points of view. All fixed; reasoning in **PLAN-3.md §14**.
>
> **Now complete on both sides.** `respond-terms` is wired: an open proposal
> appears on the register for both parties, with Accept/Decline for whoever did
> not propose it, and it suppresses the nudge while it is outstanding. Verified
> end to end on the earner's screen — accepting moved the task's rate.

---

### 7.2 Advances, and the money already owed ⭐

**The gap.** Advances (*peshgi* / *udhaar*) are near-universal in this market. A
worker takes ₹5,000 before a wedding or a medical emergency and it is repaid out
of coming months' wages. Nobody records it properly. It is the most common cause
of a relationship ending badly, and it is completely absent from every app in
this category because they all think in single transactions.

**What to build.**
- Record an advance against an engagement: amount, date, and what both sides
  agreed about repayment.
- It appears on the attendance register (§7.1) as a running balance.
- Both sides confirm — an advance one side denies is exactly the dispute this
  prevents.
- **Never automate a deduction.** Record and show; the deduction is a
  conversation between two people.

**Why it matters.** This is the feature that would make a worker trust the app
over her own memory, and it is the reason she would want the employer to use it.
Supply-side pull is the hardest thing to manufacture in a marketplace and this is
a real one.

**Size:** M · **Depends on:** §7.1

> ### ✅ Built and verified in the emulator
>
> `cash_advance` + `add-advance` / `respond-advance` / `get-advances`, shown as a
> running balance on the register. Recorded ₹5,000 as the organiser and saw it on
> the earner's screen, in her wording, with the "nothing is deducted
> automatically" copy on both.
>
> Repayments are negative rows, not a mutable "remaining" column. An unconfirmed
> row still counts towards the balance — see PLAN-3.md §14 for why that is the
> pro-worker choice rather than the lax one.
>
> **Outstanding:** the ledger detail list (`get-advances`) has no screen yet; the
> register shows the balance only, so a disputed or unconfirmed row cannot be
> answered in the app.

---

### 7.3 Add the maid you already have ⭐

**The gap — and it is a bootstrap problem, not a feature request.** Almost every
household in the target market *already has* a maid. She will not download an app
to begin a relationship that already exists. Today the product can only represent
a relationship that started inside it, which means the first thing a new user
wants to do is the one thing they cannot.

**What to build.**
- "Add someone who already works for me" — the organiser creates a lightweight
  earner record (name, phone, what they do, rate, schedule).
- The engagement is real immediately: attendance, wages, leave all work with the
  organiser as the only user.
- An **invitation** goes by WhatsApp/SMS. When the worker joins, she **claims**
  the record and the history becomes hers — including the attendance already
  logged.
- Until she claims it, she is a record, not an account. Be honest about that in
  the UI: no ratings, no reputation, nothing that implies she agreed to anything.

**Why this is the highest-leverage growth feature.** It converts existing
relationships instead of trying to create new ones, and it gets workers onto the
platform *pulled by their employer* rather than cold. Urban Company cannot do
this — their model requires the worker to be theirs.

**Size:** L · **Care needed:** the unclaimed record must never be exposed to
other users, and the claim must verify the phone number.

> ### ◐ Built. Adding verified end to end; **the claim is not yet verified**
>
> `managed_earner` + `add-existing-worker` / `my-added-workers` /
> `my-pending-claims` / `claim-work-record`, and
> `add_existing_worker_screen.dart` (two text fields, everything else a tap).
>
> **Verified in the emulator:** adding "Sunita" (₹6,000/month, Mon–Sat, early
> morning) created the record, a placeholder with `enabled = 0` and a synthetic
> username, a task with `IS_OPEN_TO_QUOTE = 0`, and **13 generated visits** — and
> her register renders the month correctly for a worker who has never opened the
> app. That is §7.3's core promise and it holds.
>
> **Not verified:** `my-pending-claims` → `claim-work-record`, and the claim
> banner on the earner's screen. The Redis container stopped part-way through, so
> no OTP could be issued and there was no way to sign in as the worker — through
> the app or the API. The test record is deliberately **left in place** so this
> can be finished in one step (see the note at the end of PLAN-3.md §15).
>
> **The engagement is real from the moment it is saved**: it is an ordinary
> `Task` with a real earner, so attendance, leave and the whole §7.1 register
> work unchanged with the organiser as the only user.
>
> **Her phone number is not reserved.** The obvious design — create the account
> under her number and let her "activate" it — takes a number from a person who
> never asked us to, and then she can never sign up normally. The stand-in gets a
> synthetic username and `enabled = false`, her number stays free, and the claim
> *migrates* the engagement to the account she creates herself. See
> `ManagedEarner` for the full reasoning.
>
> **On the two cautions in this section:**
> - *Never exposed to other users* — `earner-profile` returns "Worker not found"
>   for an unclaimed record to everyone except the household that added her, with
>   the same wording as a genuine miss so the guard itself discloses nothing. Job
>   alerts already excluded her (they need an `earner_preference` row and a prior
>   quote; she has neither). Ratings are refused outright — she has not agreed to
>   be here and could not reply to one.
> - *The claim must verify the phone* — it matches on the number the caller
>   signed in with, so the OTP is the verification. No invitation code exists to
>   leak, guess or forward.
>
> **Outstanding:** `my-added-workers` has no screen yet — the household can add a
> worker and use her register, but cannot see a list of everyone they have added
> or re-send an invitation. The invitation is offered once, at the end of adding.

---

### 7.4 The worker's own earnings view — and a work record

**The gap.** A maid working four houses has no idea what she will earn this
month until it arrives, and no record at all that she has worked for fourteen
years. That second one blocks loans, rentals, school admissions — everything that
asks for proof of employment.

**What to build.**
- **"This month"** — expected earnings across all engagements, with what is
  already confirmed and what is still to come.
- **A work record** she can show: "Worked as a maid for 3 households, Mar 2024 –
  present, 612 visits, rated 4.6." Shareable as a message.

**Why it matters.** This is the most dignifying thing the product could do, it
costs almost nothing to build on data we already hold, and no competitor offers
it. It is also a reason for a worker to keep using the app when she has no
booking pending.

**Size:** M

---

### 7.5 Wage increments, and the local rate ⭐

**The gap.** Domestic wages should rise annually. They frequently do not, because
nobody remembers when the rate was last set, and raising it requires the worker
to ask — which is a hard, relationship-straining conversation to start.

We already have the T8.1 price band per profession and the engagement's start
date and rate.

**What to build.**
- On the organiser's engagement view: *"You have paid ₹500/day since March last
  year. People nearby now pay ₹550–650."* One tap to raise it.
- A gentle annual prompt on the anniversary of the rate being set.
- Never automatic. Never nagging. Once a year, stated plainly.

**Why it beats everyone.** It is unambiguously pro-worker, it costs the platform
nothing, and it is the sort of thing that earns a product a reputation in a
community that talks to itself. No marketplace does this because most of them
make more money when wages stay low.

**Size:** S — the data already exists

> ### ✅ Built and verified in the emulator
>
> `RateGuidanceDto` on the register, payer only, with "Raise the rate" going
> through the existing `propose-terms` so the earner still has to accept.
>
> Fires only when the band is quoted in the **same unit** as the engagement, and
> only when there is headroom — the first cut nudged a household paying ₹750/day
> against a ₹400–700 band, which is true, useless and makes the product look like
> it cannot compare two numbers. See PLAN-3.md §14.
>
> **Outstanding:** `respond-terms` still has no caller, so the earner cannot yet
> accept the raise in the app. Wire that next — a proposal nobody can answer is
> worse than no proposal.

---

### 7.6 Voice notes on a job, and spoken alerts

**The gap.** T9.5 proposes voice *input for search*. The bigger gap is that both
sides frequently cannot read the thing that matters: the instruction ("come from
the back gate, the front is locked"), and the notification ("your visit tomorrow
is cancelled").

**What to build.**
- A **voice note attached to a task or a visit** — recorded by the organiser,
  played by the earner. Fifteen seconds. This is how instructions actually travel.
- **Spoken playback of key notifications** — a play button on any notification,
  using on-device TTS in the chosen language.

**Blocked by:** voice notes need file storage (T11.8, deferred). TTS playback does
not — that half can be built now.

**Size:** M (TTS) / L (voice notes, after T11.8)

---

### 7.7 "Has anyone near me used her?"

**The gap.** In a village you do not hire on five stars — you hire on *"the
Sharmas have had her for two years."* Proximity and known households are the
trust signal that actually works here; an abstract rating is not.

**What to build.** On the earner's profile: *"4 households in Dharampur Bhoja
have hired her."* Count only, never names — naming other customers would be a
privacy breach and would invite pressure.

We already have `task_assignment` and addresses; this is a query.

**Size:** S

> ### ✅ Built — shown at the decision point
>
> `QuoteViewDto.householdsNearby` / `nearbyArea`, drawn under the reputation
> chips on the quote card. Count only, viewer excluded, matched on the locality
> (`ADDRESS_LINE2`) of the **task's** address rather than the city or the
> organiser's own.
>
> Put on the quote list rather than a profile screen: that is where an organiser
> actually chooses between strangers, and it already carries the T7.4 reputation
> for the same reason.
>
> **Verified at the query level only.** The count is right (1 for an outsider, 0
> for the household that did the hiring), but it cannot be seen on screen with the
> current fixture — there is only one organiser in the database, so every count an
> organiser can see is legitimately zero. A fixture gap, not a code one. Reasoning
> in **PLAN-3.md §16**.

---

### 7.8 The first week, and the handover

Two distinct moments where engagements die and the product is silent.

**The trial.** `trialDays` exists in the data and the app does nothing with it.
A single "how is it going?" check-in on day three, to each side separately,
catches the small fixable problem (she arrives at 7, they wanted 8) before it
becomes an exit.

**The handover.** T5.1 covers *temporary* cover. There is nothing for "she is
leaving permanently on the 30th" — which is when the household is most at risk of
leaving the platform to find a replacement the old way. Build: notice → post the
replacement with an overlap → the outgoing worker shows the incoming one what to
do. That overlap is what actually makes a handover work, and it is worth paying
for.

**Size:** S (trial check-in) / M (handover)

> ### ◐ Trial check-in done; handover not started
>
> `Task.trialCheckInSentAt` + `LifecycleSweepService.sendTrialCheckIns()`, riding
> the **existing** daily reminder cron. Day three is measured from the first
> visit, not from acceptance, and **each side is messaged separately** — the
> organiser will not say "she arrives too early" in front of her, and a shared
> thread gets polite answers while the engagement ends anyway.
>
> `trialDays` had sat in the data since Phase 4 with nothing reading it.
>
> **Verified by firing the sweep** (cron overridden to 30s), which caught a
> latent bug: `LocalDate.MIN` does not fit a MySQL DATE, and
> `OccurrenceServiceImpl.isWithinTrial` had the same idiom — so the trial-window
> guard threw for any task that actually had a trial. Both fixed. **PLAN-3.md
> §19.**
>
> **The handover half is not built** — notice → post the replacement with an
> overlap → the outgoing worker shows the incoming one what to do. That is the M,
> and it is a real flow rather than a notification.

---

### 7.9 "She hasn't come today"

**The gap.** It is 9am, the maid has not arrived, and the household has no idea
whether she is late, ill, or gone. Today they have a phone number and a growing
irritation.

**What to build.** One button on today's visit: *"She hasn't come"* → notifies
her, and offers to find cover for today (T8.3 instant hire already exists, this
is the entry point it deserves). If she responds "on my way / not well", the
household knows within a minute.

**Why.** This single moment, repeated, is what turns a good engagement sour. It
is cheap to build on what exists.

**Size:** S

> ### ✅ Built and verified in the emulator, both sides
>
> `POST /organiser/report-no-show/{jobId}` on today's visit; the earner's card
> then carries "Priyank Tomer is asking where you are — tap 'On my way', or take
> leave if you cannot come", directly above the two buttons that answer it.
>
> **No status change, and no new endpoint on her side.** Marking it MISSED would
> write off a day's pay over a late bus at 9:05 on one side's word. Her answers
> are buttons she already had; what was missing was the question. Stamped once,
> so re-opening the screen cannot ring her phone again.
>
> **Deviation from the plan, stated:** the "offer to find cover for today" half
> is **not** built. It depends on T8.3 instant hire, which the §6.7 audit found
> has no caller in the app at all — so this would have meant building the entire
> instant-hire flow inside a §7.9 marked S. The entry point exists and is the
> right place to add it once instant hire is reachable.

---

### 7.10 The household, not the individual

**The gap.** The person who books is often not the person at home. `Task` carries
`contactPersonName`/`Phone` and `VisitDto` an on-site person, but there is no
household: the mother-in-law who is actually there cannot see today's schedule,
confirm the work, or let the worker in.

**What to build.** Let an organiser add household members who can see the
schedule and confirm visits, without being able to change money or end an
engagement.

**Size:** M · **Care needed:** it is a permission model; keep it to two levels.

> ### ✅ Done — two levels, default-deny
>
> `HouseholdMember` + a "My household" screen carrying **both ends**: who can
> see mine, and whose I can see. One person is often both.
>
> **The safety property is that 26 of the 27 organiser checks are untouched.**
> Authorisation stays default-deny and exactly one was widened — `confirmVisit`,
> through a single `canActFor(viewer, owner)` that also returns true for the
> owner so callers cannot forget a case. Confirming is the one thing that has to
> happen at the door by whoever is actually there; changing pay, recording an
> advance and ending an engagement all stay with the account holder.
>
> Members must already have a Gasta account, are told when they are added, and
> are revoked rather than deleted. See **PLAN-3.md §25**.

---

### 7.11 Crew booking for farm work

**The gap.** Harvest needs ten people for three days. D-1 made a task
multi-worker, but the *shape* of the request is different: a crew, often
recruited as a group by one leader, paid as a group.

Worth a conversation with the product owner before building — this may be a
different flow rather than a variation, and getting it wrong is expensive.

**Size:** L · **Status:** ~~needs a product decision first~~ → **decided
2026-08-17, built and verified 2026-08-18**

#### The product owner's decision

> "If organiser says that hire only if all said earners need to be hired, only
> then job can be done, then hiring should be done in a group. In available jobs
> list we can add some mark/highlight the job which is for group; when an earner
> clicks on that the app should ask how big is your group each time — in fact we
> can add it in filter too, for those earners who work only in group."

Three things follow, and one of them is the hard part.

**1. All-or-nothing is a property of the job, chosen per job.** Asked whether the
crew rule should be global, the answer was *"organiser chooses per job"*. That is
right: transplanting genuinely needs all ten on the same morning, while weeding
is happy with six. A flag on the task, not a platform-wide policy.

**2. A crew applies as a unit, and the size is asked every time.** Not stored on
the earner's profile — the owner was explicit about *"each time"*, and he is
right for a reason worth writing down: a crew is not a stable object. It is
whoever the leader can bring on Tuesday, and last month's answer is a guess about
this week. Asking costs one number; a stale stored size costs a no-show at
harvest.

**3. Only the leader is a Gasta user, for now.** The rest are a headcount.
Requiring ten phone numbers before anyone can accept work would kill the feature
in the field, where the crew often does not have ten phones between them. The
cost is real and should be stated plainly: **only the leader accrues a work
record and a rating.** The other nine do the work and the platform cannot see
them, which is exactly the invisibility Gasta is supposed to be undoing. It is
the right first version and the wrong end state.

#### The hard part the owner named

> "But keep in mind scenario where we keep group of 5 we keep on hired/hold while
> the remaining 5 don't get filled till end."

This is the failure mode, and it is worse than it first looks. Five people have
turned down other work for Thursday because they were told they were hired. The
sixth slot never fills. On Wednesday night the organiser has half a crew and five
people have lost a day's wage — and it is the *earners* who pay for the
organiser's job not filling, which is precisely backwards.

**It must not be possible to hold a crew indefinitely.** The mechanism already
exists: `openForDays` and `expireOpenTasks` give every task a deadline. Crews
ride that deadline rather than getting a new one, and at it the organiser is
asked a question with no silent option:

> **6 of 10 filled.** Thursday is the day after tomorrow.
> · **Go ahead with 6** — the six are confirmed now.
> · **Release them** — the six are told today, in time to find other work.

If the organiser does not answer, the six are **released**, not held. Defaulting
the other way lets an absent organiser impose the cost on people who cannot
afford it, and silence is not consent to keep someone's Thursday.

The partially-filled state should also be visible from the moment it exists —
"4 of 10 · we will know by Wednesday" on the earner's own screen, so nobody
discovers on the day that they were never really hired.

> ### ◐ Server side built and verified; app side blocked on T8.3
>
> `Task.crewAllOrNothing`, `TaskAssignment.crewSize`, people-counting instead of
> row-counting, and `sweepPartialCrews()` — which makes holding a crew
> indefinitely impossible. Verified both phases against a job needing 10 with a
> crew of 6: the organiser is asked once, and on silence the crew is
> **released**, with the earner told why.
>
> **T8.3 is now wired too**, because the crew accept path rides it and the two
> are one piece of work. `instantHire` reaches the app for the first time, the
> primary action reads "Take this job" on an instant job, and a crew job asks
> "How many of you are coming?".
>
> Verified: "Needs all 10 together · 10 left" in the Earning Zone → take it with
> 6 → `CREW_SIZE = 6`, remaining 4, and the job correctly gone from that earner's
> list. Four bugs found on the way, including a `COALESCE` on a BIT column that
> 500'd the **whole** nearby-jobs list.
>
> **The organiser's answer is wired too** — a banner on My Posted Tasks with
> "Go ahead with 6" / "Release them", on the list rather than behind a tap
> because the sweep releases the crew if nobody replies. Verified: "Go ahead"
> set `workersNeeded` 10 → 6, closed the job and confirmed the earner. Release
> was already verified through the sweep, so **both outcomes are covered**.
>
> §7.11 is complete. See **PLAN-3.md §27**.

---

### My recommendation

Do **§6.7 (the built-but-unreachable audit)** before anything in this section —
it is an hour, and it has already turned up one complete feature nobody can reach.

Then, if only three of these get built: **§7.1 (attendance and wage register)**,
**§7.3 (add the maid you already have)**, **§7.5 (wage increments)**.

The first makes the daily relationship work and is the reason people open the app
when nothing is being booked — and half of it turns out to be written already.
The second is how the platform actually gets its first thousand real engagements.
The third is cheap, and it is the kind of thing that makes people tell their
neighbours about you.

None of the three is a feature Urban Company or Yes Madam has, and none of them
is a feature they *can* have: all three depend on the relationship being the
unit, and on us not being in the payment path.

---

## 8. Working agreements

- **Verify in the emulator.** Screenshot the thing you claim works.
- **Fix every bug you find**, including analyzer warnings and things you did not
  cause.
- **Keep going** through phases; don't stop to report between them.
- **Record what you did in PLAN-3.md** — its per-item sections are the history.
  Update the tracker in this file's §5 as phases close.
- **Clean up test data** you create in MySQL or Redis.
- **State deviations from the plan explicitly**, with the reasoning, as was done
  for serviceability granularity in §5.

### Getting running

```bash
cd C:/Users/priya/git/Gasta/JeevikaService && ./mvnw -o spring-boot:run
```

```bash
cd C:/Users/priya/git/Gasta/Yapan && flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Test accounts: `8191910695` (organiser, SUPER_USER) and `9000000001` (earner).
OTP is bcrypt-hashed in Redis under `app-login-otp:<phone>`; overwrite the `otp`
field with a known hash to log in during testing.
