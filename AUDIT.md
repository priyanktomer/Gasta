# Gasta — Phase 1 Audit (Yapan + JeevikaService)

Audit only. No code was changed. Scope: **Yapan** (Flutter app) and **JeevikaService** (Spring Boot backend). `access-app` and `super-methods` reviewed only as integration points.

---

## 1. Architecture map

### The four "services" and how they actually relate

| Piece | What it is | Runtime shape |
|---|---|---|
| **Yapan** | Flutter mobile app (Android-first) | Standalone app, talks HTTP to JeevikaService at `http://10.0.2.2:8080` (hardcoded in `Yapan/lib/util/constants.dart`) |
| **JeevikaService** | Spring Boot 3.3 / Java 17 backend (Maven artifact is confusingly named `Yapan`) | The only deployed backend process |
| **access-app** | Auth library (JWT filters, OTP via Redis, Users/UserData/UserSession entities, SecurityConfig) | **Not a separate service at runtime** — pulled in as a Maven jar and component-scanned into JeevikaService (`GastaBackendApplication` scans `com.actually.accessapp`) |
| **super-methods** | Utility library (`CustomResponse` envelope, `GenericResponseMethods`, string/date/collection helpers, `CustomException`) | Same — a jar, component-scanned in |

A fourth library, `mysql-multitenancy`, provides the datasource (single MySQL `gasta` schema in dev, `ddl-auto=update`, no migrations). Redis is required for OTP storage even though OTP is mocked.

### Integration points with access-app (do not modify, per scope)
- `application.properties`: `access-app.security-mode=2.3`, `STATELESS_JWT` session mode, public matcher `/api/v1/yapan/common/**`, authority matchers for `/super-user/**` (SUPER_USER) and `/admin-user/**` (ADMIN_USER/SUPER_USER). Everything else requires any authenticated user.
- `AccessService`: `requestOtp / login / verifySignUp / refreshToken / logout / getUser` — called from `LoginServiceImpl`; `getUser()` used in every service method for identity.
- `UserData` entity + `UserDataRepo` are used directly by Jeevika entities as FK targets (organiser, earner, customer, provider, updatedBy).
- OTP is mocked as intended: `access-app-otp=false` means `OtpServiceImpl.generateOtp()` returns `"000000"` (the property is oddly wired into a variable named `appName`, but the mocked outcome is what you want for now).
- Auth headers contract: `Authorization` + `atsh` (access token), `ntkn` + `ntsh` (refresh), HTTP 412 = access token expired → client refreshes and retries.

### JeevikaService internal layout

```
controller/   CommonController (public: ping, otp-request, login/sign-up verify, refresh)
              AuthenticatedController (profile, addresses, notifications)
              OrganiserController (professions/catalog + task posting + quote management)
              EarnerController (nearby jobs, quoting, my tasks/quotations)
              DoorstepController (pickup-drop orders, provider registration/rates)
              AdminController (initial setup, countries/states)
service/  +  serviceimpl/   one interface + one impl per area; PaymentService & ContactService are empty stubs
repo/         Spring Data JPA repos + one native-SQL repo (TaskSubProsRepo, geo search)
entity/       Task, TaskSchedule, TaskQuote, TaskSubPros(@Subselect view), TaskJob, TaskChat,
              Profession, SubProfession, AppUserAddress, LocationCountry/State,
              DoorstepProvider, DoorstepServiceRate, PickupDropOrder(+Item),
              Notification, RatingOnWork, RatingOnConduct
```

Two product verticals share this backend:
1. **Task marketplace** ("organiser" posts a Task with a schedule; "earners" browse nearby jobs, submit TaskQuotes; organiser accepts → earner assigned to task + schedules).
2. **Doorstep pickup-drop** (currently laundry): providers register per profession with a rate card; customers place item-level orders; status flows PENDING → PICKED_UP → … → DELIVERED.

### Yapan (Flutter) internal layout

```
main.dart                startup: location permission → GPS → ping server → token refresh → biometric gate → app
navigation/              BottomNavigation: Home | Earning Zone | Dashboard | Notifications | Profile
screens/  (~25)          organiser flow (new_task_page 4-step wizard, posted tasks, quotes),
                         earner flow (worksheet = nearby jobs + quote sheets, earner tasks/quotations),
                         doorstep flow (services grid, laundry booking wizard, orders, order detail,
                         become-provider wizard), addresses (+ map-less picker), login/OTP screens,
                         search, notifications, profile
service/                 ApiService (single http wrapper: auth headers, 412→refresh→retry, failure envelope),
                         LoginService (token save), CategoryService (SharedPreferences cache w/ 60-min TTL),
                         LocationUtils (permission + lat/long cache), SharedPrefService
model/                   DTOs (Task, TaskSummary, QuoteView, PickupDropOrder, NameIconDto, …)
widgets.dart             shared widget factory (grids, chips, toggles, error/retry, shimmer)
```

Navigation quirk worth knowing: home-screen grids don't navigate directly — every tile pushes `HomeHelperScreen(id, title, type)` which switches on a magic `type` int (1–5) and immediately replaces itself with the real screen.

