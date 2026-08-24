# PLAN-5 — Gasta

**The entry point for every new session.** PLAN-4 was the previous one;
everything it left outstanding is either done or carried here.

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
| §G — Success gaps | ◐ §7.6 blocked, §7.8 handover → Phase 13 |

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

## Phase 3 — The wage-payment ledger ⚠️ biggest product hole

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

---

## Phase 4 — Hindi where the money is

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

---

## Phase 5 — Progressive disclosure on three screens

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

---

## Phase 6 — A Today tab, and notifications to a bell

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

---

## Phase 7 — Icons and infographics

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

---

## Phase 8 — The one screen that unlocks four endpoints

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

---

## Phase 9 — Fairness both ways

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

## Phase 11 — Deployment and store readiness

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

---

## Phase 12 — The posting flow: scheduling, instant hire, and choosing

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

---

## Phase 13 — The handover

**Goal.** "She is leaving on the 30th."

**Why now.** T5.1 covers *temporary* cover; there is nothing for a permanent
departure — which is exactly when a household is most likely to leave the
platform and replace her the old way. The trial-check-in half of §7.8 is already
done.

**Steps.** Notice → post the replacement with an **overlap** → the outgoing
worker shows the incoming one what to do. **That overlap is what actually makes
a handover work**, and it is worth paying for.

**Size:** M.

---

## Phase 14 — Pay off the known issues

Small, independent, safe to do in any gap. Detail in III.B.

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
10. **Appoint and configure a Grievance Officer.** `gasta.legal.grievance-*` are
    blank; the complaint screen degrades to showing the SLAs with no name on
    them. The IT Rules 2021 require a named person with a contact address.

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
