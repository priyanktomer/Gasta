# PLAN-5 — Gasta

> **⚠️ Historical, as of 2026-08-26.** Every phase here is done or explicitly
> parked, and the backend is deployed. **[PLAN-6.md](PLAN-6.md) is the current
> entry point.**
>
> This file is kept because it carries the reasoning, not the task list. When
> you want to know *why* `ddl-auto` is what it is, why there is no load
> balancer, or why the `Slot` enum was not trimmed, the answer is in here.

Was the entry point for every session between 2026-08-24 and 2026-08-26.
PLAN-4 was the previous one; everything it left outstanding is either done or
carried here, and what this file leaves outstanding is carried into PLAN-6.

---

## How to use this plan

Written to be executed **one phase per session**, so a fresh chat never has to
read the whole thing.

**Every session, read:** this section → **Part I** (orientation) → **the one
phase you are doing**. That is enough. Phases name the reference sections they
need; don't read Part III unless a phase sends you there.

**Phases are ordered.** Phase *N* assumes *N−1* landed; where that isn't true it
says so. Phase 0 is not code and should start immediately regardless.

**Each phase has the same shape:** Goal · Why now · Files · Steps · Verify ·
Done when · Do not.

**When you finish a phase:** update *Part I §I.3*, append a numbered section to
**PLAN-3.md** (the history file) describing what you did and what you found, and
commit. If you found a bug, add its test in the same change.

---

# Part I — Orientation

## I.1 Rules that override everything

1. **Verify in the emulator, always.** Compiling is not evidence. Last session: a
   repository method that compiled and stopped the app from starting, a
   `COALESCE` that returned 500 for a whole list, a column name that only exists
   in native SQL, and a field added in three places and forgotten in the fourth.
   None were visible from a build log.
2. **There is no "pre-existing" or "unrelated" bug.** Every defect here is ours,
   analyzer warnings included. Standing instruction from the product owner.
3. **Don't stop between phases.** Work through. Ask only when proceeding under
   either answer would be unsafe or wasteful.
4. **A comment that disagrees with its code is worse than no comment.** Five
   times here so far.
5. **`mvnw -q compile` has reported clean on a failed build.** Don't use `-q` to
   detect errors.
6. **A guard that has never fired is not known to work.** The `Slot` label check
   was proved by deliberately breaking a label and watching it throw.
7. **Adding a field means finding every place that builds the object.** Not every
   screen uses `fromJson` — the Earning Zone builds `Task` field by field, which
   is how a new flag reached the DTO, the wire and the model and still arrived
   `false`.
8. **Clean up test data** you create in MySQL or Redis.
9. **Never touch global `ThemeData`** (PLAN-4 rule 7 — it broke login once).

## I.2 How to run it

```bash
cd JeevikaService && JAVA_HOME="C:/Program Files/Java/jdk-17" ./mvnw -o spring-boot:run
```

```bash
cd Yapan && flutter run -d emulator-5554 --debug
```

MySQL and Redis (docker) are started by the product owner. The JDK matters —
Lombok silently stops generating on newer ones, which is why the enforcer plugin
pins `[17,22)`.

- Health: `GET /api/v1/yapan/common/health` → `{"status":"UP","db":"UP","redis":"UP"}`
- Every response carries `X-Request-Id`; every log line carries the same value.
  **Grep the log for the id in a failing response** — how two of last session's
  bugs were found in minutes.