The API response envelope (`CustomResponse`: message/payload/status/timestamp + per-API name) is consistent across the backend and consumed uniformly by the app — per your note, this is intentional and **not** flagged.

---

## 2. Incomplete / unfinished work

### Backend — dead or stubbed
1. **Seven endpoints return `null`** (HTTP 200 with empty body → client sees a hang/parse failure):
   - `OrganiserController`: `get-nearby-workers`, `get-ongoing-job`, `get-jobs-scheduled`, `get-jobs-posted`
   - `EarnerController`: `get-ongoing-work`, `get-worklist`, `get-works-quoted`
   - (The organiser ones are superseded by `get-my-posted-tasks*`; the earner ones by `get-my-earner-*` — these look like abandoned predecessors.)
2. **`PaymentServiceImpl` and `ContactServiceImpl` are empty classes** — payment fields on `Task` (`amountPaid`, `calculatedPart`, `partDrawn`) are never touched.
3. **`AdminService.addSupportUsers` returns `null`** (stub).
4. **`TaskChat` is missing `@Entity`** — it has `@Table`/`@Data` but is not a JPA entity; no repo, no service, no endpoint, no UI. Chat is entirely unbuilt.
5. **`TaskJob`** — javadoc says "To be populated later on from back end"; nothing ever creates a row. Per-occurrence job tracking (arrived/started/completed/canceled per slot) doesn't exist.
6. **Ratings**: `RatingOnWork` / `RatingOnConduct` entities exist but have **no repositories and no write API**. The nearby-jobs query LEFT JOINs `rating_on_conduct` for `avgRating`, which is therefore always null — the app displays "0.0 ★" forever.
7. **Task lifecycle dead-ends**: there is **no endpoint to complete, cancel/withdraw, or give feedback on a task**. `Task.feedbackProvided` and `Task.active` are never mutated after creation. Consequences:
   - Dashboard counts for "Done", "Withdrawn", "Completed", "Canceled" are permanently 0.
   - `PostedTasksScreen` filters `done`/`withdrawn` and `EarnerTasksScreen` filters `completed`/`canceled` always return empty.
8. **`MiscService.updateAddress` exists but is not exposed by any controller.** There is also no delete-address or set-home-address endpoint at all (see the matching fake UI below).
9. **`AdminService.addProfessions` / `addSubProfessions` are not reachable via any controller** — they're only called from `InitService`. Admins cannot add professions post-setup.
10. **Notification types mostly unused**: only `QUOTE_ACCEPTED` / `QUOTE_REJECTED` are ever sent. `QUOTE_RECEIVED`, `JOB_POSTED`, `JOB_ASSIGNED`, `JOB_COMPLETED`, `JOB_CANCELED` exist in the enum and the app has icons for them, but nothing emits them — notably **an organiser gets no notification when a new quote arrives** (arguably the most important one).
11. **`PickupDropOrderItem.verifiedQuantity`** — no API can ever set it (`update-status` only sets status/totalAmount), yet it's surfaced in DTOs.
12. **Stored-but-never-used fields**: `Task.openForMins/openForDays` (no expiry job/check anywhere), `DoorstepProvider.maxOrdersPerDay` (never enforced in `placeOrder`), `DoorstepProvider.servicePincodes` (CSV stored, never matched — assignment uses lat/lng instead).
13. **`YapanAppConfig.addSuperUser`** — commented-out seeding; super-user bootstrap instead relies on the hardcoded phone `8191910695` inside `LoginServiceImpl.signUpVerify` (fine for dev, but it is load-bearing and invisible).
14. Large commented-out blocks: `getProfessionsListByCategory` in `OrganiserController`, `getTaskSubProfessions` in `EarnerServiceImpl`, HireMode/related-task fields on `Task`/`NewTaskDto`, home-menu entries, etc.

### Flutter — half-built or fake
15. **Fake address actions** ([address_screen.dart:114-136](Yapan/lib/screens/address_screen.dart:114)): "Set as Home Address" and "Delete Address" both just call the **GET address-list endpoint** and show a success snackbar. Nothing happens. This is UI lying to the user.
16. **Map picker commented out** ([new_address_screen_2.dart:91-130](Yapan/lib/screens/new_address_screen_2.dart:91)): the Google Map + `_selectLocation` flow is dead code; users can only save their current GPS point as an address. (`google_maps_flutter` is still a dependency.)
17. **Search screen is a dead end** ([search_screen.dart:169-183](Yapan/lib/screens/search_screen.dart:169)): tapping a result only shows a snackbar with the ID. No navigation to the profession/booking flow.
18. **ONCE-schedule date bug** ([new_task_page.dart](Yapan/lib/screens/new_task_page.dart)): the date picker writes only to `_dateController.text`; the `taskDate` state variable used by `submit()` is never updated. Every "Once" task is scheduled for **today** regardless of the picked date.
19. **State-code mismatch breaks add-address**: `new_address_screen_2.dart` hardcodes its own state list with codes `CG` (Chhattisgarh) and `TS` (Telangana), while the backend seeds `CT` and `TG` (`InitServiceImpl`). For those states `locationStateRepo.findByCode` returns null → `state` is null → insert violates the NOT NULL FK → save fails. Also several states/UTs are missing from the app list, and `indianStates.retainWhere((s) => s == state)` **destroys the dropdown list** after the first geocode.
20. **BiometricAuthScreen dead ends**: on auth failure or exception it does nothing — user is stuck on a spinner forever ([BiometricAuthScreen.dart:55-65](Yapan/lib/screens/BiometricAuthScreen.dart:55)).
21. **Placeholder data in UI**: task title hardcoded to `"Get it done"` for every posted task; profile D.O.B hardcoded `"12-05-1990"`; wizard steps labeled "Step 1, 2, 4, 5" (no 3); sign-up screen header says "Login to your account".
22. **Duplicated dead revoke flow** in `worksheet_screen.dart`: the confirm dialog's "Revoke" button performs the revoke itself *and* pops `false`, so the second `if (confirmed == true)` block (a full copy of the same logic) is unreachable dead code.
23. `print()` debug logging left in laundry booking, become-provider, and address screens.
24. Laundry booking fetches its rate card from a **hardcoded endpoint string** (`/doorstep/profession/{id}/providers`) not in `Constants`, unlike every other call.

