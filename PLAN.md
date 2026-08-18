# Gasta — Phased Implementation Plan (Phase 2 onward)

Companion to [AUDIT.md](AUDIT.md). The audit's §5 is a *prioritised inventory* (what + how big). **This document is the executable spec**: exact fields, endpoints, DTO shapes, file paths, and acceptance checks, written so an implementing model (Sonnet-class) can build each task without re-deriving design decisions.

Detail level is deliberately uneven: **Phases 0–3 are fully specified** (that's the next real work). Phases 4–11 are concrete but lighter, and get expanded to full detail when their turn arrives — writing 100% of Phase 6 now would be guesswork, since Phase 1 will teach us things.

---

## START HERE (read this first)

**Reading order:** all of §0 (it is short and it prevents the three most likely failures), then §2 Phase 0, then §3 Phase 1. Do not skim §0.2 or §0.3.

**Work order — do not reorder:**

```
T0.7 (finish build guard) → T0.6 (pool, one line) → T0.8 (ordering) → T0.1 → T0.2 → T0.3 → T0.4 → T0.5
   → then Phase 1: T1.1 → T1.2 → T1.3 → T1.4 → T1.5 → T1.6 → T1.7 → T1.8
```

**One task at a time.** Each task has a *Files*, *Spec*, *Acceptance* and *Migration* line. Run the acceptance checks before moving on, and tick the row in §14. If a task's spec turns out to be wrong or impossible, **stop and report** rather than improvising a different design — the specs encode decisions the product owner already approved.

**Already applied to the codebase** (do not redo, do not revert):

| Change | Why | Where it's tracked |
|---|---|---|
| Stripped UTF-8 BOM from `JeevikaService/.../serviceimpl/DoorstepServiceImpl.java` | **The backend did not compile without it** (`illegal character: '﻿'`) | T0.7 (encoding pin + CI guard still to do) |
| Numeric keyboards + digit-only/length formatters on phone, OTP and amount fields; `.trim()` on submit | Phone field opened a QWERTY keyboard, and a stray trailing space silently failed login with a misleading "check mobile number" error | T6.13 (rest of that task still to do) |
| Removed now-redundant `dart:typed_data` import in `widgets.dart` | Lint introduced by the line above | — |

Files touched: `Yapan/lib/widgets.dart`, `Yapan/lib/commons/text_widgets.dart`, `Yapan/lib/screens/login_screen.dart`, `signin_screen.dart`, `signup_screen.dart`, `worksheet_screen.dart`, `new_task_page.dart`, and `JeevikaService/.../DoorstepServiceImpl.java`. Verified: `flutter analyze` reports no errors (146 pre-existing infos/warnings, no new ones) and the backend boots.

**Verify your environment before writing code** — §0.10 has the exact working recipe (JDK 17 required; MySQL and Redis are started by the product owner each day; do **not** launch database containers).

---

## 0. How to use this plan

### 0.1 Ground rules (non-negotiable, from the product owner)

| Rule | Meaning in practice |
|---|---|
| **Evolve, don't rewrite** | "acd → ABCD/abcdefg" is fine; "acd → wxyz" is not. Keep `TaskSchedule` pattern storage, the `CustomResponse` envelope, `setState`-based Flutter screens, the existing service/serviceimpl split. |
| **Don't touch `access-app` or `super-methods`** | They are Maven jars. Read them for contracts; never edit. All changes land in `JeevikaService/` and `Yapan/`. |
| **OTP / auth stay mocked** | No SMS provider, no auth hardening work. `access-app-otp=false` → OTP is `000000`. Do not "fix" this. |
| **Payments are out of scope** | Capture the attendance data payments will later settle against; build no payment flow, no gateway, no wallet. |
| **Client caching stays and grows** | `SharedPreferences` + TTL (as in `CategoryService`) is the intended approach — it protects the backend. Never replace it with always-fetch. Extend it to more catalog data. |
| **API response *shape* is intentional** | `{message, payload, status, localDateTime}` is correct. Do not restructure it. Route *naming* may be improved where the plan says so. |
| **UI changes must reduce friction** | Primary users are low-literacy. Fewer taps, bigger targets, clearer words, more icons. Never add a field or step that isn't required. |
| **Controls stay put** | Many users are rural and unskilled, and navigate by *position*, not by reading. No horizontally-scrolling chip rows, no controls that move, no lists that reorder themselves. **[DESIGN-RULES.md](DESIGN-RULES.md) is binding on every UI task in every phase** — read §6's checklist before writing a screen. |

### 0.2 Three runtime constraints that will silently break naive code

These were verified in the source and are the most likely cause of a failed first attempt:

1. **`GenericResponseMethods` cannot be called outside an HTTP request.**
   It `@Autowired`s `HttpServletRequest` and calls `getLocalAddr()` in both `infoLogger` and `errorLogger`. From a `@Scheduled` method or any background thread this throws. → Background code must use its own SLF4J logger and must not build `CustomResponse`.
2. **`accessService.getUser()` cannot be called outside an HTTP request.**
   It reads the Spring Security context, which is request-bound (`STATELESS_JWT`). → Any service method that background code shares must accept the acting user (or `taskId`/`earnerId`) as an explicit parameter rather than calling `getUser()` internally.
3. **Multitenancy does NOT block background jobs — resolved, see §0.9.**
   `DBContextHolder` is a `ThreadLocal` set from a `db` request header by an MVC interceptor, and `MultiRoutingData` registers a **default target datasource**. `AbstractRoutingDataSource` falls back to that default whenever the lookup key is `null` — which is *always*, because the Flutter app never sends a `db` header. So background threads resolve exactly the same datasource as requests.
   → Background code should still be explicit: `DBContextHolder.setCurrentDb("one")` in a `try`, `DBContextHolder.clear()` in the `finally`.
   → **Phase 1 stays request-triggered anyway** (simpler, no clock to reason about), but scheduling is now a supported option from Phase 3 onward (T3.6) — **once T0.6 raises the connection pool above 1**.

### 0.3 Database migration reality

- `spring.jpa.hibernate.ddl-auto=update`. Hibernate **adds** tables/columns. It does **not** drop columns, rename them, or reliably change nullability of existing columns.
- Adding a `nullable = false` column to a table that already has rows **fails** on MySQL unless a default exists. → New non-null columns on populated tables (`task`, `task_schedule`, `pickup_drop_order`) must be declared **nullable in the entity**, backfilled, and only tightened later if ever. Comment `// nullable for backfill; see PLAN.md §0.3` where this applies.
- **`task_job` is safe to recreate.** It is an `@Entity`, so the table exists, but nothing ever inserted a row (AUDIT §2.5). Phase 1 changes its column nullability. **Instruction:** before first run of Phase 1, in the dev DB execute `DROP TABLE IF EXISTS task_job;` and let Hibernate recreate it. Zero data loss — verify with `SELECT COUNT(*) FROM task_job;` first (expect 0).
- No Flyway/Liquibase. Every DDL-affecting task must state its manual dev-DB step explicitly.

### 0.4 Backend conventions cheat-sheet (copy these patterns)

**Controller** — thin, `private` methods, delegates immediately, passes an `apiName` string:

```java
@RestController
@RequestMapping("/api/v1/yapan/earner")
public class EarnerController {
    @Autowired
    EarnerService earnerService;

    @GetMapping("/get-my-visits")
    private ResponseEntity<CustomResponse> getMyVisits(
            @RequestParam(defaultValue = "today") String filter) {
        return earnerService.getMyVisits("get-my-visits", filter);
    }
}
```

**Service impl** — `try/catch`, `accessService.getUser()` for identity, response via `genericResponseMethods`:

```java
@Override
public ResponseEntity<CustomResponse> getMyVisits(String apiName, String filter) {
    try {
        UserData user = accessService.getUser();
        // ... work ...
        return genericResponseMethods.successResponse(apiName, "Records fetched.", payload, user.getUsername());
    } catch (CustomException ce) {
        return genericResponseMethods.errorResponse(apiName, ce.getMessage(),
                HttpStatus.BAD_REQUEST, ce.getMessage(), accessService.getUser().getUsername());
    } catch (Exception e) {
        return genericResponseMethods.errorResponse(apiName, "Could not fetch records: " + e.getMessage(),
                HttpStatus.INTERNAL_SERVER_ERROR, e.getMessage(), accessService.getUser().getUsername());
    }
}
```
Exact signatures available (verified): `successResponse(String api, String msg, Object payload, String username)` and `errorResponse(String api, String msg, HttpStatus status, Object payload, String username)`, each with an extra `HttpHeaders` overload. `errorResponse` already prefixes `"Error: "` — don't add your own.

**Entity** — Lombok `@Data`, `UPPER_SNAKE` columns, `IS_`/`HAS_` prefix for booleans, `@JsonFormat` on datetimes:

```java
@Column(name = "OCCURRENCE_DATE", nullable = false)
private LocalDate occurrenceDate;

@Enumerated(EnumType.STRING)
@Column(name = "STATUS", nullable = false)
private JobStatus status;
```

**Repo** — Spring Data derived queries; underscore to traverse relations (`findByEarner_IdAndActive`). Add `@Query` only when derived naming can't express it.

**New service area** = interface in `service/` + impl in `serviceimpl/`, both registered by the existing `@ComponentScan`.

### 0.5 Flutter conventions cheat-sheet

1. **Every endpoint gets a `Constants` entry** in `Yapan/lib/util/constants.dart`. No inline URL strings (AUDIT §2.24 is the counter-example — don't copy it).
2. **All calls go through `ApiService().httpRequest(...)`** — it handles auth headers and the 412-refresh-retry. Never use `http` directly.
3. **Typed model per payload** in `Yapan/lib/model/` with a `fromJson` factory (follow `task_summary.dart` / `pickup_drop_order.dart`; do **not** follow the `dynamic` map style flagged in AUDIT §4.23).
4. **Screen state pattern**: `bool isLoading`, `bool _hasError`, fetch in `initState`, `Widgets.buildErrorRetry(onRetry: _fetch, message: ...)` on failure, empty-state widget when the list is empty.
5. **Standard response check**: `if (res.success && res.data!.statusCode == 200)` then `json.decode(res.data!.body)['payload']`.
6. **Reuse `Widgets`/`TextWidgets`/`DateTimeWidgets` helpers** rather than hand-rolling chips, dropdowns, toggles.
7. **No `print()`** in new code.

### 0.6 New `NotificationType` values must be registered in BOTH places

Backend enum `com.actually.yapan.enums.NotificationType` currently holds exactly: `JOB_POSTED, QUOTE_RECEIVED, QUOTE_ACCEPTED, QUOTE_REJECTED, QUOTE_REVOKED, JOB_ASSIGNED, JOB_STARTED, JOB_COMPLETED, JOB_CANCELED, GENERAL`.

The app maps type → icon in `Yapan/lib/screens/notifications_screen.dart` `_iconMeta(String type)`, and currently handles all of those **except `JOB_STARTED` and `GENERAL`** (they fall through to a grey bell). **Rule: any task that emits a new type must add a `case` in `_iconMeta` in the same task.** Otherwise notifications ship looking broken.

`NotificationServiceImpl.sendNotification(user, title, message, type, referenceId)` is safe to call from anywhere — it only touches `notificationRepo` (no `accessService`, no `GenericResponseMethods`).

### 0.7 Definition of done (every task)

- [ ] Code compiles: `cd JeevikaService && ./mvnw -q compile` / `cd Yapan && flutter analyze` (no **new** issues).
- [ ] Any dev-DB step from the task's *Migration* line executed.
- [ ] Every acceptance check in the task passed manually (curl for API, app run for UI).
- [ ] No `printStackTrace()`, no `print()`, no commented-out leftovers introduced.
- [ ] New endpoints added to `Yapan/lib/util/constants.dart` if the app consumes them.
- [ ] Task's row ticked in §14 progress tracker.

### 0.8 Route-naming decision for new endpoints

Keep the existing `get-*` / verb-style identity (do not "RESTify" — that would be a `wxyz` change), **but put filters and ranges in query params, not path segments**. So: `GET /earner/get-my-visits?filter=today`, not `/earner/get-my-visits/today`. Existing path-segment filter endpoints stay untouched until Phase 6 (T6.9).

### 0.9 `mysql-multitenancy` — how it actually works, and the editing policy

Now in-repo at `mysql-multitenancy/` (artifact `com.actually:mysql-multitenancy:2.9`, Spring Boot parent 3.1.2). Read in full; here is the mechanism, because two consequences matter a great deal:

```
DataSourceInterceptor (HandlerInterceptor)
    reads request header "db"  →  DBContextHolder.setCurrentDb(value)   // ThreadLocal<String>

MultiRoutingDataSource extends AbstractRoutingDataSource
    determineCurrentLookupKey() → DBContextHolder.getCurrentDb()

MultiRoutingData @Bean getDataSource()
    setTargetDataSources(map of actually.datasources.*)
    setDefaultTargetDataSource(map.get(defaultDataSource))    // "one" — first key, lowercased
```

**Consequence 1 — tenancy is currently inert (and that's fine).** The lookup key comes from a `db` HTTP header that `ApiService` never sends (it sets only `Authorization`, `atsh`, `Content-Type`). A null key makes `AbstractRoutingDataSource` fall through to the default datasource. So today every request — and every background thread — uses `actually.datasources.one`. This is why §0.2.3 is resolved. It also means the multi-tenant capability is available later (e.g. per-city sharding) without any library change: the client or a server-side filter just has to start sending `db`. **Do not build that now.**

**Consequence 2 — the connection pool is 1.** `DataSourceProperties.setDataSources` does `ds.setMaximumPoolSize(1)` unless `max_hikari_pool_size` is present, and `JeevikaService/application.properties` does not set it. **The entire backend is serialised on a single DB connection.** This is the single biggest thing standing between this app and "big", it explains any sluggishness under concurrent use, and it is a one-line fix (T0.6). It is also a hard prerequisite for scheduling: a background job would otherwise hold the only connection and stall every request.

**Editing policy.** The library is yours, but it is a *published, versioned artifact* that other projects may consume, and `JeevikaService/pom.xml` pins `2.9`. Therefore:
- **Prefer config-level fixes** in `JeevikaService/application.properties` (T0.6 is one) — zero blast radius.
- **Library source changes need explicit approval** and a version bump (2.9 → 2.10) plus the matching `pom.xml` update, because they affect every consumer. Tasks that would need this are isolated in T11.7 and are not required by Phases 0–10.
- Known library-level oddities, deliberately **not** touched by this plan: `MvcConfig` carries `@EnableWebMvc` (which switches off Spring Boot's WebMvc auto-configuration — see R9); `@ComponentScan("com.actually.controller")` scans a package that doesn't exist here; `DataSourceProperties.getDatabaseContext()` reads a static map that `setDataSources` never populates, so it always throws (dead code); parent Boot version 3.1.2 vs JeevikaService's 3.3.3.

### 0.10 Live-run verification (the whole stack was actually run)

Backend + app were brought up and driven end-to-end. **This section is evidence, not speculation** — it replaces several "verify at implementation time" notes elsewhere.

**Working environment (reproduce with this):**

| Piece | Value |
|---|---|
| MySQL + Redis | **The product owner starts these each day before work begins** — MySQL runs host-native on 3306 (8.0.39, `root` / `my$ql`, database `gasta`), Redis runs as a Docker container on 6379. **Do not start containers for either**; the ports will already be taken. If a connection fails, ask rather than launching your own. |
| JDK for the backend | `C:/Program Files/Java/jdk-17` — **must** set `JAVA_HOME`; the machine default is JDK 26, which Boot 3.3.3 does not support |
| Build/run | `cd JeevikaService && JAVA_HOME=... ./mvnw -o spring-boot:run` (all three private artifacts are already in `~/.m2`: access-app 2.1.2, super-methods 2.0.9, mysql-multitenancy 2.9 — `-o` offline works) |
| Emulator | AVD `Small_Phone`, 720×1280, `emulator -avd Small_Phone`; app reaches the host backend via the existing `10.0.2.2:8080` base URL — no change needed |
| Login | phone `8191910695`, OTP `000000` (super-user, already in `app_users`) |
| Pre-grant to skip permission dialogs | `adb shell pm grant com.tomer.yapan android.permission.ACCESS_FINE_LOCATION` (+ `ACCESS_COARSE_LOCATION`), then `adb emu geo fix 77.2090 28.6139` |

**Empirically confirmed (previously assumptions):**

| Claim | Evidence |
|---|---|
| `task_job` is empty → safe to drop in T0.3 | `SELECT COUNT(*) FROM task_job` = **0**. R3 closed. |
| `task_chat` table does not exist | absent from `information_schema.tables` — confirms the missing `@Entity` (AUDIT §2.4) |
| **Connection pool really is 1** | boot log shows `HikariPool: one - Added connection` exactly once. R2 confirmed; T0.6 justified. |
| Dashboard Done/Withdrawn are structurally 0 | live screenshot: `Services Posted 1` · Open 1 · Assigned 0 · **Done 0** · **Withdrawn 0** |
| Hardcoded D.O.B ships to users | Profile screen shows `D.O.B  12-05-1990` (AUDIT §2.21) |
| `ONCE` schedules carry no slot | wizard step 2 with "Once" selected shows a date + time picker and **no slot list** — validates the T1.1 rule that ONCE yields `slot = null` |
| Slot labels diverge app↔backend | app shows "Early Morning (Up to 9am)"; backend `Slot.E_1` is "Early Morning Slot" (R8) — the code+label `VisitDto` design is the right call |
| Current DB state to test against | 1 user, 1 task, 1 task_schedule, 1 address, 50 professions, 104 sub-professions, 36 states, 3 doorstep orders, 0 quotes, 0 notifications |

**New UI findings from the live run**, each routed to a task:

| # | Finding | Handled by |
|---|---|---|
| U1 | **The backend did not compile.** A UTF-8 BOM on `DoorstepServiceImpl.java` made javac fail with `illegal character: '﻿'`. Fixed during this run (3 bytes stripped, file otherwise byte-identical). `job_sheet_screen.dart` has one too but Dart tolerates it — the app built and ran fine. | **T0.7** |
| U2 | **Profession list order is non-deterministic.** Two consecutive loads of Home showed different "Popular pros": *Maid / Makeup Artist / Electrician*, then *Agricultural Machinery / Farm Laborer / Automobile Mechanic*. `findByEnabled(true)` has no `ORDER BY`. For users who navigate by **position and picture rather than reading**, a grid that reshuffles every launch is actively hostile — and it makes acceptance testing unreproducible. | **T0.8** |
| U3 | Mobile-number and OTP fields open a **full QWERTY keyboard**, not a numeric keypad — the user must find `?123` to type their own phone number. | T6.13 |
| U4 | Single-select slot lists render as **checkboxes** (`checkBoxGroup(allowSingleSelect: true)`), so ticking one silently unticks another. Checkbox affordance promises multi-select. Should be radios when single-select. | T6.13 |
| U5 | **Every tab switch destroys and rebuilds the screen** and refetches — `BottomNavigation` renders `_screens[_currentIndex]` directly instead of an `IndexedStack`, so scroll position, filters and loaded data are lost each time. Confirms AUDIT §4.22 live. | T6.13 |
| U6 | Day chips are single letters `M T W T F S S` — two ambiguous `T`s and two `S`s, and unreadable for non-English users. | T9.4 |
| U7 | `_screens` and `_iconPaths` are crossed at indices 1 and 2: the Earning Zone tab wears `job_sheet.svg` and the Dashboard tab wears `work.svg`. Cosmetic but confusing. | T6.13 |
| U8 | Login/OTP screens: no resend-OTP, no timer, no back affordance from the OTP step, and a large dead area between the field and the bottom button. | T6.13 |
| U9 | **A trailing space silently breaks login.** Reported by the product owner mid-run (they hand-removed it on the emulator). Nothing trimmed or constrained the phone/OTP fields, so one stray space made the lookup miss and surfaced the misleading "Could not send OTP, please check mobile number and try again." A low-literacy user would simply be stuck with no idea why. **Fixed:** digit-only + length formatters make spaces unenterable, and `.trim()` guards paste; verified on device by typing `8191910695` + two SPACE presses + `12345` and getting exactly `8191910695`. Server-side validation of phone/OTP shape is still absent (AUDIT §3.12). | ✅ fixed; server-side validation → T6.13 |

---

## 1. Phase map

Phases 0–5 make the operational core real. Phases 6–11 are what turn a working prototype into a product that can carry real supply, real demand, and a real ops team — the "make it big" half.

| Phase | Goal | AUDIT items | Size | Gate to next phase |
|---|---|---|---|---|
| **0** | Prerequisites: unblock scale (pool=1!) + fixes that would corrupt operational data | C-B2, part of 4.19, D3, §0.9 | S | Occurrence data can't be built on a wrong date, backend isn't single-threaded |
| **1** | **Occurrence engine** — recurring schedules become dated visits | OP1 | L | Visits visible in app for today/tomorrow/later |
| **2** | Visit workflow, attendance, task completion, ratings | OP5, B1, B3 | L | A visit can go Scheduled → Completed with a rating |
| **3** | Leave, skip/pause, reminders (+ real scheduling) | OP2, OP4, OP6a | M/L | Organiser learns of leave without anyone no-showing |
| **4** | Doorstep re-confirmation, expiry, cancel + auto-recovery | OP6b, OP8, OP9 | M/L | Stale commitments self-heal |
| **5** | Substitute earner, reschedule, availability windows | OP3, OP7, OP10, B5 | L | Multi-day leave gets covered |
| **6** | Correctness, authz, N+1s, caching consolidation | D1–D14, C-B1/3/4/5/6/7/8 | L | Safe to put real load and real users on it |
| **7** | **Trust & reputation** — verified, rated, profiled earners | B1 (extends), §3.2 | L | An organiser can tell two earners apart |
| **8** | **Demand & liquidity** — rebook, instant hire, price guidance, serviceability | §3.5, §3.8, §3.10 | L | Tasks get filled fast and repeatedly |
| **9** | **Accessibility & language** — Hindi + regional, icon-first, voice | B7, §3.6 | L | A low-literacy user can complete a booking unaided |
| **10** | **Ops & support platform** — tickets, admin, disputes, ops queues | §2.2, C-B8 | L | A support team can run the marketplace |
| **11** | Scale & platform hardening — pagination, migrations, push, observability | B6, E1–E6, R3 | L | — |

Phase 0 exists because two flagged bugs would poison every occurrence generated afterwards, and because the one-connection pool discovered in §0.9 caps everything built later; it is a prerequisite, not a reordering of the feature-first priority.

---

## 2. Phase 0 — Prerequisites & data-integrity fixes

**Why first:** T0.7 is because **the backend does not compile as committed**. T0.6 is the highest-value single line in this document — the backend runs on **one** DB connection. T0.1 means every "Once" task records the wrong date, so generating occurrences from that data would bake the bug into `task_job` permanently. T0.2 crashes the endpoint the earner UI calls. T0.3/T0.4 are the scaffolding Phase 1 needs. T0.8 makes acceptance testing reproducible.

**Order: T0.7 → T0.6 → the rest.**

---

### T0.7 — Make the build reproducible (U1) ⚠️ **already applied during the live run**

**Goal:** the backend compiles from a clean checkout, and a BOM can never break it again.

**What was already done:** `JeevikaService/.../serviceimpl/DoorstepServiceImpl.java` began with a UTF-8 BOM (`EF BB BF`), which made `javac` fail with `illegal character: '﻿'` and `class, interface, enum, or record expected`. **The build was broken before any of this plan's work started.** During the live run the 3 BOM bytes were stripped (41519 → 41516 bytes, remainder byte-identical, first line now `package com.actually.yapan.serviceimpl;`). This is the one code change made outside the phase plan; it is disclosed here because without it nothing else could be verified.

**Remaining work:**
1. Pin the source encoding so platform default never decides, in `JeevikaService/pom.xml` under `<properties>`:
```xml
<project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
<project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
```
2. `Yapan/lib/screens/job_sheet_screen.dart` also carries a BOM. Dart tolerates it (the app built and ran), so this is **optional cleanup**, not a fix. Strip it with `tail -c +4` if touching the file anyway.
3. Both BOM files also contain mojibake in comment banners (`â•â•â•`, `â”€â”€â”€` where box-drawing characters were double-encoded). Harmless — they are inside comments. Clean opportunistically; do not make a dedicated pass.
4. Guard: this check belongs in whatever CI eventually exists —
```bash
for f in $(find JeevikaService/src Yapan/lib -name "*.java" -o -name "*.dart"); do
  [ "$(head -c 3 "$f" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ] && echo "BOM: $f" && exit 1
done; echo "no BOMs"
```

**Acceptance:** `cd JeevikaService && JAVA_HOME=<jdk-17> ./mvnw -o -q compile` succeeds with no `illegal character` errors; the BOM scan prints `no BOMs` (or only the tolerated Dart file).

**Size:** S · **Touches:** API build

---

### T0.8 — Deterministic catalog ordering (U2)

**Goal:** the same catalog request returns the same order every time.

**Why it belongs in Phase 0:** it is a one-line-per-query change, it is a genuine accessibility issue for users who navigate by position and picture rather than by reading, and **every later acceptance check that says "tap the first profession" is unreliable until it is fixed**. It is also a prerequisite for the T6.10 client cache to be useful — otherwise cached and freshly-fetched data disagree on order and the grid jumps.

**Files:** `repo/ProfessionRepo.java`, `repo/SubProfessionRepo.java`, and the read methods in `serviceimpl/OrganiserServiceImpl.java` / `DoorstepServiceImpl.java`

**Spec:** give every catalog read a stable sort. Prefer derived-name ordering so no method bodies change:

```java
List<Profession> findByEnabledOrderByNameAsc(Boolean enabled);
List<Profession> findByEnabledAndCategoryInOrderByNameAsc(Boolean enabled, List<ProfessionCategory> categories);
List<Profession> findByEnabledAndSupportsPickupDropOrderByNameAsc(Boolean enabled, Boolean supportsPickupDrop);
List<SubProfession> findByEnabledOrderByNameAsc(Boolean enabled);
List<SubProfession> findByEnabledAndProfessionOrderByNameAsc(Boolean enabled, Profession profession);
```
Update the call sites (`getHomeScreenProfessions`, `getHomeScreenCategories`, `getProfessionsByCategory`, `getProfessionsFromRelatedCategories`, `getProfessionsGroup`, `getSubprofessionsByProfession`, `getAllSubprofessions`, `getProviderEligibleProfessions`, `getDoorstepProfessions`). Keep the old method names deleted rather than left dangling.

Alphabetical is a placeholder for *stable*, not a claim that it's the best order — **real popularity ordering is T8.6**. Name the constant/comment accordingly so nobody mistakes this for the final product decision.

**Acceptance:** call `get-home-screen-professions` three times → byte-identical `payload` order each time; kill and relaunch the app twice → "Popular pros" shows the same six professions in the same positions.

**Size:** S · **Touches:** API

---

### T0.6 — Raise the Hikari pool above 1 (§0.9, consequence 2) ⚠️ **do this first**

**Goal:** stop serialising the whole backend on a single database connection.

**Why:** `DataSourceProperties.setDataSources` in `mysql-multitenancy` calls `ds.setMaximumPoolSize(1)` whenever `max_hikari_pool_size` is absent, and it is absent. Every concurrent request queues behind one connection. Nothing built in later phases can scale past this, and enabling scheduling (T3.6) before fixing it would let a background job block all traffic.

**Files:** `JeevikaService/src/main/resources/application.properties` — **config only, no library edit** (§0.9 editing policy).

**Spec:** add to the existing `##DB Config` block, beside the other `actually.datasources.one.*` keys:

```properties
actually.datasources.one.max_hikari_pool_size=20
```
The key is read as a raw string from the property map and parsed with `Integer.parseInt`, so it must be a plain integer with no units. Keep the name exactly as spelled (underscores) — the map keys are not relaxed-bound.

Pick 20 for dev; size it later as `((core_count * 2) + effective_spindle_count)` and never above what MySQL's `max_connections` allows across all app instances.

**Acceptance:**
1. Boot the app and confirm the Hikari log line reports the new size: look for `HikariPool-1 - configuration: ... maximumPoolSize................20` (Hikari logs its config at pool start; enable `logging.level.com.zaxxer.hikari=DEBUG` temporarily if it isn't visible).
2. Sanity check concurrency — 10 parallel calls to a real endpoint should not serialise:
```bash
for i in $(seq 1 10); do curl -s -o /dev/null -H "Authorization: $TOKEN" -H "atsh: $ATSH" \
  "http://localhost:8080/api/v1/yapan/organiser/get-dashboard" & done; wait
```
3. `SHOW STATUS LIKE 'Threads_connected';` in MySQL rises above 1 during that burst.

**Size:** S (one line) · **Touches:** API config

---

### T0.1 — Fix the "Once" task date bug (AUDIT §2.18, C-B2)

**Goal:** the date the organiser picks is the date submitted.

**Files:** `Yapan/lib/screens/new_task_page.dart`

**Spec:** `DateTimeWidgets.singleDatePicker(taskDate, context, _dateController)` writes the picked value only into `_dateController.text`; `submit()` reads the `taskDate` field, which never changes. Two options — take (a):

(a) Add an `onChanged` callback to `singleDatePicker` in `Yapan/lib/commons/date_time_widgets.dart`:

```dart
Widget singleDatePicker(String defaultDate, BuildContext context,
    TextEditingController controller, {Function(String)? onDatePicked}) {
  // ... inside the picker's onPressed, after formatting:
  controller.text = DateFormat('dd-MMM-yyyy').format(pickedDate);
  if (onDatePicked != null) onDatePicked(controller.text);
}
```
Then in `new_task_page.dart`:
```dart
dateTimeWidgets.singleDatePicker(taskDate, context, _dateController,
    onDatePicked: (v) => setState(() => taskDate = v)),
```
Keep the parameter optional so no other call site breaks.

**Acceptance:**
1. Post a task with repeat = Once, date = **3 days from today**.
2. `SELECT FULL_DATE FROM task_schedule ORDER BY ID DESC LIMIT 1;` → shows the picked date, not today.

**Size:** S · **Touches:** UI

---

### T0.2 — Fix `getTaskSchedule` crash + wrong daily strings (AUDIT §4.19, partial)

**Goal:** the endpoint the earner job-detail screen calls stops throwing and stops mislabelling daily schedules. (Full replacement with structured data is T6.7 — this is the minimal correctness fix.)

**Files:** `JeevikaService/src/main/java/com/actually/yapan/serviceimpl/EarnerServiceImpl.java`

**Spec:**
1. Guard the empty case — `res.get(0)` currently throws `IndexOutOfBoundsException` when a task has no schedule rows:
```java
List<TaskSchedule> res = taskScheduleRepo.findByTask_IdAndActive(Long.parseLong(taskId), true);
if (res.isEmpty()) {
    return genericResponseMethods.successResponse(apiName, "Records fetched successfully.",
            "Schedule not available for this task.", accessService.getUser().getUsername());
}
```
2. In the `REPEAT_DAILY` branch, `week` is computed with the **same `Day.SAT` filter as `sat`** (copy-paste bug), so weekday slots render as Saturday's. Fix to read the weekday pattern row:
```java
String week = res.stream()
        .filter(t -> t != null && (t.getDay() == Day.WEEKDAYS || t.getDay() == Day.ALL))
        .findFirst()
        .map(TaskSchedule::getSlots)
        .orElse(null);
```
3. Leave the rest of the string-building alone.

**Acceptance:** `GET /api/v1/yapan/earner/get-task-schedule/{id}` on (a) a daily task → weekday slots correct; (b) a task id with no schedule rows → 200 with the fallback message, no 500.

**Size:** S · **Touches:** API

---

### T0.3 — `JobStatus` enum + `TaskJob` extension + `TaskJobRepo` (scaffolding for OP1)

**Goal:** make `TaskJob` able to represent a dated, status-bearing visit.

**Migration:** run `SELECT COUNT(*) FROM task_job;` (expect 0), then `DROP TABLE IF EXISTS task_job;`. Hibernate recreates it on boot (see §0.3).

**Files:**
- create `JeevikaService/src/main/java/com/actually/yapan/enums/JobStatus.java`
- modify `JeevikaService/src/main/java/com/actually/yapan/entity/TaskJob.java`
- create `JeevikaService/src/main/java/com/actually/yapan/repo/TaskJobRepo.java`

**Spec — `JobStatus`** (label pattern copied from `PickupDropStatus`):

```java
package com.actually.yapan.enums;

public enum JobStatus {
    SCHEDULED("Scheduled"),
    ON_THE_WAY("On the way"),
    ARRIVED("Arrived"),
    IN_PROGRESS("Work started"),
    DONE_BY_EARNER("Marked done, awaiting confirmation"),
    COMPLETED("Completed"),
    EARNER_LEAVE("Earner on leave"),
    SKIPPED_BY_ORGANISER("Skipped"),
    MISSED("Missed"),
    CANCELED("Canceled");

    private final String label;
    JobStatus(String label) { this.label = label; }
    public String getLabel() { return label; }
    @Override public String toString() { return this.label; }
}
```

**Spec — `TaskJob` additions.** Keep every existing field. Add:

```java
@ManyToOne
@JoinColumn(name = "TASK_SCHEDULE_ID")
private TaskSchedule taskSchedule;          // which pattern row produced this occurrence

@Column(name = "OCCURRENCE_DATE", nullable = false)
private LocalDate occurrenceDate;           // the visit date

@Column(name = "OCCURRENCE_TIME")
private LocalTime occurrenceTime;           // only for ONCE/date-based rows carrying a time

@Enumerated(EnumType.STRING)
@Column(name = "STATUS", nullable = false)
private JobStatus status = JobStatus.SCHEDULED;

@Enumerated(EnumType.STRING)
@Column(name = "CANCEL_TYPE")
private CancelType cancelType;              // reuse existing enum for leave/skip vocabulary

@Column(name = "STATUS_NOTE", columnDefinition = "TEXT")
private String statusNote;                  // leave/skip reason
```

Two changes to existing fields:
```java
@Enumerated(EnumType.STRING)
@Column(name = "SLOT")                      // was nullable=false — ONCE tasks carry no slot
private Slot slot;

@ManyToOne
@JoinColumn(name = "UPDATED_BY")            // was nullable=false — generator has no acting user
private UserData updatedBy;
```

Replace the index and add the idempotency backstop:
```java
@Table(name = "task_job",
    indexes = {
        @Index(columnList = "EARNER_ID, OCCURRENCE_DATE, STATUS"),
        @Index(columnList = "TASK_ID, OCCURRENCE_DATE"),
        @Index(columnList = "ORGANISER_ID, OCCURRENCE_DATE")
    },
    uniqueConstraints = @UniqueConstraint(
        name = "uq_job_task_date_slot",
        columnNames = {"TASK_ID", "OCCURRENCE_DATE", "SLOT"}))
```
> **Caveat to document in a code comment:** MySQL treats `NULL`s as distinct in unique constraints, so slot-less (ONCE) occurrences are not protected by this constraint. The authoritative duplicate guard is the application-level existence check in T1.2.

**Spec — `TaskJobRepo`:**

```java
@Repository
public interface TaskJobRepo extends JpaRepository<TaskJob, Long> {

    List<TaskJob> findByEarner_IdAndOccurrenceDateOrderByOccurrenceTimeAsc(Long earnerId, LocalDate date);

    List<TaskJob> findByEarner_IdAndOccurrenceDateBetweenOrderByOccurrenceDateAsc(
            Long earnerId, LocalDate from, LocalDate to);

    List<TaskJob> findByOrganiser_IdAndOccurrenceDateBetweenOrderByOccurrenceDateAsc(
            Long organiserId, LocalDate from, LocalDate to);

    List<TaskJob> findByTask_IdAndOccurrenceDateBetweenOrderByOccurrenceDateAsc(
            Long taskId, LocalDate from, LocalDate to);

    List<TaskJob> findByTask_IdAndOccurrenceDateGreaterThanEqual(Long taskId, LocalDate from);

    Optional<TaskJob> findByIdAndEarner_Id(Long id, Long earnerId);

    Optional<TaskJob> findByIdAndOrganiser_Id(Long id, Long organiserId);

    long countByEarner_IdAndOccurrenceDateAndStatusIn(
            Long earnerId, LocalDate date, List<JobStatus> statuses);

    long countByTask_IdAndStatus(Long taskId, JobStatus status);
}
```

**Acceptance:** app boots; `DESCRIBE task_job;` shows `OCCURRENCE_DATE`, `STATUS`, `TASK_SCHEDULE_ID`, `CANCEL_TYPE`, `STATUS_NOTE`, and `SLOT` nullable.

**Size:** S · **Touches:** DB, API

---

### T0.4 — Occurrence-generation watermark on `Task`

**Goal:** make "have I already generated far enough ahead?" a free check, so read endpoints can safely trigger generation.

**Files:** `JeevikaService/src/main/java/com/actually/yapan/entity/Task.java`

**Spec:** add (nullable — `task` has existing rows, see §0.3):

```java
// nullable for backfill; see PLAN.md §0.3
@Column(name = "OCCURRENCES_GENERATED_UPTO")
private LocalDate occurrencesGeneratedUpto;
```
No backfill needed: `null` correctly means "nothing generated yet".

**Acceptance:** boot succeeds; `DESCRIBE task;` shows the column; existing rows have `NULL`.

**Size:** S · **Touches:** DB

---

### T0.5 — Targeted indexes for the hot queries (AUDIT §4.3, D3 — the subset Phase 1 needs)

**Goal:** the new visit queries and the existing per-user lookups actually hit an index. Full index review stays in Phase 6; this is the slice that matters now.

**Files:** `Task.java`, `TaskSchedule.java`, `TaskQuote.java`

**Spec:** replace each single mega-index with targeted ones matching real query shapes. Hibernate `update` **adds** indexes; it does not drop the old ones — that's fine, note the leftovers for Phase 6 cleanup.

```java
// Task
@Table(name = "task", indexes = {
    @Index(columnList = "ORGANISER_ID, IS_ACTIVE"),
    @Index(columnList = "EARNER_ID, IS_ACTIVE"),
    @Index(columnList = "IS_ACTIVE, IS_OPEN_TO_QUOTE, PROFESSION_ID")
})

// TaskSchedule
@Table(name = "task_schedule", indexes = {
    @Index(columnList = "TASK_ID, IS_ACTIVE"),
    @Index(columnList = "EARNER_ID, IS_ACTIVE, FULL_DATE")
})

// TaskQuote
@Table(name = "task_quote", indexes = {
    @Index(columnList = "TASK_ID, IS_REVOKED"),
    @Index(columnList = "ORGANISER_ID, CREATED_DATE"),
    @Index(columnList = "EARNER_ID, CREATED_DATE")
})
```

**Acceptance:** boot succeeds; `SHOW INDEX FROM task;` lists the new indexes.

**Size:** S · **Touches:** DB

---

## 3. Phase 1 — Occurrence engine (OP1)

**The spine of every operational feature.** A recurring `TaskSchedule` pattern becomes concrete dated `TaskJob` rows so leave, skip, reminders, attendance and "my day" have something to attach to.

**Design decisions (already made — do not re-litigate):**
- Pattern storage in `TaskSchedule` is **unchanged**. Occurrences are derived, additive data.
- Generation is **request-triggered** (`ensureOccurrences`), never a background job in this phase — see §0.2 constraint 3.
- Generation is **insert-only and idempotent**. It never edits or deletes existing rows.
- Rolling horizon, default **14 days**, from a property so it's tunable.
- Occurrences exist **only for assigned tasks** (`task.earner != null`). Unassigned tasks have no visits.
- One `TaskJob` per **(date, slot)**. A schedule row with no slots yields one row with `slot = null`.

---

### T1.1 — `ScheduleExpansionService`: pattern → dates

**Goal:** one pure, testable place that answers "which dates and slots does this `TaskSchedule` imply between A and B?". It must mirror `OrganiserServiceImpl.addNewJob`'s compression **exactly**, or occurrences will disagree with what the organiser chose.

**Files:**
- create `JeevikaService/src/main/java/com/actually/yapan/service/ScheduleExpansionService.java`
- create `JeevikaService/src/main/java/com/actually/yapan/serviceimpl/ScheduleExpansionServiceImpl.java`

**Spec — interface:**

```java
public interface ScheduleExpansionService {
    /** Dates+slots implied by one schedule row within [from, to] inclusive. Never returns nulls. */
    List<OccurrenceSlot> expand(TaskSchedule schedule, LocalDate from, LocalDate to);

    /** Simple carrier: one visit slot on one date. slot may be null. */
    record OccurrenceSlot(LocalDate date, Slot slot, LocalTime time) {}
}
```

**Spec — expansion rules by `RepeatType`** (read from `schedule.getRepeatType()`):

| RepeatType | Rule |
|---|---|
| `ONCE` | If `fullDate` is null → empty. Else one occurrence on `fullDate.toLocalDate()`, `slot = null`, `time = fullDate.toLocalTime()`. Include only if within `[from, to]`. |
| `NO_REPEAT_SELECTED_DATES` | Same as `ONCE` but pair the date with **every** non-null slot on the row (`slotsOf(schedule)`); if none, one occurrence with `slot = null`. |
| `REPEAT_DAILY` | Expand `schedule.getDay()` via **day-group table** below → weekday set. Every date in `[from, to]` whose `DayOfWeek` is in the set, paired with every slot. |
| `REPEAT_WEEKLY_SELECT_DAYS` | Identical logic to `REPEAT_DAILY` (the stored `day` may itself be a group like `ALL`/`WEEKDAYS`/`ALT_1`). |
| `REPEAT_MONTHLY_SELECT_DATES` | Day-of-month set = `dateGroup` expanded via **date-group table** below, else `{schedule.getDate()}` if non-null, else empty. For each date in `[from, to]` whose `getDayOfMonth()` is in the set → occurrence per slot. |

**Day-group table** (must match the `Rule` records in `addNewJob`):

| `Day` value | Weekdays |
|---|---|
| `ALL` | MON, TUE, WED, THU, FRI, SAT, SUN |
| `WEEKDAYS` | MON, TUE, WED, THU, FRI |
| `ALT_1` | MON, WED, FRI |
| `ALT_2` | TUE, THU, SAT |
| `WEEKENDS` | SAT, SUN |
| `MON`…`SUN` | itself |

**Date-group table** (must match the `groupDates.accept(...)` ranges in `addNewJob`):

| `DateGroup` | Days of month |
|---|---|
| `FORTNIGHT_1` | 1–15 |
| `FORTNIGHT_2` | 16–30 |
| `ODD_ALTERNATE` | 1, 3, 5, … 29 |
| `EVEN_ALTERNATE` | 2, 4, 6, … 30 |
| `TENS_1` | 1–10 |
| `TENS_2` | 11–20 |
| `TENS_3` | 21–30 |
| `WEEK_1` | 1–7 |
| `WEEK_2` | 8–14 |
| `WEEK_3` | 15–21 |
| `WEEK_4` | 22–28 |

**Implementation notes:**
- Put both tables in `private static final Map<...>` constants — no `switch` sprawl.
- `slotsOf(TaskSchedule)`: collect non-null `slot1..slot6` in order into a `List<Slot>`.
- **Month-length clamp:** a day-of-month beyond the month's length is skipped, not rolled over (day 30 does not become 1 March).
- Return an empty list rather than throwing when `repeatType` is null or data is inconsistent; log at `warn` with the schedule id.
- No `accessService`, no `GenericResponseMethods` here — this class must be callable from anywhere (§0.2).

**Acceptance (verify by temporary `main`/scratch call or by observing T1.2 output):**
1. `REPEAT_DAILY` + `day=WEEKDAYS` + slots `{E_1}` over a 14-day window starting Monday → 10 occurrences, none on Sat/Sun.
2. `REPEAT_WEEKLY_SELECT_DAYS` + `day=ALT_1` + slots `{E_1,E_3}` over 14 days → 6 dates × 2 slots = 12.
3. `REPEAT_MONTHLY_SELECT_DATES` + `dateGroup=WEEK_1` over a window covering a month start → occurrences on the 1st–7th only.
4. `REPEAT_MONTHLY_SELECT_DATES` + `date=31` across February → no occurrence in February.
5. `ONCE` with `fullDate` outside the window → empty.

**Size:** M · **Touches:** API (internal only, no endpoint)

---

### T1.2 — `OccurrenceService.ensureOccurrences`: materialise into `task_job`

**Goal:** idempotently persist the expansion for one task across the rolling horizon.

**Depends on:** T0.3, T0.4, T1.1

**Files:**
- create `JeevikaService/src/main/java/com/actually/yapan/service/OccurrenceService.java`
- create `JeevikaService/src/main/java/com/actually/yapan/serviceimpl/OccurrenceServiceImpl.java`
- modify `JeevikaService/src/main/resources/application.properties`

**Spec — property:**
```properties
##Occurrence generation
gasta.occurrence.horizon-days=14
```
Inject it in `OccurrenceServiceImpl` (the algorithm below refers to `horizonDays`):
```java
@Value("${gasta.occurrence.horizon-days:14}")
private int horizonDays;
```

**Spec — interface:**
```java
public interface OccurrenceService {
    /** Generate missing TaskJob rows for one task up to the horizon. Idempotent. Returns rows created. */
    int ensureOccurrences(Task task);

    /** Convenience for a set of tasks (e.g. an earner's assignments). */
    void ensureOccurrencesForTasks(List<Task> tasks);
}
```

**Spec — `ensureOccurrences(Task task)` algorithm:**

1. **Skip conditions** (return 0): `task == null`; `!Boolean.TRUE.equals(task.getActive())`; `task.getEarner() == null` (`TaskJob.EARNER_ID` is non-null, and an unassigned task has no visits).
2. `LocalDate today = LocalDate.now();`
   `LocalDate horizonEnd = today.plusDays(horizonDays);`
3. **Watermark short-circuit:** if `task.getOccurrencesGeneratedUpto() != null && !task.getOccurrencesGeneratedUpto().isBefore(horizonEnd)` → return 0.
4. `LocalDate from = today;` — always start at today, never generate into the past. (Starting from the watermark would be marginally cheaper but risks gaps if the app was idle; the existence check below makes re-scanning cheap.)
5. Load `List<TaskSchedule> schedules = taskScheduleRepo.findByTask_IdAndActive(task.getId(), true);` → if empty, set watermark to `horizonEnd`, save, return 0.
6. **One query for existing rows** (no N+1):
   `List<TaskJob> existing = taskJobRepo.findByTask_IdAndOccurrenceDateBetweenOrderByOccurrenceDateAsc(task.getId(), from, horizonEnd);`
   Build `Set<String> seen` of keys `date + "|" + (slot == null ? "-" : slot.name())`.
7. For each schedule row → `expansionService.expand(row, from, horizonEnd)`; for each `OccurrenceSlot`, skip if its key is in `seen`; else build a `TaskJob` and add its key to `seen` (guards duplicates *within* this run too, e.g. two schedule rows implying the same date+slot).
8. **New `TaskJob` field values:**
   ```java
   job.setTask(task);
   job.setTaskSchedule(row);
   job.setOrganiser(task.getOrganiser());
   job.setEarner(task.getEarner());
   job.setOccurrenceDate(os.date());
   job.setOccurrenceTime(os.time());
   job.setSlot(os.slot());
   job.setStatus(JobStatus.SCHEDULED);
   job.setArrived(false);
   job.setStarted(false);
   job.setCompleted(false);
   job.setCanceled(false);
   job.setCreatedDate(LocalDateTime.now());
   job.setUpdatedDate(LocalDateTime.now());
   job.setUpdatedBy(task.getOrganiser());   // no acting user in this path; organiser owns the task
   ```
9. `taskJobRepo.saveAll(newJobs);`
10. `task.setOccurrencesGeneratedUpto(horizonEnd); taskRepo.save(task);`
11. Return `newJobs.size()`.

**Method annotations:** `@Transactional` (jakarta, as used elsewhere in this codebase) on `ensureOccurrences`. **No `accessService`, no `GenericResponseMethods`** — use `private static final Logger logger = LoggerFactory.getLogger(OccurrenceServiceImpl.class);` and log created counts at `info`, anomalies at `warn`.

**`ensureOccurrencesForTasks`:** loop, wrapping each call in try/catch so one bad task can't fail a whole list request; log failures at `warn`.

**Acceptance:**
1. Create a daily task, accept a quote (T1.3 wires this) → `SELECT COUNT(*) FROM task_job WHERE TASK_ID = ?;` ≈ 14 for a daily/1-slot task.
2. Call the trigger a second time → count **unchanged** (idempotent), and `OCCURRENCES_GENERATED_UPTO` set.
3. `SELECT MIN(OCCURRENCE_DATE) FROM task_job;` ≥ today.
4. Unassigned task → 0 rows.

**Size:** M · **Touches:** DB (writes), API (internal)

---

### T1.3 — Trigger generation on quote acceptance

**Goal:** the moment an earner is assigned, their visits exist.

**Depends on:** T1.2

**Files:** `JeevikaService/src/main/java/com/actually/yapan/serviceimpl/OrganiserServiceImpl.java`

**Spec:** in `acceptQuote`, after the block that assigns the earner to the task and to active `TaskSchedule` rows (after `taskScheduleRepo.save(sched)` loop) and **before** the notification calls:

```java
// Materialise the first horizon of visits for the newly assigned earner
task.setOccurrencesGeneratedUpto(null);   // force regeneration for the new earner
occurrenceService.ensureOccurrences(task);
```
Add `@Autowired OccurrenceService occurrenceService;` to the class. Keep it inside the existing `@Transactional` method. If generation throws, the whole acceptance must **not** fail — wrap in try/catch, log at `warn`, and continue to notifications (assignment matters more than pre-generated visits, and the read-path trigger in T1.4 will recover).

**Acceptance:** post task → quote → accept → `task_job` populated for that task, earner set correctly on every row.

**Size:** S · **Touches:** API

---

### T1.4 — Earner visits API (`get-my-visits`)

**Goal:** the earner's "my day". Also the read-path safety net that generates occurrences if T1.3 missed them.

**Depends on:** T1.2

**Files:**
- create `JeevikaService/src/main/java/com/actually/yapan/dto/VisitDto.java`
- modify `service/EarnerService.java`, `serviceimpl/EarnerServiceImpl.java`, `controller/EarnerController.java`

**Spec — endpoint:** `GET /api/v1/yapan/earner/get-my-visits?filter=today`
`filter` ∈ `today` | `tomorrow` | `later` | `past` | `all`; default `today`.

Date ranges: `today` → `[today, today]`; `tomorrow` → `[today+1, today+1]`; `later` → `[today+2, horizonEnd]`; `past` → `[today-30, today-1]`; `all` → `[today-30, horizonEnd]`.

**Spec — `VisitDto`** (Lombok `@Data`, `@AllArgsConstructor`, `@NoArgsConstructor`):

```java
private Long jobId;
private Long taskId;
private String taskTitle;
private String professionName;
private String occurrenceDate;    // "yyyy-MM-dd"
private String occurrenceTime;    // "HH:mm" or null
private String slot;              // enum name, e.g. "E_1", or null  → for i18n
private String slotLabel;         // display text from Slot.toString(), or null
private String status;            // JobStatus name, e.g. "SCHEDULED" → for i18n
private String statusLabel;       // JobStatus.getLabel()
private String counterpartName;   // organiser's fullName (earner-facing view)
private String counterpartPhone;  // null until Phase 2 / B2
private String addressLine;       // address.addressLine2
private String city;
private Integer amount;           // task.fixedQuoteAmount, else openQuoteLimit
private String payUnit;           // PayUnit name or ""
private String statusNote;
```
> Both `slot`/`status` **codes** and `*Label` strings are returned: codes let the app localise later (Phase 7); labels keep this phase simple. This is the pattern T6.7 generalises.

**Spec — service method:**

```java
@Override
public ResponseEntity<CustomResponse> getMyVisits(String apiName, String filter) {
    try {
        UserData user = accessService.getUser();
        // safety net: make sure this earner's assignments have occurrences
        occurrenceService.ensureOccurrencesForTasks(taskRepo.findByEarner_IdAndActive(user.getId(), true));

        LocalDate[] range = resolveRange(filter);   // private helper per the table above
        List<TaskJob> jobs = taskJobRepo
                .findByEarner_IdAndOccurrenceDateBetweenOrderByOccurrenceDateAsc(user.getId(), range[0], range[1]);

        List<VisitDto> result = jobs.stream().map(this::toVisitDto).collect(Collectors.toList());
        return genericResponseMethods.successResponse(apiName, "Records fetched.", result, user.getUsername());
    } catch (Exception e) { /* standard 500 branch per §0.4 */ }
}
```
`toVisitDto(TaskJob)`: read `job.getTask()` for title/profession/amount/address (all already loaded via the FK), `job.getOrganiser().getFullName()` for `counterpartName`, leave `counterpartPhone` null. Guard every nested access with a null check (`task.getAddress() != null ? ... : ""`) — the existing `toTaskSummary` shows the pattern.

**Acceptance:**
```bash
curl -H "Authorization: $TOKEN" -H "atsh: $ATSH" \
  "http://localhost:8080/api/v1/yapan/earner/get-my-visits?filter=today"
```
1. As the assigned earner of a daily task → today's visit(s) returned with correct date and slot.
2. `filter=later` → future visits, none earlier than today+2.
3. As an unrelated user → empty list (not someone else's visits).

**Size:** M · **Touches:** API

---

### T1.5 — Organiser visits API (`get-task-visits`)

**Goal:** the organiser can see the upcoming visit schedule of one of their tasks (basis for skip/pause in Phase 3).

**Depends on:** T1.2

**Files:** `dto/VisitDto.java` (reuse), `service/OrganiserService.java`, `serviceimpl/OrganiserServiceImpl.java`, `controller/OrganiserController.java`

**Spec — endpoint:** `GET /api/v1/yapan/organiser/get-task-visits?taskId=5&from=2026-07-25&to=2026-08-08`
`from`/`to` optional (`@RequestParam(required = false) String from`), defaulting to `[today, today+horizon]`.

**Ownership check (mandatory):**
```java
Task task = taskRepo.findById(taskId).orElseThrow(() -> new CustomException("Task not found."));
if (!task.getOrganiser().getId().equals(user.getId())) {
    throw new CustomException("Not authorized to view this task.");
}
```
Then `occurrenceService.ensureOccurrences(task)` and query `findByTask_IdAndOccurrenceDateBetweenOrderByOccurrenceDateAsc`.

In this organiser-facing view, `counterpartName` = **earner**'s `fullName` (mirror of the earner view). Add a `toVisitDto(TaskJob job, boolean organiserView)` flag rather than duplicating the mapper — but note `OrganiserServiceImpl` and `EarnerServiceImpl` are separate classes: put the shared mapper as a `public VisitDto toVisitDto(TaskJob, boolean)` on `OccurrenceServiceImpl` and call it from both, so there is exactly one mapper.

**Acceptance:** organiser sees their task's visits; a different user gets a 400 "Not authorized to view this task."

**Size:** S/M · **Touches:** API

---

### T1.6 — Dashboard counts read from occurrences

**Goal:** "Today / Tomorrow / Later" on the dashboard stop being permanently 0 for recurring work (AUDIT §3.4).

**Depends on:** T1.2

**Files:** `JeevikaService/src/main/java/com/actually/yapan/serviceimpl/OrganiserServiceImpl.java` (`getDashboard`)

**Spec:** replace the `taskScheduleRepo.findByEarner_IdAndActive(...)` + `fullDate` loop (the "Schedule breakdown" block) with counts over `task_job`:

```java
occurrenceService.ensureOccurrencesForTasks(taskRepo.findByEarner_IdAndActive(userId, true));

List<JobStatus> live = List.of(JobStatus.SCHEDULED, JobStatus.ON_THE_WAY,
        JobStatus.ARRIVED, JobStatus.IN_PROGRESS, JobStatus.DONE_BY_EARNER);

int scheduledToday    = (int) taskJobRepo.countByEarner_IdAndOccurrenceDateAndStatusIn(userId, today, live);
int scheduledTomorrow = (int) taskJobRepo.countByEarner_IdAndOccurrenceDateAndStatusIn(userId, tomorrow, live);
int scheduledLater    = (int) taskJobRepo.countByEarner_IdAndOccurrenceDateBetweenAndStatusIn(
        userId, tomorrow.plusDays(1), today.plusDays(horizonDays), live);
```
Add the third `countBy...Between...` derived method to `TaskJobRepo`. Leave `DashboardDto`'s shape unchanged — the app already renders these three numbers.

> This intentionally does **not** fix the rest of `getDashboard`'s load-everything-into-memory problem; that's T6.2 (D2). Keep the change scoped.

**Acceptance:** with a daily assignment accepted, the Dashboard "Tasks Accepted For" card shows non-zero Today/Tomorrow/Later in the app.

**Size:** S · **Touches:** API

---

### T1.7 — Flutter: `Visit` model + constants

**Depends on:** T1.4

**Files:**
- create `Yapan/lib/model/visit.dart`
- modify `Yapan/lib/util/constants.dart`

**Spec — constants** (add near the earner block):
```dart
// Visits (occurrences)
static String myVisits = '/api/v1/yapan/earner/get-my-visits';
static String taskVisits = '/api/v1/yapan/organiser/get-task-visits';
```

**Spec — model** (follow `task_summary.dart` style; all fields nullable-safe):
```dart
class Visit {
  final int jobId;
  final int taskId;
  final String taskTitle;
  final String professionName;
  final String occurrenceDate;
  final String? occurrenceTime;
  final String? slot;
  final String? slotLabel;
  final String status;
  final String statusLabel;
  final String? counterpartName;
  final String? counterpartPhone;
  final String? addressLine;
  final String? city;
  final int? amount;
  final String? payUnit;
  final String? statusNote;

  Visit({ required this.jobId, required this.taskId, required this.taskTitle,
    required this.professionName, required this.occurrenceDate, required this.status,
    required this.statusLabel, this.occurrenceTime, this.slot, this.slotLabel,
    this.counterpartName, this.counterpartPhone, this.addressLine, this.city,
    this.amount, this.payUnit, this.statusNote });

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
    jobId: json['jobId'] ?? 0,
    taskId: json['taskId'] ?? 0,
    taskTitle: json['taskTitle'] ?? '',
    professionName: json['professionName'] ?? '',
    occurrenceDate: json['occurrenceDate'] ?? '',
    occurrenceTime: json['occurrenceTime'],
    slot: json['slot'],
    slotLabel: json['slotLabel'],
    status: json['status'] ?? 'SCHEDULED',
    statusLabel: json['statusLabel'] ?? '',
    counterpartName: json['counterpartName'],
    counterpartPhone: json['counterpartPhone'],
    addressLine: json['addressLine'],
    city: json['city'],
    amount: json['amount'],
    payUnit: json['payUnit'],
    statusNote: json['statusNote'],
  );
}
```

**Acceptance:** `flutter analyze` clean.

**Size:** S · **Touches:** UI

---

### T1.8 — Flutter: earner Today/Tomorrow/Later shows visits

**Goal:** the earner sees dated visits instead of an always-empty task list.

**Depends on:** T1.7

**Files:** `Yapan/lib/screens/earner_tasks_screen.dart`

**Spec:** this screen currently fetches `TaskSummary` from `get-my-earner-tasks/{filter}` for all five filters. Change only the date-based ones:

- Filters `today` / `tomorrow` / `later` → `GET ${Constants.myVisits}?filter=$_activeFilter`, parse `List<Visit>`.
- Filters `completed` / `canceled` → **unchanged** (still `TaskSummary`); Phase 2 moves them to visit history.
- Hold both lists in state (`List<Visit> visits` / `List<TaskSummary> tasks`) and branch the list builder on whether the active filter is date-based. Do not delete the existing tile widget — add a `_visitTile(Visit v)` beside it.

**`_visitTile` content (low-literacy-friendly, minimum text):**
- Line 1: `professionName` (large, bold) + status chip using `v.statusLabel`.
- Line 2: 📅 formatted date (`dd MMM`, via `intl`) + 🕐 `v.slotLabel ?? v.occurrenceTime ?? ''`.
- Line 3: 📍 `${v.addressLine}, ${v.city}`.
- Line 4: 👤 `v.counterpartName`.
- If `v.amount != null`: ₹ amount + payUnit.
- Status chip colours: reuse the palette approach from `my_doorstep_orders_screen.dart` `_statusColor`; **new** `_statusColorForJob(String status)` local helper for now — T6.12 de-duplicates status maps across screens, don't try to unify yet.

Keep the existing filter chip bar, loading, `Widgets.buildErrorRetry`, and empty-state patterns exactly as they are.

**Acceptance:**
1. As an assigned earner, open Dashboard → "Tasks Accepted For" → Today → the visit appears with correct date/slot/address.
2. Tomorrow and Later show the right days.
3. Airplane mode → retry widget appears, tapping Retry recovers.
4. `flutter analyze` clean.

**Size:** M · **Touches:** UI

---

### Phase 1 exit criteria

- [ ] Accepting a quote on a **daily** task creates ~14 `task_job` rows.
- [ ] `get-my-visits?filter=today` returns them for the earner and nothing for anyone else.
- [ ] Organiser `get-task-visits` returns them with an ownership check.
- [ ] Dashboard Today/Tomorrow/Later are non-zero for recurring work.
- [ ] The earner app screen lists dated visits.
- [ ] Re-running any of the above creates **no duplicate rows**.

---

## 4. Phase 2 — Visit workflow, attendance, completion, ratings

Turns a visit from a row into a tracked event, and finally closes the task loop (OP5 + B1 + B3).

---

### T2.0 — Job start code + arrival confirmation (your decision, answers R11a)

**Your idea, and it's the right one.** A code the organiser reads out and the earner types is exactly how Urban Company gates job start, and it costs nothing here because **both parties are already in the app — no SMS, no OTP service, no external dependency**. It converts "the earner claims they arrived" into "the customer confirmed presence", which is the foundation attendance and later payments both need.

**Design:**

| Aspect | Decision |
|---|---|
| Code | 4 digits, generated per `TaskJob` at occurrence-creation time (`START_CODE` column). Not secret-grade, and doesn't need to be — it proves co-presence, nothing more. |
| Who sees it | **Organiser only**, on their visit card, revealed on the visit's own day (not earlier — reduces "share it in advance" habits). |
| Who enters it | Earner, to move `ARRIVED → IN_PROGRESS`. |
| Applies to | **Every** visit, one-time and recurring alike — a recurring maid still starts each day's work. |
| One-time visits | Additionally, the organiser is explicitly **asked whether the earner arrived** (your ask): when an `ONCE` visit reaches `ARRIVED`, push a `GENERAL`-type notification "Did <name> arrive?" with Yes/No. "No" marks `MISSED` and notifies the earner. |
| **Fallback (essential)** | The organiser may be absent, asleep, or the phone may be dead. Without an escape hatch a code-gate creates permanently stuck visits. Earner taps **"Organiser not available"** → visit moves to `IN_PROGRESS` with `startedWithoutCode = true` and the organiser is notified "work started without code". Ops can review these later (Phase 10). Never block the earner from working. |
| Auto-confirm of *completion* | **No silent auto-confirm.** After `DONE_BY_EARNER`, nudge the organiser; if untouched for `gasta.visit.auto-confirm-hours` (default 24) auto-advance to `COMPLETED` but stamp `autoConfirmed = true` so attendance data distinguishes "customer confirmed" from "nobody objected". Payments later can treat those differently. |

**Files:** `entity/TaskJob.java`, `serviceimpl/OccurrenceServiceImpl.java`, `dto/UpdateVisitStatusDto.java`, earner + organiser services/controllers, `Yapan/lib/model/visit.dart`, earner and organiser visit UI.

**Extra `TaskJob` columns** (all nullable, §0.3):
```java
@Column(name = "START_CODE", length = 8)
private String startCode;                    // 4 digits, generated with the occurrence

@Column(name = "STARTED_WITHOUT_CODE")
private Boolean startedWithoutCode;

@Column(name = "AUTO_CONFIRMED")
private Boolean autoConfirmed;
```
Generate in T1.2 step 8: `job.setStartCode(String.format("%04d", new SecureRandom().nextInt(10000)));`

**API:** extend `POST /earner/update-visit-status` with an optional `startCode`. Moving to `IN_PROGRESS` requires **either** a matching `startCode` **or** `overrideNoOrganiser = true`. Mismatch → 400 "Code does not match. Ask the customer to read it again." (never reveal the correct code in the error).

**`VisitDto` additions:** `startCode` — populated **only** in the organiser view and **only** when `occurrenceDate == today`; always `null` in the earner view (otherwise the gate is pointless).

**UI:** organiser visit card shows the code large and high-contrast (it will be read aloud, possibly by someone who reads slowly) with a "Show code" reveal. Earner gets a 4-box numeric entry with a numeric keypad (see U3) and a secondary "Organiser not available" link — visibly de-emphasised but never hidden.

**Acceptance:**
1. Earner at `ARRIVED` submits the wrong code → 400, status unchanged.
2. Correct code → `IN_PROGRESS`, organiser notified.
3. `overrideNoOrganiser` → `IN_PROGRESS` with `STARTED_WITHOUT_CODE = 1` and the organiser notified.
4. Earner's `get-my-visits` payload never contains `startCode`.
5. A `DONE_BY_EARNER` visit older than the auto-confirm window becomes `COMPLETED` with `AUTO_CONFIRMED = 1` (needs T3.6 scheduling; until then it happens on next read).

**Size:** M · **Touches:** DB (3 nullable columns), API, UI

---

### T2.1 — Visit status transitions (earner side)

**Files:** `dto/UpdateVisitStatusDto.java` (new), `service/EarnerService.java`, `serviceimpl/EarnerServiceImpl.java`, `controller/EarnerController.java`

**Spec — endpoint:** `POST /api/v1/yapan/earner/update-visit-status`
Body: `{ "jobId": 12, "status": "ARRIVED", "note": "" }`

**Allowed transitions (validate; reject others with `CustomException` → 400):**

| From | To |
|---|---|
| `SCHEDULED` | `ON_THE_WAY`, `ARRIVED`, `IN_PROGRESS` |
| `ON_THE_WAY` | `ARRIVED`, `IN_PROGRESS` |
| `ARRIVED` | `IN_PROGRESS` |
| `IN_PROGRESS` | `DONE_BY_EARNER` |

Terminal for the earner: `DONE_BY_EARNER`, `COMPLETED`, `CANCELED`, `EARNER_LEAVE`, `SKIPPED_BY_ORGANISER`, `MISSED` — no transitions out.

**Ownership:** `taskJobRepo.findByIdAndEarner_Id(jobId, user.getId())` → else "Visit not found."
**Date guard:** reject if `occurrenceDate` is in the future ("You can update a visit only on its scheduled day.") or more than 2 days past.

**Status mirror helper** — put on `OccurrenceServiceImpl` and use it everywhere so the legacy booleans can never drift:
```java
public void applyStatus(TaskJob job, JobStatus next, UserData actor, String note) {
    job.setStatus(next);
    job.setArrived(next == JobStatus.ARRIVED || next == JobStatus.IN_PROGRESS
            || next == JobStatus.DONE_BY_EARNER || next == JobStatus.COMPLETED);
    job.setStarted(next == JobStatus.IN_PROGRESS || next == JobStatus.DONE_BY_EARNER
            || next == JobStatus.COMPLETED);
    job.setCompleted(next == JobStatus.COMPLETED);
    job.setCanceled(next == JobStatus.CANCELED || next == JobStatus.SKIPPED_BY_ORGANISER);
    if (next == JobStatus.CANCELED || next == JobStatus.SKIPPED_BY_ORGANISER) job.setCanceledBy(actor);
    if (note != null && !note.isBlank()) job.setStatusNote(note);
    job.setUpdatedBy(actor);
    job.setUpdatedDate(LocalDateTime.now());
}
```

**Notifications to organiser:** `IN_PROGRESS` → `JOB_STARTED`; `DONE_BY_EARNER` → `JOB_COMPLETED`; `referenceId = task.getId()`. `JOB_STARTED` currently has **no app icon case** → add it in T2.6 (§0.6).

**Acceptance:** walk a today-visit `SCHEDULED → ON_THE_WAY → ARRIVED → IN_PROGRESS → DONE_BY_EARNER`; each step 200 and DB `STATUS` + mirror booleans consistent. `ARRIVED → SCHEDULED` → 400. Another earner's jobId → 400.

**Size:** M · **Touches:** API

---

### T2.2 — Organiser confirms a visit

**Files:** `service/OrganiserService.java`, `serviceimpl/OrganiserServiceImpl.java`, `controller/OrganiserController.java`

**Spec:** `POST /api/v1/yapan/organiser/confirm-visit/{jobId}` — ownership via `findByIdAndOrganiser_Id`; allowed only from `DONE_BY_EARNER` (or `IN_PROGRESS`, to let a generous organiser close early); sets `COMPLETED` via `applyStatus`, stamps a new nullable `ORGANISER_CONFIRMED_AT` on `TaskJob`, notifies the earner (`JOB_COMPLETED`).

Also add nullable `EARNER_MARKED_DONE_AT` (set in T2.1 on `DONE_BY_EARNER`) — both columns feed attendance and, later, payments.

**Acceptance:** confirm a `DONE_BY_EARNER` visit → `COMPLETED`, both timestamps present, earner notified. Confirming a `SCHEDULED` visit → 400.

**Size:** S/M · **Touches:** DB (2 nullable columns), API

---

### T2.3 — Attendance summary

**Files:** `dto/AttendanceSummaryDto.java` (new), `OrganiserService`/`Impl`, controller

**Spec:** `GET /api/v1/yapan/organiser/get-attendance?taskId=5&month=2026-07`
Ownership-checked. Counts over `task_job` for that month using **`count` queries, not in-memory filtering** (respect AUDIT §4.11):

```json
{ "taskId": 5, "month": "2026-07", "totalScheduled": 26, "completed": 22,
  "earnerLeave": 2, "skippedByOrganiser": 1, "missed": 1, "upcoming": 0 }
```
Add `countByTask_IdAndOccurrenceDateBetweenAndStatus(...)` to `TaskJobRepo`; call it once per status (6 cheap counts) — do **not** load rows.

**Acceptance:** numbers match hand-checked DB counts; another user's taskId → 400.

**Size:** S/M · **Touches:** API

---

### T2.4 — Task completion & cancellation (B1, closes AUDIT §2.7)

**Files:** `OrganiserService`/`Impl`, controller, `dto/CancelTaskDto.java`

**Spec:**
- `POST /api/v1/yapan/organiser/complete-task/{taskId}` → ownership check; `task.setFeedbackProvided(true)`, `task.setOpenToQuote(false)`; future `SCHEDULED` jobs → `CANCELED` with note "engagement ended"; notify earner (`JOB_COMPLETED`).
- `POST /api/v1/yapan/organiser/cancel-task` body `{ "taskId": 5, "cancelType": "PERMANENTLY", "reason": "..." }` → ownership check; `task.setActive(false)`, `setOpenToQuote(false)`; future jobs → `CANCELED`; notify earner if assigned (`JOB_CANCELED`).

Both must leave **past** jobs untouched (attendance history is immutable).

**Acceptance:** after complete-task, Dashboard "Done" ≥ 1 and `PostedTasksScreen` filter *done* returns the task (both were permanently empty before). After cancel-task, *withdrawn* returns it. Past `COMPLETED` jobs unchanged.

**Size:** M · **Touches:** API

---

### T2.5 — Ratings (B1 second half)

**Files:** create `repo/RatingOnWorkRepo.java`, `repo/RatingOnConductRepo.java`, `dto/SubmitRatingDto.java`; `MiscService`/`Impl` (shared by both roles); controller `AuthenticatedController`

**Spec:**
- `POST /api/v1/yapan/authenticated/rate-earner` body `{taskId, rating(1-5), feedback}` → organiser-only for that task; writes `RatingOnWork(ratedBy=organiser, earner, profession=task.profession, task, rating, feedback, createdDate)`. Reject duplicate for the same (task, ratedBy).
- `POST /api/v1/yapan/authenticated/rate-organiser` body `{taskId, rating, feedback}` → earner-only for that task; writes `RatingOnConduct(ratedBy=earner, ratedUser=organiser, task, rating, feedback, createdDate)`.
- Repos need `Optional<X> findByTask_IdAndRatedBy_Id(...)` for the duplicate check and `@Query("select avg(r.rating) from ... where r.earner.id = ?1")` for display.

This makes the `avgRating` LEFT JOIN in the nearby-jobs query return real numbers (AUDIT §2.6) with **no query change needed** — it already reads `rating_on_conduct`.

**Acceptance:** organiser rates → row in `rating_on_work`; earner rates → row in `rating_on_conduct`; second attempt → 400; nearby-jobs response for that organiser's tasks shows a non-zero `avgRating`, and the app's "0.0 ★" becomes real.

**Size:** M · **Touches:** DB (repos only), API

---

### T2.6 — Notification gaps + app icon cases (B3, AUDIT §2.10)

**Files:** `serviceimpl/EarnerServiceImpl.java` (`addTaskQuote`), `serviceimpl/OrganiserServiceImpl.java` (`addNewJob`, `acceptQuote`), `Yapan/lib/screens/notifications_screen.dart`

**Spec:**
- `addTaskQuote` → notify **organiser**: `QUOTE_RECEIVED`, title "New Quote Received", message `"<earner> quoted ₹<amt> for \"<task title>\""`, `referenceId = task.getId()`. This is the single most valuable missing notification.
- `acceptQuote` → additionally send `JOB_ASSIGNED` to the earner (it already sends `QUOTE_ACCEPTED`; `JOB_ASSIGNED` is the one the app has an icon for and expects).
- Add `case 'JOB_STARTED'` to `_iconMeta` (`Icons.play_circle_outline`, `AppColors.darkBlue`) and `case 'GENERAL'` (`Icons.info_outline`, grey) so nothing falls to the unstyled default.

**Acceptance:** earner submits a quote → organiser's Notifications list shows a styled "New Quote Received" and the unread badge increments.

**Size:** S · **Touches:** API, UI

---

### T2.7 — Flutter: visit actions + rating dialog

**Files:** `Yapan/lib/screens/earner_tasks_screen.dart`, `Yapan/lib/util/constants.dart`, new `Yapan/lib/screens/visit_action_sheet.dart` (or a private widget), `Yapan/lib/screens/posted_tasks_screen.dart`

**Spec:**
- Constants: `updateVisitStatus`, `confirmVisit`, `getAttendance`, `completeTask`, `cancelTask`, `rateEarner`, `rateOrganiser`.
- Earner visit tile (today only): **one big primary button** whose label is the single next step — "On my way" → "I have arrived" → "Start work" → "Mark done" — derived from `v.status`. One tap, no dropdown, no free text. This is the low-literacy-friendly shape; do not build a status picker.
- Organiser: on a `DONE_BY_EARNER` visit, a "Confirm done" button; after confirming, show the rating dialog (5 stars, optional one-line feedback, skippable).
- Earner rating of organiser: offer after `COMPLETED`, skippable.
- After any action: refetch the list (`_fetch()`), show a `SnackBar`.

**Acceptance:** full round trip in the app on two accounts — earner marks the four steps, organiser confirms, both rate, both see the visit as Completed.

**Size:** M/L · **Touches:** UI

---

### Phase 2 exit criteria

- [ ] A visit goes `SCHEDULED → COMPLETED` through the app with both parties acting.
- [ ] Attendance summary matches the DB.
- [ ] Dashboard Done/Completed counts move off 0.
- [ ] Ratings persist and `avgRating` shows real values in the earner's job list.
- [ ] Organiser is notified of new quotes.

---

## 5. Phase 3 — Leave, skip/pause, reminders

---

### T3.1 — Earner marks leave (OP2)

**Spec:** `POST /api/v1/yapan/earner/mark-leave` body:
```json
{ "taskId": 5, "dates": ["2026-08-12","2026-08-13"], "cancelType": "SELECT_DATES", "reason": "family function" }
```
- Ownership: earner must be `task.earner`.
- Only **future or today** dates; reject past.
- All matching `task_job` rows in those dates with a live status → `EARNER_LEAVE` via `applyStatus`, `cancelType` and `statusNote` stored.
- Notify organiser: new `NotificationType.LEAVE_MARKED` → "Earner leave on 12, 13 Aug for \"<task>\"".
- Response payload: `{ "datesMarked": 2, "substituteSuggested": true }` — `substituteSuggested = dates.size() >= gasta.leave.substitute-threshold-days` (property, default 2). Phase 5 acts on it; Phase 3 only informs.

**Also:** `GET /api/v1/yapan/earner/get-my-leaves?taskId=5` and organiser-side visibility via the existing `get-task-visits` (status already shows `EARNER_LEAVE`).

**Size:** M · **Touches:** API, then UI (date multi-select on the visit/assignment screen — reuse `SfDateRangePicker` already used in `new_task_page`)

---

### T3.2 — Organiser skips / pauses (OP4)

**Spec:**
- `POST /api/v1/yapan/organiser/skip-visits` body `{ "taskId": 5, "dates": [...], "reason": "travelling" }` → live jobs on those dates → `SKIPPED_BY_ORGANISER`; notify earner (`VISIT_SKIPPED`).
- `POST /api/v1/yapan/organiser/pause-task` body `{ "taskId": 5, "from": "2026-08-10", "to": "2026-08-20", "reason": "" }` → same treatment across the range; notify earner once with the range.
Ownership-checked; past dates untouched.

**Size:** M · **Touches:** API, UI

---

### T3.3 — New notification types (register in both places, §0.6)

Add to `NotificationType`: `LEAVE_MARKED`, `VISIT_SKIPPED`, `VISIT_REMINDER`, `AVAILABILITY_CONFIRM_REQUEST`, `ORDER_REASSIGNED`, `TASK_EXPIRED`.
Add matching `_iconMeta` cases: leave → `Icons.event_busy` orange; skipped → `Icons.event_available_outlined` grey; reminder → `Icons.alarm` blue; confirm-request → `Icons.help_outline` amber; reassigned → `Icons.swap_horiz` purple; expired → `Icons.timer_off_outlined` red.

**Size:** S · **Touches:** API, UI

---

### T3.4 — Reminders, read-triggered (OP6a, safe variant)

**Goal:** reminders without depending on background scheduling (§0.2 constraint 3).

**Spec:** a `ReminderService.emitDueReminders(UserData user)` called at the **start of `getNotifications`** (i.e. inside a request):
- Find the user's `SCHEDULED` jobs for today and tomorrow.
- For each, emit `VISIT_REMINDER` **at most once per (jobId, kind)** — track with a new nullable `REMINDER_SENT_FOR` column on `TaskJob` (`LocalDate` = the date a reminder was last emitted for that job) so re-opening the screen doesn't spam.
- Message: "Tomorrow: <profession> at <slot label>, <city>".

This is deliberately modest: it makes reminders *exist* and be idempotent, and it proves the message copy before T3.6 moves them to a real scheduler.

**Size:** M · **Touches:** DB (1 nullable column), API

---

### T3.5 — Flutter: leave / skip UI

Earner: on an assignment, "Take leave" → date multi-select → confirm → warning if it triggers `substituteSuggested`.
Organiser: on `get-task-visits`, per-visit "Not needed" and a "Pause for dates" action.
Copy stays short and concrete ("Take leave", "Not needed today", "Pause"). No free-text requirement — reason optional.

**Size:** M · **Touches:** UI

---

### T3.6 — Enable real scheduling (unblocked by §0.9; requires T0.6)

**Goal:** move reminders and occurrence top-up off the request path onto a clock, now that we know background threads resolve the default datasource.

**Depends on:** T0.6 (**mandatory** — a background job on a 1-connection pool would block all traffic), T3.4

**Files:** `GastaBackendApplication.java`, new `serviceimpl/OccurrenceScheduler.java`, `application.properties`

**Spec:**
1. Add `@EnableScheduling` to `GastaBackendApplication` (it currently has `@EnableConfigurationProperties`, `@ComponentScan`, `@SpringBootApplication`).
2. Properties:
```properties
##Scheduled jobs
gasta.scheduler.enabled=true
gasta.occurrence.topup-cron=0 0 2 * * *
gasta.reminder.cron=0 0 18 * * *
```
3. `OccurrenceScheduler`, guarded by `@ConditionalOnProperty(name = "gasta.scheduler.enabled", havingValue = "true")` so it can be switched off per-environment:

```java
@Scheduled(cron = "${gasta.occurrence.topup-cron}")
public void topUpOccurrences() {
    DBContextHolder.setCurrentDb("one");          // explicit; see §0.2.3 / §0.9
    try {
        // page through active assigned tasks; call occurrenceService.ensureOccurrences(task)
    } catch (Exception e) {
        logger.error("Occurrence top-up failed", e);
    } finally {
        DBContextHolder.clear();                   // ThreadLocal hygiene on a pooled thread
    }
}
```
**Hard rules for this class** (§0.2): no `accessService.getUser()`, no `genericResponseMethods` — own SLF4J logger only. Page the task query (`PageRequest.of(n, 200)`) rather than loading every task.
4. Move the reminder emission from T3.4's read-triggered path into `@Scheduled(cron = "${gasta.reminder.cron}")`, calling the same `ReminderService.emitDueReminders(...)` logic. **Keep the read-triggered call in place as a belt-and-braces fallback** — `REMINDER_SENT_FOR` already makes it idempotent, so double-invocation is harmless.
5. Import `com.actually.mysqlmultitenancy.config.db.DBContextHolder` (already on the classpath and component-scanned).

**Acceptance:**
1. Temporarily set `gasta.occurrence.topup-cron=0 */2 * * * *`, boot, and watch two runs log a created-count without any datasource error — this is the empirical proof of §0.9.
2. During a run, requests still respond promptly (validates T0.6).
3. Set `gasta.scheduler.enabled=false` → no scheduled logs appear.
4. Reminders arrive once, not once per notifications-screen open.

**Size:** M · **Touches:** API config

**Then update §15 R1/R7** to record that scheduling is live.

---

## 6. Phase 4 — Doorstep re-confirmation, expiry, auto-recovery

> ⚠️ **Superseded by [PLAN-2.md](PLAN-2.md).** Phases 0–3 are complete. PLAN-2
> expands phases 4–11, adds a human-behaviour gap analysis (what people actually
> do vs what the happy path assumes), and splits Phase 4 into **4A — exits,
> corrections and reachability** and **4B — doorstep reliability** (the sketch
> below, renumbered T4.13–T4.17). Read PLAN-2 for the current plan; the sketches
> in §6–§13 below are kept for provenance.

| ID | Item | Spec sketch | Size |
|---|---|---|---|
| T4.1 | **Provider re-confirmation (OP6b)** | Add to `PickupDropOrder`: `CONFIRM_REQUESTED_AT`, `PROVIDER_CONFIRMED_AT`, `CONFIRM_DEADLINE` (all nullable `LocalDateTime`). For orders with `pickupDate ≥ 2 days` out, emit `AVAILABILITY_CONFIRM_REQUEST` ~24h before pickup. `POST /doorstep/provider/confirm-availability/{orderId}` → stamps confirmation, customer notified. Declined/past deadline → clear `provider`, status back to `PENDING`, reassign to next-nearest, notify customer with `ORDER_REASSIGNED`. | M/L |
| T4.2 | **Doorstep order expiry** | `PENDING` orders whose `pickupDate` has passed → `CANCELLED` + customer notification. | S |
| T4.3 | **Task/quote expiry (OP9)** | Enforce the already-stored `openForDays`/`openForMins`: open, unassigned tasks past their window → `openToQuote = false`, notify organiser `TASK_EXPIRED` with a repost prompt. | S/M |
| T4.4 | **Cancel + auto-recovery (OP8)** | `POST /earner/cancel-assignment` → clear `task.earner`, `openToQuote = true`, future jobs `CANCELED`, organiser notified with one-tap repost; `POST /organiser/report-no-show/{jobId}` → `MISSED`. | M |
| T4.5 | **Re-confirmation UI** | Provider: prominent "Still available?" card with Yes/No. Customer: "Confirmed ✓" / "Provider changed" state on the order. | M |

---

## 7. Phase 5 — Substitute earner, reschedule, availability

| ID | Item | Spec sketch | Size |
|---|---|---|---|
| T5.1 | **Substitute task (OP3)** | Un-comment `Task.relatedTaskId` / `relationOrder` / `HireMode` (AUDIT §2.14) plus new nullable `SUBSTITUTE_FROM` / `SUBSTITUTE_TO` dates. `POST /organiser/arrange-substitute` (and an auto-offer when `substituteSuggested`) clones the parent task as a temporary one for the leave range, `openToQuote = true`, `relatedTaskId = parent`. | M/L |
| T5.2 | **Temporary badge in job search** | Extend the nearby-jobs projection with `isTemporary` + the date range so `worksheet_screen` can render **"Temporary · 12–18 Aug"**. Requires touching the native query in `TaskSubProsRepo` and `TaskSubPros` — do this **after** T6.4 replaces that `@Subselect` hack with a DTO projection, or it gets much harder. | M |
| T5.3 | **Substitute lifecycle** | On acceptance, generate occurrences only within the range; at range end the substitute assignment closes and the original earner's jobs resume (they were `EARNER_LEAVE`, not deleted). | M |
| T5.4 | **Reschedule (OP7)** | `POST /organiser/propose-reschedule` + `/earner/respond-reschedule` on a single `TaskJob` (new nullable `PROPOSED_DATE`, `PROPOSED_BY`); `CancelType.RESCHEDULE`. Doorstep: `POST /doorstep/reschedule-order/{orderId}` while `PENDING`/confirmed. | M |
| T5.5 | **Availability windows (OP10)** | New `ProviderUnavailability` entity (provider, from, to) honoured by doorstep assignment and T4.1; earner working-days/slots preference used to pre-filter nearby jobs. | M |
| T5.6 | **Doorstep provider choice (B5)** | Customer picks the provider (so rates match the fulfiller — fixes AUDIT §4.17/§4.28); provider records `verifiedQuantity` + line prices at pickup. | M |

---

## 8. Phase 6 — Correctness, authz, performance, caching

Straight from AUDIT §5-D / §5-C, sequenced so prerequisites land first. Full specs written when reached. This phase is the gate before real users: it is what makes Phases 7–11 safe to build on.

| ID | Audit | Item |
|---|---|---|
| T6.1 | D1 | Authz/ownership pass: registered-provider check + no-overwrite in `acceptOrder`; ownership on `getTaskSchedule`; robust `getQuotesForTask`; block self-quoting; limit pending-order address exposure until acceptance |
| T6.2 | D2 | Kill N+1s: `toTaskSummary` count-per-task, per-order item fetches, `getDashboard` load-everything |
| T6.3 | D7 | ✅ **Done.** `@ControllerAdvice` — consistent 400s, no raw exception text, real logging (envelope unchanged). Shipped: `ApiExceptionHandler` (validation / unreadable body / missing param / type mismatch / escaped `CustomException` / catch-all with a neutral sentence and the stack trace in the log only); `catch (CustomException)` → 400 added to the 7 service methods that lacked one; human-readable `message =` on every constraint in `SignUpDto`, `LoginDto`, `LoginRequestDto`, `QuoteDto`; one sentence per field, preferring the emptiness violation. Client side: `ApiService.serverMessage` + `Widgets.showApiError` so screens stop replacing the server's explanation with "something went wrong", `LoginService.lastError` so signin/signup stop guessing "Invalid OTP", and `showSnackBar` now clears the previous bar, allows 4 lines (the old one clipped) and holds errors 6s. Also: a wrong OTP returned **500** because the access library reports bad credentials that way — corrected to 401 in `LoginServiceImpl` (library is off-limits, D-5). Removed a dead `@Pattern` on `NewTaskSchedule.date` (an `Integer`) that would have thrown `UnexpectedTypeException` the moment anything cascaded `@Valid`. Verified on device: bad number, wrong OTP and blank OTP each render the real reason. |
| T6.4 | 4.4/4.5 | ✅ **Done** (with T6.5 — same code, doing them separately would have meant touching it twice). `TaskSubPros` deleted: it was `@Subselect("select ID from task")` pretending to be an entity so Hibernate would accept a 20-column native query, and it carried five `@ManyToOne` `SubProfession` edges that `getSubPros()` walked — five extra selects per job on the busiest list in the app. Replaced by the `NearbyJobRow` projection + `NearbyJobDto`, with the names joined and `CONCAT_WS`'d in SQL. `ORDER BY 2` (which is `ADDRESS_LINE2` — the list claimed to sort by distance and sorted by street name) → `ORDER BY distanceKm, id`. `hasQuoted`'s `LEFT JOIN task_quote` duplicated a row per quote and was being papered over with a `LinkedHashSet` afterwards → `EXISTS`. The 25 km ceiling was hardcoded at the call site while only the floor came from the filter, so narrowing the filter never narrowed the query; both bounds are parameters now. |
| T6.5 | D9 | ✅ **Done.** `DistanceBucket` enum owns the km boundaries, which were written out three times (the `minDistance` switch, the Java re-filter, and `_distanceLabel` in `worksheet_screen.dart`). SQL now filters `floor < km <= ceiling` from the enum and the Java pass runs **only** for a non-contiguous selection (ticking "Very Short" and "Very Long" but nothing between); `sqlFloorOf` dips below zero for `VERY_SHORT` because `0 > 0` would have hidden a job at the earner's own coordinates. The DTO carries `distanceBucket` (code, for Phase 9 translation) and `distanceLabel` (words), so the app stopped deciding for itself what "Short" means. Verified on device: 3 jobs listed with the server's label, and unticking "Very Short" empties the list as it should. |
| T6.6 | D8 | ✅ **Done.** The booking form was configured by `getName().equalsIgnoreCase("Maid")` / `"Makeup Artist"` — a string an admin can edit, so renaming a profession silently changed its rules and a second recurring profession would have got the wrong form. Two columns now carry what the names stood for: `ALLOWS_ONE_OFF` (default true) and `MULTI_SELECT_SLOTS` (default false), alongside the existing `MULTI_SELECT_SUB_PROFESSIONS` — which, it turned out, was `false` even for Maid, so the name check was the *only* thing enabling multi-select. Backfilled the two rows to reproduce today's behaviour exactly, seeded the same in `InitServiceImpl` for a fresh DB, and taught `addProfessions` to carry the flags. Slots and pay units were identical in both old branches, so they stay hardcoded until something actually differs — noted in the code so the next difference becomes a column, not another name check. Verified: Maid → multi-select on, no "Once"; Makeup Artist → multi-select on, "Once" offered; Chef/Cook → neither. On device, Maid's form takes two specialisations and offers only Daily/Day(s)/Date(s), Carpenter's offers Once. |
| T6.7 | C-B7 | ✅ **Done.** `get-task-schedule` returned a paragraph of English the server had assembled (`"MON-FRI: Early Morning Slot"`) and the app printed it — nothing to translate, because the words were chosen where the reader's language is unknown. Now it returns `TaskScheduleDto`: `repeatType`, a list of lines each carrying a `ScheduleGroup` code + `slotCodes`, and `onceDate`/`onceTime` as ISO values. The weekday/Saturday/Sunday collapsing (Daily vs MON-SAT vs MON-FRI + SAT-SUN) stays server-side — it is reasoning, not wording — but only its *result* travels. New `lib/model/task_schedule.dart` owns the words and rebuilds the same sentence. Also fixed: the old daily branch printed **nothing** for any row shape it did not anticipate, which is how a task could show an empty schedule with no explanation; unrecognised shapes now list their rows. Verified on device — `MON-FRI: Early Morning Slot` and `Date: 03-03-2026 / Time: 09:00 AM` render exactly as before. |
| T6.8 | D6 | ✅ **Done as T4.15** — the doorstep work in Phase 4B needed the transition guard immediately, so it landed there rather than waiting for Phase 6. `DELIVERED → PENDING` is rejected. |
| T6.9 | D10 | ✅ **Done.** `revoke-quotation` was a **GET that withdraws a quotation** — re-fireable by any retry, prefetch or reload; now POST. The four `{filter}` path segments (`get-my-earner-tasks`, `get-my-earner-quotations`, `get-my-posted-tasks-filtered`, `get-received-quotes-filtered`) are `?filter=` query params, matching the endpoints added in Phase 1. App call sites and `Constants` updated to match. **Caught a regression from T6.3 while verifying this:** the old GET returned *500*, because the catch-all in `ApiExceptionHandler` was swallowing Spring's `HttpRequestMethodNotSupportedException` and `NoHandlerFoundException` — so every typo'd URL and every stale client looked like a broken server. Both now map to 405/404 with a plain sentence. Verified: new query-param routes 200, old path-segment routes 404, GET revoke 405, POST revoke 200; on device all three quotation filters return what the DB holds. |
| T6.10 | D4/D5 | ✅ **Done.** Three parts. **(1) `CacheService`** — `CategoryService` and `search_screen` each kept their own cache in their own shape (ISO timestamp vs epoch millis, different keys, slightly different expiry maths); one helper now owns read/write/invalidate with a shared TTL. **(2) `get-catalog-version`** — a one-query fingerprint (row counts + newest `UPDATED_DATE` across `profession`, `sub_profession`, `location_state`, `location_country`, hashed) that the app compares before deciding its catalog is stale. Counts alone would miss an edit, timestamps alone would miss a delete; together they catch both. This cuts the pointless hourly refetch *and* the up-to-an-hour delay before a new profession appears. Verified: stable across calls, changes when a profession row is touched, returns to the same value when restored. **(3) `IconService`** — every catalog response was stat-ing and re-reading an SVG per profession, ~80 file reads per home-screen call, for files that cannot change without a redeploy; now cached (misses too, so icon-less professions stop re-checking). `get-home-screen-professions` 77 ms → 21 ms. Verified on device: home icons and search results both still render. |
| T6.11 | C-B1/3/4/5/6/8 | ✅ **Done.** **C-B1:** the 7 `return null` endpoints deleted (they answered 200 with an empty body — worse than an error); nothing referenced them, all now 404. **C-B3:** new `get-states` + `StateService`; the app's own copy said `CG`/`TS` where the server stores `CT`/`TG`, so an address in Chhattisgarh or Telangana **saved with no state and no complaint**. The list is 36 rows now, not 28 — the hardcoded one omitted every union territory. Not filtered by `enabled` (all 36 are seeded false; that flag is for serviceable areas, T8.4). Killed the `retainWhere` that emptied the dropdown down to the single geocoded value, so the state could never be corrected once location was read. **C-B4:** search results navigate into the booking/category flow instead of showing "Selected: Chef/Cook (ID: 2)". **C-B5:** titles are "Maid — Cook, Dishwash", not "Get it done" on every task. **C-B6:** biometric failure now offers Try again / Close app instead of an endless spinner with no way out; the D.O.B row showing `12-05-1990` for every user is gone (nothing collects one). **C-B8:** `add-professions` / `add-sub-professions` mapped — written and wired but unreachable, so adding a profession meant editing `InitServiceImpl` and redeploying. **Two more bugs found while verifying:** the booking form guarded its spinner with `areSubProfessionsLoading && areProfessionRulesLoading`, so it drew as soon as *either* call finished and hit `LateInitializationError` reading the rules — fixed to `||`, and `ProfessionRuleDto`'s `late` fields given real defaults so a slow fetch degrades to an empty form, not a red screen; and the state dropdown overflowed 10px and updated its model without `setState`, so choosing a state left the previous one on screen. |
| T6.12 | D11/D12/D13 | ☐ **Not started** — pure refactor with no user-visible change, so it was left until after the behaviour work. Shared fetch/state helper, typed models, de-duplicated status maps & accept/reject flows, grid→navigation decoupling |
| T6.13 | U3/U4/U5/U7/U8/U9 | ✅ **Done.** Friction found in the live run. **U3/U9:** numeric keyboards + digit/length formatters + `.trim()` on phone, OTP and amount (done earlier); quantity in laundry booking now digits-only too — the numeric keypad still offers `-`, `.` and `,`, and any of them made `int.tryParse` fail and silently reset the order to one shirt. Server-side phone/OTP shape validation landed with T6.3. **U4:** `Widgets.checkBoxGroup` draws **radios** when `allowSingleSelect`; checkboxes promised "pick as many as you like" and then silently unticked the previous one. **U5:** `BottomNavigation` uses an `IndexedStack`, so a tab switch no longer destroys the screen and refetches everything — built lazily per first visit, since eagerly building all five would fire five screens' worth of requests before the user asks for any. Verified: scroll position survives switching away and back. **U7:** un-crossed `_screens`/`_iconPaths` at indices 1↔2. **U8:** OTP screen gained a back arrow (a mistyped number was previously unrecoverable without force-closing the app) and a "Resend code" with a 30s countdown, in a fixed position so it never moves under a finger. |

---

## 9. Phase 7 — Trust & reputation

**Why this is the "big app" phase, not a nice-to-have.** Urban Company's moat is not its booking form, it's that customers believe the person arriving is competent and safe. Today an organiser choosing between two quotes sees only a name and an amount — there is literally nothing else to decide on. Every item here builds on Phase 2's ratings.

| ID | Item | Spec sketch | Size |
|---|---|---|---|
| T7.1 | **Earner profile** | New `EarnerProfile` entity (user 1:1): `about`, `yearsExperience`, `languages` (CSV, matters for the Indian market), `serviceRadiusKm`, `photoRef`. `GET/POST /authenticated/earner-profile`. Public read on quote cards. | M |
| T7.2 | **Verification badges (mocked, admin-flipped)** | `VerificationStatus` enum `UNVERIFIED / DOCS_SUBMITTED / VERIFIED / REJECTED` on `EarnerProfile`; earner submits (no real document upload yet — see T11.8), admin flips via `/admin-user/set-verification`. Badge rendered next to the name. **No KYC integration, no real identity checks** — consistent with the mocked-auth rule. | M |
| T7.3 | **Reputation aggregates** | `EarnerStats` table (`earnerId` PK): `avgRating`, `ratingCount`, `jobsCompleted`, `onTimePercent`, `cancellationRate`, `repeatHireCount`. Recomputed for one earner on visit completion / rating submission / cancellation — **never aggregated live in a listing endpoint** (AUDIT §4.11). Data all exists by Phase 2. | M |
| T7.4 | **Reputation at the decision point** | Quote cards in `received_quotes_screen.dart` and `quotes_for_task_screen.dart` show ★ rating, jobs-completed, verified badge, languages. Highest-leverage UI change in the whole plan for conversion — an organiser can finally compare two earners. | M |
| T7.5 | **Favourites & block list** | `UserPreferredEarner(userId, earnerId, preference IN {FAVOURITE, BLOCKED})`. "Book the same person again" (feeds T8.2 rebook and Phase 5 substitute selection); blocked earners stop seeing that organiser's tasks and are excluded from auto-assignment. Enormous for recurring domestic work. | M |
| T7.6 | **Organiser reputation shown to earners** | Surface `RatingOnConduct` properly in the nearby-jobs card (count + average, not just the currently-always-zero `avgRating`) so earners can avoid bad customers — a two-sided marketplace needs both directions. | S/M |

---

## 10. Phase 8 — Demand, liquidity & discovery

Makes posted work actually get filled, and filled *again*. Recurring domestic services live or die on repeat booking.

| ID | Item | Spec sketch | Size |
|---|---|---|---|
| T8.1 | **Price guidance (data already exists and is being thrown away)** | `AddProfessionDto` carries `baseUnit`, `barLow`, `barHigh` (e.g. Maid → `"per day", 500, 1500`) for ~40 seeded professions, but `Profession` has no such fields, so `BeanUtils.copyProperties` **silently discards all of it**. Add the three columns (nullable, §0.3), copy them in `addProfessions`, expose via `get-profession-rules`, and show "Usually ₹500–1500 per day" in the new-task wizard's amount step. Backfill by re-running `/super-user/initial-setup` on a fresh DB or a one-off UPDATE. Cheap, and it stops low-literacy users guessing blind. | S/M |
| T8.2 | **One-tap rebook** | `POST /organiser/rebook-task/{taskId}` clones profession, sub-professions, schedule pattern, address and pay from a finished task; optionally targets a favourite earner (T7.5) directly instead of reopening to quotes. Button on completed tasks. | M |
| T8.3 | **Instant hire / broadcast-and-accept** | Replaces the stubbed `get-nearby-workers`. `HireMode.INSTANT` (enum already exists, field currently commented out on `Task`): notify the N nearest matching, available, non-blocked earners; **first accept wins**, no quoting round; falls back to the quote flow when `openForMins` expires (T4.3 already enforces expiry). This is the single biggest fill-speed lever. | L |
| T8.4 | **Serviceability gating** | `LocationState.enabled` is seeded and never checked (AUDIT §3.8). Enforce at task-post and order-place with a clear "we're not in your area yet" message + waitlist capture (`AreaWaitlist(pincode, city, userId)`) — waitlist data tells you where to expand. | M |
| T8.5 | **Earner job alerts** | Earner saves preferred professions + area; emit the already-unused `JOB_POSTED` notification on matching new tasks. Turns the app from pull to push for supply. | M |
| T8.6 | **Discovery polish** | Search results navigate into booking (folds C-B4 if still open); browse by sub-profession; "popular near you" ordering on the home grid driven by real booking counts instead of a static list. | M |

---

## 11. Phase 9 — Accessibility & language (the actual differentiator)

Product intent names unskilled/low-literacy users as primary. Urban Company is an English-first, urban-affluent product; **this is where Gasta can be genuinely better rather than merely comparable.** Everything here is additive and reversible.

| ID | Item | Spec sketch | Size |
|---|---|---|---|
| T9.1 | **i18n scaffold + Hindi** | `flutter_localizations` + ARB files; extract every user-facing string. Unblocked by T6.7 (structured schedule data instead of server prose) and by the code-plus-label DTO pattern already shipped in T1.4 — the backend sends `status`/`slot` **codes**, the app supplies the words. | L |
| T9.2 | **Regional languages** | Marathi, Tamil, Telugu, Bengali, Kannada, Gujarati as additional ARBs — pure data once T9.1 lands. | M |
| T9.3 | **Language picker** | First-launch chooser (before login, since login itself must be readable) + a switcher in Profile; persisted through the T6.10 cache helper. | S |
| T9.4 | **Icon-first / big-target pass** | Core flows only (login, home, new-task wizard, visit actions): larger type and tap targets, fewer words per screen, profession pictograms (the SVG icon set already exists server-side), progress dots already present in the wizard. Includes **U6**: replace the ambiguous single-letter day chips `M T W T F S S` (two `T`s, two `S`s, English-only) with localized short day names, and label the bottom-nav tabs in the chosen language rather than leaving five unlabelled icons. Strictly clarity-increasing — no new fields, no extra steps. | M |
| T9.5 | **Voice input & read-back** | `speech_to_text` for free-text fields (task description, feedback) and TTS read-out of visit details for non-readers. Must degrade gracefully when unavailable/permission-denied — never a hard dependency for completing a flow. | M |
| T9.6 | **Replace typing with choosing** | Numeric keypads, pickers and chips wherever text entry is currently required; pre-filled sensible defaults everywhere. | M |

---

## 12. Phase 10 — Ops & support platform

A marketplace at scale is run by people, and right now there is no surface for them at all: `ContactServiceImpl` is an empty class, and the admin endpoints that exist are unreachable.

| ID | Item | Spec sketch | Size |
|---|---|---|---|
| T10.1 | **Support tickets** | Implement the empty `ContactService`/`ContactServiceImpl` (AUDIT §2.2) as its intended purpose: `SupportTicket(user, category, subject, body, status, linkedTaskId/orderId)` + create/list/reply endpoints, plus a "Need help?" entry point on task and order screens. | M |
| T10.2 | **Admin / catalog management** | Expose the already-written but unreachable `addProfessions`/`addSubProfessions` (C-B8); enable/disable professions and states; manage serviceable areas (T8.4); approve verifications (T7.2); user lookup by phone. | M |
| T10.3 | **Disputes & manual intervention** | Force-reassign an earner, force-complete or force-cancel a task, mark a dispute resolved — each writing an `AdminAuditLog(actor, action, targetType, targetId, reason, at)`. Non-negotiable once real money-adjacent trust exists, even with payments parked. | M |
| T10.4 | **Cancellation policy & penalty ledger** | Per-profession free-cancellation window; late cancellations and no-shows recorded as **data** (`PenaltyRecord`) for later settlement. Records only — no charging, no wallet (payments stay out of scope). | M |
| T10.5 | **Ops queues (read APIs)** | The work-lists an ops person actually opens each morning: unfilled tasks past their window, visits with no earner action today, doorstep orders awaiting re-confirmation, no-shows, open tickets. All count/page queries, no in-memory scans. | M |
| T10.6 | **Admin UI inside the app** ✅ *decided: yes* | A `SUPER_USER`/`ADMIN_USER`-gated admin section in the existing Flutter app — no second frontend. Gate on the authority already returned by `get-self-account-details` (verified live: Profile shows `Role: SUPER_USER`), and rely on the existing `/super-user/**` and `/admin-user/**` matchers in `application.properties` so the server enforces it too, not just the UI. Entry point: a new "Admin" row in the Profile → Actions list (beside "Become a Service Provider"), opening a simple list-of-tools screen: catalog management, verification queue, serviceable areas, ops queues (T10.5), ticket inbox (T10.1). Screens are plain lists and forms — this is an internal tool, so the low-literacy design rules do **not** apply here and shouldn't slow it down. | M/L |

---

## 13. Phase 11 — Scale & platform hardening

| ID | Item | Spec sketch | Size |
|---|---|---|---|
| T11.1 | **Pagination everywhere** (B6) | `page`/`size` on every listing endpoint + infinite scroll. Do this before real data volume, not after. | M |
| T11.2 | **Real migrations** (R3) | Adopt Flyway, baseline the current schema, switch `ddl-auto` to `validate`. Until this lands, every schema change carries a manual dev-DB step and prod is not safely evolvable. | M |
| T11.3 | **FCM push** (E4) | Replace notification polling for reminders and re-confirmations — the flows from OP6 only really work with push. | M |
| T11.4 | **Observability** | Request ids, structured logs (extend the existing `GenericResponseMethods` logging rather than replacing it), slow-query logging, Actuator health/metrics. | M |
| T11.5 | **Config & environments** | dev/staging/prod profiles, secrets out of git (E6), app base-URL flavours (D14). | S/M |
| T11.6 | **Abuse guards** | Rate-limit the public endpoints — `otp-request` above all, since it is unauthenticated and unthrottled today. | S/M |
| T11.7 | **Library-level items (needs approval, §0.9)** | Investigate `@EnableWebMvc` in `MvcConfig` (it disables Boot's WebMvc auto-config — R9); align the multitenancy parent Boot version 3.1.2 → 3.3.x; remove the dead `getDatabaseContext()`. Requires a 2.9 → 2.10 bump and a `pom.xml` update. | M |
| T11.8 | **File/image storage** | There is **no upload path anywhere** today, yet profile photos (T7.1), verification documents (T7.2) and doorstep item-condition photos all need one. Decide local disk vs S3-compatible object storage, add multipart handling and size/type limits. | M/L |
| T11.9 | **Test scaffolding** | No real tests exist (`test/widget_test.dart` is the Flutter default). Start where value is highest and cost lowest: unit tests for `ScheduleExpansionService` (pure logic, the 5 acceptance cases in T1.1 become the first 5 tests), then a smoke suite over the visit lifecycle. | M |
| T11.10 | **Retention** (R5) | Purge/archive `task_job` rows older than ~12 months, keeping attendance history within a rolling year. | S |
| T11.11 | **Remaining polish** (E1–E3, E5) | Dead deps (`dio`, unused map plugin, `toggle_switch`), `Slot` label typos and unused values, typography helper, tokens → `flutter_secure_storage`, artifact rename. | M |

---

## 14. Progress tracker

| Phase | Task | Status |
|---|---|---|
| 0 | **T0.7 Build/encoding (BOM)** — BOM stripped, encoding pinned in `pom.xml`, guard at `scripts/check-no-bom.sh` | ☑ |
| 0 | **T0.6 Hikari pool > 1** — `max_hikari_pool_size=20`; boot log shows `maximumPoolSize....20`, MySQL `Threads_connected` 23 | ☑ |
| 0 | T0.8 Deterministic catalog ordering — `OrderByNameAsc` repos + `TreeMap` grouping; 3 identical calls verified | ☑ |
| 0 | T0.1 Once-date bug — picked 28-Jul in app → `FULL_DATE = 2026-07-28`, not today | ☑ |
| 0 | T0.2 `getTaskSchedule` crash/labels | ☑ |
| 0 | T0.3 `JobStatus` + `TaskJob` + repo — table dropped (0 rows) and recreated | ☑ |
| 0 | T0.4 Generation watermark | ☑ |
| 0 | T0.5 Targeted indexes — verified via `information_schema.STATISTICS` | ☑ |
| 1 | T1.1 `ScheduleExpansionService` — 5 plan cases + 4 edge cases pass | ☑ |
| 1 | T1.2 `ensureOccurrences` — idempotent across repeated reads | ☑ |
| 1 | T1.3 Trigger on accept — daily/weekday task → 10 rows, daily/ALL → 15 | ☑ |
| 1 | T1.4 `get-my-visits` — today/tomorrow/later/past/all; empty for unrelated users | ☑ |
| 1 | T1.5 `get-task-visits` — owner sees visits, non-owner gets 400 | ☑ |
| 1 | T1.6 Dashboard from occurrences — Today 1 / Tomorrow 1 / Later 23 in app | ☑ |
| 1 | T1.7 `Visit` model + constants | ☑ |
| 1 | T1.8 Earner visits UI — visit tiles render on Today/Tomorrow/Later | ☑ |
| 2 | **T2.0 Job start code + arrival confirmation** — code gate, "customer not available" fallback, auto-confirm stamp, one-off arrival prompt | ☑ |
| 2 | T2.1 Visit status transitions (earner) — transition table + date guard + `applyStatus` mirror | ☑ |
| 2 | T2.2 Organiser confirms a visit — both timestamps stamped | ☑ |
| 2 | T2.3 Attendance summary — 6 count queries, matches hand-checked DB | ☑ |
| 2 | T2.4 Task completion & cancellation — Done/Withdrawn filters no longer empty | ☑ |
| 2 | T2.5 Ratings — both directions persist; `avgRating` returns 4.0 instead of null | ☑ |
| 2 | T2.6 Notification gaps + icon cases — `QUOTE_RECEIVED`, `JOB_ASSIGNED`, `JOB_STARTED`/`GENERAL` icons | ☑ |
| 2 | T2.7 Flutter visit actions + rating dialog — full two-account round trip in the emulator | ☑ |
| 3 | T3.1 Earner marks leave — dates marked, organiser notified, `substituteSuggested` at ≥2 days | ☑ |
| 3 | T3.2 Organiser skips / pauses — per-date skip and range pause, past dates untouched | ☑ |
| 3 | T3.3 New notification types + icon cases | ☑ |
| 3 | T3.4 Read-triggered reminders — 4 emitted, unchanged across 3 screen opens | ☑ |
| 3 | T3.5 Flutter leave / skip UI — date multi-select, "Take leave" / "Not needed" / "Pause for dates" | ☑ |
| 3 | T3.6 Real scheduling — 3 clean runs on `scheduling-1`, kill-switch verified, 10 concurrent requests in 312 ms | ☑ |
| 4–11 | **Tracked in [PLAN-2.md](PLAN-2.md) §7** — expanded, re-scoped, and with human-behaviour gaps folded in | ☐ |

---

## 15. Risks & open decisions

| # | Item | Status |
|---|---|---|
| R1 | **Background jobs under `mysql-multitenancy`.** Traced in §0.9: a null `db` header → null ThreadLocal → `AbstractRoutingDataSource` falls back to the default datasource. Background threads behave identically to requests. | ✅ **Resolved** — proven live in T3.6: three scheduler runs on `scheduling-1`, no datasource error |
| R2 | **Connection pool is 1** (§0.9 consequence 2). Confirmed live — boot log adds exactly one connection. Caps every phase; must be fixed before any scheduled job exists. | ✅ **Fixed in T0.6** — `maximumPoolSize=20`, 10 concurrent requests in 312 ms |
| R15 | **Hibernate cannot widen a MySQL `ENUM` column.** `@Enumerated(EnumType.STRING)` maps to `enum(...)` on MySQL, and `ddl-auto=update` never alters the value list — so every new `NotificationType` failed to insert with "Data truncated". Fixed by pinning `columnDefinition = "VARCHAR(64)"` on `Notification.notificationType` plus a one-off `ALTER TABLE notification MODIFY COLUMN NOTIFICATION_TYPE VARCHAR(64) NOT NULL`. **Other enum columns (`task_job.STATUS`, `SLOT`, `CANCEL_TYPE`) have the same latent problem** — they only work today because the table was created fresh with every value. Widen them the same way before adding values, or let Flyway (T11.2) handle it. | ⚠️ **Fixed for notifications; latent elsewhere** |
| R16 | **Response `Content-Type` carried no charset**, so Dart's `http` decoded UTF-8 bodies as latin-1 and "₹" rendered as "â‚¹" in the app. Fixed on both sides: `server.servlet.encoding.*` makes the server declare `charset=UTF-8`, and `ApiService` now decodes `bodyBytes` as UTF-8 so every existing caller is covered. | ✅ **Resolved** |
| R3 | **`task_job` recreate** — verified live: `COUNT(*) = 0`. Safe to drop. | ✅ **Resolved** (§0.10) |
| R12 | **The build was broken as committed** (BOM → javac failure). Fixed during the live run; encoding pin and CI guard still outstanding. Nobody could have implemented anything until this was found. | ◐ **T0.7** |
| R13 | **Catalog order is non-deterministic**, so the home grid reshuffles between launches — bad for position-and-picture navigation, and it makes "tap the first profession" acceptance steps unreliable. | **T0.8** |
| R4 | **`ddl-auto=update` can't tighten nullability** — new columns on populated tables stay nullable (§0.3). Flyway (T11.2) is the real answer and is a deliberate proposal, not a silent change. | Open until T11.2 |
| R5 | **Horizon vs. schedule edits.** Phase 1 never edits existing occurrences; if a schedule changes (no endpoint exists today — AUDIT §3.9), future rows go stale. Reconciliation belongs with T5.4. | Deferred, documented |
| R6 | **Occurrence volume.** ~14 rows/task/fortnight is trivial now; purge lands in T11.10. | Watch |
| R7 | **`MISSED` detection** is manual in T4.4; automatic no-show marking becomes possible once T3.6 is live. | Unblocked by T3.6 |
| R8 | **Slot enum divergence** — backend has 30+ values, app has 4 (`E_1..E_4`) with different strings (AUDIT §4.21). `VisitDto` returns codes **and** labels so the app never calls `Slot.values.byName` on an unknown value. Don't emit non-`E_*` slots until T11.11 prunes them. | Mitigated by design |
| R9 | **`@EnableWebMvc` in `MvcConfig`** switches off Boot's WebMvc auto-configuration for the whole backend, so `spring.mvc.*`/`spring.jackson.*` properties and Boot's default error/static handling are inert. Harmless today (the app works), but it will surprise someone. Library-level → T11.7, needs approval. | Documented |
| R10 | **Multi-tenancy is available but inert** — the `db` header is never sent. If per-city/region sharding is ever wanted, it needs no library change, only a client header or a server-side filter. Explicitly **not** being built. | Parked by choice |
| R11 | **All four decisions answered** — (a) **job start code** adopted: organiser reads a 4-digit per-visit code, earner enters it to start work, with a mandatory "organiser not available" fallback and *no* silent auto-confirm of completion (24h auto-advance flagged as `autoConfirmed`); one-time visits additionally ask the organiser "did they arrive?" → **T2.0**. (b) `substitute-threshold-days = 2` **confirmed** → T3.1 property default. (c) **admin UI in-app, approved** → T10.6 rewritten. (d) local languages stay in **Phase 9** — wanted, not urgent during development. | ✅ **Closed** |
| R14 | **Docker note for whoever runs this next:** do *not* start MySQL/Redis containers — the host already serves 3306 (native MySQL 8.0.39) and 6379 (container `my-redis`). Unrelated `gasta-local-*` / `gasta-api-*` containers exist on this machine and were left untouched. Full working recipe in §0.10. | Documented |

---

*Plan written against the code as of this audit, plus the `mysql-multitenancy` source now present in-repo. Phases 0–3 are implementation-ready; Phases 4–11 are directionally fixed and get expanded to full task specs at their turn. Nothing here changes the app's architecture or identity: pattern-based scheduling, the response envelope, `setState` screens, and client-side caching all stay — the growth comes from completing what the schema already anticipated and then building trust, liquidity, language and ops on top.*