- Emulator `Small_Phone`, 720×1280. Package `com.tomer.yapan` (`in.gasta.app.dev`
  on the same emulator is a *different* build — don't debug the wrong one).
- `adb emu geo fix 78.18 29.59` puts the device in Pundri Kalan, where the seeded
  data is.

## I.3 State of play

**Phase 1 is mostly done — see PLAN-3 §28.** The migration chain now builds a
database from nothing (it could not, which blocked the whole phase), the
Testcontainers harness exists, **all twelve III.D.1 rows have a regression test,
each verified by reintroducing the original defect**, `scripts/seed.sql` +
`reset.sql` work, and CI runs on both repositories — green on the app, and on
the backend pending one repository secret (`GH_PACKAGES_TOKEN`).

Four of the five contract cases are now swept across every endpoint — anonymous
access, invalid input, and response date and enum shape — plus `X-Request-Id`,
and two golden flows go through the real front door with real tokens. **The
invalid-input sweep found six defects, all fixed** (PLAN-3 §28), including
`register-interest` silently saving an empty row into the demand-signal table.

Outstanding from Phase 1: per-endpoint happy paths beyond the two written, the
wrong-*authenticated*-user case where it is not hand-written, and the Flutter
golden flows in `integration_test/`, which need a device. **60 backend tests and
27 app tests, all green.**

| Phase | State |
|---|---|
| 0–4B | ✅ Complete |
| 5 — Substitution, flexibility, identity | ◐ T5.7 identity recovery **deferred by the owner** (III.A) |
| 6 — Correctness, authz, perf, caching | ✅ Complete |
| 7 — Trust & reputation | ◐ T7.1 / T7.5 / T7.6 built, **unreachable** → Phase 8 |
| 8 — Demand & liquidity | ✅ Complete |
| 9 — Accessibility & language | ◐ T9.5 / T9.6 outstanding; Hindi 57% → Phase 4 |
| 10 — Ops & support | ✅ Complete |
| 11 — Scale & hardening | ◐ T11.8 file storage, T11.11 remainder |
| §E — Doorstep | ✅ Complete |
| §F — Design system | ✅ Adopted |
| §G — Success gaps | ◐ §7.6 blocked; §7.8 handover ✅ Phase 13 |

**Phase 1 is done and merged** (2026-08-24) — 60 backend + 27 app tests, CI on
both repos, seed data, and a migration chain that can finally build a database
from nothing. Start at **Phase 2**.

**Nothing is half-built.** Everything touched is finished and verified, or
deliberately not started with the reason written down.

## I.4 Where things live

| Concern | Backend | App |
|---|---|---|
| Occurrences (visits from schedules) | `OccurrenceService`, `ScheduleExpansionService` | — |
| Register / advances (§7.1, §7.2) | `RegisterService`, `CashAdvance`, `TermsChangeRequest` | `screens/attendance_register_screen.dart` |
| Earnings + work record (§7.4) | `RegisterServiceImpl.getMyEarnings` | `screens/my_earnings_screen.dart` |
| Household (§7.10) | `HouseholdService`, `HouseholdMember` | `screens/household_screen.dart` |
| Crew (§7.11) | `Task.crewAllOrNothing`, `TaskAssignment.crewSize`, `LifecycleSweepServiceImpl.sweepPartialCrews` | `screens/worksheet_screen.dart`, `screens/posted_tasks_screen.dart` |
| Nearby jobs | `NearbyJobRepo` (native SQL), `NearbyJobDto`, `NearbyJobRow` | `screens/worksheet_screen.dart` |
| Doorstep | `DoorstepServiceImpl` | `laundry_booking_screen.dart`, `become_provider_screen.dart`, `provider_orders_screen.dart` |
| Ops desk | `AdminOpsService` | `screens/ops_queue_screen.dart` |
| Reputation | `ReputationService`, `UserReputation` | `ReputationChips` |
| Fetch / state | — | `service/api_state.dart` (`ApiState`, `fetchInto`) |
| Offline cache | — | `service/cache_service.dart` |
| Auth | `access-app` library | `service/login_service.dart` (`RefreshResult`), `main.dart` |
| Navigation | — | `navigation/bottom_navigation.dart`, `service/app_mode_service.dart` |
| i18n | — | `lib/l10n/app_en.arb`, `app_hi.arb`, generated class `L` |
| Migrations | `src/main/resources/db/migration/V1..V9.sql` | — |
| Scheduled jobs | `OccurrenceScheduler` + `LifecycleSweepServiceImpl` | — |

**Conventions that are load-bearing.** DESIGN-RULES.md is binding. Enum columns
must be VARCHAR, never native MySQL `ENUM`. No N+1 — batch with `findBy…In(...)`.
Schema changes Hibernate cannot make go in Flyway; `ddl-auto=update` is still on
for new columns.

---

# Part II — The phases

## Phase 0 — Start the clocks (not code) ⚠️ today

**Goal.** Begin the two things that run on wall-clock time, so they are never
what everything else waits for. (It said *three* while DLT registration was one
of them; that left for III.A and the count did not follow it out.)

**Why now.** One protects data that cannot be recovered; the other takes
somebody else's time, so the sooner it starts the less it blocks.

1. **Database backups.** ✅ **Done.** `scripts/backup-db.sh` — `mysqldump`,
   gzip, dated file, rotation, and `--verify` restores into a scratch schema and
   compares the table count. Proven both ways: **40 tables restored**, and the
   failure guard fired on a wrong password rather than leaving a 20-byte gzip
   header that looks like a backup.
   **Still on the product owner:** point `GASTA_BACKUP_DIR` at another disk and
   put it on a schedule. A backup beside the database survives a dropped table
   and not a dead drive, which is the failure it is really for.
2. **Engage an Indian lawyer** for the documents in III.C. ⚠️ **Still open, and
   now the blocker.** Phase 2 has built the *mechanism* and shipped six
   placeholder documents, each opening with a DRAFT banner; the *text* must come
   from them. Send III.C as the brief, along with
   `JeevikaService/src/main/resources/legal/` — a draft to correct is a cheaper
   thing to hand a lawyer than a blank page.

**Not here any more: DLT / SMS registration.** OTP delivery is out of PLAN-5
entirely (III.A) — the app is to be *completed* first. When release is actually
near, DLT registration is the long pole and takes days to weeks, so it starts
then, not now.

**Done when:** a backup has been taken **and restored once** to prove it works
(done), and the lawyer is briefed (outstanding).

---

## Phase 1 — A safety net before the next feature ✅ done

> ### ✅ Phase 1 is merged — do not redo it
>
> A cloud session implemented this on `claude/plan-5-implementation-ql0oft`;
> reviewed, fixed and **merged into `main` in all three repos on 2026-08-24**.
> **60 backend tests and 27 app tests, all green**, run offline on the dev
> machine.
>
> **What landed:** a Testcontainers harness (MySQL + Redis), a regression test
> for each of the twelve III.D.1 defects, contract sweeps for anonymous access /
> invalid input / response date and enum shape, `scripts/seed.sql` + `reset.sql`,
> `scripts/check-endpoint-callers.py` (the III.D.2 meta-test), CI on both repos,
> and six validation fixes the invalid-input sweep found. PLAN-3 §28 has the
> detail.
>
> **The headline was `V1__baseline.sql`.** It was a no-op (`SELECT 1`) on the
> reasoning that Hibernate had built every existing database — but **Flyway runs
> before Hibernate**, so against an empty database V2's first statement hit a
> table nothing had created (`Table 'gasta.task_schedule' doesn't exist`). **No
> fresh database could ever be provisioned**, which is why CI and Testcontainers
> were impossible and why `ddl-auto=validate` (Phase 11) was unreachable. Editing
> an applied migration normally breaks existing databases; checked first — this
> database's V1 row is a Flyway `BASELINE` with a **NULL checksum**, so it is
> neither validated nor re-run. Confirmed after merging: *"Successfully validated
> 10 migrations"* and the backend starts against the existing database.
>
> **Three things needed fixing that CI did not surface**, all worth knowing:
> - `SchemaBuiltByFlywayOnlyTest` could not create its schema —
>   `MySQLContainer` grants its application user rights on one database only
>   (*"Access denied for user 'gasta'@'%'"*). `IntegrationTestBase` now exposes an
>   admin account and grants the app user on the new schema.
> - **Testcontainers was not in the local `~/.m2`** and the build runs offline.
>   Cached now, so `mvnw -o test` works — but remember this the next time a
>   dependency is added.
> - A **flaky** app test: the TTL case wrote through `CacheService` then read with
>   `ttl: Duration.zero`, and `0 > 0` is false, so it passed alone and failed in
>   the full suite. It now writes the saved-at stamp two hours into the past.
>
> **Still outstanding from Phase 1:** per-endpoint happy paths beyond the two
> written, the wrong-*authenticated*-user case where it is not hand-written, and
> the Flutter golden flows in `integration_test/` — which need a device, so they
> belong to a local session, not a cloud one.

**Goal.** Make the following phases verifiable: integration tests against
a real schema, a regression test per bug already found, reproducible seed data,
CI.

**Why now.** There are **two test files in the entire product**
(`ScheduleExpansionServiceImplTest.java`, `widget_test.dart`). Every defect in
III.D.1 passed both compilers. The next phases add a payment ledger, a consent
flow and a tab change — all touching things that already broke once.

**Files**

- `JeevikaService/pom.xml` — add `testcontainers`, `mysql`, `junit-jupiter`.
  **Check `~/.m2` first**: the build runs offline, which is exactly why Actuator
  was rejected (III.F).
- `JeevikaService/src/test/java/...` — one file today
- `Yapan/test/widget_test.dart`; new `Yapan/integration_test/`
- New: `scripts/seed.sql`, `scripts/reset.sql`

**Steps**

1. **Testcontainers harness.** `@SpringBootTest` with MySQL 8 + Redis containers.
   Run Flyway from V1 on a clean container each time — that also continuously
   proves the migration chain, which is the gate for `ddl-auto=validate`
   (Phase 10).
2. **One test per bug in III.D.1.** That table is the sprint: twelve real cases,
   all previously invisible to the compiler.
3. **Seed profile** (`scripts/seed.sql`): one organiser, three earners, a
   household with members, tasks in every state, a half-filled crew job, a
   doorstep provider on a non-laundry profession, an advance awaiting agreement.
   One command to load, one to reset. Every verification last session began with
   hand-written `INSERT`s that then had to be cleaned up — which is why some
   scenarios never got tested at all.
4. **Widget tests for `ApiState`'s four states** — loading / ready / stale /
   failed — across the converted screens. ~60 small tests, and it locks in the
   §6.2 offline work, which is otherwise invisible until somebody loses signal.
5. **CI** — GitHub Actions on push: `flutter analyze`, `flutter test`,
   `mvnw verify`. Free at this size. Migrations as their own step.

**Verify.** Deliberately break something and watch the suite fail: revert V8's
`ALTER` and confirm the doorstep-registration test goes red (rule 6). ✅ Done —
it fails with `Column 'SERVICE_TYPE' cannot be null`, the original production
error. Three other guards were proved the same way; see PLAN-3 §28.

**Done when:** the twelve regression tests pass, `seed.sql` reproduces a full
dataset in one command, CI is green on a push.

**Do not.** Don't chase a coverage percentage. Don't mock the repository layer
for the native-SQL tests — mocks would have caught **none** of the twelve.

---

## Phase 2 — Consent, age gate, grievance, deletion ✅ done 2026-08-25

**Goal.** The legal mechanisms exist in the product, with placeholder text the
lawyer later replaces.

**Why now.** There is **no consent flow anywhere today**, and the app collects
phone numbers, precise location, home addresses and work history. The age gate is
the single largest legal exposure (III.C.2). None of this needs final legal text
to *build* — only to fill in.

**Read first:** III.C.

**Files**

- `Yapan/lib/main.dart` — `StartupWrapper._handleStartupActivity`, where the
  language picker and mode question already chain. Consent goes in that chain,
  **before** login.
- `Yapan/lib/screens/language_picker_screen.dart` — the pattern to copy; it is
  bilingual and deliberately does not use the translation table.
- New backend `UserConsent`: user, document key, version, accepted-at.
- `AuthenticatedController` — deletion endpoint.
- `AdminOpsService` — the grievance queue exists; route complaints into it.

**Steps**

1. **Consent screen** in the startup chain: plain language, **Hindi and
   English**, itemised by purpose, with a real "no" that does something sensible.
   An English-only consent screen in front of this audience is arguably no
   consent at all.
2. **Store consent with document key + version + timestamp**, so it can later be
   shown this user agreed to *that* text on *that* day. Re-prompt on version
   change.
3. **Age gate at signup** — a date of birth, not a checkbox. **Block under-18
   earner accounts.** Also guard `add-existing-worker`, which today creates a
   worker record from a phone number with no verification and is the riskiest
   path in the app for this.
4. **Grievance screen** — entity name, address, officer name, email, and the SLAs
   (24h acknowledge / 15 days resolve under IT Rules; 48h / 1 month under the
   Consumer Protection E-Commerce Rules). An in-app form writing to the ops queue.
5. **Terms and Privacy reachable from the login screen**, not only from inside.
6. **Account deletion that actually deletes**, with a documented retention
   exception list (audit rows, legally required records).

**Verify.** A new user cannot pass consent without answering; declining does
something sensible; a 17-year-old date of birth is refused; deletion removes the
account while the audit row survives; every string appears in Hindi.

**Done when:** all six exist, and swapping in the lawyer's wording is a content
change, not a code change.

**Do not.** Don't ship legal text you wrote yourself. Don't make consent one
"I agree" over a wall of English.

### What was built

Backend — `UserConsent` and `UserAccountProfile` entities with repos, migration
`V10`; `ComplianceService`/`Impl`; `SupportKind.GRIEVANCE`; six endpoints
(`consent-status`, `record-consent`, `declare-age`, `file-grievance`,
`delete-my-account` authenticated; `legal-document`, `grievance-officer` public);
the `add-existing-worker` age guard with `ManagedEarner.adultDeclaredAt` and
migration `V11`.

App — `compliance_service.dart`; `consent_screen.dart` (bilingual, itemised,
real "no"); `legal_document_screen.dart` with a small Markdown renderer;
`grievance_screen.dart`; consent gate in `BottomNavigation`; date of birth on
`signup_screen.dart`; Terms/Privacy on `login_screen.dart`; complaint, documents
and delete-account on `user_account_screen.dart`; the adult checkbox on
`add_existing_worker_screen.dart`.

Documents — six placeholder Markdown files in
`JeevikaService/src/main/resources/legal/`, English and Hindi, each opening with
a DRAFT banner. Versions live in `application.properties`, so the lawyer's text
is a content change and a bumped property.

**Two decisions worth knowing.** The document *text* is served by the backend
rather than bundled in the app, so the words and the version can never disagree
— an app one release behind would otherwise show old wording under a new version
number, which is the failure `UserConsent` exists to prevent. And the consent
gate lives inside `BottomNavigation` rather than the startup chain, because
consent belongs to an account and the startup chain runs before anybody has one;
six places construct that widget and all of them are covered by the one gate.

### Verified in the emulator

Consent gate fires on launch and after signup; Hindi toggle switches every
string; documents open in both languages; acceptance writes three rows with key,
version and locale and is not re-asked; **declining writes `ACCEPTED=0`** rather
than vanishing; grievance files as `KIND=GRIEVANCE` into the ops queue and
returns a reference number; the date-of-birth picker **cannot select a date less
than 18 years ago** (the year list ends at 2008) and the declaration reaches
`user_account_profile`; deletion anonymises the account, clears the profile,
signs out, and **keeps the consent rows**; `add-existing-worker` is refused by
the server without `adultDeclared` and proceeds with it.

Backend suite 69/69, `flutter analyze` clean.

### Defects found and fixed while verifying

1. **`PHONE` is `NOT NULL`** in `app_users`, and deletion set it to null — the
   constraint violation rolled the whole transaction back and the user was told
   "something went wrong" while keeping the account they had asked to be rid of.
   Blanked to `""` instead. Only running the destructive path found this.
2. **Login-screen links were invisible** — `colorScheme.onPrimary` is white, and
   the surrounding screen uses it for *button* text. On the near-white page
   background the links were present, tappable and unseeable. Same mistake in
   the date-of-birth field, fixed the same way.
3. **Document body text rendered washed out** — `RichText` does not consult the
   ambient `DefaultTextStyle`, so a style with no colour gets a fallback rather
   than the theme's foreground. `Text.rich` restores it.
4. **Paragraphs broke mid-sentence** — the renderer emitted one widget per
   source line, so every hard wrap in the Markdown became a visible gap. Lines
   are gathered into blocks now, including continuation lines under a bullet.
5. **The privacy table ran off the screen**, cut mid-word. Cells are sized from
   the viewport.

### Still not done ⚠️ — carried to Phase 14

- **Declining consent does not stop the app.** It records the refusal and asks
  again next launch. Honouring a refusal properly means withdrawing the features
  that depend on the data, and that belongs with the real text a lawyer signs
  off. **This must not ship as it stands.**
- **Deletion is a soft delete wearing a hard delete's name.** `USERNAME` is the
  phone number and is retained, because the IT Rules 2021 require registration
  information for 180 days after cancellation. A retention job has to clear it
  once that window passes; that job does not exist. `RetentionService` is where
  it goes.
- **The documents are drafts.** Every one opens with a DRAFT banner saying so.
  Phase 0's lawyer engagement is still the blocker.
- **The grievance officer is unset.** `gasta.legal.grievance-officer-*` are
  blank; the screen degrades to showing the SLAs without a name. A real person
  has to be appointed under the IT Rules.
- **`ManagedEarner.adultDeclaredAt` being written was not observed end to end.**
  The guard's refusal and pass-through are both verified; watching the timestamp
  land would have meant manufacturing an address, task, schedules, occurrences
  and a placeholder user in the dev database and then unpicking that chain.
- **Existing `managed_earner` rows have a null declaration**, deliberately.
  Back-filling one nobody made would be inventing evidence; null means "added
  before we asked".

---

## Phase 3 — The wage-payment ledger ✅ done 2026-08-25

**Goal.** Record whether the wage was actually handed over.

**Why now.** §7.1 tells both sides "22 days worked, comes to ₹16,500" — and
**nothing records whether ₹16,500 was paid.** The advances ledger is meticulous
about money *lent* while the wage itself has no record at all. That asymmetry is
the one a worker notices, and it undercuts the register that is supposed to be
the reason she opens the app. It is also the receipt III.E says every comparable
product has.

**Files**

- **Copy the shape of** `JeevikaService/.../entity/CashAdvance.java` — read its
  class comment first; the reasoning applies almost line for line.
- `RegisterService` / `RegisterServiceImpl` — `getRegister` is where it surfaces
- `Yapan/lib/screens/attendance_register_screen.dart` — the advances card and its
  ledger sheet are the pattern to mirror
- `entity/Task.java` — **delete the dead `amountPaid` column**

**Steps**

1. `WagePayment`: task, month (`yyyy-MM`), amount, paid-on, note, recorded-by,
   `organiserAgreedAt`, `earnerAgreedAt`, `disputedAt`, created-date.
   **`@JsonFormat` on every date** — a bare `LocalDate` serialises as
   `[2026,8,10]` and broke the advances sheet once.
2. Endpoints mirroring the advance ones: `add-payment`, `respond-payment`,
   `get-payments` — and **wire all three in the same change**. §7.2 shipped
   `add-advance` without `respond-advance` and stranded both sides.
3. On the register, beside "comes to ₹16,500": "₹16,500 received on the 3rd", or
   "nothing recorded yet". **Partial payments are normal here** — show the
   remainder.
4. Delete `Task.amountPaid` (declared, never written, never read) or somebody
   will wire it to something later.

**Verify.** Record a partial payment, confirm from the other side, check both
stamps in MySQL, check the register shows the remainder, and check a month with
nothing recorded says so rather than showing ₹0.

**Done when:** both sides can record and agree a payment, and the register shows
owed vs received.

**Do not.** ⚠️ **Never auto-deduct payments against the advance balance.**
`CashAdvance`'s own comment explains why: automating a decision that belongs to
two people talking to each other is the fastest way to make a worker distrust the
app. **Never put Gasta in the payment path** — this is a record, not a payment,
and that distinction is what keeps the intermediary framing true (III.C.1).

### What was built

`WagePayment` + repo + `V12`, shaped like `CashAdvance` down to the two
agreement stamps and the dispute stamp. `add-payment`, `respond-payment` and
`get-payments`, all three wired in the same change. On the register, a **Wage
paid** card above the Advance card — the order is the point: the money she is
owed comes before the money she has been lent. `Task.amountPaid` dropped in the
same migration, since a dead column called AMOUNT_PAID sitting beside a real
payment ledger is an invitation to wire the wrong one.

Three figures, never combined: what the month came to, what was paid, what is
still owed on advances.

**`WagePaymentDto`**, not the raw entity. Returning `WagePayment` serialised
`task`, `earner`, `organiser` and `recordedBy` in full — and `UserData` carries
`email`, `authorities` and a `password` field. The password is a `"dummyp"`
placeholder because this product authenticates by OTP, so nothing secret escapes
today; that is luck, not design. The app reads six fields, so the projection
sends six.

### Verified in the emulator

Recorded from both sides (the labels turn round: "Got paid" / "Paid the wage",
"How much did you get?" / "How much did you pay?"); the recording side is stamped
and the other is left "Waiting", with no answer buttons shown to the person who
wrote the row; agreeing sets the second stamp and clears any dispute; disputing
leaves the row in the ledger, still counted in the total, showing "Questioned";
a month with nothing recorded says **"Nothing yet"** rather than ₹0; a partial
payment states the remainder. Backend 69/69, `flutter analyze` clean. Test rows
removed from MySQL afterwards.

### Note for whoever does Phase 14

The **advance** endpoints still return `CashAdvance` raw and leak the same
`UserData` fields. Not changed here — separate surface, separate verification.
Item 11 below.

---

## Phase 4 — Hindi where the money is ✅ done 2026-08-25

**Goal.** The screens that decide money read in Hindi.

**Why now.** `app_en.arb` has 183 strings; `app_hi.arb` has 104. **Every screen
built in the last two sessions is English-only** — register, advances, earnings,
work record, household, crew. For an audience that "may read nothing at all",
shipping the *money* screens in English only is the wrong way round.

**Files**

- `Yapan/lib/l10n/app_en.arb`, `app_hi.arb` (generated class `L`)
- The screens above; most strings are still literals, not `l.x`

**Steps**

1. Extract literals to `app_en.arb`, money screens first, in this order:
   register → advances → earnings/work record → household → crew.
2. Translate into `app_hi.arb`. Prefer the words a worker uses — *peshgi/udhaar*
   for advances is already the domain language.
3. Fix the server-side strings that are prose rather than codes; they cannot be
   translated at all (DESIGN-RULES §5, T9.1 remainder).
4. Check truncation at 720×1280 **in Hindi** — Devanagari runs longer than
   English and buttons are where it shows first.

**Verify.** Switch to Hindi and walk the register, an advance, earnings and a
crew accept. Nothing English, nothing clipped.

**Done when:** the money path is fully Hindi.

**Do not.** Don't machine-translate money words without a human check — getting
*advance* or *wage* subtly wrong is worse than leaving English.

**Note.** The five bottom-nav labels **are already localised**
(होम / काम / ब्यौरा / सूचना / प्रोफ़ाइल). An earlier draft of this plan claimed
otherwise and was wrong.

**The 183/104 figures above were also stale.** Both ARB files held 69 keys and
were already in step; the work was never translation of a backlog, it was
*extraction* — the strings were literals in the screens.

### What was done

**69 → 402 keys**, both files, no gaps. Screens: the attendance register
(including the advances and wage ledgers), earnings and the work record,
household, posted tasks, the worksheet, and `earner_tasks_screen` — which was
not on the plan's list but is the screen a worker opens every morning and the
only route to the register, so leaving it English meant walking through English
to reach a Hindi money screen.

Domain vocabulary, because the plan is right that getting these wrong is worse
than leaving English: पेशगी for an advance, मज़दूरी for a wage (not वेतन, which
is salaried-office language), हाज़िरी for the register — the word on the paper
register it replaces. **A native speaker should still read these before
release.**

### Four defects this turned up

1. **Dates were English whatever the language.** Six `DateFormat(..., 'en')`
   calls, so the register said "August 2026" over an otherwise-Hindi screen.
   Unpinning them needs `initializeDateFormatting()` in `main()`, or intl throws
   on a locale it has no data for — a wrong-language month traded for a crash.
2. **`L.of(context)` inside `initState`.** The first fetch passes a translated
   error message, and Dart evaluates that argument before the call, so the
   lookup ran before the Localizations scope existed. The register threw on
   open. Six screens moved their first fetch to `didChangeDependencies`.
3. **A filter pane compared a code against its own translated label.** In Hindi
   `'Category' != श्रेणी`, so neither tab looked selected and the wrong list
   showed. Two `static const` maps had the same shape, mixing labels with codes;
   they are methods now.
4. **A parameter named `l` shadowed the localisation getter of the same name**
   in `my_earnings_screen`. Renamed rather than worked around.

### Left in English, deliberately

**Server prose — the plan's step 3, and the one part not finished.** Profession
names and `Slot` labels come from the database and the `Slot` enum as English
sentences, so the card still reads "Agricultural Machinery" and "Early Morning
Slot". The status label was the same problem and *is* fixed, because `Visit`
already carries the code beside it — the app maps the code and ignores the
server's words. Professions need a translations table; `Slot` has 38 values of
which about four are used, so translating it before **Phase 14's trim** would be
work thrown away. Carried as Phase 14 item 12.

Also left: `DateFormat` patterns, distance-band and filter-pane codes, and
'1 km'…'9 km' (Latin numerals are DESIGN-RULES §7).

---

## Phase 5 — Progressive disclosure on three screens ✅ done 2026-08-25

**Goal.** Stop single list items from filling the screen.

**Why now.** Cheap, immediately felt, and the product owner's own example.

**Principle.** *Show the least that lets someone decide, and put the rest one tap
away — but never two.*

**Files**

- `Yapan/lib/screens/earner_tasks_screen.dart` — the eight-button card
- `Yapan/lib/screens/worksheet_screen.dart` — Earning Zone tiles,
  `_FullScreenTaskViewer`
- `Yapan/lib/screens/user_account_screen.dart` — the `_actionTile` list

**Steps**

1. **The eight-button card** ⚠️ worst offender. Verified on the emulator: one
   visit card carries *call*, *Attendance and pay*, *On my way*, *Tell someone*,
   *I feel unsafe*, *Take leave*, *Leave this job*, *Ask to move this visit*. The
   card is taller than the screen, so **a worker with three jobs today cannot see
   her second without scrolling past eight buttons.**
   → Collapsed by default: profession, date, slot, household, address, pay. One
   primary action inline (*On my way*, or *Attendance and pay* once done).
   Everything else behind one **More** that expands in place. Keep the card, keep
   the actions, keep their order — change only what is visible before the tap.
   **`I feel unsafe` is the judgement call:** most urgent, least used. One tap
   from expanded, never buried, but it need not occupy list space on a normal day.
2. **Job tiles** — tap to expand in place (description, schedule, primary action).
   **Keep the full-screen viewer**; swiping between jobs is good and people use
   it. This removes a navigation level for glance-decide-act without removing the
   browsing screen.
3. **Profile** is a flat list of twelve. Three labelled groups, same items, same
   order within each: **Money & work** (earnings, working hours, household) ·
   **Doing business** (provider, orders, addresses) · **Account & help** (rest).

**Verify.** Three jobs today visible without scrolling past one card's actions.
Check at `textScaler` 1.6 and in Hindi.

**Done when:** no list item exceeds roughly half the viewport when collapsed.

**Do not.** Don't remove any action. Don't add a density setting or a
customisable home — every preference is a question asked of somebody who opened
the app to find out what time to arrive.

### What was done

**The visit card.** Collapsed to the facts — profession, status, date, slot,
address, who, pay — plus at most one action: today's next step. Everything else
sits behind one **More** that expands in place, so the list never moves under
her. Nothing was removed.

**The safety pair is the judgement call, and it splits on *where she is*.**
Once a visit is ON_THE_WAY, ARRIVED or IN_PROGRESS it is not a row in a list any
more — it is happening — so "I feel unsafe" stays on the collapsed card, where
her thumb already is. A visit still merely scheduled (she is at home, it is
tomorrow's work) puts it under More with the rest.

**Job tiles** expand in place to show the description, which was already in the
list response, so deciding whether a job is worth taking no longer needs a push
and a back. The full-screen viewer stays — swiping between jobs is good.

**The profile** is three groups: *Home & household* · *Money & work* ·
*Account & help*.

### One departure from the plan

The plan sketched *Money & work* as (earnings, hours, household) and *Doing
business* as (provider, orders, addresses). **Addresses and household stayed
together** instead, under *Home & household* — the file's own comment says why
they were placed side by side: they answer "where I am and who is there", and
the person who needs both is the one who books but is not home during the day.
Splitting them to match the sketch would have made the list worse.

The happy consequence is that the groups fall on boundaries the list already
had, so this was two cuts and three headings — no tile moved or retyped. A first
attempt reassembled the tiles programmatically and mangled the `if (_isStaff)`
wrapper around the ops queue; a list of seventeen actions is not worth rebuilding
to save two scrolls.

### Verified in the emulator

Two visit cards fit where one used to overflow the screen; expanding grows the
card in place; the job tile shows its description without leaving the list; the
profile reads as three groups. Checked in Hindi and at **font scale 1.6** —
nothing clipped, text wraps rather than truncating.

**Not done:** the profile screen's own strings are still English (its headings
included). Phase 4's scope was the money path; this screen is the next one worth
translating.

---

## Phase 6 — A Today tab, and notifications to a bell ✅ done 2026-08-25

**Goal.** Put the most-used screen in the bottom bar.

**Why now.** "What do I have today" costs **three taps** (Dashboard → "2 jobs
today" → My Accepted Tasks) and it is the daily reason to open the app. Meanwhile
**Alerts** holds a permanent slot for machine-written messages — and a bell with
a badge **already exists** in the Dashboard app bar, so the tab is partly
redundant.

**Files**

- `Yapan/lib/navigation/bottom_navigation.dart` — `_screens`, `_labelsFor`,
  `_iconPaths` are **five parallel lists; keep them in step**
- `Yapan/lib/service/app_mode_service.dart` — `tabOrderFor(AppMode)` already
  returns a per-role order over those five (`hire`, `work`, `both`)
- `Yapan/lib/screens/job_sheet_screen.dart` — Dashboard, and where the bell is now
- `Yapan/lib/l10n/*.arb` — add `navToday` (en + hi)

**Steps**

1. Add a `TodayScreen`: this day's visits for whichever role, with the one action
   each needs inline (*On my way* for the earner, *did she come?* for the
   organiser), tomorrow below. Mostly a promotion of existing widgets, not a new
   feature.
2. Replace `NotificationsScreen` in `_screens` with it; move notifications to a
   **bell in the app bar on every top-level screen**, keeping the unread count
   §6.2 made correct.
3. Update `tabOrderFor` for all three modes. **Role-aware ordering already
   exists** — this is an edit to those arrays, not a new mechanism.

| Slot | Now | After |
|---|---|---|
| 1 | Home | Home |
| 2 | Work | Work |
| 3 | Dashboard | **Today** |
| 4 | Alerts | Dashboard |
| 5 | Profile | Profile |

**Verify.** Today is one tap from anywhere. Notifications still reachable, badge
still correct. Check all three app modes. Check the Hindi label width at 720px.

**Done when:** the daily screen is one tap and nothing has been lost.

**Do not.** **Keep five tabs** — a sixth stops fitting at 720px, in Hindi first.
**Don't delete Dashboard**: its Organiser/Earner split is the only place a
dual-role user sees both halves at once. Don't move the money screens; people
have learned where they are. Changing tab *membership* per role (rather than
order) is a bigger step — later, if at all, because a bar that differs between
two people discussing the app is a support cost.

### What was built

`TodayScreen`, deliberately thin: each row carries the one action today asks for
and nothing else, and anything more opens the screen that already does it
properly. Rebuilding the visit card here would have left the app with two
versions of it to keep in step.

**Both roles on one screen.** The household's half needed a backend endpoint —
`GET /organiser/get-my-visits`, the mirror of the earner's, same query and same
DTO with the other party. Before it, a household with three workers opened three
screens to find out who was coming. It lives on `EarnerService` because a copy on
the other service would be a second place to forget the two occurrence safety
nets that path runs.

**The bell.** `NotificationBell` fetches its own count and opens the list, on
Home, the Earning Zone, Dashboard, Today and Profile. The Dashboard's existing
bell **had no tap handler at all** — it drew the icon and the badge and gave you
no way to see what had happened. That one is gone.

**A sixth icon.** `today.svg`, a calendar with one day filled, in the same 24×24
1.5-stroke style as the other five. It has to be told apart at a glance from
job_sheet's circled tick, because this bar is navigated by picture. It also has
to be **listed in `pubspec.yaml`** — assets are enumerated one by one there, and
the first build drew a blank space where the icon should have been.

### The tab order

Today takes the middle slot in every mode; Dashboard keeps its place in the bar
but gives up the centre, because it is read weekly and Today is read daily.

| Mode | Order |
|---|---|
| hire | Home, **Today**, Dashboard, Profile, Work |
| work | Work, **Today**, Home, Dashboard, Profile |
| both | Home, Work, **Today**, Dashboard, Profile |

### Verified in the emulator

Today is one tap from anywhere and shows today's and tomorrow's visits with the
right action on each; the bell opens the list with its 121 unread intact; the
badge is correct; the new icon is distinct in the bar; all of it in Hindi at
720px with nothing clipped.

---

## Phase 7 — Icons and infographics ✅ mostly done 2026-08-25 (one illustration left)

**Goal.** Make the app readable by picture, not only by word.

**Why now.** The register's day legend — ✓ Worked · ✗ Did not come · Leave · Left
early · Questioned · To come — is the best thing in the app for a low-literacy
reader. It is a pattern, and almost nothing else follows it.

**Files**

- `profession` table, `ICON` / `ICON_NAME` columns — professions **51** and **52**
- `Yapan/lib/design/tokens.dart` — `AppStatus` owns the status colour map
- `Yapan/lib/widgets.dart` — the shared money component (₹ duplication, T11.11)

**Steps**

1. **Fix the wrong icons** ⚠️ a real bug, visible in screenshots. On Doorstep
   Services **three of four professions draw a clothes hanger**: laundry
   (correct), *Cylinder and Heavy Item Delivery* (wrong), *Water Supply* (wrong).
   Only Appliance Mechanic has its own. Somebody scanning that grid by picture —
   the entire point of a picture — sees three laundries.
2. **Give status an icon, not just a word.** `PENDING`, `DELIVERED`, `CANCELLED`,
   `Assigned`, `Scheduled` are text chips. `AppStatus` already owns colours; add
   an icon per status and use it everywhere. **Colour alone is not enough** —
   roughly 1 in 12 men has a colour-vision deficiency, and the farm-labour side
   of this audience skews male.
3. **Infographics, where they explain a *concept*** somebody cannot read a
   paragraph about:
   - **First run: how the register works.** Three panels — she comes, you both
     see the same days, the total adds itself up. The product's core idea,
     currently explained nowhere.
   - **How advances work.** "Written down, shown next to the wage, never taken
     off automatically." One picture prevents the likeliest money
     misunderstanding.
   - **The work record (§7.4) as something you can show someone.** Currently
     plain text for WhatsApp. A card with profession icons, years, visit count
     and rating — designed to be *read across a bank counter* — is worth far more.
   - **Crew jobs** — one line of illustration for all-or-nothing.
4. **Cheap wins:** a type icon on every notification row; an icon in each empty
   state saying which *kind* of empty; and the T11.11 ₹ duplication (an icon
   beside text that already contains the symbol) fixed once in the shared
   component.

**Verify.** Open Doorstep Services and confirm four distinct icons. Walk a
doorstep order through every status and confirm each has its own icon.

**Done when:** no two unrelated professions share an icon, and no status is
distinguished by colour alone.

### What was done

**1. The wrong icons — fixed, and the cause with them.** There is no icon column
on `profession`: `IconServiceImpl.fileNameFor` derives the filename from the
name, so a profession without a matching SVG resolves to nothing. Three of the
four doorstep services had no file, and `doorstep_services_screen` fell through
to a hardcoded `dry_cleaning_outlined` left over from when the screen was
laundry-only — so the grid showed a clothes hanger three times out of four.
Three SVGs added (jerrycan, gas cylinder, hanger), and **the placeholder is
neutral now**, so the next profession added without an icon looks like no icon
rather than like laundry.

**2. Status has an icon everywhere.** `AppStatus` had carried one per status all
along; two of the three chips in the app drew only the colour. One `StatusChip`
component now, icon + label + tint + border, used by the visit card and the
doorstep orders list.

**3. The register explainer**, which the plan rightly calls the product's core
idea explained nowhere. `HowItWorksSheet` — three panels of big icon, short
line, one sentence, the same shape as the register's day legend. It appears once,
on the screen it is about, at the moment somebody is looking at the thing it
explains. Not an onboarding carousel at launch: that is read by nobody. **How
advances work** uses the same sheet from a help button on the advances card,
because "does this come off my wage by itself" is the likeliest money
misunderstanding in the app.

**4. T11.11 — "₹ ₹600 / day".** Four places drew `Icons.currency_rupee` beside
a string that already began with ₹. Each was right on its own and wrong beside
the other, so the symbol has one owner now: `MoneyText`. The two quote-type
chips that carry ₹ in their own text lost the icon.

Notification rows already carried a type icon, so that part of step 4 was
already true.

### The work record card ✅ done 2026-08-25

**`work_record_card_screen.dart`** — the §7.4 piece, and the one the phase said
was worth more than anything else left in it.

**It is designed to be read across a bank counter**, by somebody on the other
side of it who has never used this app, and that single sentence decided the
whole layout: three numbers rather than a paragraph, each big enough to read at
arm's length, with its label *under* it rather than beside it — a label with a
number after it is a sentence, and a sentence is what somebody skimming a card
across a counter does not read. A drawn border rather than a shadow, because
this is held out at arm's length and often outdoors, where a soft shadow simply
is not there.

**The professions carry icons**, matched on keywords in the name rather than a
table of all fifty-odd: the names arrive from the server as English prose
(Phase 14 item 11), so an exact map would be a second list to maintain and
wrong the day somebody renames one. The generic work badge is the fallback and
is not a failure.

**The card says nothing here was typed by hand.** A record somebody could have
written themselves is worth nothing to the person reading it, so the footer
answers the question the reader will actually have: these are Gasta's records of
work the *household* marked done.

**The name comes off the device**, from the saved-accounts store the switcher
already keeps, rather than from a request — a card opened to show to somebody
standing there should not wait on the network to put a name on itself.

What it replaced: a tinted box on the earnings screen with two sentences
composed in English, and a WhatsApp share whose text was also composed in
English regardless of the sender's language. Both now come from the ARB, with
ICU plurals so "1 people" and "1 लोगों" stop happening.

### Still not done — one of the four infographics

- **Crew jobs**, one line of illustration for all-or-nothing. Needs drawing
  rather than composing, which is why it is named here rather than half-built.

---

## Phase 8 — The one screen that unlocks four endpoints ✅ done 2026-08-25

**Goal.** Make T7.1 / T7.5 / T7.6 reachable, and show the ID-verified badge.

**Why now.** Four endpoints — `earner-profile`, `organiser-profile`,
`set-earner-connection`, `my-favourites` — are marked ✅ and **no screen reaches
any of them.** This is the last of the §6.7 built-but-unreachable class.
`UserReputation.idVerified` is set by ops, carried on `ReputationDto`, and
**displayed nowhere** — for a household letting a stranger into their home it is
the most valuable thing on the screen, and it is already computed.

**Files**

- `dto/ReputationDto.java` (`idVerified` present)
- `Yapan/lib/util/constants.dart` — add the four paths
- New `Yapan/lib/screens/worker_profile_screen.dart`
- Entry points: quote cards, the visit card, the register's counterpart name

**Steps**

1. One screen: name, professions, work record (§7.4 counts), both rating kinds,
   **ID-verified badge**, and a favourite/block control (`set-earner-connection`).
2. Reachable from wherever a person's name already appears.
3. `my-favourites` becomes a section here or on the hire flow — re-booking the
   same person is Gasta's core differentiator and has no surface today.

**Verify.** Open from three entry points. Favourite someone and confirm it
persists. Confirm a non-party sees only what they should (III.D.4).

**Done when:** all four endpoints have a caller and the badge is visible.

**Do not.** Don't show a composite trust *score* — counts beside their context,
never a number that invites a threshold (T7.7).

### What was built

`PersonProfileScreen`, one screen for both directions — `earner-profile` and
`organiser-profile` return the same fields, and the symmetry is the point (T7.6:
the person travelling alone to a stranger's house has more at stake than the one
opening the door). `FavouritesScreen` for the fourth.

**The ID line is stated either way.** Shown only when true, an absent badge is
ambiguous — "not checked" or "the app forgot" — and that difference matters to
somebody deciding whether to open their door. It reads "ID checked by Gasta" or
"ID not checked yet".

**Counts, no score.** Jobs completed, days missed, left early, and the two
ratings kept apart with their counts beside them: 5.0 from one person and 4.6
from forty are not the same claim. A "new" person gets *"nobody has rated them
yet"* rather than an empty star row, because a blank where a number should be
reads as a bad number.

### The blocker, and what it cost

The constants for all four endpoints were **already in `constants.dart`** — the
plan was right that nothing called them, and it turns out nothing had ever been
missing except the screen. But neither `AttendanceRegisterDto` nor `VisitDto`
carried the counterpart's **user id**, only their name and phone. So the two
best entry points — the register and the visit card, where the person's name is
already on screen — had nothing to navigate with. `counterpartId` added to both;
nothing new is disclosed, since it is the same person the screen is already
about.

### Entry points

The register's app bar, the visit card's name row (tappable, with a chevron when
there is somebody to open), and **"People I book again"** on the profile screen.
That last one matters most: re-booking the same person is what this product is
for, and it had no surface at all.

### Verified in the emulator

Opened from the visit card; name, ID line, record and both ratings render in
Hindi; the favourite/block controls appear only on an earner's profile, because
the mechanism exists in one direction and a dead button would be worse than
none.

### Note

MySQL ran out of connections during this phase — repeated `spring-boot:run`
restarts leave orphaned pools behind, and `max_connections` is reached after
about a dozen. If the backend will not start and the log says *"Too many
connections"*, kill the stray `java.exe` processes; it is not a code fault.

---

## Phase 9 — Fairness both ways ✅ done 2026-08-25

**Goal.** Measure household reliability the way worker reliability is measured.

**Why now.** `UserReputation` counts `visitsMissed` and `engagementsLeftEarly` —
**both about the worker.** There is no equivalent for the household: no count of
last-minute cancellations, no record of an organiser who books and is repeatedly
not there. When an organiser cancels at 6am, the earner has already travelled or
turned down other work, and nothing remembers it. **A product whose thesis is
that the worker is a person with a livelihood cannot measure only her failures.**

**Files**

- `entity/UserReputation.java`
- `LifecycleSweepServiceImpl` — where `visitsMissed` is already incremented
- `OrganiserServiceImpl` — the skip / cancel paths

**Steps**

1. Mirror-image counters: visits cancelled by the organiser at short notice,
   engagements ended early by the household.
2. Show them exactly as the worker's are — **counts beside their context, hidden
   below a small threshold, never a rate** (the §6.5 rule).
3. **State a cancellation expectation** (III.C.7). Not a fee — Gasta is not in
   the payment path — but a stated expectation and a recorded behaviour. Silence
   currently reads as "nobody minds", and the cost falls on whoever travelled.

**Verify.** Cancel a visit at short notice as the organiser; confirm the counter
moves and shows on the Phase 8 profile.

**Done when:** both sides' reliability is visible on the same terms.

### What was built

`VISITS_CANCELLED_LATE` and `ENGAGEMENTS_ENDED_BY_THEM` on `user_reputation`
(V13), mirroring the two counters that were only ever about the worker.

**Short notice is owned in one place** — `ReputationServiceImpl.SHORT_NOTICE_DAYS`
— and it is two days: the day before, or the day itself. A visit called off a
week ahead records nothing, because that is a schedule change; one called off at
dawn is a lost day, and the two must not share a counter. `skip-visits` asks the
service rather than deciding for itself.

**Ending an engagement counts against whoever ended it.** `endAssignment` already
had the comment explaining why the earner's counter must not move when a
household lets her go; the same reasoning, run the other way, is the new branch.

On the Phase 8 profile the two appear as ordinary rows: same shape, same colour,
hidden at zero, never a rate.

**Step 3 — the expectation, stated before the fact.** Cancelling today or
tomorrow now shows what it costs her ("she may already have travelled, or turned
down other work") and what happens ("no charge — but this is recorded on your
profile, the same way a missed day is recorded on hers"). The app's window and
the backend's are the same two days, deliberately: warning about something that
is not recorded, or recording something not warned about, would be worse than
either alone.

### ⚠️ What this ran into, and Phase 11 should note

**`ddl-auto=update` beat Flyway to the columns.** Adding the fields to the entity
made Hibernate create them on the next devtools restart — nullable, no default —
and V13 then failed with *"Duplicate column name"*, leaving `success=0` in
`flyway_schema_history` and taking the whole context down: every
`@SpringBootTest` failed to start, five tests with it.

Repaired by dropping the Hibernate-made columns and deleting the failed history
row, after which V13 applied with the definition it actually specifies
(`NOT NULL DEFAULT 0`). **The order matters: write the migration before the
entity, or restart with `ddl-auto=none` in between.** This is the strongest
argument yet for Phase 11's `ddl-auto=validate`.

---

## Phase 10 — Push, with a fallback that works

**Goal.** Notifications arrive without the app being open.

**Read first:** III.F for the transport comparison.

**Files**

- `service/PushSender.java` (interface), `serviceimpl/LoggingPushSender.java` —
  **every call site is already wired** (T11.3)
- App: an FCM handler + a WorkManager periodic poll

**Steps**

1. **FCM as the transport.** It is free — there is no paid tier for what Gasta
   needs, so "no paid services" does not rule it out. If the objection is the
   Google dependency, III.F lists what each alternative really costs.
2. **A WorkManager poll as the fallback**, because on Xiaomi / Oppo / Vivo /
   Realme a meaningful share of pushes never arrive. 15-minute floor, battery
   aware.
3. One config flag, mirroring how the logging sender is selected today.

**Verify.** Push received with the app closed. Then **disable push at the OS
level** and confirm the poll still surfaces the same notification.

**Done when:** both paths deliver and neither is required for correctness.

**Do not.** ⚠️ **Nothing that costs somebody money or a day's work may depend on
push.** The crew-release decision (§7.11), the advance confirmation (§7.2) and
the visit reminder all assume the user opens the app. Keep it that way — push is
an accelerator, not the mechanism.

---

## Phase 11 — Deployment and store readiness ◐ backend live 2026-08-26

**Goal.** It can be installed by somebody who is not us.

**Files**

- `application-prod.properties` — written already, and its `ddl-auto=validate`
  **will fail today, deliberately**
- `application.properties` — `gasta.db.password` still has the literal dev
  default `my$ql`
- `Yapan/android/` — signing, target SDK, permissions

**Steps**

1. **Capture every existing table's DDL as Flyway migrations** so
   `ddl-auto=validate` passes. V1 is an empty baseline; this is the real work and
   the gate for a reproducible schema.
2. Remove the literal dev password default once no local workflow needs it.
3. **Crash reporting** — Sentry free tier, or self-hosted GlitchTip. A crash on a
   user's phone is invisible today.
4. Store assets: icon, feature graphic, screenshots, description.
5. **Data Safety declaration** (location, phone, addresses), **privacy policy
   URL**, and a **location permission justification** — Google scrutinises this
   and Earning Zone needs location to work at all.
6. Signing key, versioning, target SDK compliance.

**Done when:** a signed build installs from an internal track and the prod
profile starts against a real database.

### ◐ Steps 1 and 2 done, and the backend is live — 2026-08-26

**https://yapan.duckdns.org** — Ampere A1, 2 OCPU / 12 GB, Ubuntu 24.04 aarch64,
`ap-mumbai-1`. One VM, five containers, one public port. Provisioned from the
OCI CLI so the whole thing is re-creatable and reviewable rather than a sequence
of clicks somebody remembers. Runbook in [deploy/README.md](deploy/README.md).

**Step 1 turned out to be already done.** The migrations written across phases
2–13 had quietly finished it: 14 of them build a 44-table schema from nothing
and `ddl-auto=validate` passes. Proven both ways — the prod profile starts clean
against an empty database, and dropping `handover_notice.OVERLAP_FROM` makes it
refuse to start naming that exact column. `SchemaBuiltByFlywayOnlyTest` was
already the standing guard; the comments in both properties files claiming a
prod start would fail were years-stale and are corrected.

**Step 2** — the literal dev password default is still in
`application.properties`, deliberately, because local work still needs it. The
prod profile has no defaults at all, which is the half that matters.

**No load balancer, and that is a decision.** One VM running one application. A
load balancer balances across two or more backends or terminates TLS somewhere
the app cannot reach; neither is true. It would have added a NAT gateway (a
private subnet has no outbound without one), a Bastion for SSH, and OCI
Certificates with manual rotation — three more things to misconfigure. Caddy
gets and renews Let's Encrypt certificates itself.

**TLS is not hardening, it is the product working.** `AndroidManifest.xml`
declares no `usesCleartextTraffic`, so Android 9+ blocks plain HTTP outright. An
`http://` deployment installs fine and fails every request on a real phone.

**Verified end to end:** from outside, 443 and 80 answer and 8080 / 3306 / 6379 /
33060 are all refused; SSH is restricted to one address. The app, built with
`--dart-define=GASTA_API_BASE=https://yapan.duckdns.org`, signed an account up
over HTTPS — consent rows and all — against the cloud database. The test account
was removed afterwards.

**Three defects found by doing it**, each of which would have cost an evening:

- `spring.redis.host` was read by **nothing**. Removed in Spring Boot 3.0; this
  application is on 3.3.3. It worked locally only because Spring's default is
  `localhost:6379` and every machine that ran this had Redis exactly there.
- The same bug meant **the test suite never used its Testcontainers Redis** —
  every `@SpringBootTest` was talking to the developer's own, with a container
  sitting unused beside it. Suite is 77/77 with it genuinely in use now.
- The host `iptables` rules landed **after** the REJECT. Every guide online says
  `-I INPUT 6`, correct for Oracle's older rule set and wrong for the 24.04
  image where REJECT is at line 5 — so 80 and 443 read as open in
  `iptables -L` while doing nothing at all.

### Still to do

3. Crash reporting — nothing yet.
4. Store assets.
5. Data Safety, privacy policy URL, location justification. **The privacy policy
   URL can now exist**, which was previously blocked on having a domain.
6. Signing key, versioning, target SDK.

Plus, from doing the deploy: **CI.** `deploy.sh` ships a ~200 MB tar each time
because there is no registry. GitHub Actions building the arm64 image into GHCR
makes deploys incremental — the natural next step, and deliberately not the
first one.

---

## Phase 12 — The posting flow: scheduling, instant hire, and choosing ✅ done 2026-08-25

**Goal.** Make posting a job easier, and make instant hire something that
*happens* inside scheduling rather than a separate thing to find.

**Why now.** The product owner's direction, 2026-08-24:

> "I don't want to make the app difficult to use. Instant hire, if not needed
> then remove or whatever. When we schedule a job for today and select schedule
> time (there by default current time is shown) — there itself we can think of
> instant hire, like Rapido/Uber. It starts finding but may take some time, so
> we ask the user: work is open for how many hours, by default half an hour.
> See scheduling functionality properly and scope of improvement."

That is a better design than the one the code was heading towards, and **most of
it already exists** — this is mostly wiring, not building.

**What is already there** (verified 2026-08-24):

| Piece | State |
|---|---|
| `new_task_page.dart:55` — `TimeOfDay taskTime = TimeOfDay.now()` | ✅ the time field **already defaults to now** |
| `Task.openForMins` / `openForDays`, and both on `NewTaskDto` | ✅ backend already accepts a minutes window |
| `LifecycleSweepServiceImpl.quoteDeadline()` + `expireOpenTasks()` | ✅ already closes a job when its window passes |
| `Task.IS_INSTANT_HIRE`, DTO → wire → `Task` → Earning Zone → *Take this job* | ✅ **the whole accepting half works** |
| `POST /organiser/post-instant-job` | ⚠️ implemented, **no caller** — this is D-7 |
| App sending `openForMins` | ❌ the app only ever sends `openForDays` |

**Steps**

1. **Fold instant hire into scheduling — do not build a separate posting screen.**
   When the chosen date is today and the time is at/near now, the job *is* an
   instant hire. Set the flag from that, rather than asking the organiser to
   understand a second concept.
2. **Ask "how long should this stay open?"** — the Rapido/Uber shape. Default
   **30 minutes**; offer a couple of longer choices. Send it as `openForMins`,
   which the backend already understands and already expires on.
3. **Show that it is searching**, and what happens when it does not fill —
   because it often will not. The crew partial-fill banner (§7.11,
   `posted_tasks_screen.dart`) is the pattern: state the deadline, and say what
   happens if nobody comes.
4. **Then decide D-7**: with this in place, `post-instant-job` is either the
   endpoint this flow calls, or it is redundant and should be **deleted**. Do not
   leave it sitting unreachable — that is the §6.7 defect this plan keeps closing.
   **Do not delete the accepting side**; it is the expensive half and it is
   finished.
5. **T9.6 — replace typing with choosing.** Same screen. The wizard still asks
   for free text where a picker would do. Directly serves the low-literacy goal
   and needs no new dependency.
6. **Review the scheduling step as a whole** while you are in there, as asked.
   Known rough edges: `openForMins` never sent; the repeat/pattern options are
   the densest part of the wizard; and a job posted for "today, 6am" tomorrow
   morning is indistinguishable from one posted for next month.

**Verify.** Post a job for today at the current time and confirm it becomes an
instant hire an earner can take from Earning Zone; post one for next week and
confirm it does *not*. Let a 30-minute window expire and confirm the job closes
and the organiser is told.

**Done when:** instant hire is reachable without a separate screen, and D-7 is
either wired or deleted rather than parked.

**Do not.** Don't add an "instant hire?" toggle the organiser has to reason
about — the whole point is that choosing *today, now* already says it.

### What was built (steps 1–4)

**No toggle.** `isInstantHire` is a getter over the schedule: repeat is *Once*,
the date is today, and the chosen time is within the next two hours. "About now"
rather than exactly now, because the clock defaults to the current time and a
person spends a minute or two in the wizard — a strict comparison would stop
being true while they filled the form in.

**The Rapido/Uber question**, appearing only when the schedule already said
"now": *we will start looking straight away* → *how long should this stay open?*
(30 minutes, 1 hour, 2 hours, until this evening) → *if nobody takes it in that
time, the job closes and we will tell you.* That last line is the one usually
left out, and it is the one that decides whether an organiser waits or reposts
the same job three times.

**`openForMins` is finally sent.** The backend has accepted it and expired on it
since it was built; the app only ever sent `openForDays`, so a job meant to run
for half an hour ran until the default.

### D-7 is resolved: wired, not deleted

`post-instant-job` **is** the endpoint this flow calls. The decision was made for
us by a comment already in `OrganiserServiceImpl`: `addNewJob` passes
`instantHire = false` *unconditionally*, so that no request body can turn an
ordinary posting into an instant one — a different product behaviour and a
different alerting policy. That reasoning is right, which means **the route
carries the meaning and a body flag cannot**. A first attempt sent
`hireMode: INSTANT` to `post-new-job`; it would have looked like it worked and
done nothing.

### Verified in the emulator

Today at the current time shows the block; changing the date to the 29th makes
it disappear. Both in Hindi.

**Not verified:** letting a 30-minute window actually expire and confirming the
job closes and the organiser is told. That is `expireOpenTasks`, which is
existing and tested code, but the end-to-end wait was not sat through.

### Steps 5 and 6 ✅ done 2026-08-25

**T9.6 — the whole of step 3 was a 300-pixel blank box labelled "Describe the
task".** A step of the posting wizard, on the screen a new organiser meets
first, that a person who cannot write comfortably simply cannot fill. It is now
eight tappable notes — what the work involves, then what to expect at the house
— with the box kept underneath, shortened, and relabelled *"Anything else? (you
can leave this empty)"*.

The notes are held as **codes**, not sentences, so the description comes out in
whichever language the organiser is posting in. `description` is derived from
the selected codes plus the typed text on every read rather than stored, so the
two cannot drift apart. **Nothing in the list is about the worker** — a chip
asking for a particular kind of person is not a chip this app will offer.

**The wizard is in Hindi now.** It was the screen a new organiser meets first
and it was almost entirely English: every section title, both buttons, the pay
options, the price band, the three asterisk notes, the address block.

⚠️ **The repeat options had to be split into codes and labels before any of that
was safe.** Nine places compared `getRepeatTypes()[i]` against the literal
English words on screen to decide which half of the form to draw. Translating
the screen would have made every one of those comparisons false in Hindi — the
wizard would have drawn the wrong fields, silently, in one language only. That
exact defect already happened once on the filter pane. Same for
`getSelectDateOptions` and for the pay units, which showed the raw enum (`DAY`,
`MONTH`, `SLOT`) in both languages.

Day names now come from `intl` in the reader's language rather than a
hand-written `['Mon', 'Tue', …]`, which is one fewer list for anybody to
translate when a language is added.

### Three more defects found by running it

**The wizard was numbered 1, 2, 4, 5.** There has never been a step 3, so it
told every organiser it had lost one. The count is derived from the page list
now, so adding a page cannot reintroduce it.

**"Next" posted the job.** On the last step the primary button still read
*Next*, so the control that publishes a job to strangers was labelled as if it
only turned a page. It says *Post this job* there now.

**"Until this evening" was a fixed six hours.** Posted at 11pm it meant 5am. The
other three window chips are durations; this one now is too, and is true at
every hour.

**And one thing step 6 asked for:** a date field reading `27-Aug-2026` looks the
same whether the job is tomorrow or eleven months out. It now carries *Today* /
*Tomorrow* / *In 4 days* / *Tuesday, in 23 days* beneath it — past a week the
weekday leads, because "in 23 days" is a number nobody pictures.

### Verified

Emulator, Hindi, 720×1280: every step of the wizard end to end for two
professions; notes tapped and the text reaching MySQL as Hindi; days and slots
posting as `MON` / `WED` / `E_1` with `REPEAT_WEEKLY_SELECT_DAYS` — the codes,
not the labels, which is the thing the split had to prove; the instant-hire
block still appearing for *today, now* after that split. Test postings removed
from MySQL afterwards. `flutter analyze` clean.

### Still open, and not this phase

Profession names and sub-profession names (`Maid`, `Cook`, `Sweep-Mop`) and slot
labels (`Early Morning (Up to 9am)`) still arrive from the server as English
prose. That is **Phase 14 item 11**, which needs a code beside each label the
way `Visit` already carries `status` beside `statusLabel`.

---

## Phase 13 — The handover ✅ done 2026-08-25

**Goal.** "She is leaving on the 30th."

**Why now.** T5.1 covers *temporary* cover; there is nothing for a permanent
departure — which is exactly when a household is most likely to leave the
platform and replace her the old way. The trial-check-in half of §7.8 is already
done.

**Steps.** Notice → post the replacement with an **overlap** → the outgoing
worker shows the incoming one what to do. **That overlap is what actually makes
a handover work**, and it is worth paying for.

**Size:** M.

### What was built

`HandoverNotice` + `V14__handover_notice.sql`, `HandoverService` /
`HandoverServiceImpl`, four endpoints (`give-notice`, `withdraw-notice/{id}`,
`get-notice`, `post-replacement/{id}`), `closeElapsedNotices()` on the nightly
retention sweep, `GiveNoticeSheet`, the household's banner on
`task_visits_screen`, the notice state and withdraw control on
`earner_tasks_screen`, and 17 ARB strings in both languages.

**The migration was written before the entity, deliberately.** Phase 9 did it
the other way round and `ddl-auto=update` created the columns first, nullable
and without defaults; Flyway then failed on a duplicate column, wrote
`success=0` into `flyway_schema_history` and took down every `@SpringBootTest`
in the suite.

**Three days is the default overlap and it is a judgement, not a calculation.**
One day is a tour of the kitchen; a week is a household paying two people for
work one can do. Three is enough to be shown the routine on a normal day and be
watched doing it on the next. The household can move it — the constant is only
what the field is filled in with when nobody says otherwise. The app duplicates
the number to *show* the date before it is sent; the server's value wins, so if
the two ever disagree the screen is wrong and the data is right.

**A notice for today is refused, not accepted-and-flagged.** Leaving today is a
real thing people do and the app already has a button for it. Calling it a
handover would put a replacement search on a clock that has already run out —
and the refusal says so in those words rather than "invalid date".

**The row survives everything.** Completed and withdrawn notices both stay:
"who worked here before, and why did they go" is asked months later, and the
answer should not depend on somebody having tidied up. Which is also why there
is no unique key on `TASK_ID` — an engagement can be given notice on, have it
withdrawn, and be given notice on again. The service enforces one *live* notice
at a time, which is a different rule and belongs there.

**`postReplacement` reuses `rebook-task`** rather than growing a second way to
post the same job, with the previous-worker window set to zero — rebook gives
the outgoing worker first refusal, which is exactly wrong for their replacement.

**Only the household can post it.** The outgoing worker sees that a replacement
is being looked for and cannot start the search in somebody else's name.

**The sweep only closes the notice; it never ends the engagement.** A last day
passing means the notice has been worked through, not that the app should
delete somebody's job for them.

### Two defects found by running it

**The earner's button was a dead end.** After giving notice it still read "I am
leaving — give notice", and the server refuses a second notice on the same job —
so the only control on the card was one that always failed, and a notice given
in a bad week could not be taken back in a good one. The card now fetches the
notice when it expands (once per task, not once per row on every load) and shows
the last day, the overlap line and "I am staying after all" in its place.

**An assigned task could not reach its own visit schedule.** `posted_tasks_screen`
checked `openToQuote` before `assigned`, and a task can be both — task 9 in the
dev data is. The card drew "Tap to see visits & code" (that line is drawn on
`assigned`) and then opened the quote list, so the schedule, the start code and
confirm-done were unreachable for that task by any route. Found while trying to
open the household's half of this phase. One-line reorder; the comment above it
now says why the order matters.

### Verified

Emulator, Hindi, 720×1280: earner gives notice → picker refuses today and
everything before it, first selectable day is tomorrow → overlap line appears
with the date → reason optional → row lands in `handover_notice` with
`OVERLAP_FROM` three days back → withdraw stamps `WITHDRAWN_AT` and keeps the
row → notice given again → household opens the task and sees "Ramesh Kumar 30
Aug को काम पूरा करेंगे / 5 दिन बाकी / नया व्यक्ति 27 Aug से शुरू कर सकता है" →
"find someone to take over" posts task 19 and links it → banner switches to "a
replacement has been posted" and the button goes. Test data removed from MySQL
afterwards.

`HandoverNoticeRulesTest` — 8 cases on a real MySQL, pinning the refusals
(today, the past, an overlap after the last day, a second live notice, a worker
posting their own replacement, an outsider giving or reading one) and the
overlap default and its clamp to today. The happy path is proved in the
emulator, which is where the screens have to be proved anyway; what that run
cannot prove is the negative space, and a refusal that stops refusing looks
exactly like a feature working. Suite 69 → **77/77**. `flutter analyze` clean.

---

## Phase 14 — Pay off the known issues ✅ mostly done 2026-08-25

Small, independent, safe to do in any gap. Detail in III.B.

**Status: 1, 2, 3, 5, 6, 9, 10 and 11 are done. 4 was deliberately not done —
see below. 7 is a "consider" and was left. 8 and 12 are blocked on the lawyer
and on appointing a person.**

1. Delete `Task.amountPaid` (if Phase 4 has not).
2. Delete the `TaskChat` placeholder — a `@Table` with no `@Entity` is a trap.
3. **Delete `get-statements` and `pause-task`** rather than wiring them: the
   register already shows the month, `skip-visits` already pauses by date range.
   Two ways to do one thing is how they drift.
4. Trim the `Slot` enum — 38 values for ~4 used, two naming schemes meaning
   different things. The label guard stops them lying; the bloat remains.
5. Stop concatenating `e.getMessage()` into user-facing text in the remaining
   services. `errorResponse` already takes the technical detail separately.
6. Give `CacheService` an eviction policy — device entries grow unbounded. T11.10
   covers the server; the phone has nothing.
7. Consider splitting `OrganiserServiceImpl` (~2,400 lines). Not a defect, but
   three of last session's bugs lived there.
8. ⚠️ **Make a declined consent mean something.** Phase 2 records the refusal
   and re-asks next launch; it does not stop the app using the data. Doing it
   properly means withdrawing the features that depend on that data, which needs
   the lawyer's text to say which those are. **Not shippable as it stands.**
9. ⚠️ **Finish account deletion.** `USERNAME` holds the phone number and is
   kept, because the IT Rules 2021 require registration information for 180 days
   after cancellation. Nothing clears it when that window passes, so today's
   "deletion" is a soft delete wearing a hard delete's name. Add the sweep to
   `RetentionService`, which already batches by cutoff for notifications, keyed
   on `UserAccountProfile.deletionRequestedAt` (indexed for this).
10. **Stop the advance endpoints returning raw entities.** `get-advances`,
    `add-advance` and `respond-advance` serialise `CashAdvance` whole, which
    drags `UserData` — `email`, `authorities`, `password` — out with it. The
    password is a `"dummyp"` placeholder today, so nothing secret leaks; that
    stops being true the day anybody adds password login. Phase 3's
    `WagePaymentDto` is the pattern, and the app already reads only seven
    fields. Check the other endpoints that return entities while you are there.
11. **Translate the server's prose labels.** ◐ **Slot done, professions not.**
    Both reach the app as English sentences, so a Hindi card said "Early Morning
    Slot". `slotLabel` already mapped the four codes in use; the two pickers in
    the posting wizard and the one on *add an existing worker* were not calling
    it and drew the enum's own English `value` instead — fixed 2026-08-25, and
    safe because all three select by index or identity, never by label.
    **Profession names are still English** ("Maid", "Agricultural Machinery").
    The mechanism is the same — a code beside the label — but the fifty-odd
    translations are a content decision, not a code one: for several the Hindi
    *is* the common word (मिस्त्री) and for others the English is what people
    actually say. That needs the product owner, not a guess.
12. **Appoint and configure a Grievance Officer.** `gasta.legal.grievance-*` are
    blank; the complaint screen degrades to showing the SLAs with no name on
    them. The IT Rules 2021 require a named person with a contact address.

---

### What was done

**1.** `Task.amountPaid` went with Phase 3's V12.

**2.** `TaskChat` deleted — a `@Table` with no `@Entity` is a trap: it looks
mapped, is not, and the next person to "fix" it by adding `@Entity` gets a table
created under them.

**3.** `get-statements` and `pause-task` deleted, controller through service
through interface, plus their two dead constants in the app. Neither had a
caller; the register already shows the month and `skip-visits` already pauses by
date range.

**5.** **119 messages** across 13 files stopped putting exception text in front
of users. Every one built its message as `"Could not do X: " + e.getMessage()`,
so what a person read was a constraint name or a JDBC error — nothing they can
act on and rather a lot about the deployment. The detail was never lost:
`errorResponse` takes it as a separate `payload` argument and every one of these
was already passing it there too. The concatenation was duplication into the
wrong field.

**6.** `CacheService.evictOldEntries()`, run unawaited at launch. Every
`fetchInto` with a cacheKey writes two `SharedPreferences` entries keyed by id —
`REGISTER_9_2026-08`, one per task per month — and nothing ever removed them, so
the file grew for the life of the install on the cheapest phones in the market.
Thirty days, keyed off the `_AT` stamps and removing **pairs**: walking the value
keys would leave the stamps behind, which is how a cache-clearing routine ends up
growing the file it was written to shrink. `SharedPrefService` gained `keys()`
and a real `remove()` — the old `invalidate` wrote `''`, which is fine for
invalidating and useless for reclaiming space.

**9.** `purgeDeletedAccounts()` on the nightly sweep. Phase 2's deletion kept
`USERNAME` — the phone number — because the IT Rules 2021 require registration
data for 180 days after cancellation, and nothing cleared it afterwards. It is
replaced with a `deleted-{id}` tombstone rather than null, because the column is
NOT NULL and unique and every foreign key points at it: the personal data goes
and the shared records stay attached to a row that identifies nobody. Idempotent
by that prefix, since the profile rows live forever.

**10.** `CashAdvanceDto`. The three advance endpoints returned `CashAdvance`
whole, dragging `UserData` — `email`, `authorities`, `password` — with it. The
app reads seven fields; it sends seven now.

**11.** The **`Slot` half**, four labels, without item 4 (below). Professions
too still send English prose and need a translations table — unchanged.

### ⚠️ Item 4 was deliberately not done

The trim is listed under "small, independent, safe" and on inspection it is none
of the three.

What is true: 38 values, two naming schemes, and only **E_1, E_2 and E_4** exist
anywhere in the database. `ProfessionRuleDto` hardcodes
`List.of(E_1, E_2, E_3, E_4)`, so the other 34 are genuinely unreachable.

What that costs to remove: `SlotLabelTest` pins `C_0700_1100`, `C_0730_1130` and
`D_12_20` — three real defects where a label was wrong by up to sixteen hours —
and `assertLabelMatchesName()` guards the whole A/B/C/D scheme. Trimming deletes
34 values **and** the guard **and** the test that documents why the guard exists,
in exchange for less bloat. The E_* labels carry no times, so nothing survives
for the mechanism to check.

And the reason the plan wanted it first — that translating 34 unused labels is
work thrown away — **does not need it**. The app maps the four codes it knows and
falls through to the server's label for anything else, exactly as `_statusLabel`
already does for job status. So item 11's Slot half is done and item 4 is not,
which is the outcome the plan wanted by a route that risks nothing.

Do the trim when somebody has decided the A/B/C/D scheme is never coming back.
It is a product decision, not a cleanup.

### Item 7 — left alone

Splitting `OrganiserServiceImpl` (~2,400 lines) is a "consider", not a defect,
and a large mechanical reshuffle of the file where three of last session's bugs
lived is not something to do at the end of a long pass without a reason to.

---

# Part III — Reference

*Phases point here. Don't read this unless one sends you.*

## III.A Deferred by the product owner — do not re-litigate

| Item | Decision | Exposure if left |
|---|---|---|
| **T5.7 identity recovery** | Keep deferred (re-asked 2026-08-17) | **An earner who loses their phone loses everything** — work record, ratings, engagements — with no route back. Ops can rescue one user by hand; it does not scale. The cheap half (phone change verified through the old number) is still worth taking. |
| **T11.7 / D-5 `mysql-multitenancy` changes** | Leave the library alone — fix at config level | ⚠️ **This was recorded as `access-app` in PLAN-4 §6.3 and in earlier drafts here. Wrong library.** D-5 is about `mysql-multitenancy`, whose `MvcConfig` carries `@EnableWebMvc` — which makes `spring.mvc.*` and `spring.jackson.*` **inert**. That is not theoretical: it silently disabled the date-serialisation floor added in §20, found and fixed 2026-08-24 (PLAN-3 §29, `JacksonWebConfig`). Also open there: `@ComponentScan` on a package that does not exist, dead `getDatabaseContext()`, and a parent Boot version trailing the app's. The library is published and versioned, so config-level fixes in the app are preferred — but **check D-5 before trusting any `spring.mvc.*` or `spring.jackson.*` property.** |
| **T11.3 push / T11.12 masked calling** | Stubbed behind interfaces | Push is Phase 10. |
| **D-2 TaskChat** | Stays deferred | T4.9 phone reveal covers the need. Delete the placeholder (Phase 14). |
| **D-3 in-app payments** | Correctly out of scope | **Not** the same as Phase 3, which is a record, not a payment. |
| **D-6 multi-tenancy** | Inert by choice | — |
| **Random OTP + SMS delivery** | **Deferred again by the product owner, 2026-08-24** | Out of PLAN-5 entirely. The app is to be *completed* first; security and release-readiness come in a later plan. The path exists end to end — generation, bcrypt into Redis, rate limiting (T11.6), verification — and development uses a fixed `000000`. When it is picked up it needs an SMS provider (~₹0.12–0.25 a message) and **TRAI DLT registration, which takes days to weeks**, so start that paperwork before the code. |
| **D-7 instant hire, posting side** | **Not deferred — folded into Phase 12, 2026-08-24** | Found by `check-endpoint-callers.py`: the accepting half is built and `post-instant-job` has no caller, so the flag rides every job payload for something nobody can create. **An earlier draft recorded this as "deferred by the product owner" on 2026-08-19; that attribution was not accurate** and is corrected here. The owner's actual direction is that instant hire should not be a separate thing at all — scheduling for today at the current time *is* the instant hire. See Phase 12; detail in DEFERRED.md D-7. |

## III.B Known issues, unfixed

1. **`Task.amountPaid`** — declared, never written or read. Phase 3 / 14.
2. **`Slot` enum bloat** — 38 values for ~4 used; `A_0600_0730` and `E_1` are two
   schemes meaning different things. Label guard added; bloat remains.
3. **`OrganiserServiceImpl` ~2,400 lines** — where three of last session's bugs
   lived.
4. **`e.getMessage()` in user-facing text** in several services. Fixed on the
   paths verified to reach users (`registerAsProvider`, search/worksheet
   snackbars); the pattern remains elsewhere.
5. **No cache eviction on the device** — `CacheService` grows unbounded.
6. **Two endpoints recommended for deletion** — `get-statements`, `pause-task`.

## III.C Indian law and the documents

> **This is not legal advice and I am not a lawyer.** It is a map of the
> obligations a platform in this shape has, written so the right questions get
> asked. **An Indian lawyer must review the actual documents before a single real
> user signs up.**

**C.1 What Gasta legally *is* — get this right first.** Everything follows from
one framing, which must be in the terms **and true in the product**: **Gasta is
an intermediary, not an employer and not a staffing agency.** If a court or
labour inspector concludes otherwise, minimum wage, PF, ESI, gratuity and
termination obligations attach for every worker on the platform.

What keeps it honest, mostly already true:
- **Gasta is not in the payment path** — cash between two people. The strongest
  single fact in its favour, and why Phase 3 must stay a ledger.
- Gasta does not direct the work, set hours, or supervise.

⚠️ **Word §7.5 rate guidance carefully.** "People nearby pay ₹550–650" is
information. If it reads as instruction it starts to look like a platform setting
wages — employer-ish, and it touches competition law. Keep it descriptive, keep
it a range, never make it a default that fills a field. **And it must never
suggest below the state-notified minimum wage** — the ethical line and the
protective one are the same line.

**C.2 Child labour — the largest exposure.** Domestic work is prohibited under 14
and hazardous for 14–18 (Child and Adolescent Labour (Prohibition and Regulation)
Act). Needs: a real date of birth at signup, a hard block on under-18 earner
accounts, the prohibition in the terms, and a guard on `add-existing-worker`,
which creates a worker record from a phone number with no verification. Ops
tooling and the audit log already exist.

**C.3 Intermediary status.** To keep IT Act §79 safe harbour under the **IT
(Intermediary Guidelines) Rules 2021**: publish Terms and Privacy Policy
accessible without login; **appoint a Grievance Officer** with real name, email
and physical address published in the app; **acknowledge within 24 hours, resolve
within 15 days**; act on valid takedown orders within 36 hours; retain
registration data for 180 days after cancellation.

**C.4 Consumer Protection (E-Commerce) Rules 2020** apply on top — Gasta is a
marketplace e-commerce entity. Display legal name, address, customer care and
grievance officer; no unfair trade practice; do not misrepresent ratings. Their
clock is **48 hours to acknowledge, one month to redress**.

**C.5 DPDP Act 2023.** Newest and least covered — **there is no consent flow
today.** Needs: notice and consent before collection, itemised by purpose, in
Hindi as well as English; purpose limitation and minimisation (location is needed
by *one* screen); rights of access, correction and erasure; breach notification
to the Data Protection Board; verifiable parental consent for under-18s (another
reason C.2 is not optional); and a grievance route for data, which can be the
same officer.

**C.6 Labour and social security at scale.** Not blockers today, cheaper to
design for now. The **Code on Social Security 2020** defines *aggregators* and
its schedule contemplates domestic and other services — aggregators can owe
**1–2% of turnover** to a social security fund. Gasta has no turnover because it
takes no cut; the moment it does, this attaches. **POSH Act 2013**: a household
*is* a workplace for a domestic worker — the safety alert (T5.9) is the
mechanism, the policy is missing. **e-Shram**: encouraging registration helps the
worker and shows good faith.

**C.7 The documents.**

| Document | Notes |
|---|---|
| **Terms of Use** | Intermediary framing (C.1), prohibited uses, the under-18 rule, termination, limitation of liability, indemnity, governing law and a named Indian jurisdiction. |
| **Privacy Policy** | DPDP-shaped: what, why, how long, shared with whom, rights, officer. |
| **Worker terms** | Separate and **shorter**. The person with the least reading ability should not get the longest document. |
| **Conduct rules** | Harassment, discrimination, safety, what removes an account. |
| **Cancellation expectations** | Phase 9. Not a fee — an expectation and a record. |
| **Grievance page** | Officer name, address, email, SLA. |

Two drafting cautions: Indian consumer courts routinely read down one-sided
terms, so a reasonable limitation of liability protects more than an
over-reaching one. And **all of it must exist in Hindi** — an English-only
consent screen in front of this audience is the thing that looks worst in
hindsight.

## III.D Testing detail

**D.1 The regression table — the suite built from bugs that already happened.**
Every one passed both compilers. **All twelve now have a test** (Phase 1, merged
2026-08-24), and each was verified by reintroducing the original defect and
watching it fail — a guard that has never fired is not known to work. Kept here
because the list is also the argument for the layers in D.2, and because a new
one belongs in it the moment it is found.

| Bug | Test that catches it | Layer |
|---|---|---|
| `SERVICE_TYPE` NOT NULL vs a null-writing entity (×2 tables) | Save a non-laundry rate / order item against a real schema | Integration |
| `COALESCE` on a BIT column → `BigDecimal` projection failure | Call `get-nearby-jobs`, assert 200 | Integration |
| `t.INSTANT_HIRE` — column does not exist | Any execution of that native query | Integration |
| `findByActive…AndCrewAllOrNothing` — Spring reads `Or` as a keyword | Context loads | Integration |
| Three `Slot` labels 4–16 hours wrong | Label derived from the constant name | Unit (guard exists — keep both) |
| `givenOn` serialised as `[2026,8,10]` | Assert JSON shape of every date field | Contract |
| Earnings counted past-dated visits as future income | Fixed clock, visits either side of today | Unit |
| Unread badge counted one page, not the total | 40 unread → assert 40 | Contract |
| `crewAllOrNothing` lost because a screen built `Task` by hand | Parse a payload through *every* constructor | Widget |
| Auto-assigned order acceptable by nobody | assigned + PENDING → accept succeeds | Integration |
| Network failure cleared the session | `refreshAuthToken` against an unreachable host | Unit |
| Household member confirming a visit | Authorisation matrix (D.3) | Integration |

**D.2 Layers, and what each is for.**

- **Integration (Testcontainers) — highest value.** Native SQL against a real
  schema, migrations applying, entity/column disagreement, projections. Mocked
  repositories would have caught **none** of D.1.
- **Contract — one per endpoint (~90), five cases each:** happy path · wrong user
  · invalid input · not found · **response date/enum shape**. Add a meta-test
  that fails when an endpoint has **no caller in the app** — §6.7's audit was
  manual and the drift will recur.
- **Unit** for isolated logic: occurrence generation, the register's
  payable/unrecorded split, advance arithmetic, crew counting, rate banding,
  retention cutoffs. **Inject a fixed clock** — half of these are date logic and
  "today" is not a constant.
- **Widget** — `ApiState`'s four states per screen, plus overflow at 720×1280
  with the keyboard up, and `textScaler` 1.6.
- **Integration (Flutter)** — golden flows only, they are slow:
  1. sign in → today's visit → *On my way* → done
  2. post a job → quote → accept → visits appear
  3. register a provider → book doorstep → DELIVERED
  4. register → record an advance → other side agrees
  5. crew job with a group size → organiser answers the partial fill
  6. **offline → cold start → today's visit still readable**
- **Manual checklist** for what automation cannot see: contrast, icon
  correctness, Hindi truncation, and whether a sentence makes sense to somebody
  who reads slowly.

**D.3 The scenario matrix.** Test the axes that interact, not the cross product:
role (organiser · earner · both · household member · ops) × engagement state
(open · quoted · assigned · running · trial · ended · expired · partly-filled
crew) × network (online · offline-with-cache · offline-cold · slow) × data (empty
· one · many · long strings · Hindi) × time (before/during/after a visit, month
boundaries, a deadline passing).

**The authorisation matrix deserves its own exhaustive table:** for every
endpoint, assert what a *non-party* gets. §7.10 widened exactly one organiser
check out of 27 — a test should fail loudly if a twenty-eighth ever quietly opens.

**D.4 The rule worth adopting now.** A bug found by hand gets a test in the same
change that fixes it. Every row in D.1 exists because that was not the rule.

## III.E Measured against Urban Company / Yes Madam

Most of their feature list is deliberately not Gasta's — they optimise for
matching strangers quickly and taking a cut. Five things are universal, and four
are missing here:

- **(a) Household reliability is not tracked** while worker reliability is →
  Phase 9.
- **(b) The ID-verified badge is computed and shown nowhere** → Phase 8.
- **(c) No cancellation policy of any kind** → Phase 9.
- **(d) No receipt** → Phase 3.
- **(e) No grievance route with a name on it** → Phase 2, and a legal requirement
  rather than a nicety.

**What Gasta already does better and must not lose:** the safety alert during a
visit (T5.9), "Tell someone" sharing a visit, the visit code at the door, the
attendance register, and advances. None of the comparison apps have the last two
and they cannot easily — those depend on the relationship being the unit.

**Still missing product-wide:** onboarding (a language picker and a role
question, then the user is alone); help content ("Get help" exists and is empty);
dispute resolution (days can be flagged and advances disputed, and then nothing
happens — ops has a queue and an audit log, connect the ends); account deletion;
analytics (nothing is measured, so nothing about real usage is knowable —
self-hosted Plausible or Umami if cost is the objection); and an e-Shram nudge.

## III.F Blocked, and why

| Item | Blocked by |
|---|---|
| **§7.6 spoken alerts / T9.5 voice input** | No TTS or speech plugin in `~/.pub-cache`; adding one needs network **plus** a Gradle sync. The highest-value accessibility feature for this audience — revisit the moment the toolchain allows. |
| **§7.6 voice notes** | Also needs T11.8 file storage. |
| **T11.8 file / image storage** | Not started. Blocks voice notes, ID photos, before/after pictures. |
| **Spring Boot Actuator** | Only 3.1.2 and 4.1.0 are cached against a 3.3.3 app, and the build runs offline — it would fail to resolve or silently mix versions. `HealthController` covers the need meanwhile. |

**Push transports** (Phase 10):

| Option | What it actually costs |
|---|---|
| **FCM** | A Google dependency. **Free** — no paid tier for this. Survives Doze and OEM battery killers, which is the whole problem. |
| **ntfy** (self-hosted) | A server — but the backend needs one anyway, so marginal cost is near zero. Open source, good. The app holds a subscription, so the OEM-killer problem returns. |
| **Gotify** | As ntfy, smaller ecosystem. |
| **UnifiedPush** | Right idea; almost nobody in this market has a distributor installed. |
| **Persistent WebSocket** | Free, and **least reliable on these phones.** Xiaomi/Oppo/Vivo/Realme kill background sockets. We watched `lowmemorykiller` reap this app during testing — same mechanism. |
| **Polling** (WorkManager, 15-min floor) | Free, survives everything, up to 15 minutes late, costs battery. |

---

## Appendix — how the last session went

Twelve items delivered and verified. The pattern worth carrying: **almost every
real defect was found by looking at the screen with real data in it**, not by
reading code or trusting a build.

- "Still to come: 67 days, ₹35,100" included 31 days that had already passed.
- Registering any non-laundry doorstep provider had **never been possible**.
- An auto-assigned order could be placed and then accepted by nobody.
- Losing signal at launch **logged users out** of an app they could not then log
  back into.
- Three `Slot` labels said times four to sixteen hours wrong.

Every one compiled cleanly and passed the analyzer.