---

## 3. Missing features (judged against "broader and better than Urban Company" for the Indian market)

Ordered roughly by how conspicuous the absence is:

1. **Task completion / settlement loop** — the marketplace ends at "quote accepted". No done/confirm/pay/feedback. Without this the core loop doesn't close and the dashboard is permanently half-zeros. (Payment can stay mocked/COD-marker; the *state transition* and *ratings* are the missing product.)
2. **Ratings & trust** — for a labor marketplace this is the currency. Entities exist; capture and display are absent (earner rating shown to organiser, organiser conduct rating shown to earner — the schema already anticipates both).
3. **Contact between matched parties** — after acceptance there is no phone reveal, call button, or chat. An assigned earner literally cannot coordinate arrival. (TaskChat placeholder exists; a simple "show phone number after assignment" would already close the gap.)
4. **Recurring-schedule awareness ("my day")** — schedules are stored as patterns (`REPEAT_DAILY`, day/dateGroup), but Today/Tomorrow/Later filters and dashboard counts only look at `fullDate`, which is null for recurring tasks. A maid hired daily never appears in anyone's "Today". No occurrence expansion exists anywhere.
5. **Worker discovery / instant hire** — "Nearby Earners" and "Hire Instantly" are commented out of the home menu and stubbed in the API. Only reverse-marketplace (post & wait for quotes) works.
6. **Localization & low-literacy UX** — app is English-only with text-heavy flows. For the stated primary users, Hindi + regional language support (and more icon/voice-forward flows) is the single biggest product gap. There is no i18n scaffolding at all (`gen_l10n` config exists in build artifacts but no ARB files/usage).
7. **Pagination** — every listing endpoint returns the full result set (`findByOrganiser_Id...` etc.) and the app renders it all. Fine at 10 rows, broken at 10,000 users.
8. **Serviceable-area gating** — countries/states are seeded and can be "enabled", but nothing checks them; any lat/lng works. Pincode/city gating is absent.
9. **Task editing/withdrawal** by organiser; quote editing by earner (only revoke exists).
10. **Doorstep provider choice** — customer can view providers/rates but cannot *choose* one; backend silently auto-assigns nearest (see §4 conflict). No price confirmation step after pickup verification.
11. **Push notifications** — in-app polling only; no FCM. For a "come back when someone quotes" product, this matters.
12. **Basic input validation** — mobile number format/length, amount numeric checks, OTP length — almost none client- or server-side (`@Valid` is on a few DTOs but most have no constraints).

### 3b. Operational feature gaps (highest-priority missing category)

Benchmarked against how **Urban Company (formerly Urban Clap)** and **Yes Madam** run day-to-day operations. The current app handles *matching* (post → quote → accept) but nothing that happens **after week one of an engagement** — and for recurring domestic work, operations *are* the product. Notably, your schema already anticipated most of this: `TaskJob` (per-occurrence tracking, unimplemented), `CancelType` (`RESCHEDULE, ONLY_TODAY, SELECT_DATES, PERMANENTLY` — literally the leave/skip vocabulary), and the commented-out `relatedTaskId`/`relationOrder`/`HireMode` fields on `Task` (a ready-made hook for substitute/temporary jobs). These features are *completions of your own design*, not new architecture.

1. **No occurrence engine** — recurring schedules are never materialized into concrete dated visits, so nothing downstream (leaves, reminders, attendance, "today" lists) has anything to attach to. `TaskJob` is the intended table and is empty.
2. **Earner leave management** — a maid on a daily engagement has no way to mark tomorrow (or 5 days) as leave; the organiser finds out when nobody shows up.
3. **Substitute/temporary earner** — for multi-day leaves, no way to arrange temporary cover; no way for other earners to see such short-term gigs in their nearby-jobs list (needs a "Temporary, {date range}" job type — the commented-out related-task fields fit exactly).
4. **Organiser pause/skip** — organiser traveling for a week cannot skip visits or pause the schedule; earner would show up to a locked door.
5. **Visit-day workflow** — no "on my way / arrived / done" states, no organiser confirmation of a completed visit, no missed-visit/no-show record. (Urban Company's job start/end flow; verification codes can stay mocked per your constraint — a confirm-tap suffices.)
6. **Reminders & re-confirmation** — nothing reminds either party of tomorrow's visit; your doorstep example is exact: an order scheduled long in advance gets no "are you still available?" ping to the provider (or customer), and no fallback reassignment when the provider has forgotten/declines.
7. **Reschedule** — neither a single task occurrence nor a doorstep pickup can be moved; the only tool is cancel (which also doesn't exist for tasks).
8. **Cancellation & auto-recovery** — no cancel-with-reason using `CancelType`; when an assigned earner bails, the task doesn't reopen to quotes; pending doorstep orders never expire or escalate.
9. **Task/quote expiry** — `openForDays`/`openForMins` are collected from the organiser and stored, then ignored; stale tasks stay "open" forever.
10. **Provider/earner availability windows** — doorstep providers have only a binary active toggle (no "off from 12th–18th"); earners have no declared working days/slots to pre-filter the jobs list.

---

## 4. Bad approaches / weak patterns

### JeevikaService — schema & data modeling

| # | Finding | Why it's a problem |
|---|---|---|
| 4.1 | **`TaskSchedule` pattern model with `SLOT_1..SLOT_6` and `DAY`/`DATE`/`DATE_GROUP` columns** ([TaskSchedule.java](JeevikaService/src/main/java/com/actually/yapan/entity/TaskSchedule.java)) | Repeated-column denormalization (max 6 slots, only 4 ever written since profession rules cap at E_1..E_4). Worse, the *access pattern* is "what's happening on date X" — a pattern row can't answer that without expansion logic, which doesn't exist (see §3.4). The `DateGroup` heuristics (`ALT_1`, `TENS_2`, `FORTNIGHT_1`…) compress user selections lossily at write time (`OrganiserServiceImpl.addNewJob`) and force every reader to decompress them (`EarnerServiceImpl.getTaskSchedule`). Both sides are already buggy (below). |
| 4.2 | **`Task.SUB_PROFESSION_1..5` columns** instead of a join table | Same repeated-column pattern; silently truncates to 5; makes "find tasks by sub-profession" unqueryable without OR-chains. |
| 4.3 | **One giant composite index per table** (e.g. `Task`: `IS_ACTIVE, IS_OPEN_TO_QUOTE, PROFESSION_ID, ORGANISER_ID, EARNER_ID, CREATED_DATE` as a *single* index) | Leftmost-prefix rule means `findByOrganiser_Id`, `findByEarner_Id`, the quote lookups, etc. can't use these. In practice most hot queries are unindexed. Applies to `task`, `task_quote`, `task_schedule`, `app_user_address`, `notification`, etc. |
| 4.4 | **`TaskSubPros` `@Subselect("select ID from task")` + `@Immutable` entity used purely as a row-mapper for one native query** ([TaskSubProsRepo.java](JeevikaService/src/main/java/com/actually/yapan/repo/TaskSubProsRepo.java)) | The subselect lies about its columns (maps 20 fields over `select ID`); it only works because the native query aliases everything. Fragile duplicate of `Task`'s mapping; any column rename breaks it silently. A DTO projection would do the same job honestly. |
| 4.5 | **Nearby-jobs native query issues**: `ORDER BY 2` (orders by ADDRESS_LINE2 — meaningless), `HAVING` on the distance alias without GROUP BY, LEFT JOIN to `task_quote` can fan out rows (papered over by `LinkedHashSet` dedupe in Java), and the distance-bucket filter is applied **twice** (min/radius in SQL, then label-bucket re-filter in Java with slightly different edges: SQL `minDistance` for "Short" is 0.8 but Java's bucket is 0.8–2). | Wrong ordering, duplicated logic, subtle boundary inconsistencies between the two filters. |
| 4.6 | **Distance contract = UI label strings** (`"Very Short"`, `"Moderate"`…) passed from app to backend and switch-matched on both sides | Magic strings shared across two codebases; adding a bucket or translating the UI breaks search. Should be an enum/numeric range in the contract. |
| 4.7 | **`AppUserAddress.state` joins on non-PK `CODE`; `LocationState` uniqueness is (CODE, COUNTRY_CODE)** | Join by non-unique-alone code; combined with the client sending its own (wrong) codes, this is where add-address breaks (§2.19). |
| 4.8 | **DB credentials in `application.properties` in git**; CORS `*`; `spring.jpa.hibernate.ddl-auto=update` with no migration tool | Acceptable for a college project, but worth flagging: schema drift via `ddl-auto=update` is already visible (entities renamed leave orphan columns) and there's no way to evolve schema deliberately. |
| 4.9 | **`mysql-multitenancy` + Redis as hard dependencies** for a single-tenant dev app | Operational complexity with no current benefit; Redis exists only to store a mocked OTP. (Not asking to remove — just noting the weight.) |

### JeevikaService — services & API behavior

| # | Finding | Why |
|---|---|---|
| 4.10 | **Authorization is authentication-only for most business routes.** Concrete gaps: `getTaskSchedule` — any user can read any task's schedule; `getQuotesForTask` — ownership is checked only *if the list is non-empty* (and by inspecting quote #0); `DoorstepController.acceptOrder` — **any authenticated user** can accept any pending order (no check they're a registered/active provider) and it silently overwrites the auto-assigned provider; `pending-orders/{professionId}` exposes all pending orders **with customer names and addresses** to any logged-in user; `addTaskQuote` doesn't prevent quoting your own task (the search excludes own tasks, the API doesn't). | These are logic-level access controls, not "auth hardening" (which you deprioritized) — they're one-line ownership checks that protect user data and marketplace integrity. |
| 4.11 | **N+1 queries in listing endpoints**: `toTaskSummary` does a `countByTask_Id...` per task (posted-tasks list); `getMyOrders`/`getPendingOrdersForProvider`/`getMyProviderOrders` do `findByOrder` per order; `getDashboard` loads **entire task/quote/schedule tables for the user into memory** just to count them. | Violates your own "listing should be cheap" rule. Counts should be `count()` queries or a grouped query; items should be fetched with `IN (orderIds)`. |
| 4.12 | **Icons as base64 SVG inlined in every list response**, re-read from disk and re-encoded per request (`getHomeScreenProfessions`, `getProfessionsGroup`, `getDoorstepProfessions`, …) | Fattens every catalog response (compression helps but doesn't fix repeat cost); no server-side caching; the icon set is static and could be bundled in the app or served as cacheable static files. |
| 4.13 | **Business rules keyed on profession *name strings***: `getProfessionRules` special-cases `"Maid"` / `"Makeup Artist"` by `equalsIgnoreCase`; a name edit silently changes booking rules. A DB flag (`multiSelectSubProfessions`) was added later but the name checks remain as OR-conditions. | Data-driven rules half-migrated; finish the migration and delete the name checks. |
| 4.14 | **Error handling**: every method is `try/catch(Exception)` → 500 with `e.getMessage()` concatenated into the user-facing message (leaks SQL/internal details); `CustomException` → 400 mapping is applied in Doorstep but not in Organiser/Earner (a "Quote not found" surfaces as 500 there); `printStackTrace()` for logging. | Inconsistent semantics for the client, information leakage, and no real logs. A `@ControllerAdvice` would centralize this without changing the response envelope. |
| 4.15 | **Mutations via GET**: `earner/revoke-quotation/{id}` (and the app calls it with GET). | Cacheable/prefetchable mutation; also inconsistent with every other write being POST. |
| 4.16 | **Route-style inconsistency**: verb-RPC names (`get-nearby-jobs`, `post-new-job`, `add-task-quote`) alongside resource-nested doorstep routes (`/doorstep/provider/rates/{providerId}`); filters as **path segments** (`get-my-earner-tasks/{filter}` with magic strings `today|done|withdrawn`) instead of query params; `refresh-token` living under `/common/secure/` while being public; duplicate aliases in responses (`providerId` and `id` both returned "for compatibility"). *(Response body shape not flagged — this is about route naming only.)* |
| 4.17 | **Doorstep has two conflicting assignment models**: `placeOrder` auto-assigns the nearest provider (and prices items off *that* provider's rates), while `pending-orders` + `acceptOrder` implement an open marketplace where anyone can grab the order — overwriting the assigned provider **while keeping unit prices from the original provider's rate card**. | Prices can belong to provider A while provider B fulfills. Pick one model (recommend: customer picks provider, or auto-assign with provider accept/decline). |
| 4.18 | **`updateOrderStatus` has no transition validation** — a provider can move DELIVERED back to PENDING, or set CANCELLED, any time; `updateMyRates` does delete-all-then-insert (brief window with no rates; relies on `@Transactional`, but also loses rate history). |
| 4.19 | **`EarnerServiceImpl.getTaskSchedule` returns display prose** ("MON-FRI: 08:45 AM - 10:00 AM\n…") built server-side | Untranslatable (kills the localization goal), unparseable by the client, and already buggy: in the REPEAT_DAILY branch `week` is computed by filtering `Day.SAT` (copy-paste — same filter as `sat`), so several daily-schedule strings render wrong; `res.get(0)` throws if a task has no schedule rows. |
| 4.20 | **`addNewJob` grouping mutates shared DTO instances** (`getBaseSchedule` returns the *original* list element, then `base.setDay(...)`/`setDate(null)` mutates it while the same list is being iterated/filtered) — works today by luck, extremely easy to break. Also `address` can silently be null (invalid `addressId` → NPE at save → 500 with raw message). |
| 4.21 | **Slot enum duplication & typos**: backend `Slot` has 30+ values with display strings (`C_0700_1100("07:00 AM - 11:00 PM")` — PM typo; `D_12_20("12:00 AM - 08:00 PM")`), the app has its own 4-value `Slot` enum with *different* display strings. Only E_1..E_4 are ever used; the rest are dead weight that will crash the app's `values.byName` if ever emitted. |

### Yapan (Flutter) — app-wide patterns

| # | Finding | Why |
|---|---|---|
| 4.22 | **No state management layer; everything is `setState` + per-screen fetch-on-init** | Every tab switch/back-navigation refetches (bottom nav keeps screens alive, but every pushed screen refetches on open); no shared session/user store (profile, addresses fetched repeatedly by different screens); loading/error boilerplate copy-pasted ~15 times. A light shared-service/ChangeNotifier layer (not a framework rewrite) would cut hundreds of lines. |
| 4.23 | **Untyped `dynamic` JSON maps in many screens** (addresses, provider profiles, laundry rates: `address["state"]["name"]`, `profile['rates']`) | Null-safety bypassed; a missing key is a runtime crash on-screen. Other screens (TaskSummary, QuoteView, PickupDropOrder) do it properly — inconsistent. |
| 4.24 | **`widgets.dart` grids hardwire navigation**: `buildGridItemN` pushes `HomeHelperScreen(type: 1..5)`, and `HomeHelperScreen` is an int-switch router | A "generic" grid component that can only navigate to one place, driven by magic ints spread across call sites. Adding a tile type means touching three files. |
| 4.25 | **Three separate cache implementations** with the same TTL logic: `CategoryService` (professions map + categories list), `SearchScreen` (its own `professions_cache` keys for the *same* sub-professions data), `LocationUtils` (lat/lng) — plus `CategoryService` keeps 6 "backward compatible" wrapper methods around 2 real ones. **To be clear: the caching *approach* (SharedPreferences + TTL to spare the backend) is good and stays — the flag is only the triplication. The plan consolidates it into one helper and extends it to more catalog data (§5-D4).** |
| 4.26 | **Client-side schedule-day compression duplicated from backend**: `new_task_page.submit()` re-implements the ALL/WEEKDAYS grouping that `addNewJob` then re-does with its own rules. Two lossy compressions in a row, maintained in two languages. |
| 4.27 | **Widget-builder methods mutate caller state**: `multiSelectChoiceChipGrid` / `checkBoxGroup` mutate the passed-in `selectedOptions` list *and* invoke the callback with the same reference — double-mutation bugs waiting to happen. |
| 4.28 | **Laundry rate card shows an arbitrary provider's prices** (`payload[0]` of providers list) while the backend assigns the *nearest* provider — estimated total can be from a different provider than the one who fulfills (compounds 4.17). |
| 4.29 | **Duplicated UI logic**: status→color/icon maps copy-pasted in `my_doorstep_orders_screen` and `doorstep_order_detail_screen`; accept/reject quote flows duplicated in `received_quotes_screen` and `quotes_for_task_screen`; login/signup screens are near-clones. |
| 4.30 | **Dead dependencies / dead code**: `dio` (never imported), `google_maps_flutter` (commented-out map only), `toggle_switch` (custom toggle built instead); commented-out blocks throughout (`Task` model, home menu, map). |
| 4.31 | **Tokens in `SharedPreferences`** (plain-text on device) rather than `flutter_secure_storage`. Noted, not prioritized per your instruction. Biometric gate is cosmetic (skipped on emulators, dead-ends on failure). |
| 4.32 | **`Constants.baseUrl` hardcoded to the Android-emulator alias `http://10.0.2.2:8080`** — no dev/prod switch, breaks on a physical device. |
| 4.33 | Per-widget font sizing recomputed inline everywhere (`(MediaQuery...width * 0.04).clamp(...)` appears ~80 times) instead of a small typography helper — noise that makes every widget tree harder to read. |

---

## 5. Proposed priority-ordered plan

Sizes: S ≈ ≤half a day, M ≈ 1–3 days, L ≈ 1+ week. Blast radius: **DB** (schema), **API** (contract), **UI**.

Ordering per your rules — missing features first (with **operational features as the top tier**, benchmarked against **Urban Company / Urban Clap / Yes Madam**), then incomplete work, then bad-approach fixes, then polish. **Payments are explicitly deprioritized** (only the attendance data that payments will later need is captured). **Your client-side caching approach (SharedPreferences + TTL in `CategoryService`) is understood, kept, and extended — nothing in this plan removes client caching; several items add more of it to reduce backend load.**

### A. Missing features — Tier 1: Operational features (highest priority)

These build on structures already in your schema (`TaskJob`, `CancelType`, the commented-out `relatedTaskId`/`HireMode` fields), so they evolve the existing design rather than replace it.

| ID | Item | Size | Touches |
|---|---|---|---|
| OP1 | **Occurrence engine (foundation for everything below)**: a rolling job materializes the next ~7–14 days of each active recurring `TaskSchedule` into `TaskJob` rows (date + slot + earner + status). Pattern storage stays exactly as-is; `TaskJob` finally gets populated as its javadoc promised. Today/Tomorrow/Later lists and dashboard counts read from occurrences (also fixes §3.4 recurring-blindness). Spring `@Scheduled` is enough — no new infra. | L | DB (populate existing table, ~2 new columns: status/cancel reason), API, UI |
| OP2 | **Earner leave marking**: earner selects date(s) on an assignment → those `TaskJob`s marked `ON_LEAVE` (vocabulary from `CancelType`: `ONLY_TODAY` / `SELECT_DATES`), organiser notified immediately. Leave history visible to both parties. | M (on OP1) | API, UI |
| OP3 | **Substitute / temporary earner** (your example): when leave spans ≥ N days — or organiser taps "arrange substitute" — the system auto-posts a **temporary task** for that date range, linked to the original via the existing (currently commented-out) `relatedTaskId`/`relationOrder` fields. In other earners' nearby-jobs list it appears with a clear **"Temporary · 12–18 Aug"** badge and pre-filled pay from the original task. Substitute's assignment auto-ends at range end; original earner resumes. | M/L | DB (un-comment fields), API, UI |
| OP4 | **Organiser pause / skip visits**: organiser skips a single occurrence ("not needed today") or pauses a date range (vacation) → affected `TaskJob`s marked `SKIPPED_BY_ORGANISER`, earner notified so nobody travels to a locked door. | M (on OP1) | API, UI |
| OP5 | **Visit-day workflow + attendance**: earner marks *On my way / Arrived / Done* on today's `TaskJob` (fields `arrived/started/completed` already exist); organiser one-tap confirms; monthly attendance summary per assignment (worked / leave / skipped / missed). This is the Urban Company job-execution flow, and the data basis for payments later — **without building payments now**. Verification stays a simple tap (no OTP, per your constraint). | M (on OP1) | API, UI |
| OP6 | **Reminders & doorstep re-confirmation** (your example): scheduled notifier sends (a) day-before + morning-of reminders for task occurrences to both parties, and (b) for doorstep orders booked ≥ 2 days ahead, a **"confirm you're still available"** prompt to the provider ~24h before pickup (customer gets a reminder too). Provider confirms → customer sees "Confirmed ✓"; provider declines or ignores past a cutoff → order returns to PENDING pool / next-nearest provider, customer notified of the change. Uses the existing Notification table + polling; no FCM dependency (FCM is D-tier). | M/L | DB (confirm fields on order), API, UI |
| OP7 | **Reschedule flows**: move a single task occurrence (organiser or earner proposes, other party accepts — `CancelType.RESCHEDULE`); customer/provider reschedule a doorstep pickup while PENDING/confirmed. | M | API, UI |
| OP8 | **Cancellation with reason + auto-recovery**: cancel-task and cancel-assignment endpoints using `CancelType` (`PERMANENTLY` ends an engagement); when an assigned earner cancels, the task **auto-reopens to quotes** and the organiser is notified with one-tap "repost". No-show reporting on a missed `TaskJob`. Doorstep PENDING orders auto-expire after X days with customer notification. | M | API, UI |
| OP9 | **Task & quote expiry**: enforce the already-collected `openForDays`/`openForMins` — scheduled job closes expired open tasks and notifies the organiser ("no earner found — repost?"). | S/M | API |
| OP10 | **Availability windows**: doorstep provider "unavailable from–to" date range (beyond the binary toggle, honored by assignment + OP6); earner working-days/slots preference used to pre-filter nearby jobs. | M | DB, API, UI |

### B. Missing features — Tier 2: other net-new

| ID | Item | Size | Touches |
|---|---|---|---|
| B1 | **Close the task loop**: complete/cancel endpoints (`feedbackProvided`/`active` finally mutated — OP5/OP8 provide most of this), rating capture (`RatingOnWork`/`RatingOnConduct` repos + endpoints + simple dialog); wires dashboard counts and makes `avgRating` real | M | DB (repos only), API, UI |
| B2 | **Post-assignment contact**: reveal counterpart phone once assigned + call button (chat stays deferred, §C-B9) | S | API, UI |
| B3 | **Quote-received / assigned notifications**: emit `QUOTE_RECEIVED` and `JOB_ASSIGNED` (app already renders these types) | S | API |
| B4 | **Real address management**: expose `update-address`, add delete (soft) + set-home endpoints; replace the fake UI actions (§2.15) | S/M | API, UI |
| B5 | **Doorstep provider choice + price confirmation**: customer picks provider (rates then match the actual fulfiller — fixes 4.17/4.28); provider records `verifiedQuantity` + line prices at pickup | M | API, UI, DB (minor) |
| B6 | **Pagination** on listing endpoints + infinite scroll | M | API, UI |
| B7 | **i18n scaffold + Hindi** — biggest UX lever for low-literacy users (prereq: structured schedule payload, §C-B7) | L | UI |
| B8 | **Worker discovery ("nearby earners")** — implement or explicitly drop the stubs | L | DB, API, UI |

### C. Incomplete features (finish what's half-built)

| ID | Item | Size | Touches |
|---|---|---|---|
| C-B1 | Delete or implement the 7 null endpoints (recommend delete — successors exist) + their dead client constants | S | API |
| C-B2 | Fix the ONCE-date bug in `new_task_page` (picked date never submitted) | S | UI |
| C-B3 | Fix add-address state codes: serve states from backend (public `get-states` endpoint, **cached client-side like categories**) instead of the duplicated wrong list; fix the `retainWhere` dropdown bug | S/M | API, UI |
| C-B4 | Search results navigate to the profession/category flow | S | UI |
| C-B5 | Task title: user-entered or derived from profession + sub-professions (drop "Get it done") | S | UI |
| C-B6 | Biometric failure UX (retry/exit), remove hardcoded D.O.B, fix sign-up copy, step numbering | S | UI |
| C-B7 | Structured schedule payload (data, not prose) rendered client-side — fixes 4.19 bug, enables Hindi (B7) | M | API, UI |
| C-B8 | Expose admin add-profession/sub-profession endpoints (impls exist) | S | API |
| C-B9 | Decide TaskChat / remaining dead fields: schedule chat (L) or remove placeholders. (`TaskJob` + `relatedTaskId` + `HireMode` + `CancelType` are now *used* by Tier A — only chat remains undecided.) | S (decide) | DB |

### D. Bad-approach fixes (from §4)

| ID | Item | Size | Touches |
|---|---|---|---|
| D1 | **Authz/ownership pass** (4.10): registered-provider check + no-overwrite in `acceptOrder`; ownership on `getTaskSchedule` / robust `getQuotesForTask`; block self-quoting; limit pending-order address exposure to area, full address only after acceptance | S/M | API (behavior) |
| D2 | **Kill N+1s + dashboard count queries** (4.11) — protects the backend at exactly the scale you're worried about | M | API (internal) |
| D3 | **Index restructure** (4.3): targeted composite indexes matching real queries (`task(organiser_id, active)`, `task_schedule(earner_id, active, full_date)`, `task_job(earner_id, date)` for OP1, …) | S | DB |
| D4 | **Client cache: consolidate & extend (keep your approach)** (4.25): one `CacheService` (SharedPreferences + TTL, same as `CategoryService` today) reused for categories, professions, sub-professions, states, profession rules, home menu, doorstep professions. Add a tiny **catalog-version endpoint** (one cheap GET returning a version number bumped on admin changes) so the client refetches only when data actually changed instead of every 60 min — *less* backend load than today, and icons stop being re-downloaded. | M | API (1 endpoint), UI |
| D5 | **Icon delivery** (4.12): server caches encoded icons in memory (no per-request disk read/encode); client caches them via D4 | S/M | API, UI |
| D6 | **Status-transition validation** for pickup-drop orders (4.18) + unify assignment model guard rails (4.17, with B5) | S | API |
| D7 | **Error handling via `@ControllerAdvice`** (4.14): consistent 400s, no raw exception text, real logging — envelope shape unchanged | S/M | API (messages) |
| D8 | **Finish data-driven profession rules** (4.13): backfill flags, delete "Maid"/"Makeup Artist" name checks | M | DB, API |
| D9 | **Distance buckets as enum contract** (4.6); align SQL/Java bucket edges; fix `ORDER BY 2` → distance | S | API, UI |
| D10 | **Revoke-quotation → POST** (4.15); filters → query params where cheap | S | API, UI |
| D11 | **App: shared fetch/state helper + typed models** for addresses/providers/rates (4.22/4.23) — incremental, no framework migration | M | UI |
| D12 | **De-duplicate client logic**: status maps, accept/reject flows, dead revoke block, `CategoryService` legacy wrappers (folds into D4) (4.27/4.29) | S/M | UI |
| D13 | **Decouple grid → navigation** (4.24): onTap callbacks; retire `HomeHelperScreen` int-switch | S/M | UI |
| D14 | **Base URL config** (4.32): flavor/env-based, emulator default kept for dev | S | UI |

### E. Polish / nice-to-haves

| ID | Item | Size | Touches |
|---|---|---|---|
| E1 | Remove dead deps (`dio`, map plugin if unused after C-B3, `toggle_switch`), commented-out blocks, `print()`s | S | UI/API |
| E2 | Slot label typos; prune unused backend Slot values | S | API |
| E3 | Typography helper for the repeated `MediaQuery` clamps (4.33) | M | UI |
| E4 | FCM push notifications (upgrade from polling once OP6 proves the flows) | M | API, UI |
| E5 | Tokens → `flutter_secure_storage` (deprioritized per your instruction) | S | UI |
| E6 | Rename Maven artifact `Yapan` → `JeevikaService`; DB creds → env vars | S | build/config |

### Suggested sequencing

1. **Slice 1 — operational foundation**: OP1 (occurrence engine) + OP2 + OP4 + OP5 + B1 + B3, with D3 (indexes incl. `task_job`) done alongside. After this: recurring work has leaves, skips, attendance, completion, and real dashboard numbers.
2. **Slice 2 — reliability of commitments**: OP6 (reminders + doorstep re-confirmation) + OP8 + OP9 + B2 + B4, plus quick correctness fixes C-B1…C-B6 and authz D1.
3. **Slice 3 — substitution & flexibility**: OP3 (temporary earner) + OP7 (reschedule) + OP10 + B5.
4. **Slice 4 — scale & UX**: B6 (pagination) + D2 + D4/D5 (caching) + C-B7 → B7 (Hindi).

Payments, chat, and worker discovery stay parked until you pull them forward.

---

*Notes on method: audit was code-reading only (every file in `Yapan/lib` and `JeevikaService/src`, plus access-app's SecurityConfig/OtpService/AccessService surface). The app/backend were not executed — items flagged as runtime bugs (e.g. §2.18, §2.19) are traced through the code but unverified against a live DB.*
