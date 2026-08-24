# Gasta — PLAN-3: everything remaining

Companion to [PLAN.md](PLAN.md) (phases 0–3 + the original 4–11 sketches),
[PLAN-2.md](PLAN-2.md) (phases 4–11 revised, human-behaviour gaps) and
[DEFERRED.md](DEFERRED.md). Binding UI rules live in
[DESIGN-RULES.md](DESIGN-RULES.md).

**Why a third file.** Phases 0–4 and 6 are implemented and verified. What is
left is (a) the phases never started, (b) a set of defects and gaps found by
actually using the app that no earlier document lists, and (c) three areas the
product owner raised directly — doorstep beyond laundry, UI uniformity and
responsiveness, and ease-of-use. Rather than scatter those across two existing
files, everything outstanding is gathered here in implementation order.

**Read this file, not the phase sketches in PLAN.md**, where they disagree.
PLAN.md's phase 5–11 tables are the *original* sketches; §C–§G below supersede
them with detail. PLAN-2's additions (T5.7–T5.9, T7.7, T8.8, T9.0, T10.7,
T11.12) are folded in here rather than repeated.

---

## 1. Honest status ledger

Anything not listed as done is not done. This exists because the previous plans
were partially implemented and it was not obvious from reading them which parts.

| Phase | State |
|---|---|
| 0 — Foundations | ✅ Complete (T0.1–T0.8) |
| 1 — Occurrences | ✅ Complete (T1.1–T1.8) |
| 2 — Visit lifecycle | ✅ Complete (T2.0–T2.7) |
| 3 — Leave / skip / scheduler | ✅ Complete (T3.1–T3.6) |
| 4A — Exits, corrections, reachability | ✅ Complete (T4.1–T4.12) |
| 4B — Doorstep reliability | ✅ Complete (T4.13–T4.17) |
| 5 — Substitution, flexibility, identity | ✅ Complete (T5.0–T5.6, T5.8, T5.9). **T5.7 deferred to Phase 10** — it needs T10.2's admin tooling. |
| 6 — Correctness, authz, perf, caching | ◐ **T6.1–T6.11, T6.13, T6.14 done. T6.12 not started.** T6.8 was delivered early as T4.15. |
| 7 — Trust & reputation | ◐ T7.1–T7.6 and T7.8 done (T7.1 text-only by decision); T7.7's remaining signals not started |
| 8 — Demand & liquidity | ✅ T8.1–T8.6 and T8.8 done and verified (T8.7 deferred as D-1) |
| 9 — Accessibility & language | ◐ T9.0, T9.1, T9.3, T9.7 done + verified; T9.2, T9.5, T9.6 not started |
| 10 — Ops & support | ✅ T10.1–T10.7 done and verified |
| 11 — Scale & hardening | ◐ T11.1, T11.2, T11.6, T11.9, T11.13 done + verified; T11.3/T11.12 stubbed behind interfaces (decided); T11.4, T11.5, T11.7, T11.8, T11.10, T11.11 not started |

**Partial items to be explicit about:**

- **T6.12** (shared fetch/state helper, typed models, de-duplicated status maps)
  was skipped deliberately: pure refactor, no user-visible change, and doing it
  while behaviour was still moving would have meant refactoring twice. It is now
  §D-0 below and should land *before* Phase 7 adds more screens.
- **T9.4's day-chip item** was done under T6.14 (`Mon`…`Sun` instead of
  `M T W T F S S`). **The bottom-nav labelling half is now done too**, alongside
  F-7 — the five icons carry their names, so the bar is no longer a memory test
  for the people least able to pass it. What remains of T9.4 is larger tap
  targets in the wizard.
- **C-B4 (search navigates)** was done under T6.11, so T8.6 no longer includes
  it.
- **T5.2 (temporary badge)** was blocked on T6.4, which is now done — the
  `@Subselect` hack is gone and `NearbyJobRow` is a plain projection, so
  extending it is now cheap.

---

## 2. Section A — Defects and gaps found in the live run

These are not new features. They are things that are wrong or missing today,
found by using the app, and none of them appear in PLAN.md or PLAN-2.md.
**Do these first** — they are small and they block or degrade later work.

### A-1. Professions without sub-professions are unsearchable ⚠️ *raised by product owner*

**Symptom.** Searching "carpenter" returns "No results found", although Carpenter
is on the home screen and bookable.

**Cause.** `getAllSubprofessions` (`OrganiserServiceImpl:504`) starts from
`subProfessionRepo.findByEnabledOrderByNameAsc(true)` and groups *upward* into
professions and categories. A profession with zero sub-professions has no rows to
group, so it never enters the payload. `search_screen.dart` searches that
payload, so those professions do not exist as far as search is concerned.

This is not an edge case: most professions have no sub-professions.

**Fix.**
- Drive the query from `professionRepo.findByEnabledOrderByNameAsc(true)` and
  attach sub-professions with a single `findByProfession_IdInAndEnabled(...)`
  lookup grouped in memory (one extra query, not N — the T6.2 rule).
- Professions with no sub-professions appear with an empty `subProfessions` list.
- The Flutter side already handles an empty list; verify rather than assume.
- Rename nothing — the endpoint keeps its `get-all-subprofessions` path, which is
  now a slight misnomer; add a comment rather than break the client.

**Also fix while here:** search matches with `contains`, so "carpenter" would not
match "Carpentry". Add a simple normalisation (lowercase, trim) on both sides and
match on `contains` of either direction. Do **not** add fuzzy matching — it
misfires badly on Indian-language transliteration.

**Acceptance:** searching "carp" returns Carpenter as a Profession result and
tapping it opens the booking flow; searching "cook" still returns both Chef/Cook
and the Cook sub-profession; a profession with sub-professions still shows them.

**Size:** S · **Touches:** API, UI (verify only)

### A-2. Doorstep is hardcoded to laundry ⚠️ *raised by product owner*

Covered in full in **§E** below — it is large enough to be its own section.

### A-3. The `Task.title` of every pre-existing task is "Get it done"

T6.11 fixed the *generator*, so new tasks get "Maid — Cook, Dishwash". Existing
rows still say "Get it done". A one-off `UPDATE` deriving the title from
profession + sub-professions should run once, or those tasks stay unreadable in
every list forever.

**Size:** S · **Touches:** DB (one-off script)

### A-4. `LocationState.enabled` is false for all 36 rows

`get-states` (T6.11) deliberately ignores the flag, because filtering by it would
empty the address form. That is correct for *now*, but T8.4 (serviceability
gating) intends to use the same flag for a completely different purpose — "do we
operate here". Two meanings on one column will collide.

**Decide before T8.4:** either (a) `location_state.IS_ENABLED` means "we operate
here" and the address form uses a separate unfiltered read (current behaviour,
just document it), or (b) add `IS_SERVICEABLE` and leave `IS_ENABLED` for
catalog visibility. **Recommendation: (a)** — one flag, clearly documented, and
the address form's read is explicitly the odd one out.

**Size:** S (decision + comment) · **Touches:** docs, then T8.4

### A-5. Location failure strings are sent to the server as coordinates

`LocationService.fetchLatLong` returns `"No Permission"` or
`"Error fetching location: …"` **as the location string** on failure.
`worksheet_screen` then does `.split(',')[0]` on it and posts that as `latitude`.
The server's `Double.parseDouble` throws, and the earner sees "Could not fetch
records" with no idea that location permission is the problem.

**Fix.** Return a nullable typed result (`LatLng?`), not a sentence. On null,
show a dedicated state: "Turn on location to see jobs near you" with a button
that opens settings. This is a daily-blocker for the exact audience least able to
diagnose it.

**Size:** S/M · **Touches:** UI

### A-6. `TextEditingController` rebuilt inside `build()`

`new_address_screen_2.dart` constructs `TextEditingController(text: postalCode)`
inline in `build`. It works today only because nothing calls `setState` while
those fields have focus — and T6.11 just added a `setState` to that screen. It
will bite. Hoist to state fields with `initState`/`dispose`.

**Size:** S · **Touches:** UI

### A-9. Denying the location prompt strands the app on the splash *(found while verifying A-5)*

**Symptom.** Tap "Don't allow" on the first-launch location prompt and the app
never leaves the splash spinner. No message, no button, nothing in logcat.
Reinstalling does not help, because Android remembers the answer. The entire
product is lost to one tap.

**Cause.** `main.dart` `_handleStartupChecks` was
`if (permissionGranted) { if (gpsEnabled) { pingServer(); } }` — with no `else`
on either branch. Refuse the permission, or have GPS off, and nothing at all
happens next.

**Fix.** Ask for the permission at launch as before, then call `pingServer()`
**whatever the answer**. Location is needed by one screen — nearby jobs — not by
logging in or hiring, so it must not gate the launch. A-5's "Turn on location"
state is what handles the refusal, on the screen that actually needs it.

**Acceptance:** denying the prompt still reaches the home screen; Earning Zone
shows the A-5 state; granting it later works without a reinstall. *Verified in
the emulator.*

**Size:** S · **Touches:** UI

### B-1. Every "My Posted Tasks" filter except All was broken *(found during T5.1)*

`posted_tasks_screen.dart` built the URL as
`'${Constants.myPostedTasksFiltered}$_activeFilter'` — no `?filter=` — so it
requested `…/get-my-posted-tasks-filteredassigned`, got a 404, and showed
**"Could not load tasks. Please check your connection."** Four of the five
filters on that screen have never worked, and the error blamed the user's
network. One-line fix; verified in the emulator.

### B-2. Saving a farm address was impossible *(found by chasing a lint)*

`new_address_screen_2.dart` declared `enum AddressType { Home, Farm, Office }`
and posted `addressType?.name.toUpperCase()`. The server's enum is
`HOME, OFFICE, AGRICULTURE_FIELD, WAREHOUSE, PUBLIC_PLACE, EVENT_VENUE, OTHER`
— there is no `FARM`, so choosing it produced a value the server could not
deserialise. On a product whose users include farmers. The existing seeded
address named "My field" is stored as `HOME`, which is the bug's fingerprint.

Four of the seven types were also unreachable, so warehouses, shops, public
places and event venues had to be filed under the wrong kind.

**Fixed** by mirroring the server enum with an explicit wire `code` and a
separate display `label` (so Phase 9 can translate the label without touching
what is sent), and posting `.code`. Verified in the emulator: a "Farm / Field"
address now stores `AGRICULTURE_FIELD`.

### B-3. `flutter analyze lib/` cleared, 132 → 0

Not cosmetics — the list was hiding real defects. Chasing it produced B-2
above, plus: a duplicated quote-revoke flow in `worksheet_screen.dart` where
the dialog popped `false` and did the work inline, leaving the identical block
below it permanently unreachable; a dead `?? "Unknown error"` on a
non-nullable field that turned an empty failure into "Could not place order: ";
and ~40 `BuildContext`-across-await sites that crash if the user leaves the
screen mid-request. Wire-mirroring enums (`RepeatType`, `Slot`) keep the
server's SCREAMING_CASE under a documented `ignore_for_file`, because renaming
them would break serialisation.

**Keep it at zero.** A warning left in the list hides the next real one.

### B-4. Seven dropdowns overflowed the screen

`DropdownButtonFormField` sizes to its widest option unless told otherwise, so
"Pickup Drop Cloth Wash and Ironing" pushed the provider form's profession
field 11 px off a 720 px screen — the same defect already fixed once for the
State picker in `new_address_screen_2.dart`, which is how it was recognised.
A sweep found seven more without `isExpanded: true`, in the provider form,
laundry booking, login and the address form. All fixed; verified at 720×1280
per DESIGN-RULES §6.

### T5.5 note — one-off jobs are exempt from the slot filter

The first cut of the nearby-jobs slot filter matched only tasks whose schedule
rows name a slot. One-off bookings carry a date and a time instead, so *every*
one-off job vanished for anyone who set a working-hours preference — silently,
with nothing on screen to say work was being hidden. The query now also keeps
tasks that state no slot at all. Caught by the row counts in testing, not by
the compiler.

### D-1 notes — what the implementation settled

Built as designed in DEFERRED §D-1, with three decisions worth recording:

- **`Task.earner` stays**, as a documented derived field pointing at the first
  active assignment. Converting all dozen call sites at once would have been one
  enormous change across every path Phase 4A had just hardened. For a
  single-worker task the two agree exactly.
- **Occurrences are per assignment**, and the dedupe key gained the earner id.
  Without that a job with three workers on the same Monday slot generated *one*
  visit that only one of them could mark done.
- **`endAssignment` cancels only the leaving earner's visits.** It used to
  cancel every future visit on the task; on a three-person job that meant one
  person resigning wiped the other two off the schedule with no notice.

A backfill (`db/D-1-backfill-task-assignments.sql`) gives already-assigned tasks
their assignment row. `ensureOccurrences` also falls back to `task.earner` when
no rows exist, so the backfill is tidiness rather than a correctness
requirement.

### E-5. §E status and what is still unverified

**Done and verified:**

- `ServiceVariant(profession, code, label, pricingUnit, needsDiagnosis)` replaces
  the `LaundryService` enum as the axis of `DoorstepServiceRate` and
  `PickupDropOrderItem`. The enum survives as seed data for laundry, with its
  codes unchanged, so no existing row was rewritten — 4 rates and 7 order items
  repointed cleanly.
- Four doorstep services across three pricing units: laundry (PIECE), appliance
  repair (VISIT, `needsDiagnosis`), water (ITEM), cylinder/heavy items (ITEM).
- `get-service-variants/{professionId}` serves codes **and** labels, so the app
  no longer carries its own copy of the service list — that hardcoded list in
  two screens was the actual reason doorstep could only be laundry.
- **Laundry regression check passed**: an order placed exactly as before still
  succeeds, with the same codes.
- The service list is now driven by `supportsPickupDrop`, not by who happens to
  have registered. The old behaviour could not bootstrap: no providers → not
  listed → no customers → no reason for a provider to sign up. Coverage is
  reported as an `available` flag the card shows as "Coming soon".

**Defects found and fixed while doing it:**

- `saveRates` did `LaundryService.valueOf(...)` in a try/catch whose catch was
  `continue`. A provider registering for anything but laundry had their
  **entire price list silently dropped** while the screen said it had saved.
- **Every profession icon was unrenderable.** `_SvgOrFallback` called
  `Image.memory(bytes)` — a *raster* decoder — on SVG bytes, with the comment
  "SVG needs flutter_svg, already in project" sitting directly above it. So any
  profession that actually had an icon showed a red X reading "invalid image
  data", and the screen only looked passable because most professions have no
  icon file and fell through to the placeholder. Now `SvgPicture.memory`.
  <br>**I misdiagnosed this twice before finding it** — first as an encoding
  problem, then as a stale client cache. It was neither; the fresh-cache screen
  still showed the red X, which is what finally ruled both out. Separately,
  22 of 73 SVGs did declare `iso-8859-1` and were re-encoded as UTF-8 — a real
  latent problem, but not this one.
- Doorstep cards overflowed by up to 15px on the longer service names, and the
  availability suffix was being glued into `name` (which caused it, and would
  have needed translating in Phase 9). Now a separate flag, and the card cannot
  overflow.

**Still to verify:**

1. ~~Icon rendering~~ — **done**, see the `Image.memory` defect above.
2. End-to-end booking of a **non-laundry** service in the UI. That needs a
   provider registered against one of the three new professions — until then
   every new service correctly reads "Coming soon", which is itself the
   correct behaviour.

### F-8. §F status, and why the global theme was backed out

**Built and in place:**

- `lib/design/tokens.dart` — `AppText` (a five-name scale replacing ~120
  ad-hoc multipliers, with the decorative face reserved for the wordmark),
  `AppSpacing`, `AppRadii`, `AppSemanticColors` (with greys that actually pass
  WCAG AA — `Colors.grey` is 2.8:1 on this background), and `AppStatus`.
- `lib/design/app_button.dart` — `AppButton.primary/.secondary/.danger`,
  48dp minimum, full width by default, filled-vs-outlined hierarchy guaranteed.
- The **four duplicated status→colour maps** now delegate to `AppStatus`, so a
  status cannot be orange on one screen and blue on the next.
- **System font scale is finally read** (`MediaQuery.textScaler`), clamped to
  1.6×. Nothing read it before, so every large-font user — the exact audience
  this product targets — got layouts computed for 1.0× and overflowed.
- **Portrait locked.** Landscape was neither supported nor prevented, so
  rotating gave a broken screen.

**Backed out, and worth remembering:** the first cut also set
`elevatedButtonTheme`, `outlinedButtonTheme` and `inputDecorationTheme`
globally. That silently resized hand-built layouts across the app — on the OTP
screen it grew the Proceed button enough to squeeze the scroll view above it to
nothing, so the field could not be reached and **nobody could log in**. Caught
in the emulator, which is exactly what DESIGN-RULES §6 exists for.

The conclusion is in the code: a global theme change is not a safe way to
retrofit a design system onto layouts built without one. Only styling that
cannot change a layout's size stays in `_withComponents`. `AppButton` is the
vehicle, adopted screen by screen with an emulator check after each — which is
what §F-4 said in the first place.

**Outstanding:** the screen-by-screen migration onto `AppButton` and `AppText`
(2 screens done, ~16 to go), and testing each at 1.3× and 1.6× font scale.

### F-7 as built

Matches §12's spec, verified in the emulator:

- Asked **once**, on first launch, before login. Three large picture-and-word
  cards, skippable; skipping gives `BOTH`, which is exactly the old behaviour.
- Choosing "I want work" lands on Earning Zone with the tabs reordered
  **Work / Home / Dashboard / Alerts / Profile**; switching to "I need help" in
  Profile reorders to **Home / Dashboard / Alerts / Profile / Work**
  immediately, without logging out.
- **Nothing is ever hidden** — the acceptance criterion that matters most. The
  order is a permutation, never a subset, so a `HIRE`-mode user who takes a job
  still has Earning Zone; it is simply last. The mode is a client-side
  presentation preference: no column, no endpoint, no authority change.
- The `IndexedStack` is indexed by *screen*, not by bar position, so reordering
  cannot rebuild or reset the screens behind it. Icons follow their screen for
  the same reason — a bar people navigate by shape cannot survive its pictures
  moving (AUDIT U7).

Stored per device rather than per account: on a shared phone (T5.8) two people
may reasonably want different landing screens.

### F-6 progress

**All ten done.** Items 1, 4, 6 and 7 landed earlier; 2, 3, 5, 8, 9 and 10
followed, and each was checked on the emulator rather than only compiled.

| # | What shipped | Verified |
|---|---|---|
| 1 | Search moved below "Get things done" | ✅ screenshot |
| 2 | Distance is a fixed five-option bar on Earning Zone ("1 km … Any"), cumulative rather than five independent bands. Removed from the filter sheet; "Look further away" drives the same state so the control always reflects the filter | ✅ one tap moves the selection and refetches |
| 3 | One next action per Dashboard card, shown **only when the count is non-zero** — an invitation to act on nothing is worse than silence | ✅ "5 services waiting for someone to quote → View"; "1 job today → Open" (singular correct) |
| 4 | Monthly estimate beside a recurring rate, Indian digit grouping. Now on the organiser's posted-tasks card too, not only Earning Zone — that is the screen where the decision is actually made | ✅ "₹500 / DAY  ≈ ₹15,000 per month" |
| 5 | Nullable `LANDMARK` on the address, through `NewAddressDto` → `VisitDto`, form field after the street line, rendered **above** the address line on the earner's card and suppressed for the organiser | ✅ end to end, organiser → earner |
| 6 | Teaching empty states | ✅ screenshot |
| 7 | "What happens next" after posting | ✅ |
| 8 | WhatsApp share on an open task and in Profile ("Tell a friend"), via `wa.me` so it degrades to a web page when WhatsApp is absent | ✅ launches the external handler |
| 9 | `CacheService.readStale` + `SavedInfoBanner`: Earning Zone, Dashboard and posted tasks show saved data with a banner instead of an error | ✅ compiles and renders; the banner path is exercised by killing the backend |
| 10 | `confirmDestructive` — one dismissible confirm, cancel first and outlined, stacked so 1.6× font does not overflow. Applied to skip-visit and the new withdraw | ✅ screenshot |

**Defects found while doing F-6** (none of them in any plan document):

- **`Constants.cancelTask` had no caller anywhere in the app.** The endpoint
  existed, the constant existed, and the Dashboard offered a "Withdrawn" filter
  — but an organiser who posted a service had **no way to withdraw it**. Wired
  up behind the new confirm.
- **`cancelTask` notified only `task.getEarner()`** — the derived *first*
  active assignment (D-1). Cancelling a three-worker task told one person and
  left the other two turning up. Now ends every active assignment and notifies
  each.
- **`AppStatus` was missing every doorstep status**, and the server spells it
  `CANCELLED` (two Ls) where `JobStatus` spells it `CANCELED`. A cancelled
  order therefore drew the muted default grey instead of red, on the screen
  where that distinction matters most. Both spellings are now listed, with a
  note saying why.
- **The app told the organiser that accepting a quote "will auto-reject all
  other pending quotes".** That stopped being true when D-1 made tasks
  multi-worker. `QuoteViewDto` now carries `workersNeeded`/`workersTaken`
  (filled with one batched query per page, not one per quote) and the confirm
  says which of the three things will actually happen.
- **`url_launcher` could not see a browser, dialer or mail client.** Android 11+
  hides installed apps unless they are declared in `<queries>`, and the manifest
  declared only `PROCESS_TEXT`. This had already broken the T5.9 support-call
  button — silently, because `launchUrl` just returns false.
- **Every network failure in the app produced one sentence and nothing else.**
  `ApiService` swallowed the exception and returned "Could not connect",
  identically for a wrong base URL, a blocked cleartext request and a genuinely
  offline phone; non-2xx responses were handed to callers as `success: true`
  with no trace. Both now log in debug builds — which is how the OTP failure in
  this very session was diagnosed in one line instead of twenty minutes.

**Done and verified:** 1 (search demoted below the two action cards on Home),
4 (monthly estimate on the job card — "₹500 DAY" is ₹15,000/month and the app
never said so, and that is the number the decision is made on), 6 (the "No jobs
found nearby" dead end became three one-tap routes: look further, change
working hours, pick more kinds of work), 7 ("Posted. Workers nearby can see it
now — we will tell you when someone quotes", so silence does not read as
failure and prompt a repost).

The monthly estimate deliberately returns null for hourly, per-visit and
per-total units: multiplying those up would invent a commitment nobody made. It
also uses Indian digit grouping (1,50,000 not 150,000) — reading a number in
the wrong grouping is a real way to misjudge an amount by a factor of ten.

**Remaining:** 2 (distance filter out of the sheet), 3 (dashboard next
actions), 5 (landmark field — needs a DB column), 8 (WhatsApp share), 9
(offline tolerance via the T6.10 cache), 10 (confirm before destructive).

### A-7. Leftover wide indexes

T0.5 added targeted indexes; Hibernate `update` cannot drop the originals. They
cost write throughput and nothing else. Drop them in the same migration that
introduces Flyway (T11.2), not before — dropping indexes by hand on a dev DB that
prod does not match is how schemas diverge.

**Size:** S · **Touches:** DB, folded into T11.2

### A-8. Enum columns still backed by MySQL `ENUM`

From DEFERRED's latent-issues table, repeated here because it is a **release
blocker in disguise**: `task_schedule.DAY`, `DATE_GROUP`, `REPEAT_TYPE`,
`SLOT_1..6`, `task.QUOTE_TYPE`, `PAY_UNIT`. Adding any enum value fails at insert
with "Data truncated" (R15). Phase 5 adds `CancelType.RESCHEDULE` — **that will
fail** unless these are widened first.

**Do this as the first task of Phase 5**, exactly as T4.1 did for `task_job`.

**Size:** S · **Touches:** DB, entities

---

## 3. Section B — Phase 5: substitution, flexibility, identity

The theme: *a schedule agreed once will need to change.* Today there is no
endpoint to edit a schedule at all (AUDIT §3.9), so the only way to change
anything is to cancel and re-post.

### T5.0 — Widen the remaining enum columns *(new, blocking)*

Per A-8. `columnDefinition = "VARCHAR(64)"` on every `@Enumerated(EnumType.STRING)`
column listed there, plus the matching `ALTER TABLE … MODIFY COLUMN`. Verify by
adding a throwaway enum value, inserting, and rolling back.

**Acceptance:** `SHOW COLUMNS` reports `varchar(64)` for all listed columns; row
counts unchanged.

**Size:** S · **Touches:** DB, entities

### T5.1 — Substitute task

Un-comment `Task.relatedTaskId` / `relationOrder` / `HireMode` (AUDIT §2.14) plus
new nullable `SUBSTITUTE_FROM` / `SUBSTITUTE_TO`.
`POST /organiser/arrange-substitute {taskId, from, to}` clones the parent as a
temporary task: same profession, sub-professions, address, pay and slot pattern;
`openToQuote = true`; `relatedTaskId = parent`.

Auto-offered when T3.1 set `substituteSuggested` (leave ≥ 2 days) — offered, not
automatic: the organiser may prefer to skip those days.

**Acceptance:** earner takes 4 days' leave → organiser sees "Arrange a
replacement for 12–15 Aug?"; accepting creates a task visible in nearby jobs with
those dates only.

**Size:** M/L · **Touches:** DB, API, UI

### T5.2 — Temporary badge in job search

Extend `NearbyJobRow`/`NearbyJobDto` with `isTemporary`, `substituteFrom`,
`substituteTo`; render **"Temporary · 12–15 Aug"** on the job card.
*Unblocked* — T6.4 replaced the `@Subselect` entity with a plain projection, so
this is now two fields and a `SELECT` column rather than a schema fight.

**Size:** S/M · **Touches:** API, UI

### T5.3 — Substitute lifecycle

On acceptance, occurrences generate **only within the range**. At range end the
substitute assignment closes and the original earner's visits resume — they were
marked `EARNER_LEAVE`, never deleted, so nothing needs recreating.

**Acceptance:** substitute for 12–15 Aug has exactly 4 visits; on 16 Aug the
original earner's visits are `SCHEDULED` again.

**Size:** M · **Touches:** API

### T5.4 — Reschedule a single visit

`POST /organiser/propose-reschedule {jobId, newDate, newSlot}` and
`POST /earner/respond-reschedule/{jobId} {accept}`. New nullable
`TaskJob.PROPOSED_DATE`, `PROPOSED_SLOT`, `PROPOSED_BY`. `CancelType.RESCHEDULE`
(needs T5.0). Doorstep equivalent: `POST /doorstep/reschedule-order/{orderId}`
while `PENDING` or confirmed.

**Also resolves R5** (horizon vs. schedule edits): when a *pattern* changes,
future `SCHEDULED` occurrences beyond today are deleted and regenerated;
anything already acted on is left alone. Add
`POST /organiser/update-schedule/{taskId}` for the pattern case — it is the
missing endpoint AUDIT §3.9 flagged.

**Acceptance:** proposing a new date leaves the original `SCHEDULED` until
answered; accepting moves it and notifies; editing a weekly pattern regenerates
only untouched future rows.

**Size:** M/L · **Touches:** DB, API, UI

### T5.5 — Availability windows

New `ProviderUnavailability(provider, from, to, reason)` honoured by doorstep
assignment and the T4.13 re-confirmation sweep. Earner-side working-days/slots
preference used to pre-filter nearby jobs, so an earner who only works mornings
stops seeing evening work.

**Acceptance:** a provider unavailable 10–12 Aug is not assigned an order in that
window; an earner who works mornings only does not see evening-slot jobs.

**Size:** M · **Touches:** DB, API, UI

### T5.6 — Doorstep provider choice

Customer picks the provider rather than being auto-assigned, so the rates quoted
match the fulfiller — this is the actual fix for AUDIT §4.17/§4.28, which T4.13
currently papers over by re-pricing on reassignment. Provider records
`verifiedQuantity` and line prices at pickup, and the customer approves any
difference before work starts.

**Acceptance:** the price shown at booking equals the price charged, or the
customer explicitly approved the change.

**Size:** M · **Touches:** API, UI

### T5.7 — Identity recovery — **deferred to Phase 10 (product owner, 2026-07-27)**

Both halves move out of Phase 5. The phone-change flow could ship alone, but
the half that matters — recovering an account from a *lost* phone — needs an
admin who can verify work history, and that tooling is T10.2. Splitting them
would ship the easy half and leave the earner whose phone is gone exactly where
they are today, while spending Phase 5 time on it. It lands whole, with the
admin queue it depends on.

<details>
<summary>Original spec, retained for Phase 10</summary>

Phone change and lost-phone flows. Verify via the old number when reachable;
otherwise an admin-assisted path (T10.2) using work history as evidence. Today a
lost phone means a lost account and a lost earnings record — for an earner that
is their entire reputation.

**Acceptance:** a user can move their account to a new number; the old number can
no longer log in; visits, ratings and statements follow.

**Size:** M · **Touches:** DB, API, UI, admin

</details>

### T5.8 — Shared-device account switching

Multiple saved accounts on one device with a persistent "you are ‹name›"
indicator. One phone per family is the norm here, not the exception, and posting
a job as the wrong family member is currently invisible and unrecoverable.

**Acceptance:** two accounts on one device; switching does not require re-entering
an OTP within the token lifetime; every screen shows whose account is active.

**Size:** M · **Touches:** UI, token storage

### T5.9 — Call for help

A permanent, visible support phone number in Profile and on **every error state**,
plus a "request a callback" button. T10.1's ticket form assumes the user can
write; many cannot.

**Decided (product owner, 2026-07-27):** the number is not chosen yet, so it
ships as a **single named constant** (`Constants.supportPhone`) wired through
every screen. Swapping in the real number is then a one-line change rather than
a hunt through the codebase — which is the whole point of doing it this way
round.

**Acceptance:** every error screen offers a phone number; the callback request
creates a ticket with the user's number and last screen.

**Size:** S · **Touches:** UI, API

### Phase 5 exit criteria

- [x] A schedule can be changed without cancelling and re-posting. *(T5.4 —
      per-visit reschedule with the other side's agreement, and
      `update-schedule` for the whole pattern.)*
- [x] Leave longer than the threshold can be covered by a temporary worker.
      *(T5.1–T5.3 — offered on the visits screen, badged in job search, visits
      generated only inside the range.)*
- [x] An earner only sees work they can actually do. *(T5.5 — working hours
      filter, opt-in, with one-off jobs exempt.)*
- [ ] Losing a phone does not lose an account. **Deferred to Phase 10 with
      T5.7**, which needs T10.2's admin tooling to be worth anything.
- [x] A family sharing one phone can tell whose account is open. *(T5.8 —
      switcher with "Using now", no OTP within the token lifetime.)*
- [x] Someone who cannot read can still reach a human. *(T5.9 — number on every
      error state and in Profile, plus a callback request.)*

Also delivered in Phase 5, not originally listed: doorstep provider choice
(T5.6), which is what actually makes the price quoted the price charged rather
than T4.13's re-pricing workaround.

---

## 4. Section C — Phase 6 remainder

### T6.12 — Shared fetch/state helper and typed models *(was skipped)*

Deliberately deferred while behaviour was moving; now it should land **before**
Phase 7 adds ~6 screens that would otherwise copy the current pattern.

**Spec:**
- One `ApiState<T>` (loading / data / error) + a `FutureBuilder`-style widget so
  every screen stops hand-rolling `isLoading` / `_hasError` / `setState` triples.
  There are currently ~15 copies with subtly different error handling.
- Typed models for the remaining `json.decode(...)['payload']` call sites that
  still index maps by string (`worksheet_screen`, `job_sheet_screen`,
  `user_account_screen`).
- One status→(colour, label, icon) map instead of `_statusColor` /
  `_statusColorForJob` / the doorstep variant.
- One accept/reject flow instead of the near-duplicates in
  `quotes_for_task_screen` and `received_quotes_screen`.

**Acceptance:** no behaviour change anywhere; `flutter analyze` clean; the
screens touched still render identically in the emulator (screenshot before and
after).

**Size:** M/L · **Touches:** UI only

---

## 5. Section D — Phases 7–11

Kept from PLAN.md/PLAN-2.md with corrections where implementation has since
changed the ground. Only the deltas and the newly-detailed parts are written out;
where a task is unchanged it says so.

### Phase 7 — Trust and reputation

Unchanged in intent: **T7.1** earner profile, **T7.2** verification badges
(mocked, admin-flipped), **T7.3** reputation aggregates in `EarnerStats`,
**T7.4** reputation at the decision point, **T7.5** favourites/block list,
**T7.6** organiser reputation shown to earners, **T7.7** reliability signals from
`AssignmentExit`/`TaskJob`.

Corrections and additions:

| ID | Change |
|---|---|
| T7.1 | **Needs T11.8 (file storage) first, or ships without a photo.** There is no upload path anywhere in the codebase. Either sequence T11.8 before T7.1, or ship the profile text-only and add photos later — **recommend the latter**, because a text profile is still a large improvement and T11.8 is a genuine infrastructure decision that should not block trust work. |
| T7.3 | `EarnerStats.avgRating` must be **recomputed on write**, never aggregated in a listing query — the nearby-jobs query already does one `AVG` sub-select per call and that is the pattern to stop, not extend. |
| **T7.8** *(new)* | **Earner safety.** An earner — often a woman — travels to a stranger's home. Add: the organiser's name and area visible before accepting; a "share my visit" button that sends a WhatsApp/SMS message with the address and time to a chosen contact; and an in-visit "I feel unsafe" action that alerts ops (T10.5) and surfaces the support number (T5.9). This is the single most important thing on this list for supply-side trust in this market, and nothing in the current plan covers it. **Size:** M |

### Phase 8 — Demand and liquidity

Unchanged: **T8.1** price guidance, **T8.2** one-tap rebook, **T8.3** instant
hire, **T8.4** serviceability gating, **T8.5** earner job alerts, **T8.8**
referral.

Corrections:

| ID | Change |
|---|---|
| T8.1 | Still the best value-for-effort item in the plan. `AddProfessionDto` carries `baseUnit`/`barLow`/`barHigh` for ~40 professions and `BeanUtils.copyProperties` **silently discards all of it** because `Profession` has no such fields. Three nullable columns + copy + expose. Now also feeds the "what will this cost me per month?" answer in §F-6. |
| T8.4 | Depends on the A-4 decision. |
| T8.6 | **Reduced** — search navigation shipped in T6.11 and A-1 fixes the coverage gap. What remains is browse-by-sub-profession and real popularity ordering on the home grid. |

### Phase 9 — Accessibility and language

Unchanged: **T9.0** language picker before login, **T9.1** i18n scaffold +
Hindi, **T9.2** seven regional languages (generated, `needs-native-review`),
**T9.3** picker + Profile switcher, **T9.4** icon-first/big-target pass,
**T9.5** voice input and read-back, **T9.6** replace typing with choosing.

Corrections:

| ID | Change |
|---|---|
| T9.1 | **Unblocked and cheaper than planned.** T6.7 removed the last server-generated prose (schedule text is now codes), and T1.4's code+label pattern is used throughout. The remaining server strings are error messages — which T6.3 centralised, so they are localisable in one place if wanted, or left English with the app supplying its own text per code. |
| T9.4 | Day chips done under T6.14. Remaining: bottom-nav labels (five unlabelled icons today), profession pictograms already exist server-side, larger tap targets in the wizard. |
| **T9.7** *(new)* | **Numerals.** Devanagari vs Latin digits for amounts and dates. Recommend **Latin digits always**, even in Hindi — money and phone numbers are read in Latin digits by essentially everyone in this market, and mixed numerals are a known source of error. Decide once, write it down. **Size:** S |

### Phase 10 — Ops and support

Unchanged: **T10.1** support tickets (implement the empty `ContactServiceImpl`),
**T10.2** admin/catalog management, **T10.3** disputes and manual intervention
with `AdminAuditLog`, **T10.4** cancellation policy and penalty ledger (records
only), **T10.5** ops queues, **T10.6** admin UI inside the app (decided: yes),
**T10.7** dispute resolution working the `DISPUTED` queue.

Corrections:

| ID | Change |
|---|---|
| T10.2 | **Partly done** — `add-professions` and `add-sub-professions` were exposed in T6.11. What remains is enable/disable, serviceable areas, verification approval and user lookup. |
| T10.4 | Inputs now exist: `AssignmentExit.noticeDays`, `duringTrial`, no-show and abandon counts from Phase 4A. |
| T10.6 | Gate on the authority already returned by `get-self-account-details`; the `/super-user/**` and `/admin-user/**` matchers in `application.properties` already enforce it server-side. Low-literacy design rules explicitly do **not** apply to admin screens. |

### Phase 11 — Scale and hardening

Unchanged: **T11.1** pagination, **T11.2** Flyway, **T11.3** FCM push,
**T11.4** observability, **T11.5** config/environments, **T11.6** abuse guards,
**T11.7** library items (needs approval), **T11.8** file/image storage,
**T11.9** test scaffolding, **T11.10** retention, **T11.11** remaining polish,
**T11.12** masked calling.

Corrections:

| ID | Change |
|---|---|
| T11.2 | Now also carries A-7 (drop leftover wide indexes) and is the natural home for A-8 if T5.0 has not already done it. |
| T11.6 | `otp-request` is unauthenticated and unthrottled. With T5.9 adding a visible phone number and T8.5 adding notifications, this stops being theoretical. **Raise its priority** — it is the one item here that is a live abuse surface today. |
| T11.9 | `ScheduleExpansionService` is pure logic with 5 documented acceptance cases; those become the first 5 tests at near-zero cost. |
| **T11.13** *(new)* | **Payload weight.** Every catalog response inlines base64 SVGs — the home screen ships ~80 of them. On a 2G connection in a village that is the difference between a usable app and an abandoned one. Serve icons from a cacheable static path with an ETag, or send an icon *name* the app resolves from bundled assets. The T6.10 icon cache made this fast on the server; it did not make it small on the wire. **Size:** M |

---

## 6. Section E — Doorstep beyond laundry ⚠️ *raised by product owner*

**The finding is bigger than the tagline.** The doorstep vertical is not
laundry-flavoured, it is laundry-*shaped*:

- `LaundryService` enum (`WASH` / `IRON` / `WASH_AND_IRON`) is a column on
  `DoorstepServiceRate` and drives `PickupDropOrderItem`.
- `PickupDropOrder` models pickup → process → deliver, with per-*piece* pricing.
- `laundry_booking_screen.dart` asks for garment type and quantity.
- The only seeded doorstep profession is "Pickup Drop Cloth Wash and Ironing".
- `Profession.supportsPickupDrop` exists but **is never set true in the seed** —
  the doorstep list is driven entirely by which providers happen to register.

So "add more doorstep services" means generalising the model, not adding rows.

### E-1. Generalise the service-type axis

Replace the `LaundryService` enum on `DoorstepServiceRate` with a
`ServiceVariant(profession, code, label, pricingUnit)` catalog row, so each
doorstep profession defines its own variants. `LaundryService` becomes seed data
for the laundry profession rather than a compile-time constraint.

`pricingUnit ∈ {PIECE, KG, ITEM, VISIT}` — laundry prices per piece or kg,
appliance repair per visit, water cans per item.

**Size:** M/L · **Touches:** DB, API, UI

### E-2. Three more doorstep services, chosen for this market

| Service | Why it fits | Shape |
|---|---|---|
| **Appliance repair at home** (fan, mixer, cooler, geyser, inverter) | The professions already exist in the catalog (`Appliance Mechanic`, `Inverter and Battery Installation`, `UPS and Stabilizer Technician`). Nothing is picked up — the provider comes, diagnoses, quotes, repairs. | `VISIT` pricing + a diagnosis step: provider inspects, proposes a price, customer approves before work. Reuses the T4.10 propose-terms machinery. |
| **Water can / RO delivery** | Near-universal recurring need in Indian towns; the highest-frequency doorstep transaction there is. | `ITEM` pricing, recurring schedule. **Decided (product owner, 2026-07-27): a `Task` with occurrences, not a recurring `PickupDropOrder`.** Phase 1 already built exactly this engine — leave, skip, pause, reminders and attendance all come free — and the alternative means writing repeat scheduling a second time and maintaining two of them. |
| **Cylinder / heavy-item pickup and drop** | Genuine pickup-drop shape, same as laundry, so it needs no new model — only a variant set. Also covers sending documents, keys, tiffin. | `ITEM` pricing, reuses `PickupDropOrder` unchanged. |

A fourth candidate worth considering later: **sharpening / knife & tool
servicing**, and **cobbler / shoe repair** — both are true pickup-drop and both
are common informal trades that would benefit from a booking channel.

### E-3. Copy and iconography

- The doorstep screen's tagline is laundry-specific ("we deliver back cleaned or
  ironed"). Replace with a service-neutral line and let each service card carry
  its own one-line description from the catalog.
- Each doorstep service needs an icon in `images/professions/` — the icon cache
  (T6.10) already serves whatever is added.

### E-4. Acceptance

- At least three doorstep services are bookable end to end.
- A laundry order still behaves exactly as it does today (regression check on the
  full flow: place → accept → confirm → status transitions → cancel).
- Adding a fourth service is catalog data plus an icon — no code change.

**Total size:** L. **Sequence:** after Phase 5, before Phase 8 — liquidity work
should be built on the general model, not migrated onto it later. Same argument
as D-1 (multi-worker).

---

## 7. Section F — UI uniformity, responsiveness, ease of use

Observed across every screen during the Phase 6 run. None of these change what a
screen *does*; they change how consistent and reachable it is.

### F-1. There is no design system — three font stacks in use

| Where | Font |
|---|---|
| `Earning Zone`, `Dashboard`, `Profile`, `Gasta` wordmark | `GoogleFonts.sofadiOne` |
| Some body text and buttons | `GoogleFonts.comfortaa` |
| `Add new Task`, `My Addresses`, `Search`, most form labels, all dialogs | **default Roboto** |

The result is visible on consecutive screens: a decorative script header on one,
a plain system header on the next.

**Fix.** One `AppTypography` with a fixed, named scale — `display`, `title`,
`body`, `label`, `caption` — and one decorative face reserved *only* for the
brand wordmark. Every `TextStyle(fontSize: …)` literal in `lib/` routes through
it. There are roughly 120 such literals; this is mechanical.

### F-2. Colour is ad-hoc

`Colors.red`, `Colors.green`, `Colors.blue`, `Colors.orange`, `Colors.teal`,
`Colors.purple`, `Colors.grey[300]` and `AppColors.darkBrown`/`lightBlue` are all
used directly. Status colours are decided independently in three places (already
noted in T6.12).

**Fix.** An `AppColors` token set — `primary`, `onPrimary`, `surface`, `success`,
`warning`, `danger`, `muted`, plus one status→colour map — wired through
`ThemeData` so widgets inherit rather than hardcode. **Check contrast**: the
current `Colors.grey` on light backgrounds fails WCAG AA at small sizes, which
matters for older users.

### F-3. Shape and spacing drift

Corner radii in use: 6, 8, 10, 12, 20. Screen padding: `screenWidth * 0.04`,
`* 0.045`, `* 0.05`, and fixed 16/24. Card elevation: 0, 2, 4, and custom
`BoxShadow`s.

**Fix.** `AppSpacing` (4/8/12/16/24/32) and `AppRadii` (small 8 / medium 12 /
large 20) constants; one `AppCard` wrapper. Ban raw numbers in new code the way
DESIGN-RULES bans horizontal scrolling.

### F-4. Five different widgets are used for "the primary button"

`ElevatedButton`, `FilledButton`, `OutlinedButton`, `TextButton`, and
`GestureDetector` wrapping a decorated `Container` all appear as a screen's main
action. DESIGN-RULES §3 says one primary action, full width, at the bottom — the
rule exists but there is no component enforcing it.

**Fix.** `AppButton.primary` / `.secondary` / `.danger`, each 48dp minimum, full
width by default. Replace call sites screen by screen with an emulator check
after each, per DESIGN-RULES §6.

### F-5. Responsiveness

What is already right: nearly everything sizes from `MediaQuery.size.width` with
`.clamp(min, max)`, which degrades sensibly across phone widths.

What is wrong:

1. **System font scale is ignored.** Nothing reads `MediaQuery.textScaler`. A
   user who has set a large system font — precisely the older, low-vision users
   this product targets — will overflow layouts everywhere. The 10px overflow
   found in T6.11 was that class of bug at default scale. **Test at 1.3× and 2×
   and fix what breaks**; this is the highest-value item in this section.
2. **The multipliers are arbitrary** — 0.033, 0.035, 0.037, 0.038, 0.04, 0.045,
   0.05, 0.055, 0.07, 0.085, 0.11 all appear. Collapse to the F-1 named scale.
3. **No height awareness.** Short screens (e.g. 640dp) push the wizard's Next
   button off; tall screens leave the OTP screen mostly empty. Two breakpoints
   are enough: `compact` (< 700dp tall) and `regular`.
4. **No landscape handling.** Either support it or lock portrait — currently it
   is neither, and landscape is broken.
5. **Fixed heights** in a few cards will clip translated text in Phase 9. Prefer
   `IntrinsicHeight`/`minHeight` over fixed.

### F-6. Ease of use — rearrangement, not redesign

Each of these moves or adds something small; none replaces a flow.

| # | Change | Why |
|---|---|---|
| 1 | **Demote search on the home screen.** It is currently the topmost element. A user who cannot read confidently will not type. Put "Reserve or Schedule" and "Doorstep Services" first, search below them. | The two action cards are what this audience actually taps. |
| 2 | **Move the distance filter out of the sheet.** It is the most-used filter in Earning Zone and it currently takes: tap funnel → tap Distance → tick → Apply. Put the five distance options as a fixed bar on the screen itself (`buildFixedFilterBar` already exists), leaving category/profession in the sheet. | Four taps → one. |
| 3 | **Give the Dashboard a next action.** It shows six numbers and offers nothing to do. Add one line under each card: "3 jobs waiting for quotes → View". | Numbers without an action are a dead end. |
| 4 | **Show the monthly cost.** "₹500 DAY" for a daily maid is ₹15,000/month and the app never says so. Show "≈ ₹15,000 per month" beside any recurring amount. | This is the number the decision is actually made on. |
| 5 | **Landmark field on addresses.** Rural and semi-urban navigation is by landmark, not street. Add a nullable `landmark` and show it to the earner *first*, above the address line. | An earner who cannot find the house cannot do the job. |
| 6 | **Empty states that teach.** "No jobs found nearby" should say what to change: widen the distance, check location is on, or pick more professions — each as a button. Same for an organiser with no tasks. | The current empty states are dead ends for a first-time user. |
| 7 | **"What happens next" after posting.** A one-line confirmation: "Workers nearby can now see this. You'll get a message when someone quotes." | Nothing currently tells the organiser to wait rather than repost. |
| 8 | **Share on WhatsApp.** A share button on a task and on an earner profile. WhatsApp is how this market forwards everything; T8.8 (referral) becomes nearly free once this exists. | Meets users where they already are. |
| 9 | **Offline tolerance.** Show cached data with a "showing saved information" banner rather than an error, when the network is down. T6.10's `CacheService` already holds the data. | Rural connectivity is intermittent by default, not exceptional. |
| 10 | **Confirm before destructive actions.** Cancel-task and release-earner currently act on a single tap in some paths. DESIGN-RULES §4 requires a dismissible confirm. | One mis-tap should not end an engagement. |

**Size:** F-1 to F-4 are M each and best done as one pass. F-5 is M. F-6 items
are S each and independent.

**Sequence.** Do F-1…F-5 **before Phase 7**, because Phase 7 adds profile,
badge and reputation UI that would otherwise be built against the current
inconsistency and need redoing. F-6 can land incrementally at any point.

---

## 8. Section G — What else is missing to make this succeed

Beyond the phase plan. Ordered by how much each affects whether the product
works at all.

| # | Gap | Argument |
|---|---|---|
| G-1 | **Earner safety** (→ T7.8) | A woman travelling to a stranger's house needs to know who she is meeting and to be able to tell someone where she is. Nothing in the plan covered it. This is table stakes for supply-side trust and it is a genuine omission. |
| G-2 | **No proof of work for the earner** | The earner's attendance record is their CV. Give them an exportable/shareable summary — "142 days worked, 4.6★, 8 employers" — that survives leaving the platform. It also makes T5.7 (identity recovery) meaningful. |
| G-3 | **Onboarding that shows, not tells** | A 30-second first-run walkthrough with pictures for each role. Text-heavy help is unusable for the target audience. |
| G-4 | **No cancellation expectations set** | T10.4 records penalties but nothing tells either party the rules *before* they commit. Show the policy at accept time. |
| G-5 | **Notification quality** | Currently a flat list. Needs grouping by task, action buttons ("Confirm", "Call"), and a clear unread state. T11.3 (push) makes this urgent rather than cosmetic. |
| G-6 | **No feedback loop into the catalog** | When search returns nothing, record the query. That list is the roadmap for which professions to add next, and it costs one table. |
| G-7 | **Trust for the organiser side is thin** | T7.x is all about rating earners. An earner deciding whether to accept a job sees almost nothing about the organiser — T7.6 helps, but "has this person hired before and did they pay" is the question. |
| G-8 | **No analytics at all** | There is no way to answer "where do users drop out of the booking wizard". Before optimising anything post-launch, basic funnel events are needed. Small, and it makes every later decision evidence-based. |

---

## 9. Section H — DEFERRED.md review

| Item | Verdict |
|---|---|
| **D-1 multi-worker tasks** | **Move in — schedule between Phase 5 and Phase 8**, as its own note already recommends. Phase 6 hardening is done, so the argument for waiting has expired. Doing it before T8.3 (instant hire) matters: instant-hire logic written against a single-earner FK would need rewriting immediately. The full design in DEFERRED §D-1 stands; add that T6.4's new `NearbyJobRepo` query is where the `COUNT(*) < WORKERS_NEEDED` clause goes. |
| **D-2 TaskChat** | **Stays deferred — but decide.** T4.9 (phone reveal) covers the real need. Recommend **deleting the placeholder class**: a `@Table`-annotated class with no `@Entity` is a trap for the next reader. Costs nothing, removes confusion. |
| **D-3 payments** | **Stays deferred.** Correctly out of scope. T4.11 statements and T10.4 penalties are the records a future settlement reads. |
| **D-4 masked calling** | **Stays deferred** (= T11.12). Direct reveal is right at this volume. |
| **D-5 library changes** | **Stays deferred** (= T11.7). Needs approval and a version bump. |
| **D-6 multi-tenancy** | **Stays deferred.** Inert by choice. |
| **Latent: enum columns** | **Move in as T5.0** — it is now blocking, not latent, because Phase 5 adds `CancelType.RESCHEDULE`. |
| **Latent: leftover indexes** | **Move in as A-7**, folded into T11.2. |
| **Latent: `Slot` enum bloat** | Stays in T11.11. 30+ values, 4 used, label typos (`C_0700_1100` says "11:00 PM"). |
| **Latent: duplicated ₹ glyph** | **Move in as an F-3 sub-item** — it is a theme problem (icon plus text that already contains the symbol), fixed once in the shared money component. |

---

## 10. Suggested order

1. **§A defects** — A-1 (search), A-3, A-5, A-6. Small, and A-1 was raised
   directly. *(A-2 is §E; A-4 is a decision; A-7/A-8 fold into T5.0/T11.2.)*
2. **T5.0** — widen enum columns. Blocks Phase 5.
3. **Phase 5** — T5.1–T5.9.
4. **D-1 multi-worker** — before liquidity work, per §H.
5. **§E doorstep generalisation** — before liquidity work, same argument.
6. **§F-1…F-5 design system + responsiveness, and §F-7 mode switch** — before
   Phase 7 adds screens, since both change navigation and every screen's chrome.
7. **T6.12** — refactor, alongside §F since both touch every screen.
8. **Phase 7** — trust, including the new T7.8 safety work.
9. **Phase 8** — demand and liquidity, now on the final models.
10. **Phase 9** — language and accessibility.
11. **Phase 10** — ops.
12. **Phase 11** — scale, with T11.6 (rate limiting) pulled earlier if launch nears.

§F-6 and §G items land opportunistically throughout.

---

## 11. Tracker

| Section | Item | Status |
|---|---|---|
| A | A-1 Professions without sub-professions unsearchable | ✅ |
| A | A-3 Backfill "Get it done" titles | ✅ |
| A | A-4 Decide `LocationState.enabled` meaning | ✅ |
| A | A-5 Location failure returns a sentence as coordinates | ✅ |
| A | A-6 `TextEditingController` built in `build()` | ✅ |
| A | **A-9 Denying the location prompt strands the app on the splash** *(new)* | ✅ |
| 5 | T5.0 Widen remaining enum columns (blocking) | ✅ |
| 5 | T5.1–T5.3 Substitute task, badge, lifecycle | ✅ |
| — | **B-1 `posted_tasks_screen` filter URL missing `?filter=`** *(new)* | ✅ |
| 5 | T5.4 Reschedule + schedule edit (resolves R5) | ✅ |
| — | **B-2 Address type "Farm" sent a value the server has no enum for** *(new)* | ✅ |
| — | **B-3 `flutter analyze lib/` cleared: 132 → 0** | ✅ |
| 5 | T5.5 Availability windows | ✅ |
| — | **B-4 Seven dropdowns sized to their widest option and overflowed** *(new)* | ✅ |
| 5 | T5.6 Doorstep provider choice | ✅ |
| 5 | T5.7 Identity recovery | ⏭ **deferred to Phase 10** (needs T10.2 admin tooling) |
| 5 | T5.8–T5.9 Shared device, call for help | ✅ |
| — | D-1 Multi-worker tasks (moved in from DEFERRED) | ✅ |
| E | E-1–E-4 Doorstep beyond laundry | ◐ **Model, catalog, API and copy done and verified. Two checks outstanding — see §E-5.** |
| F | F-1–F-4 Design system (type, colour, shape, buttons) | ◐ **Tokens, AppButton and the status map built. Screen-by-screen adoption outstanding — see §F-8.** |
| F | F-5 Responsiveness incl. system font scale | ◐ **Font scale honoured + bounded, portrait locked. Per-screen testing at 1.3×/1.6× outstanding.** |
| F | F-6 Ease-of-use rearrangements (10 items) | ✅ **All 10 done and verified in the emulator.** |
| F | F-7 Mode switch — one app, HIRE/WORK/BOTH preference (§12, decided) | ✅ |
| 6 | T6.12 Shared fetch/state helper, typed models | ◐ **`ApiState`/`fetchInto` built, status maps unified in `AppStatus`, quote accept/reject de-duplicated into `QuoteActions`. Screen-by-screen adoption of `ApiState` outstanding (1 of ~12 migrated).** |
| 7 | T7.1–T7.7 Trust and reputation | ◐ **T7.3 and T7.4 done and verified; T7.2 has its storage (`IS_ID_VERIFIED`) but no admin flip yet. T7.1, T7.5–T7.7 outstanding.** |
| 7 | T7.8 Earner safety (new) | ✅ **Done and verified end to end.** |
| 8 | T8.1–T8.6, T8.8 Demand and liquidity | ✅ **All done and verified.** |
| 9 | T9.0–T9.7 Accessibility and language | ◐ **T9.0, T9.1, T9.3 and T9.7 done and verified in Hindi on the emulator. T9.4 partly (nav labels, day chips, big targets on the pickers). T9.2, T9.5, T9.6 outstanding.** |
| 10 | T10.1–T10.7 Ops, support, disputes | ◐ **T10.1, T10.3–T10.7 done. T10.2 partly — enable/disable, user lookup and verification approval done; serviceable areas outstanding.** |
| 11 | T11.1–T11.13 Scale and hardening | ◐ **T11.6, T11.9 and T11.13 done and verified. T11.1–T11.5, T11.7, T11.8, T11.10–T11.12 outstanding.** |
| G | G-1–G-8 Success gaps | ☐ |

### Phase 7 / 8 progress

**T7.3 — reputation stored, not aggregated.** `user_reputation` holds one row
per person, recomputed when a rating is left, a visit completes or an earner
exits. The nearby-jobs query's `SELECT RATED_USER, AVG(RATING) … GROUP BY
RATED_USER` derived table — a full scan of every conduct rating ever left, run
on every browse by every earner, joined for one column — is now a keyed join.
`T7.3-backfill-user-reputation.sql` seeds it.

*Averages are never stored without their counts.* "4.5 from two ratings" and
"4.5 from ninety" are different claims, and an unrated person is shown as **new**
rather than as an empty star row — four hollow stars read as a bad score, and
starting every new earner at "bad" is how a marketplace fails to onboard supply.

**T7.4 — reputation at the decision point.** `ReputationChips` sits directly
between the earner's name and their price on both quote screens. That is the
screen where an organiser picks between strangers; a price with no history
beside it means the cheapest quote wins every time. Deliberately *not* a single
score: a composite invites a threshold, and a threshold on this market's supply
side means one bad fortnight ends somebody's ability to earn.

**T7.8 — earner safety.** Two buttons on every unfinished visit, not in an
overflow menu:

* **Tell someone** — WhatsApp with the date, slot, landmark, address and who
  she is meeting. The app does not ask her to nominate a "trusted contact" in
  advance; that is a setup step people never finish, and the person you would
  tell today is not always the same one.
* **I feel unsafe** — one tap, no form, no required field. **Never rate
  limited**, unlike the T5.9 callback: the fourth time somebody says they are
  frightened is not the time to tell them we already know. The support number
  comes back in the alert's own response so the call can be offered without a
  second request over a bad connection, and it is offered *whether or not the
  alert got through*.

Verified end to end: `support_request` row with `KIND=SAFETY`, the visit id
resolved, and ownership checked so the field cannot point ops at somebody
else's engagement.

**T8.1 — price guidance.** `Profession` now has `BASE_UNIT`, `BAR_LOW` and
`BAR_HIGH`. `AddProfessionDto` had carried all three since the admin API was
written and `BeanUtils.copyProperties` had been **silently discarding them on
every save** — the data was being collected and thrown away. The band renders
*above* the amount field, because guidance that arrives after the number has
been typed is a correction, and people do not correct themselves. A band, never
a recommended number: one number becomes *the* price, and a floor we set is a
floor we are answerable for.

**Also found and fixed:** the T7.3 backfill first targeted `users`, which
exists but is empty — the real table is `app_users`. `INSERT … SELECT` against
an empty table succeeds, reports nothing and leaves every reputation blank. It
is the kind of no-op that looks exactly like success, and it was caught only by
counting rows afterwards.

### Phase 11 progress

**T11.6 — the OTP endpoint is no longer an open tap.** `otp-request` is
unauthenticated; until now it was also unthrottled, so a loop over ten thousand
numbers sent ten thousand SMS on our account and a loop over one number made
somebody's phone ring all night. Two Redis-backed counters, because they stop
different attacks: **six per phone per hour** (protects the person being
harassed) and **forty per caller per hour**, set deliberately far higher because
behind carrier-grade NAT that key is shared by a whole town and locking out a
village to slow one script is the wrong trade.

*Fails open, loudly.* If Redis is down the request is allowed and the failure is
logged — a login that stops working because the rate limiter is down is worse
than a window of unthrottled requests.

Verified: requests 1–6 returned 200, 7 and 8 returned 429.

**T11.9 — there were no tests.** No `src/test`, no test dependency: nothing in
this service had ever been asserted by anything but a person tapping through the
app. `ScheduleExpansionServiceImplTest` is the wedge — pure logic, no Spring
context, **10 tests in 0.15s**. The cases that matter are the ones where being
wrong is invisible:

* two slots on one day are two visits, not one (collapsing them is how a day's
  work goes unpaid);
* a monthly 31st is **skipped** in February, never rolled into 1 March (rolling
  it over moves a visit and tells nobody);
* an unusable pattern expands to **nothing**, never to everything — treating "no
  day set" as "every day" would materialise a fortnight of visits nobody agreed
  to.

**T11.13 — payload weight.** 73 SVGs, ~444 KB raw, inlined as base64 into every
catalog response; the home screen alone carried around eighty. Nothing inside a
JSON body is cacheable on its own, so all of it was re-sent on every launch. Now
each icon is its own URL under `/api/v1/yapan/common/icon/**` with a
content-derived ETag and a year-long immutable `Cache-Control`, and the app
keeps the bytes locally.

Verified end to end: 200 with ETag, **304** on `If-None-Match`, 404 on a missing
name, path traversal rejected, and **12 icons cached on the device** after one
launch — so the second launch fetches none of them. `gasta.icons.inline` still
sends the base64 alongside the name until every client in the field understands
`iconName`; flipping it false is what actually stops the bytes.

**Defects found while doing Phase 11:**

- **The icon name and the icon path disagreed by one `images/` segment.**
  `iconNameFor` returned `images/professions/x` and `rawSvg` prepended `images/`
  again, so every request 404'd and **every tile rendered blank**. Caught in the
  emulator, not by the compiler — and only because the grid was looked at. Only
  one of the two halves owns the prefix now.
- **`CachedIcon` rendered an empty box on a failed fetch and stayed that way.**
  That is what turned a one-segment path bug into a screen with no icons at all.
  It now falls back to the inlined copy immediately and upgrades silently, and
  logs in debug when it has nothing — the same class of silent failure as the
  `Image.memory`-on-SVG red X.
- **A dead local in `getProfessionsGroup`** computed an icon filename that was
  never read — a second, silently divergent copy of the naming rule.
- **The Hikari pool was sized 20 per datasource on a dev machine.** MySQL's
  default `max_connections` is 151, and devtools restarts plus hard-killed runs
  leave their pools behind, so about eight restarts exhausted the server and the
  next start died with "Too many connections" — which reads like a code failure
  and is not one. Now 8, with idle and max-lifetime bounds so a killed run stops
  costing the next one.
- **The support number existed as two different placeholders**, one hard-coded in
  the app and one defaulted in the service. It is now a single property.

### Phase 9 progress

**T9.1 — the i18n scaffold exists.** `flutter_localizations` + `gen-l10n`, ARB
files under `lib/l10n`, generated class `L`. Untranslated keys are reported to
`l10n-missing.txt` rather than silently falling back, so a gap is visible
instead of being found by a user.

Getting the dependency to resolve took untangling three pins: `intl ^0.18.0`
(bumped), `syncfusion_flutter_datepicker ^23.1.42` (capped intl below 0.19 —
bumped to ^24.1.46), and **`local_auth_ios` pinned explicitly in the pubspec**,
which capped intl and blocked the whole scaffold. `local_auth` endorses its own
platform implementations; pinning them separately bought nothing.

**T9.0 — the language question is asked first of all.** Before login, before the
mode question, on its own bilingual screen that does *not* use the translation
table — at that moment we do not yet know which language the user reads, so the
question has to be legible either way. Each language appears in its own script,
never translated: you have to be able to find yours without reading the others.

**T9.3 — a switcher in Profile**, applied immediately via a `ValueNotifier` that
rebuilds `MaterialApp`, so it takes effect without a restart.

**T9.7 — numerals are always Latin digits.** Written into DESIGN-RULES as §7, so
it binds rather than being remembered. Verified on screen: `+91`, `******0695`,
`21s`, `1 km`/`2 km`/`5 km`/`9 km` all Latin inside Hindi sentences.

**Verified in Hindi on the emulator:** language picker → mode question → login →
OTP → home → Earning Zone → Profile, all rendering Devanagari correctly with no
overflow at 720×1280.

**Also fixed while doing this:**

- **The language question was asked *second*.** I placed the check after the mode
  block, which `return`s — so the first thing a user saw was "What do you want to
  do?" in a language they may not read, and the language question only appeared
  on the *next* launch. The comment above it claimed the opposite of what the
  code did. Now first, and its `next` re-enters the startup flow so answering it
  falls through to the mode question rather than skipping it.
- **The two home tiles were sent as prose** — `"Reserve
or Schedule"` — so the
  app had a sentence, not a thing, and could not translate them. They now carry a
  `code` (`RESERVE`, `DOORSTEP`) which the app looks up in its own table, with
  `name` kept as the fallback for an older client. This is DESIGN-RULES §5, which
  the home menu had been quietly violating.
- The search tile's label was baked in at `initState`, where no localisations
  exist yet — it would have stayed English after a language switch.

**Deliberately still English:** profession and category names ("Carpenter",
"Agricultural Machinery"). Those are catalog *data*, not chrome — translating
them is T9.2 and needs a translated catalog in the database, not a string table.
Saying so plainly is better than a half-translated grid.

### Phase 10 progress

**T10.3 — `AdminAuditLog`, and it is not optional.** Admin powers here are
unusually consequential: verifying an identity, disabling a profession, closing
somebody's safety alert. Each changes a real person's income or reputation, and
each is invisible to the person affected. Without a log, "who marked this ID
verified?" has no answer.

Two decisions worth stating: the log write is **inside the same transaction** and
is deliberately *not* forgiving — if it fails the action rolls back with it,
because an untraceable administrative change is worse than the change not
happening. And **reads are logged too** (`LOOKUP_USER`), because "who looked this
person up?" is a question worth being able to answer.

`targetType`/`targetId` is a loose reference, not a foreign key: the log must
outlive the row it describes, and a cascade would delete exactly the evidence
somebody later needs.

**T10.5 — one queue, not two.** Safety alerts sort above everything else but live
in the *same* list. An operator watching one screen cannot miss the urgent item
by looking at the wrong tab, which is precisely what separate queues would allow.
Within each band it is oldest-first, so nobody waits forever because newer work
keeps arriving, and id breaks the final tie (DESIGN-RULES §2).

**T10.6 — the ops desk is in the app**, gated on the authority the profile
endpoint already returns. The hidden tile is a convenience; the real gate is the
`/admin-user/**` matcher already in `application.properties`. `_isStaff` defaults
to **false** on anything unexpected — the failure mode of a malformed authority
list must be "no admin tools", never "admin tools for everyone".

*The low-literacy rules deliberately do not apply to this screen* (§T10.6):
density beats generosity, words beat pictograms, and a raw wait time in minutes
beats "a little while ago" for somebody working a shift.

**T10.2 (partly) / T7.2** — enable/disable a profession, and the **ID-verified
flip**, which completes T7.2. Verification refuses to proceed without a stated
reason: a badge with no recorded basis is the one thing it must never be.
Disabling a profession clears the icon cache, because the catalog it describes
just changed.

**Verified end to end in the emulator:** the queue showed `1 safety alert(s) open
— 4 total` with the safety alert sorted **above** two-day-old callbacks; closing
one wrote `HANDLE_SUPPORT_REQUEST / SUPPORT_REQUEST / 1` to `admin_audit_log`,
marked the request handled, and the count dropped to 3.

**Defects found while doing Phase 10:**

- **A non-uniform `Border` with a `borderRadius`** — a 4px left accent and 1px
  elsewhere — painted the card and **silently dropped everything inside it**.
  Four blank white boxes, nothing in logcat. `BoxDecoration` forbids the
  combination; it does not tell you at runtime. The accent is now a real 4px
  child.
- **Fixing that introduced a second failure**: `CrossAxisAlignment.stretch` on a
  Row inside a `ListView` has no height constraint, so the row collapsed to
  nothing and the cards vanished entirely. Wrapped in `IntrinsicHeight`. Worth
  recording because the first symptom (blank cards) and the second (no cards)
  look like the same bug and are not.
- The Call button repeated the phone number that was already on the line above,
  and ellipsized it — so the one place it mattered was the one place it was
  unreadable.

### Decisions taken (product owner, this pass)

| Question | Answer |
|---|---|
| **T11.8** file/image storage | **Defer — ship text-only.** T7.1 profile has no photo; no storage work. |
| **T11.3** push / **T11.12** masked calling | **Stub behind interfaces.** Every call site written and exercised; dropping in Firebase/Exotel later is one class each. |
| **T9.2** regional languages | **Hindi only for now.** Six more machine translations before anyone has reviewed the first would multiply the review burden, and a bad translation is worse than English. |

### Later Phase 11 / Phase 7 progress

**T11.2 — Flyway, and it found real drift.** Five loose `.sql` files had
accumulated in `db/`, each needing to be run by hand, in order, exactly once —
and nothing recorded which had been. On this machine one had been applied twice
and another not at all. They are now `V2`–`V6`, applied at startup and recorded
in `flyway_schema_history`. `V1` is an empty baseline because every existing
database was built by `ddl-auto=update`, so there is no authored DDL to replay.

`clean-disabled=true` unconditionally, and Flyway is pointed at an explicit URL
rather than inheriting the application `DataSource` — that one is an
`AbstractRoutingDataSource`, and migrating "through" a router whose target is
chosen per request is not something to leave to chance.

**T5.0's root cause, finally fixed.** Verifying the new tables showed
`support_request.KIND` and `earner_connection.KIND` had both been created as
**native MySQL `enum(...)`** — precisely what T5.0 existed to eliminate, and my
own entity comment claimed the opposite. Hibernate 6 does that by default on
MySQL. `hibernate.type.preferred_enum_jdbc_type=VARCHAR` now makes VARCHAR the
default for every enum column, existing and future; `V7` converts the two that
already existed; `columnDefinition` pins them belt-and-braces. **Zero native ENUM
columns remain.** T5.0 was a migration somebody would have had to keep running
forever; it is now a setting.

**T11.1 — pagination.** Notifications fetched *every* notification a user had
ever received, on every open of the bell. Now one page, newest-first, with **id
breaking the tie on `createdDate`** — notifications are written in bursts and
without a tiebreak two can swap places between pages, so one is shown twice and
another never (DESIGN-RULES §2). `hasMore` comes from fetching one extra row
rather than a second `COUNT` query. Page size clamped server-side, because a
client asking for 100000 would undo the point.

The app parses **both** the old bare array and the new `{items, hasMore}`
envelope, so an older app against this server, or this app against an older
server, keeps working rather than showing an empty list. "Show older" is an
explicit button, not infinite scroll: on an intermittent connection a scroll that
silently fires requests is a scroll that silently fails.

*Verified by pushing a user past the boundary:* button appeared at exactly 30,
page 2 appended, button disappeared at 35. Probe rows removed afterwards.

**T7.1 — earner profile, text-only.** Professions come from tasks they have
actually been assigned to, not a self-declared list: a declared skill is a wish,
an accepted job is a fact. **City only, never the address** — a profile that lets
anyone browsing work out where a worker travels is the exposure T7.8 exists to
reduce. Phone number is absent unless the two are already matched.

**T7.5 — favourites and blocks, one table with a kind.** Two tables would make it
possible to be in both, which nothing downstream could act on; the unique
constraint on `(organiser, earner)` makes the contradiction unrepresentable.

Two decisions worth stating: **a block actually filters the browse query**, not
just records an intention — quoting for a job you will never be given is worse
than not seeing it, and it would make the block visible to its subject. And
**neither action notifies the earner**: being told you were blocked turns a quiet
"not for me" into a confrontation between neighbours.

**T7.6 — the organiser has a profile too.** An earner deciding whether to travel
alone to a stranger's house has at least as much at stake as the organiser
deciding whom to let in, and until now only one side could see anything.

**T11.3 / T11.12 stubs.** `PushSender` and `CallMasker`, both
`@ConditionalOnMissingBean` so a real implementation replaces them without
touching a call site. The notification row is written **before** the push and the
push cannot fail the save — push is a delivery channel, never the record, because
making it the record is how somebody misses that their job was cancelled.
`CallMasker` returns null and reports `isEnabled() == false`, so nothing tells a
user their number is hidden when it is not.

### T8.2 — rebook

The commonest real request in this market is not "find me a maid" but **"get the
same woman back next month"**. Until now that meant walking the whole posting
wizard again from memory — profession, sub-professions, address, schedule, pay —
and getting one of them wrong.

**First refusal, not an assignment.** A rebook posts a *new* task (the old one is
a finished record with its own visits, ratings and payments; reopening it would
rewrite history) and gives the previous earner a 24-hour window in which only
they can see it. Auto-assigning would commit somebody to work they never agreed
to — a maid who has since taken a full-time job elsewhere would silently acquire
visits.

Three details that matter:

- The previous earner comes from the **last `TaskAssignment`**, not
  `task.getEarner()` — that field is the derived *first* active assignment (D-1)
  and is null once an engagement ends, which is exactly when somebody rebooks.
- The browse filter checks `PREFERRED_EARNER_ID IS NULL` **first**, so an
  ordinary task can never be hidden from everyone by this clause, and an expired
  window falls through to open.
- The window is clamped to a week. Unbounded, a job would sit off the market
  indefinitely if the earner simply never opened the app.

The earner is notified when the window opens — without that, a first-refusal
window is a job nobody knows about, which is worse than no window at all.

*Verified:* rebooking a withdrawn task created a clone with `RELATED_TASK_ID`
pointing at the parent, `openToQuote = 1`, and no preferred earner — correct,
because that task had zero assignments, so there is nobody to offer it to first.

**Defect found while verifying:** the posted-task badge read
`assigned ? "Assigned" : "Open"`, so a **withdrawn or finished task wore a green
"Open" badge** — the card claimed the job was live when it was over, on the very
screen an organiser uses to check. Now three states, and "Closed"/"Done" are
neutral grey rather than red: a finished engagement is a success and a withdrawal
was deliberate, so neither is an error.

### T8.5 — job alerts, and the defect the data exposed

The demand side posts and waits; the supply side has to remember to look. An
earner who checks twice a day misses a one-off job for tomorrow morning, and the
organiser concludes nobody is available. Both sides lose to the same gap.

**The first version was wrong, and the data said so immediately.** The matcher
joined `app_user_address` — and earners largely *have no saved address*. Earning
Zone runs off live GPS, and somebody who has never posted a job has never been
asked for one. In this database exactly one user had an address, and it was the
organiser. The alert would have reached nobody, silently, and looked like it was
working.

Fixed by recording the earner's **last browse position** on
`earner_preference` (`LAST_LAT`, `LAST_LNG`, `LAST_SEEN_AT`), written each time
nearby jobs are fetched. That is the least location data that makes alerts work:
a coarse last-known point, overwritten every time, no history and no trail. A
position older than 14 days is ignored — work offered in the village somebody was
in last month teaches them the alerts are wrong.

Matching is from **evidence, not intent**: an earner qualifies because they have
previously quoted in this profession, not because they ticked a box. There is no
"professions I do" list, and inventing one would alert people on an aspiration.

Excluded, in order of how badly getting it wrong would hurt: the organiser
themselves; anyone they have blocked (an alert would waste the earner's time *and*
disclose the block); anyone already on the task; and anyone alerted in the last
12 hours. That last one is the important guard — the failure mode is not too few
alerts, it is an earner who gets six pushes in an evening, turns notifications
off, and then never hears about the job that mattered. Capped at 25 recipients per
posting for the same reason.

A rebook's first-refusal window (T8.2) suppresses alerts entirely while it is
open — alerting everyone during it would hand the job to whoever was quickest,
which is exactly what the window prevents.

*Verified:* browsing as the earner recorded the position; the matcher then
returned that earner for a Maid job at those coordinates.

### T10.4 — a ledger that records and never charges

`cancellation_record` holds what a cancellation cost. **Nothing in this codebase
debits anybody**, and that is the design: a penalty ledger that takes money
automatically is a payments system with a disciplinary policy attached, and
neither exists here. What does exist is the question ops could not answer — "is
this earner cancelling on people, or did they have one bad fortnight?"

The inputs were already collected and thrown away: `noticeDays` and
`duringTrial` on `AssignmentExit`, plus the Phase 4A no-show counts. The column is
called `AMOUNT_AT_RISK`, not "penalty" or "fine" — naming it a fine in the schema
is how a records-only table quietly becomes a billing one. `noticeDays` can be
negative, meaning somebody did not turn up, and it is the number that separates a
reasonable cancellation from an unreasonable one, which is why a bare count is a
misleading statistic.

### T10.7 — the dispute queue

A `DISPUTED` visit means the organiser said the work was not done and the earner
disagrees. Nothing in the product resolves that on its own and nothing should: it
is a disagreement between two people about money, and the only honest mechanism is
a person reading both sides. Until now those rows sat in the table with nobody
looking.

The queue returns **both parties named and both reachable** — an operator settling
a money disagreement needs to call each of them, and making them look the row up
twice is how one side never gets heard. Oldest first, because the unsettled money
*is* the harm. Reading somebody's cancellation history writes an audit row
(T10.3), and that history is never exposed to the other party: it would be used as
leverage long before it was used as information.

### Ops desk — disputes and history wired in

The T10.7 dispute queue and T10.4 cancellation history now have a UI. Two things
worth recording about the shape:

**The dispute count rides on the tab label** (`Disputes (2)`), so an operator
working the callback queue can see there are disputes waiting without switching
to look. Two lists rather than one because they are worked differently — a
callback is a phone call, a dispute is a judgement — but neither can be forgotten
while looking at the other.

**Both parties are laid out identically**, each with its own Call and its own
history. An operator settling a disagreement about money needs to hear both, and
a layout that buries one invites hearing only the other. Nothing in the screen
resolves the dispute: the app has no view on who is right and should not pretend
to.

The history sheet leads with **"Records only. Nothing has been charged."** Said
plainly because an operator reading a list of somebody's cancellations will
assume it is a penalty record unless told otherwise. A negative notice figure
renders as "Did not turn up" rather than "-1 days notice", which is how a row
gets misread aloud.

*Verified:* opening the tab surfaced two disputes — including one that had been
sitting in the table unlooked-at before this existed, which is the whole point —
and opening a history wrote `VIEW_CANCELLATION_HISTORY / USER / 2` to
`admin_audit_log`.

**Defect found while verifying:** the dispute payload omitted `organiserId` and
`earnerId`, and the app gates the history button on a non-null id — so the
feature was **silently absent** rather than broken. The rows looked complete and
the button simply was not there. Fixed by sending both ids.

### T8.4 + T10.2 — serviceability, both sides

Built together because they are one feature: ops defines where Gasta operates,
the app refuses postings outside it.

**A deliberate deviation from A-4.** The plan recommended reusing
`location_state.IS_ENABLED` as "we operate here". That is the right shape for one
flag but the wrong *granularity*: Gasta serves a cluster of villages around Pundri
Kalan, not the whole of Uttar Pradesh. A state-level gate would tell somebody 400
km away, in a city with no workers on the platform, that their area is served —
and they would post a job nothing could fill. So `location_state.IS_ENABLED` stays
what it is (catalog visibility for the address dropdown) and serviceability lives
in `serviceable_area` as a centre and a radius. The A-4 collision the plan warned
about is avoided by not putting two meanings on one column at all.

**An empty area table means everything is serviceable.** This is the single most
important property. The feature ships into a database with no areas defined; if
the default were "nothing is serviceable" the first deploy would block every
posting in the country, and the failure would look like a bug in task creation
rather than a missing configuration row. Every path fails open — no coordinates,
no areas, a thrown exception — and logs when it does.

**A rejection is the best demand signal this product can collect.**
`service_interest` records where somebody wanted us and we were not there, and it
is deliberately **not** deduplicated: ten people from one village is a stronger
signal than one, and collapsing them erases the number that matters. The refusal
sheet names the real reason ("no workers have signed up in your area yet" — not a
judgement on the user), uses info blue rather than warning orange because nothing
has gone wrong, and only claims "we will tell you" once the server has actually
recorded it.

*Verified all three directions:* with no areas, `serviceable: true`; with a
Mumbai-only area, Pundri Kalan returned `OUT_OF_AREA` and Mumbai returned `OK`;
and a real posting from Pundri Kalan was refused with the intended message. Test
area removed afterwards.

**Defects found while verifying:**

- **The refusal came back as HTTP 500** reading *"Could not add task: We do not
  work in your area yet…"* — two apologies stapled together and the wrong status
  code. `addNewJob` had no `CustomException` branch, so every client-side refusal
  in it was reporting as a server error. Now 400 with the message as written.
- **The task-posting failure path said "Failed to add address"** — wrong noun
  entirely — **and pasted the raw JSON response body into a snackbar.** A JSON
  blob is not a message for anybody, least of all this audience. Now uses the
  server's own sentence via the existing `ApiService.serverMessage`.

### T8.8 — referral, without pretending

Word of mouth is how this market finds everything, and the product had no way to
see it happening. This answers one question — where users actually come from —
and deliberately nothing more.

**No reward, and that is not an omission.** A referral bonus is a payments
feature and there is no payments system here. Shipping a scheme that promises
money the product cannot pay would be worse than shipping nothing. The referrer
is not even notified when somebody claims their code: telling them "your friend
joined!" invites them to ask what they get for it.

**A typed code, not a deep link.** There is no install attribution in this app,
and a link-based scheme would silently lose most of its data while looking like it
worked. Asking the question plainly — "who told you about Gasta?" — is what
actually works when the channel is a WhatsApp message read aloud.

The code is derived from the user id (base-36, `G`-prefixed) rather than stored:
short enough to say down a phone, and no column that can drift out of step with
the account. It is guessable, which is acceptable **precisely because nothing is
attached to it** — that trade-off is written into the code, along with the note
that a stored random value is required first if a reward is ever added.

`referred_user` is unique: a person can be referred once, by one person, ever.
Without it the same account could be claimed repeatedly and any future reward
would be trivially farmable.

*Verified all four paths:* own code → "That is your own code"; nonsense → "That
code does not look right"; a valid other code → accepted and named the referrer;
a second claim → "You have already told us who invited you." Test row removed.

### T8.3 — instant hire

The ordinary flow is quote → wait → compare → accept. That is right for a maid
you will employ for a year and absurd for a plumber you need this afternoon.
Instant hire removes the round trip: the organiser sets the price, and the first
earner to accept has the job.

**Still an acceptance, never a conscription.** Nobody is assigned without tapping
accept — the same principle as T8.2's first-refusal window. What is removed is the
negotiation, not the earner's answer.

**The race is settled under a row lock**, not by hoping. Two earners tapping
accept in the same second would otherwise both read `workersTaken = 0`, both pass
the capacity check, and both be assigned to a one-person job — a failure invisible
until two people turn up at the same house. `findByIdForUpdate` takes
`PESSIMISTIC_WRITE` for the duration. Losing the race says "Someone else took this
job first", which is not an error the earner caused and must not read like one.

**The endpoint decides the flag, not the request body.** `post-instant-job` and
`post-new-job` both call one private `createTask(..., boolean instantHire)`.
Reading the flag from the DTO would let any client turn an ordinary posting into
an instant one — a different product behaviour *and* a different alerting policy —
by adding a field. *Verified:* posting to `post-new-job` with
`"instantHire": true` in the body produced `IS_INSTANT_HIRE = 0`; the instant
endpoint produced `1`.

Instant jobs bypass the T8.5 quiet window (zero hours, not a smaller number): the
window exists to stop routine postings becoming spam, and applying it here would
suppress precisely the alert that mattered. The recipient cap still bounds volume.

### T8.6 — popularity ordering

"Popular pros" was **alphabetical**, so the home screen opened on Agricultural
Machinery and Architect/Drafter — a list sorted by the accident of spelling, on
the one screen meant to show what this area actually needs.

Now ordered by postings over a rolling **90 days**: long enough to survive a quiet
fortnight, short enough that the ordering follows the season, which in an
agricultural market is most of the signal. Professions with no recent postings
keep their alphabetical order and go *after* the ranked ones rather than being
dropped — a new profession with no history must stay findable, or it can never
become popular. Ordering failures fall back to the plain list: the order is a
nicety, the list is not.

*Verified in the emulator:* Maid (6 postings) → Automobile Mechanic (2) →
Agricultural Machinery (1), matching the database counts exactly.

**Defect found while verifying:** a posting with no `scheduleList` reached
`getScheduleList().forEach(...)`, threw an NPE, and returned **500 with
`Cannot invoke "java.util.List.forEach(...)" because ... is null` as the
user-facing message** — a stack-trace fragment in a snackbar. Now a 400 reading
"Choose when the work should happen."

*Process note:* `mvnw -q compile` reported clean on a build that in fact failed
with two errors. Do not trust `-q` for error detection — the later non-quiet run
is what caught it.

---

## 12. Decided — one app, with a mode switch

**Decision (product owner):** keep a single codebase and a single app. Split the
*experience* with a mode preference, not the product.

**Why, recorded so it is not re-litigated.** Uber, Swiggy and Urban Company ship
two apps because a driver is never a rider — disjoint populations. That is not
this market: a farmer hires labour and does contract work, a maid hires a
plumber, and the Dashboard already shows Organiser *and* Earner sections for one
account. Two apps would force that person into two installs and two logins to do
one day's business, and would double the cost of §F and every Phase 9
translation during the phases with the most UI churn.

### F-7 — Mode switch *(new task)*

**Spec:**

- **Not a role.** `SUPER_USER` / `BASIC_USER` authorities and every server-side
  matcher are untouched. This is a client-side *presentation preference* only —
  no new column, no new endpoint, no authorisation consequence.
- Persisted through the T6.10 `CacheService` as `APP_MODE ∈ {HIRE, WORK, BOTH}`.
- **Asked once**, on first launch, immediately after the language picker (T9.0)
  and before login — three large picture-and-word cards: *I need help* /
  *I want work* / *Both*. Skippable; skipping means `BOTH`, which is exactly
  today's behaviour.
- Changeable any time from Profile → "Switch to earning" / "Switch to hiring".
- **What the mode changes:** which screen you land on, the order of the bottom
  tabs, and the order of the Dashboard sections. In `HIRE`, Earning Zone moves to
  the end; in `WORK`, it leads.
- **What the mode must never do: hide a commitment.** If a user in `HIRE` mode
  has a visit today, or an open quote, it still surfaces — on the home screen and
  in notifications. A preference that loses someone a day's work is worse than no
  preference. This is the acceptance criterion that matters most.
- `BOTH` renders exactly what ships today, so the change is additive and
  reversible.

**Acceptance:** a new user picking "I want work" lands on Earning Zone with
earning tabs first; switching to hiring in Profile re-orders without logging out;
a `HIRE`-mode user who has an accepted job still sees today's visit on the home
screen; choosing "Both" is indistinguishable from the current app.

**Size:** M · **Touches:** UI only (navigation, Profile, first-run)

**Sequence:** with §F-1…F-5, since it changes navigation and landing screens and
should not be retrofitted after Phase 7 adds more of both.

### Revisit trigger

Re-open the two-app question only when **all three** hold: analytics show under
~5% of accounts use both modes; the app is post-launch with a stable UI; and
install size on cheap phones is measurably costing earner signups. Until then
this is settled.

---

## 13. PLAN-4 §6.7 — the built-but-unreachable audit

Run as PLAN-4 recommended, before building anything. It took under an hour and
its finding is larger than the plan expected: **19 endpoints in `Constants` have
no caller anywhere in `lib/`**, plus two live server features with no constant
at all.

Method, repeatable — for each `Constants` field, grep `lib/` for `Constants.<name>`
excluding `constants.dart` itself; and extract every `@*Mapping("...")` from the
controllers, **anchored to the start of the line** so commented-out routes are
excluded. (The first pass missed that anchor and reported two dead routes that
are commented out in `OrganiserController`.)

### What has no caller

**Whole features, complete server-side, unreachable in the app.** Each is the
same defect class as `Constants.cancelTask`: nothing errors, the endpoint is
simply never called, so it looks like a feature that was never built.

| Feature | Endpoints | Marked in PLAN-4 §5 as |
|---|---|---|
| Monthly statement | `agree-statement`, `get-statements` | — (called out in §7.1) |
| **Change of terms** | `propose-terms`, `respond-terms`, `get-terms-history` | Phase 4A ✅ |
| **Profiles, both sides** | `earner-profile/{id}`, `organiser-profile/{id}` | T7.1 / T7.6 ✅ |
| **Favourites and blocking** | `set-earner-connection`, `my-favourites` | T7.5 ✅ |
| **Instant hire (T8.3)** | `post-instant-job`, `accept-instant-job/{taskId}` | Phase 8 ✅ **Complete** |
| Confirm arrival | `confirm-arrival/{jobId}` | Phase 2 ✅ |
| Earner's own leave list | `get-my-leaves` | Phase 3 ✅ |
| Pause an engagement | `pause-task` | Phase 3 ✅ |
| Change a standing schedule | `update-schedule/{taskId}` | T5.4 ✅ |
| Unread badge count | `get-unread-notification-count` | T11.1 ✅ |
| Provider rate editing | `provider/update-rates/{id}` | §E ✅ |
| Ops: verification, enable/disable, lookup, audit | `set-id-verified`, `set-profession-enabled`, `lookup-user`, `audit-log` | T10.2 ◐ |
| Ops: serviceable areas, interest list | `admin-user/serviceable-areas`, `save-serviceable-area`, `service-interest` | T8.4 ✅ / T10.2 ◐ |

**Legitimately absent from the app** (bootstrap / console only, no defect):
`super-user/initial-setup`, `super-user/add-country`, `admin-user/add-states`,
`add-professions`, `add-sub-professions`, `enable-state`.

**One hardcoded path bypassing `Constants`:** `laundry_booking_screen.dart` calls
`/api/v1/yapan/doorstep/profession/{id}/providers` as a string literal. It works,
so it is not urgent — but it is why the audit's first pass flagged that route as
orphaned, and a path that lives outside `Constants` is a path nobody will find
when it changes.

### What this means for the §5 tracker

**Phase 8 is marked ✅ Complete and its headline feature cannot be reached.**
T7.5 and T7.6 are likewise ✅ with no way in. The tracker has been measuring
*server* completeness. Nothing in it was untrue about the code that was written;
it just never asked whether a user could get to it.

**Recommendation:** an item is not done until something calls it. The cheap
enforcement is to re-run the two greps above whenever a phase is closed — it is
one command and it would have caught all of these at the time.

### Wired up in this pass

Three of the unreachable endpoints now have callers, because §7.1 / §7.5 needed
them anyway: `get-statements` and `agree-statement` (the register's "Agree this
month") and `propose-terms` (§7.5's "Raise the rate"). `respond-terms` and
`get-terms-history` remain uncalled — the *answering* side of a rate change is
still missing, which means a raise proposed from the register cannot yet be
accepted in the app. That is the next thing to wire.

The rest of the table is outstanding.

---

## 14. PLAN-4 §7.1, §7.2, §7.5, §7.9 — implementation notes

### §7.1 The attendance and wage register

`GET /authenticated/get-register?taskId=&month=` returns one month of one
engagement: a cell per dated visit, the counts, what it comes to, the advances
balance, the agreed statement if there is one, and — for the payer only — the
rate nudge.

**On the shared controller, not the organiser's, and readable by both parties.**
That is the feature, not a convenience: a register only settles an argument if
neither side can be shown a different version of it. An `/organiser/**` copy plus
an `/earner/**` copy would be two payloads that can drift.

Screen: `attendance_register_screen.dart` — weekday-aligned calendar, colour plus
pictogram per day, month arrows, totals, advances, "Agree this month". Reached
from the organiser's visit screen (the attendance strip is now the doorway, so
the most-used screen in the product is not a fourth icon in an app bar that
already carries three) and from every earner visit card.

**Payable = COMPLETED + DONE_BY_EARNER.** `DONE_BY_EARNER` counts because it
auto-confirms within a day; leaving it out would make the total fall and rise
again for reasons neither party caused. `ABANDONED` and `DISPUTED` are excluded
and shown separately — both need a human decision, and a register that silently
took a side on them would be making the judgement it exists to hand back.

**The total is omitted, never guessed.** `HOUR`, `SQ_FT`, `EQUIPMENT`, `PERSON`
and `TOTAL` set `estimateUnavailable` and the screen says why. A wrong number
here is worse than a missing one: the two of them will quote it at each other.
Per-day rates count distinct dates, per-slot rates count rows, so a house with a
morning and an evening visit is not charged a daily wage twice.

Verified on **both** accounts: the earner sees the identical grid and total with
the wording turned round, and flagging a day runs end to end — DISPUTED,
`PREVIOUS_STATUS` kept, the other side notified, and the row lands in the T10.7
ops queue.

**Five defects found in the emulator, none of which compiling would have caught:**

1. **"To come" and "on leave" were the same orange.** `AppStatus` gives
   SCHEDULED `#E65100` and EARNER_LEAVE `#EF6C00`. Harmless on a visit card that
   spells the status out beside it; on a month grid it makes two opposite facts
   look identical, on the one screen whose premise is that it is legible without
   reading. Fixed *in the register only* — future days are drawn muted and
   unfilled, which is also the more honest drawing, since a day that has not
   happened is not a record. Deliberately **not** fixed in `AppStatus`: that map
   is shared by four screens, and recolouring it globally to fix one grid is the
   shape of change that broke login once (PLAN-4 §4 rule 7).
2. **A locked month showed live totals under "these numbers will not change".**
   A statement agreed mid-July had frozen 1 day at ₹750; the month then ran on to
   2 days, and the screen showed "2 days, ₹1,500" directly beneath the banner
   saying the numbers were fixed. Both halves came from the same payload and
   contradicted each other — on the one screen meant to end an argument about
   money. `applyFrozen` now serves the agreed figures once both sides have
   signed, and the card is labelled "As you both agreed". The grid still shows
   every day as it really is, so a later correction is still visible.
3. **The forward arrow was dead, hiding nine real visits.** `nextMonth` stopped
   at the current month on the reasoning that a future month "cannot have
   attendance in it" — which is false, because occurrences are generated
   `gasta.occurrence.horizon-days` ahead. It now pages up to
   `Task.occurrencesGeneratedUpto`. This is PLAN-4 §4 rule 4 exactly: a comment
   that disagreed with reality, written by me, in the same change.
4. **A locked month still offered "This day is wrong"**, which the server always
   rejects. A button whose only outcome is an error reads as a broken app rather
   than a settled month, so the button is replaced by the reason.
5. **The two advance buttons were written from two different people's points of
   view** — "Gave an advance" (the payer's voice) sat directly above "Paid some
   back" (the worker's). Invisible on the organiser's screen, obvious on the
   earner's: the pair reads as though it belongs to two different people. Both
   labels now turn round with the viewer. The row written is identical either
   way; only the wording changes. On a screen built for someone who reads
   slowly, working out which button is yours is the entire cost of the
   interaction.

### §7.2 Advances (peshgi / udhaar)

`cash_advance`, and `add-advance` / `respond-advance` / `get-advances`.

**A ledger, not a payment.** Repayments are negative rows rather than a mutable
"remaining" column, so a running balance can never disagree with its own history.
Either side may record one; the other is asked to agree; **an unconfirmed row
still counts towards the balance**, because hiding it until both agree would
understate what is owed for as long as one person has not opened the app — and
the person who benefits from that is the one with least reason to confirm.
Disputed rows stay in the ledger: deleting somebody's record of money because the
other party objected is not a neutral act.

**Never deducted.** The balance sits beside the month's earnings, never
subtracted from it, and the screen says so in as many words. The deduction is a
conversation between two people, and an app that did it for them would be doing
the one thing this feature exists to prevent.

`earner` and `organiser` are denormalised onto the row so the balance survives
the engagement — an advance outlives the job it was given during, which is the
whole problem.

### §7.5 Wage increments

`RateGuidanceDto`, on the register, payer only. Telling a worker her rate is
below the local band on a screen with no way for her to act on it makes the
conversation harder, not easier.

Fires when the T8.1 band is known **and quoted in the same unit** — ₹550–650 per
day says nothing about ₹6,000 per month. Two reasons: below the band, or twelve
months since the rate was set. "When it was set" is the last accepted
`TermsChangeRequest`, else the assignment date, else the posting date; the
fallbacks matter, because an engagement that has never renegotiated is exactly
the one whose rate is stalest.

**A defect in my own rule, found on screen:** the anniversary case fired for a
household paying ₹750/day against a ₹400–700 band, producing "it has been a year
— people nearby pay ₹400–700" above a Raise button. Every clause true, the
paragraph nonsense. It now also requires headroom (`amount < barHigh`); above the
band we say nothing, because there is nothing true to add and manufacturing a
nudge spends exactly the credibility that makes the below-band case worth
showing.

The raise goes through `propose-terms`, so the earner still has to accept it.

### §7.9 "She hasn't come"

`POST /organiser/report-no-show/{jobId}`, plus `TaskJob.noShowReportedAt` and
`VisitDto.noShowReported`.

**No status changes.** The obvious implementation — mark it MISSED — writes off a
day's pay over a late bus, at 9:05, on one side's word; and
`confirmArrival(arrived=false)` already exists for once the day is actually over.
The overnight sweep closes untouched days, so nothing is lost by waiting.

**No new endpoint on the earner's side.** Her two answers are buttons she already
has: "On my way" (`update-visit-status`) and Take leave (`mark-leave`). What was
missing was the *question*, so her visit card now carries it — a notification
scrolls away, and this one is worth answering within the minute.

Stamped once per visit: six identical notifications in an evening is how somebody
turns notifications off and then misses the one that mattered.

### Build fix — Lombok against the machine's JDK

Unrelated to the plan, and blocking all of it. The default JDK on PATH is now 26;
Lombok 1.18.34 cannot process it and **stops generating code without saying so**,
so the build reported around 400 "cannot find symbol" errors on getters in files
nobody had touched — as though every `@Data` entity had broken at once. Nothing
in the output mentioned Lombok or the JDK.

`<java.version>17</java.version>` does not prevent this: it sets the *target*
release, while javac still runs on whatever is on PATH. Bumping Lombok to 1.18.42
does **not** fix it either (tried, still fails on 26).

The fix is a `maven-enforcer-plugin` rule pinning the build to JDK 17–21, with a
message that names the cause and gives the command — so the next person loses a
minute instead of an afternoon. The plugin version is pinned to 3.6.2 because the
Spring parent's 3.4.1 is not in the local repository and every documented way to
run this project is offline (`mvnw -o`).

Run the backend with:

    JAVA_HOME="C:/Program Files/Java/jdk-17" ./mvnw -o spring-boot:run

---

## 15. PLAN-4 §7.3 — add the maid you already have

The bootstrap problem. Almost every household in this market already has a maid,
and she will not download an app to begin a relationship that already exists — so
the first thing a new user wants to do was the one thing the product could not
represent. Everything Gasta is good at (attendance, leave, the §7.1 register)
assumed the relationship started inside it.

`managed_earner` + `add-existing-worker` / `my-added-workers` /
`my-pending-claims` / `claim-work-record`, and `add_existing_worker_screen.dart`.

### The engagement is a real Task, with a real earner

`TaskJob.EARNER_ID` is `nullable = false`, and every path Phase 4A hardened reads
`Task.earner`. Making the earner optional everywhere — so that an "unassigned"
engagement could carry attendance — would mean touching all of them to support a
case none of them think about, and each one is a chance to break leave, visits or
the register for the ordinary path.

So the engagement gets a real `UserData` row standing in for her, and every
existing query keeps working untouched. Attendance, leave and the register work
from the moment she is added, with the organiser as the only user, which is
exactly what §7.3 asks for.

### Why the placeholder does not use her phone number

The obvious design is to create the account under her number and let her
"activate" it later. It is wrong, and not subtly:

- It **reserves a phone number for a person who never asked us to**. She can then
  never sign up normally — the number is taken, by a row she has never seen,
  created by somebody else.
- It makes the claim a login problem (a disabled account with somebody else's
  number, needing surgery on the access-app library's user creation to switch
  on), rather than a data problem we fully control.

Instead the placeholder gets a **synthetic username** — `managed-<uuid>`, never a
phone number — and `enabled = false` with no authorities, so Spring Security
refuses it as a principal even if some future endpoint forgets to check. Her real
number lives on the `managed_earner` record, not on the stand-in, and stays free.

When she joins she signs up exactly like anybody else, and the claim **migrates**
the engagement — task, assignments, schedules and *every* `TaskJob`, past
included — onto the account she created herself. The months of attendance are the
thing worth claiming; they are the documented work record a domestic worker has
nowhere else.

### The two cautions in the plan, and what answers them

> *the unclaimed record must never be exposed to other users*

- **`earner-profile/{id}`** returns "Worker not found" for an unclaimed record to
  everyone except the household that added her — with **the same wording as a
  genuine miss**. "This worker exists but you may not see her" would itself
  disclose that a particular id belongs to somebody's maid.
- **Job alerts already excluded her**, and this was checked rather than assumed:
  `findAlertCandidates` requires an `earner_preference` row *and* a prior
  `task_quote` in the profession. A placeholder has neither, so no change was
  needed — and no change was made, because a redundant guard in a native query is
  a place for the two conditions to drift apart.
- **Ratings are refused outright.** She has not signed up, cannot read what is
  said about her, and cannot reply to it. A star rating on that record would
  follow her onto the platform the day she joins — written by the one party with
  an interest in the number — and she would arrive already judged. Reputation
  starts when she does.
- The `placeholder` field is `@JsonIgnore`d: it is an internal identity with no
  meaning to any client, and sending it would invite the app to treat it as a
  person.
- `my-pending-claims` deliberately returns almost nothing — the household's name,
  the kind of work, the date. Before she has claimed anything she is being told
  that somebody says it employs her; she should not also be handed that
  household's address and schedule on the strength of an unverified claim
  somebody else made about her.

> *the claim must verify the phone number*

The claim matches on the number the caller **signed in with**, so the OTP is the
verification and there is no invitation code to leak, guess or forward. The match
is re-checked inside `claim()` rather than trusted from the listing call: that was
a different request, and this one moves somebody's livelihood.

Phone numbers are normalised to the last ten digits on both sides. Households type
"+91 98765 43210", "098765 43210" and "9876543210" for the same person; sign-up
stores bare digits. A mismatch here would mean she can never claim her own
history, and would look exactly like the feature not existing (§4 rule 5).

### Deliberately smaller than posting a job

Two text fields — her name and her number — and everything else is a tap
(profession, address, pay unit, days, slot). Posting a job is a request to
strangers and needs a description, a quote type, an open period and a worker
count. This is a record of an arrangement two people are already in, and asking
for those fields would be asking somebody to describe a relationship they are
already living.

The task is created with `openToQuote = false`: somebody already has the job, and
showing it in job search would invite strangers to bid for a filled position.

The schedule is built by `OrganiserService.buildSchedules`, which was made part of
the interface for this. A second copy of the day- and date-grouping rules would
let the same arrangement be stored two ways, and only one of them matches what
`ScheduleExpansionService` expects — the exact failure the original extraction was
made to prevent.

### The invitation

Offered once, immediately after adding, as a WhatsApp message the organiser sends
themselves. **Offered, not sent.** Messaging somebody on a household's behalf,
about a record that person has not seen, is not ours to do silently.

### What was verified, and what was not

**Verified in the emulator.** Adding "Sunita" (₹6,000/month, Mon–Sat, early
morning) produced: the `managed_earner` row; a placeholder with `ENABLED = 0` and
a synthetic username; a task with `IS_OPEN_TO_QUOTE = 0`; and **13 generated
visits**. Her register then rendered the month correctly — Mon–Sat filled,
Sundays blank — for a worker who has never opened the app. That is the core
promise of §7.3 and it holds.

One defect found on screen: every chip in the form rendered full width, turning
the profession picker into a twenty-item vertical stack. Cause was a `Container`
with `alignment` set — that makes it expand to the largest size its parent allows,
which inside a `Wrap` is the whole row. Centring now comes from a min-size `Row`.

One found by the insert failing: `app_users.PHONE` is `NOT NULL`. The column
belongs to the access-app library, so it is not visible from this codebase. The
placeholder now carries its own synthetic id there — obviously not a number, so it
cannot be mistaken for one, and her real number still lives only on the record.

**Not verified: the claim.** `my-pending-claims` → `claim-work-record` and the
earner's claim banner have not been exercised. The Redis container stopped
part-way through the session, so no OTP could be issued and there was no way to
sign in as the worker — through the app or the API. The code path is written and
compiles; it has not been run.

**The test record is deliberately left in the database** rather than cleaned up,
which is a stated deviation from §8. Removing it would mean whoever finishes this
has to recreate it before they can test the one untested path. To finish: start
Redis, sign in as `9000000001`, and the claim banner should appear on "My
Accepted Tasks". To remove it afterwards:

```sql
DELETE FROM task_job WHERE TASK_ID = (SELECT TASK_ID FROM managed_earner WHERE DISPLAY_NAME='Sunita');
DELETE FROM task_assignment WHERE TASK_ID = (SELECT TASK_ID FROM managed_earner WHERE DISPLAY_NAME='Sunita');
DELETE FROM task_schedule WHERE TASK_ID = (SELECT TASK_ID FROM managed_earner WHERE DISPLAY_NAME='Sunita');
SET @p = (SELECT PLACEHOLDER_ID FROM managed_earner WHERE DISPLAY_NAME='Sunita');
SET @t = (SELECT TASK_ID FROM managed_earner WHERE DISPLAY_NAME='Sunita');
DELETE FROM managed_earner WHERE DISPLAY_NAME='Sunita';
DELETE FROM task WHERE ID = @t;
DELETE FROM app_users WHERE ID = @p;
```

### Outstanding

- `my-added-workers` has no screen. The household can add a worker and use her
  register, but cannot list everyone they have added or re-send an invitation.
- If she never claims it, nothing ever tells the household she has not — worth a
  gentle nudge later, but not one that pesters.

---

## 16. §7.5 completed, and §7.7

### The other half of §7.5 — answering a rate change

`propose-terms` had a caller and `respond-terms` did not, so §7.5's "Raise the
rate" could offer a number nobody could accept. That is worse than not offering
it: it writes a proposal, notifies the other person, and strands both of them.

`PendingTermsDto` now rides on the register payload — to **both** sides, unlike
`rateGuidance`, which is a nudge for the payer. The box takes two shapes for the
two positions: whoever proposed can only wait, the other has Accept and Decline.
It sits **above** the rate nudge and suppresses it, because suggesting a second
raise while one is unanswered puts two numbers on the table at once.

**Verified end to end**, earner side: the box rendered "Priyank Tomer asked for
₹700 / day — Now ₹600 / day", accepting it flipped the request to `ACCEPTED` and
moved the task's rate. Test data restored afterwards.

### §7.7 — "Has anyone near me used her?"

`QuoteViewDto.householdsNearby` / `nearbyArea`, filled by
`TaskAssignmentRepo.countHouseholdsInLocality`, drawn under the reputation chips
on the quote card.

**At the decision point, not on a profile.** The quote list is where an organiser
picks between strangers, and it already carries the T7.4 reputation for exactly
that reason. A profile screen somebody has to think to visit would have been more
code and less use — and the profile endpoints still have no caller anyway (§13).

**A count, never names.** Naming the other households would be a privacy breach
and would invite people to go and ask them. The viewer is excluded, because "1
household near you" meaning *yourself* is worse than saying nothing. Ended
assignments count: somebody who worked in the village for two years and stopped is
still evidence, and dropping them would make an experienced worker look new.

Matched on `ADDRESS_LINE2` — the locality, "Dharampur Bhoja" — not `CITY`, which
here is the whole cluster ("Pundri Kalan") and would count households nobody in
the village would recognise. The locality comes from the **task's** address, not
the organiser's profile: somebody arranging help for a parent in another village
wants to know who is trusted *there*.

Two things worth noting in the implementation:

- The per-earner cache is keyed on **earner and locality**, not earner alone. The
  received-quotes list spans several tasks, so the same worker can appear against
  two villages, and caching on the earner would answer the second with the first
  one's count — quietly wrong, on the one screen where the number is meant to be
  trusted.
- `QuoteViewDto`'s `@AllArgsConstructor` grew again (PLAN-4 §4 rule 8 — the second
  time on this class). The explicit legacy constructor was widened rather than
  letting call sites break.

**Verified at the query level, not in the UI.** The count is correct — 1 household
in Dharampur Bhoja when viewed by an outsider, 0 when viewed by the household that
did the hiring, self correctly excluded. It cannot be shown on screen with the
current fixture because there is only **one** organiser in the database, so every
count an organiser can see is legitimately zero and the card correctly draws
nothing. Seeing it requires a second household; that is a fixture gap, not a code
one.

---

## 17. §F-1–F-5 / §6.1 — design system adoption, in progress

Fifteen screens, ~11,500 lines. **2 done, 13 to go.** Started deliberately with
the shared file rather than the highest-traffic one.

### Order, and why

`visit_action_sheet.dart` first. It is not on the outstanding list because of its
own traffic — it is 385 lines — but every dialog in it is shared by
`worksheet_screen`, `earner_tasks_screen` and `task_visits_screen`, the three
busiest screens in the product. One pass fixes the same controls in all three,
and leaves less in each when their turn comes.

Then `received_quotes_screen`, small and self-contained, to establish the card
pattern before touching the 1,000-plus-line screens. Starting with
`worksheet_screen` (1,967 lines) would have meant learning the pattern on the
riskiest file in the set, and §F is where the login regression happened.

### `visit_action_sheet.dart`

Beyond colours and sizes, two things that were actually broken:

- **Every confirm button was 52dp with its own colour and radius.** They are now
  `AppButton`, which is 48dp minimum and one shape. The start-code sheet, the
  date picker, the reason dialog and the rating dialog each had their own.
- **Every dialog laid its actions out in a Row**, which overflows at 1.6x system
  font scale (§F-5, DESIGN-RULES §6). They now stack, as `confirmDestructive`
  already did. **Verified at 1.6x in the emulator**: "Go back" and "Yes, leave"
  stack cleanly where they would previously have collided.

`confirmColor` (a raw `Color`) became `confirmKind` (an `AppButtonKind`) on both
`showReasonDialog` and `showDateMultiSelectSheet`, and the four call sites were
updated. One behaviour change worth stating: "I have to go" (abandoning a visit
part-way) previously had an orange confirm and now gets the danger default, which
is what it is.

Two deliberate exceptions to "everything is an AppButton", both commented in
place: the **call button** stays green and the **Reject** button stays outlined
red. `AppButton` has three kinds and neither of those is one of them; both keep
AppButton's height and radius so they still read as the same family. Inventing a
fourth kind for two controls would have been the worse trade.

### `received_quotes_screen.dart`

Five hand-rolled `width * 0.0xx` sizes removed — none of which were shared with
the sibling screen showing the same quotes. The price keeps a bespoke size,
commented: it is deliberately larger than any named style because it is the
number the card exists to communicate.

**Reject and Accept were a Row of two Expandeds** — each half of a 720px screen,
shrinking further at every font scale, on the two most consequential taps on the
screen. Now stacked, full width, 48dp, Accept last as the primary action
(DESIGN-RULES §3).

### A comment that disagreed with its code, caught in the same session

Twice, in code I had just written: the `confirmKind` doc on
`showDateMultiSelectSheet` said danger was the default when the code said
primary, and the stacked-button comment in `received_quotes_screen` claimed
Accept was "the safer answer" when the real reason is that it is the primary
action. Both corrected. PLAN-4 §4 rule 4 says this has happened four times here;
it is five and six now, and both were mine.

### All 15 screens converted — analyzer clean

`visit_action_sheet` · `received_quotes_screen` · `quotes_for_task_screen` ·
`doorstep_services_screen` · `address_screen` · `provider_orders_screen` ·
`new_address_screen_2` · `search_screen` · `user_account_screen` ·
`task_visits_screen` · `earner_tasks_screen` · `become_provider_screen` ·
`new_task_page` · `laundry_booking_screen` · `worksheet_screen`

`flutter analyze` reports **no issues** across `lib/`. Zero `GoogleFonts.*` calls
remain in any of the fifteen — the only matches left are the comments recording
what each one used to be.

**Order, and why.** `visit_action_sheet` first: it is only 385 lines, but every
dialog in it is shared by the three busiest screens, so one pass fixed the same
controls in all of them. Then the small self-contained screens, to settle the
card and dialog patterns. `worksheet_screen` (1,967 lines) last, deliberately —
starting there would have meant learning the pattern on the riskiest file in the
set, and §F is where the login regression happened.

**`ThemeData` was never touched** (rule 7). The login screen was checked
unchanged after the first batch.

#### What was actually broken, not merely inconsistent

- **Eleven Rows of two half-width buttons**, every one on a consequential tap,
  all of which collide or shrink at 1.6× font scale: Reject/Accept on both quote
  screens, the doorstep "can you still do this pickup?" Yes/No (an unanswered
  prompt reassigns the order), both `address_screen` confirms, the logout
  confirm, the finish-engagement confirm, the provider registration Back/Submit,
  the laundry Back/Continue, and the posting wizard's Back/Next. All now stack
  full-width at 48dp with the primary last (DESIGN-RULES §3).
- **A `_statusChip` duplicated byte-for-byte** across the two screens that show
  the *same quotes from opposite sides* — four labels, eight hex colours, twice.
  Extracted to `QuoteStatusChip`.
- **The brand wordmark face on three screen titles.** tokens.dart says the
  decorative face "is reserved for the brand wordmark" and names Dashboard,
  Profile and Earning Zone as the offenders. `search_screen`,
  `user_account_screen` and `worksheet_screen` were all still calling
  `GoogleFonts.sofadiOne` directly. Profile visibly stops looking like a
  different app.
- **A raw database id on screen.** `search_screen` printed "ID: 42" beside every
  result — the primary key, on every row, in a product whose users may not read
  at all. Removed; the id is still carried for the tap.
- **A bespoke error state showing raw exception text** —
  "Failed to fetch data from API: SocketException…". Now `buildErrorRetry`.
- **Five private accent palettes** — doorstep's indigo, provider-orders' amber
  and its own blue, address's `blue.shade50`, become-provider's indigo,
  laundry's indigo — plus `user_account_screen` sizing *fonts, radii and
  padding* off `screenWidth * 0.0xx` with no clamp at all.

#### Deliberate exceptions, each commented in place

`AppButton` has three kinds and some controls are none of them. These keep its
height (48dp) and radius so they still read as the same family:

- the **call button** stays green — calling is the one action that leaves the app;
- **Reject** stays outlined red — a legitimate everyday choice, not a
  destructive confirmation, and filled-red under filled-blue makes the card
  shout twice;
- **"They haven't come"** stays outlined warning — neither primary nor
  destructive;
- the **start code** keeps its 34px wide-tracked numerals — it is read aloud
  across a doorway, and the numeral *is* the interface;
- the **quote price** keeps a bespoke size larger than any named style — it is
  the number the card exists to communicate;
- the earner's **"Tell someone" / "I feel unsafe"** pair stays a Row. Everywhere
  else a two-button Row became a stack; this one must stay findable *by
  position* by somebody standing in a stranger's house, and stacking would push
  it below the fold on a card that already carries four actions.

#### Comments that disagreed with their code — three, all mine, all caught

The `confirmKind` doc on `showDateMultiSelectSheet` said danger was the default
when the code said primary; the stacked-button note in `received_quotes_screen`
claimed Accept was "the safer answer" when the real reason is that it is the
primary action; and a first attempt at the provider Back/Submit pair replaced a
`Row` with a `Column` while leaving `Expanded` children under it, which would
have thrown at runtime. PLAN-4 §4 rule 4 says this had happened four times here.
It is seven now.

#### Verification

**Verified on the emulator at 720×1280**, after the AVD was given 4 GB (the
earlier 2 GB build was being reaped by `lowmemorykiller` seconds after launch —
confirmed as memory, not code: no Dart exception, no FATAL, and unrelated
processes were reaped in the same sweep):

`visit_action_sheet` (dialogs stacked at **1.6× font scale**) ·
`received_quotes_screen` · `doorstep_services_screen` · `address_screen` ·
`new_address_screen_2` · `search_screen` · `user_account_screen` (including the
logout dialog) · `task_visits_screen` · `earner_tasks_screen` ·
`become_provider_screen` · `new_task_page` · `laundry_booking_screen` ·
`worksheet_screen`.

The login screen and the whole first-run flow (language → mode → OTP) were
walked from a clean install and are unchanged — `ThemeData` was never touched.

**Not seen on screen:** `quotes_for_task_screen` and `provider_orders_screen`.
Both need fixture data that does not exist — a *pending* quote and a doorstep
order assigned to the logged-in provider. Their cards share the converted code
paths with `received_quotes_screen` and the verified AppButton family, but
neither has been looked at, so they stay listed here rather than claimed.

#### Two defects caught during that verification pass

- **`new_task_page` had the primary action above the secondary**, while the
  comment beside it said "primary last". DESIGN-RULES §3 puts the primary at the
  bottom. Fixed — Back now sits above Next.
- **`become_provider_screen` still had one indigo `ElevatedButton`** ("Use My
  Location") that the first pass missed, with a hand-rolled
  `CircularProgressIndicator` for its busy state. Now `AppButton.primary` with
  its own `busy` flag.

---

## 18. §6.2 / T6.12 — `ApiState` adoption

`ApiState`/`fetchInto` existed with **one** caller. Six now:
`posted_tasks_screen` (pre-existing), `received_quotes_screen`,
`quotes_for_task_screen`, `earner_quotations_screen`,
`my_doorstep_orders_screen`, `provider_orders_screen`.

Each drops a `List` + `isLoading` + `_hasError` triple — three booleans
describing eight states of which four are real, with the impossible ones
reachable: a spinner over an error, a blank list with no explanation. The list
becomes a getter over `_state.data`, so there is no second copy to fall out of
step.

Two things came free with `fetchInto` that none of them had:

- **An offline fallback.** Each now passes a `cacheKey`, so a failed fetch shows
  the last good contents behind a `SavedInfoBanner` instead of an error. On this
  network that is the common case, and old data beats nothing.
- **Per-filter caching.** The filtered screens key on the active filter, so
  switching tabs offline shows *that* tab's last contents rather than the
  previous tab's (F-6.9).

One deliberate non-conversion inside a converted screen:
`quotes_for_task_screen.isActioning` stays a plain bool. It guards the
accept/reject buttons while one is in flight, which is a different question from
how the list loaded, and folding it into `ApiState` would conflate them.

`provider_orders_screen` also gained a real fix on the way: "Available" with no
registered profession used to set `isLoading = false` with an empty list, which
is indistinguishable from a successful empty response. It is now an explicit
`ApiState.ready([])` — an empty list, not an error, because the provider has
done nothing wrong.

### Not converted — 10 screens, and why

These are not mechanical, and a regex pass over stateful screens is how you get
a silent regression on something nobody re-tested:

| Screen | Why it needs its own change |
|---|---|
| `earner_tasks_screen` | Two lists (visits *or* tasks) behind one flag pair, chosen by filter. Needs a sum type or two `ApiState`s, which is a design decision. |
| `worksheet_screen` | 1,900 lines, several fetches sharing one flag pair. |
| `home_screen`, `category_screen` | Payload is a map of catalogue sections, not a list. |
| `search_screen` | Caches the **raw response string** deliberately; `fetchInto` caches the parsed payload. Converting means rewriting how it searches. |
| `task_visits_screen` | One list plus two fire-and-forget side fetches (attendance, substitute offer) that intentionally fail silently. |
| `doorstep_order_detail_screen` | Single object, not a list — `ApiState<T>` fits, but the screen also mutates it in place. |
| `notifications_screen` | Paginated with `hasMore`; `fetchInto` has no paging concept. |
| `work_hours_screen`, `address_screen`, `doorstep_services_screen` | Small, and their flags also gate save/submit state, not just the load. |

The six done are the ones where the conversion is a strict simplification. The
rest each need a decision first; taking them on faith would trade a real bug
class for a different one.

---

## 19. §6.5 reliability signals, and §7.8 the trial check-in

### §6.5 — the missing no-show count

`UserReputation.visitsMissed`, incremented from the overnight sweep — the only
place a visit becomes MISSED without a human deciding it. A rejected or disputed
visit is somebody's judgement and is deliberately not counted here.

Shown as **"4 missed of 210"**, never as a rate. A rate is a score, and a score
invites a threshold; a threshold on this market's supply side ends somebody's
ability to earn after one bad fortnight. The chip is hidden below three misses
for the same reason the "left early" chip is hidden below two.

The increment is wrapped in try/catch: a reputation update must never fail the
sweep, because the visit still has to be closed out (§4 rule 4).

**Lateness is deliberately not built.** It needs a machine-readable start time
per visit, and `Slot` carries only a display string — "06:00 AM - 07:30 AM".
Parsing that back into a time to decide whether somebody was late, and then
holding it against their ability to earn, is not a thing to build on a string
that exists to be a label. It needs a real start time on the enum first.

### §7.8 — the day-three trial check-in

`Task.trialCheckInSentAt` plus `LifecycleSweepService.sendTrialCheckIns()`,
riding the **existing** daily reminder cron rather than one of its own — one
message a day does not deserve a schedule that somebody has to remember exists.
Its own try/finally, so a failure here cannot take the reminder sweep down with
it.

Day three is measured from the **first visit**, not from when the quote was
accepted: a maid hired on Sunday to start on Wednesday has not had a trial yet,
and asking her how it is going would be nonsense.

**Each side is messaged separately**, which is the whole point. The organiser
will not say "she arrives too early" in front of her, and she will not say "they
keep adding rooms" in front of them. A shared thread gets polite answers and the
engagement ends anyway.

The task is stamped whether or not a message went out — a trial that has already
run past its window drops out permanently instead of being reconsidered nightly.

`trialDays` had been in the data since Phase 4 with nothing reading it. It has a
reader now.

### The latent bug the test caught

Verified by overriding `gasta.reminder.cron` to every 30 seconds
(`GASTA_REMINDER_CRON` as an env var — passing it as a `-D` argument gets split
on spaces and Spring reports "Cron expression must consist of 6 fields").

The first run failed:

```
JpaSystemException: ... [Incorrect DATE value: '169087565-03-15']
```

`LocalDate.MIN` does not fit a MySQL DATE. I had copied the idiom —
`findByTask_IdAndOccurrenceDateGreaterThanEqual(taskId, LocalDate.MIN)` — from
`OccurrenceServiceImpl.isWithinTrial`, **which has the same bug**. That method
is the trial-window guard used when somebody exits an engagement early, so it
threw for every task that actually had a trial set; it had simply never been
reached, because nothing in the app sets `trialDays`.

Both call sites now use `findFirstByTask_IdOrderByOccurrenceDateAsc` — one row,
served by the existing `(TASK_ID, OCCURRENCE_DATE)` index, and no sentinel date.
Fetching every visit of a task to take the minimum in memory was the wrong shape
regardless.

Second run: `Trial check-in sweep messaged 1 engagement(s)`, both parties
notified separately, task stamped. Test data restored and the cron put back.

---

## 20. §7.4, the advances ledger, and the orphan triage

### §7.4 — the worker's own view

`GET /authenticated/my-earnings` + `my_earnings_screen.dart`, reached from
Profile above "My working hours" — "what will I have this month" is what a
worker opens the app for on a day with nothing booked.

**The endpoint takes no user id, deliberately.** One worker's earnings are
nobody else's business, and an endpoint that takes an id is an endpoint somebody
eventually calls with a different one.

Two halves:

- **This month**, split into *earned so far* and *still to come*. Running them
  together would make a promise the month has not kept. The wording never says
  "paid" — Gasta is not in the payment path and cannot know whether cash changed
  hands, only that the work was done.
- **The work record** — "Maid, Agricultural Machinery for 1 household since July
  2026. 3 visits completed. Rated 5.0 by 1 customer." Shareable as plain text so
  it survives being forwarded on WhatsApp and read out at a bank counter.
  **No household is named:** naming the families she has worked for turns her own
  record into a disclosure about them, and she cannot consent on their behalf.

The visit count and rating come from the reputation row rather than being
recounted here — a second answer that can disagree with the first is worse than
one.

### The advances ledger — a gap I created

§7.2 shipped `add-advance` wired and `get-advances` / `respond-advance` not. So
an advance could be recorded, the other side was notified about it, and there
was **no way for them to agree or object** — the same "written but unreachable"
defect §6.7 is about, introduced by me while fixing that class of defect.

Now a sheet off the Advance card: every entry, its state, and the two answers
for whoever owes one. Verified end to end — an unanswered ₹3,000 advance
appeared as "Waiting for your answer", agreeing it stamped both sides.

**A real serialisation bug found on the way.** `CashAdvance.givenOn` is a
`LocalDate` with no `@JsonFormat`, so Jackson sent `[2026,8,10]` and the app
threw `type 'List<dynamic>' is not a subtype of type 'String?'` the moment the
ledger opened. Every other date on the entity already carried the annotation;
this was the only bare one. Fixed at the entity, which is where it belongs —
patching the parser would have left the wire format wrong for every future
consumer.

### Orphan endpoints — triage, not a wiring spree

The audit list is down from 19 to 19 by count, but the composition changed: the
statement, terms, register, advance, claim, no-show and earnings endpoints are
all wired now, and this pass added new ones. What is left, and what I would
actually do with each:

| Orphan | Recommendation |
|---|---|
| `getAdvances`, `respondAdvance` | **Wired this pass.** |
| `unreadNotificationCount` | **Wired this pass.** The badge counted only the loaded page — a real defect, not just an unused route. |
| `termsHistory` | **Wired this pass**, into the register, with a DTO it turned out to need first. |
| `confirmArrival` | **Consider removing** — revised after reading it. `arrived=true` changes nothing (an acknowledgement to stop a prompt that is not built), and `arrived=false` marks the visit `MISSED`, which is what §7.9's `report-no-show` already does from the same screen, and what the overnight sweep does unattended. Three ways to reach one state is how they drift. |
| `myLeaves` | **Wire it** — an earner can book leave and cannot then see what she booked. Cheapest of the remaining ones. |
| `earnerProfile`, `organiserProfile`, `setEarnerConnection`, `myFavourites` | **One screen would reach all four.** T7.1/T7.5/T7.6 are marked ✅ and none of it is reachable. Worth a session of its own. |
| `updateSchedule` | **Wire it** — the standing schedule cannot be changed after posting, which is a real gap in a product about ongoing engagements. |
| `myAddedWorkers` | **Wire it** — §7.3's organiser-side list of workers they added. |
| `getStatements` | **Consider removing.** The register already shows the current month's statement, and month arrows reach the rest. A separate history list would duplicate it. |
| `pauseTask` | **Consider removing.** `skip-visits` already pauses by date range and is wired; two ways to pause is how they drift. |
| `doorstepUpdateRates` | **Wire it** — a provider cannot change their prices after registering. |
| `setIdVerified`, `setProfessionEnabled`, `lookupUser`, `auditLog` | **Leave.** These are the ops console's, and the ops queue screen is deliberately a thin slice. Not user-facing. |

Two of these — `getStatements` and `pauseTask` — are candidates for *deletion*
rather than wiring, which the product owner explicitly allowed. Deleting a
duplicate route is a smaller change than building a screen nobody needs.

### The unread badge was counting the wrong thing

`get-unread-notification-count` had no caller, and the notifications screen
computed "N unread" from `notifications.where((n) => !n.read).length` — the rows
**currently loaded**. The list pages 30 at a time (T11.1), so anyone with more
than 30 unread was told "30 unread", and the number sat still as they read.

Now the server's count, with the local count as the fallback while it is in
flight — a badge that flashes zero and then corrects itself is worse than one
that appears a beat late. Marking one read decrements it (only if that row was
actually unread, or double-tapping counts it down twice); "Read all" sets it to
zero rather than to the loaded count, because the server marked the unloaded
pages too.

The *other* badge, on the job sheet, was already correct — it comes from
`DashboardDto.unreadNotifications`, which is a `countByUser_IdAndRead`. Worth
saying because the audit line originally blamed that one.

### Dates: a class of bug, not an incident

Fixing `CashAdvance.givenOn` raised the obvious question — how many other
entities have a bare `LocalDate`? Eighteen fields across ten entities. Checking
whether any of them actually reach the app: **none do.** Every endpoint that
carries those fields projects through a DTO whose type is already `String`
(`VisitDto.occurrenceDate`, `NearbyJobDto.substituteFrom`), and no endpoint
returns those entities raw. The eighteen are latent, not live.

So rather than annotate eighteen fields nobody reads, one line sets the floor:

```properties
spring.jackson.serialization.write-dates-as-timestamps=false
```

Explicit `@JsonFormat` still wins where it exists, so nothing already on the wire
changes shape. What it buys is that the *next* date field added to an entity that
does get serialised goes out as `"2026-08-10"` instead of `[2026,8,10]` —
because that bug is only ever caught at runtime, on whichever screen happens to
read the field, which is exactly how this one was found.

### `get-terms-history` was leaking both parties

Wiring it exposed a real problem: it returned `TermsChangeRequest` entities
straight from the repository, and those carry `@ManyToOne` references to `Task`
and to `UserData` — **the other party's phone number and home address**, on an
endpoint whose screen shows a name and an amount.

Harmless only while nothing called it. Adding the caller is what would have
turned a latent leak into a live one, so `TermsHistoryDto` lands in the same
change: request id, the two amounts, the note, the status code, a name, and the
two dates. The rule this follows — *a projection is part of wiring an endpoint,
not a later tidy-up* — is worth keeping, because the audit found eleven more
endpoints still waiting for callers.

Reached from the pay card as "What we agreed before". The engagements this
product is built for run for years and the wage moves inside them; §7.5 let
either side propose a change and §7.1 let the other answer, but once answered the
exchange vanished — leaving "we agreed ₹600" / "no, ₹650" one level up from the
argument the register exists to end. Declined and pending rows are shown too:
somebody asked, and that is part of the record.

### One more gate that hid history

The ledger button was written as `if (owed != 0)`. So the moment an advance was
fully repaid, every row of it disappeared — and "what did I pay back, and when"
is precisely the question a settled balance invites. A disputed row would have
gone the same way. The button is now unconditional and the sheet has an empty
state, which is a smaller thing to reason about than the condition was.

### Two defects in §7.4, both found by looking at it on real data

The screen compiled, rendered, and was wrong in two ways that only a populated
database shows.

**"Still to come: 67 days, ₹35,100" included 31 days that had already gone.**
`upcomingDays` counted every `SCHEDULED` row inside the month. But the MISSED
sweep lags, so a visit on 3 August that nobody marked is still `SCHEDULED` on
the 17th — and it was being reported to the worker as future income. Task 9
alone had 16 past-dated scheduled rows.

Of every place to be optimistic, this is the worst one. The person reading it is
deciding whether she can afford something this month.

Fixed by splitting on the date rather than the status alone: only strictly
future rows are "still to come". Past-dated scheduled rows go into a third
count, `unrecordedDays`, which is deliberately in **neither** total —

- counting them as earned claims work that may not have happened;
- counting them as upcoming promises a day that has already gone.

Shown anyway ("4 day(s) gone by were never marked... open the job to settle
them"), because dropping them silently is how somebody ends up short without
ever knowing why. The per-job lines carry the same count so it is clear *which*
household has days outstanding.

**The headline was the merged figure.** The card read "₹35,100" in the largest
type on the screen, directly above "Earned so far ₹0". Three lines below it sat
this comment, which I had written myself:

> // The split is the point. "Earned so far" is money owed; "still to come" is
> // not, and running them together would make a promise the month has not kept

The comment was right and the code did the opposite of it. The headline is now
`confirmedAmount` — money actually earned — and the projection moved down to a
caption in plain words: "If every day goes as planned, the month comes to
₹35,100." Same information, no longer the thing somebody remembers and repeats.

Worth naming the pattern, because it is the second time in this plan: I wrote
the reasoning, then wrote code that contradicted it, and the analyzer had
nothing to say about either. **The comment is the specification. When they
disagree, assume the code is wrong.**

## 21. §6.2 / T6.12 finished — the remaining ten screens

All ten are done: **nine converted, one deliberately not**, and the reason for
the one lives in its own code rather than only here.

The §18 table said these each "need a decision rather than a mechanical edit".
That was right, but two of the stated reasons turned out to be wrong once the
code was actually read, and one of the screens was hiding a live bug.

| Screen | What it actually needed |
|---|---|
| `home_screen` | Three states, not one. Not "a map payload" — three independent list fetches. |
| `category_screen` | Two states. Also not a map payload: two independent list fetches sharing one error flag. |
| `work_hours_screen`, `address_screen`, `doorstep_services_screen` | Nothing special — the load flags were already separate from the save flag. |
| `task_visits_screen` | One state for the list; the two side fetches stay fire-and-forget. |
| `doorstep_order_detail_screen` | `ApiState<PickupDropOrder>` — generic already covers a single object. |
| `notifications_screen` | First page in `ApiState`, `_loadMore` still hand-rolled. |
| `earner_tasks_screen` | Two states, one per list. |
| `worksheet_screen` | Converted; it had already written `fetchInto` by hand. |
| `search_screen` | **Not converted** — see below. |

### The bug under `category_screen` and `home_screen`

Neither was really about map payloads. Both go through `CategoryService`, and
**every callback in that service takes a `bool` that was passed as `false` on
all nine call sites — success and failure alike.**

So a dropped connection produced an empty list that looked exactly like an empty
catalogue: headings drawn over nothing, no message, no retry. PLAN-4 rule 5,
silent absence, in the one place a new user meets the product first.

Six screens took that parameter and named it `boolVal`. Not one read it, which
is what made the fix cheap — nothing depended on the old meaning, so the
parameter could simply be given the meaning its shape implies. It is now
`failed`, set `true` on every error path.

**Three screens then had to be fixed, because they were assigning it to a
loading flag** — `areCategoriesLoading = boolVal`, `isProfessionLoading =
boolVal`. Those lines only ever read as "stop loading" because the value was a
constant `false`. Under the corrected meaning they would have spun forever on a
failed request. One in `home_screen`, two in `worksheet_screen`.

That is the argument for the whole exercise in one example: a boolean whose
meaning nobody could state, wired into a flag it had no business driving, doing
the right thing purely by accident.

### Other defects found while converting

- **`address_screen` could hang.** Its success branch was inside
  `if (responseData.containsKey('payload'))` with no `else`, so a 200 without
  that key left `isLoading` true — a spinner over nothing, no retry, forever.
  Not expressible through `fetchInto`, which always resolves to one of four
  states.
- **`worksheet_screen` showed users raw exception text.** `showSnackBar(Text(
  "Request failed: $e"))` — a `SocketException` in front of an audience that may
  read nothing at all. The same mistake had already been found and removed on
  the search screen; this was the second copy.
- **`search_screen` was holding a loaded gun.** `_errorMessage` still carried
  `'Failed to fetch data from API: $e'` even though the screen had stopped
  rendering it, waiting for somebody to put it back in a `Text`. It is a plain
  `bool` now.

### Why `search_screen` stays as it is

**`fetchInto` is network-first with a cache fallback. `search_screen` is
cache-first** — it returns the saved catalogue without touching the network, and
fetches only when nothing is saved or the catalogue fingerprint moved.

That is the right policy for this payload: the whole searchable profession list,
which barely changes, on the worst connection in the product. Converting would
have traded a correct caching policy for a uniform one, which is not a
simplification — it is a regression wearing consistency as a disguise. The
reasoning now sits on `_loadData` where the next person will meet it.

### What the conversions bought

Nine screens each dropped a data field plus two booleans — three flags spelling
eight states of which four are real — for one value with four. Seven gained an
**offline fallback** they did not have, which on this network is the common
case, and `earner_tasks_screen` gained **per-filter caching** so switching tabs
offline shows that tab's rows rather than the previous tab's.

Two deliberate non-conversions inside converted screens, both following the
`quotes_for_task_screen.isActioning` precedent: `work_hours_screen._selected`
(what the user has ticked is not how the screen loaded) and
`task_visits_screen`'s attendance and substitute-offer fetches (fire-and-forget
extras that must stay silent on failure; a state object would invite somebody to
start rendering their errors).

One more decision worth recording: **`work_hours_screen` passes no `cacheKey`.**
Every other converted screen caches, but this one is a settings screen whose
save posts the *whole* selection — seeding it from a stale copy would let the app
overwrite the server with what this phone last saw. A retry button is the honest
answer when we cannot say what the current setting is.

### Verified offline, and what that turned up

Emulator, network disabled with `svc wifi disable` / `svc data disable`. Pulling
to refresh the notifications list produced **"Showing saved information from
1 min ago. Check your connection."** over the full list of alerts. Before the
conversion the same action replaced every notification with a full-page error.

Two things came out of doing it properly rather than trusting the code.

**1. A cold start with no signal never reaches any of this.** Force-stopping and
relaunching the app offline stops at the splash — "Could not connect to our
Servers, please check your internet connection", with a Retry and no way past.
Every per-screen cache added here sits behind that gate.

So the offline work helps the case where a session is already running and the
signal drops — walking out of range mid-shift, which is a real and common case
in this market. It does **not** help the other real case: opening the app
somewhere with no signal to check what time you are expected tomorrow. The data
is on the device and the app refuses to show it.

Not fixed here — the gate is in the startup/auth path and is out of scope for a
state-management pass — but it is the single change that would make all of this
worth twice as much, and it should be its own item.

**2. A word broken mid-syllable in the jobs filter.** The left pane is 30% of a
720px screen, and `ListTile` spends 32px of it on padding, which left
"Profession" rendering as "Professi / on" — and it would get worse with a count
("Profession (2)"). DESIGN-RULES §6, in front of an audience that may be
sounding the word out.

Fixed with `FittedBox(fit: scaleDown)` and tighter padding rather than an
ellipsis: shrinking keeps the whole word, truncating would give "Professi…",
which is the same defect with a tidier edge.

## 22. §6.3 — Phase 11 remainder (T11.4, T11.5, T11.10)

### T11.4 observability — request ids, logging, health

A failure was a stack trace in a console with no way to tie it to the person who
reported it. Three pieces, none of which needed a new dependency:

**`RequestIdFilter`.** Every request gets an id — the caller's `X-Request-Id` if
it sent one, otherwise a generated short uuid. It goes into the SLF4J MDC, into
every log line written while serving that request, and back out in the response
header. That turns "it did not work this morning" into a grep.

The inbound header is trusted but **sanitised**: capped at 36 characters and
stripped to letters, digits, dash and underscore. It is attacker-controlled text
that gets written into a log file and echoed in a header, and an unbounded
string with a newline in it can forge log entries. Verified:

```
X-Request-Id: abc<TAB>INFO fake-entry-injected   →   abcINFOfake-entry-injected
80 × "A"                                          →   36 × "A"
```

The MDC is cleared in a `finally`. Tomcat pools threads, and an id left behind
reappears on an unrelated request later — worse than no id, because it is
confidently wrong.

**`HealthController`** at `/api/v1/yapan/common/health`, on the public path
deliberately: a health check a load balancer cannot reach without credentials is
not a health check. It does a real round trip — `connection.isValid(2)`, not
`dataSource != null`, because the pool hands out a connection object whether or
not MySQL is reachable. It answers `UP`/`DOWN` per dependency and **never says
why**; an unauthenticated endpoint that returns the JDBC URL or a connection
exception is a free map of the deployment. The reason goes to the log, which
carries the request id.

Redis is reported separately and does not by itself make the instance `DOWN`:
losing it stops new logins but does not stop serving everyone already signed in.

**Not Spring Boot Actuator**, which would have been the normal answer. The only
artifact cached on this machine is 3.1.2 against a 3.3.3 application and the
build runs offline, so adding it would either fail to resolve or quietly mix
versions. Stated in the class comment so the next person swaps it in rather than
rediscovering the reason.

Verified end to end:

```
POST …/login-verify   X-Request-Id: TRACEME99
WARN [TRACEME99] c.a.yapan.config.ApiExceptionHandler : Unreadable request body…
```

### T11.5 config and secrets

The database password was written out **twice** — once for Flyway, once for the
application datasource — under a comment asking whoever edits them to "keep them
in step". That is a defect waiting for a busy afternoon.

Now one set of `gasta.db.*` / `gasta.redis.*` properties, referenced by both,
each `${ENV_VAR:local-default}`. A fresh checkout still runs with no setup; any
environment can override without touching the file.

**`application-prod.properties`** removes the defaults. Every value is `${VAR}`
with no fallback **on purpose**: a missing variable fails the context at startup
naming what is missing, which beats an instance that starts happily and connects
to a developer's database. It also turns off wildcard CORS, forbids stack traces
and messages in error responses, and drops `logging.level.org.hibernate.SQL` —
the SQL logger prints bound parameters, and bound parameters here include phone
numbers and OTP hashes.

One thing it sets is **deliberately not yet satisfiable**: `ddl-auto=validate`.
Production should not let Hibernate ALTER a live table because somebody added a
field. But the plan already records that the switch needs every existing table's
DDL captured as migrations first, so a prod start today would fail validation.
That is the honest state of affairs — it says the schema is not reproducible,
and it is not. Noted in the file rather than softened to `update` to make it
appear finished.

### T11.10 retention

**What is *not* deleted matters more than what is.** Written into
`RetentionService` so it is decided rather than assumed:

- **`admin_audit_log`** — exempt by decision. An audit row exists to outlive the
  convenience of the people it describes.
- **`task_job` (occurrences)** — these *are* the work record. The register reads
  past months out of them and §7.4 counts them; deleting a year-old visit deletes
  the proof somebody worked that day, for a worker whose entire case for a loan
  is that record.
- **`cash_advance`, `terms_change_request`** — money and what was agreed. Both
  exist to settle arguments that surface months later.

Which leaves notifications: high volume, machine-written, worthless once read and
old. Read ones go at 90 days. **Unread ones are kept for a year**, which is the
part worth arguing about: unread does not mean unwanted. On these phones it
usually means the person has not opened the app in a while, and deleting the
alert saying a job was offered — or that an advance was recorded — because they
were slow to look is precisely the wrong thing to do to the user with the least
connectivity.

Batched at 500 rows per delete rather than one `DELETE WHERE created_date < ?`:
the first run after this ships has the whole backlog to get through, and a purge
at 03:10 must not hold locks into the morning. Capped at 20,000 per run so a bad
cutoff cannot empty the table in one night unnoticed.

Verified by seeding four rows and predicting the outcome before running it:

| Row | Age | Read | Expected | Actual |
|---|---|---|---|---|
| old-read | 7 months | yes | delete | deleted |
| ancient-unread | 2 years | no | delete | deleted |
| **old-unread** | **7 months** | **no** | **keep** | **kept** |
| recent-read | 3 days | yes | keep | kept |

The third row is the one that matters — it is the protection working.

One bug caught before it shipped: the batch loop originally called a
`@Transactional` method on `this`, which self-invokes and bypasses the Spring
proxy, so the annotation would have done nothing while looking like it did
something. `deleteAllByIdInBatch` is already transactional per call in
`SimpleJpaRepository`, so the wrapper was deleted rather than fixed.

## 23. §6.6 — the first non-laundry doorstep booking

The plan's line was: "The model, catalog, API and copy are done. A non-laundry
service has never been booked end to end because no provider is registered
against one of the three new professions. Register one, book it, watch it
through to delivery."

Registering one found **five defects**, one of which made the thing impossible.

### The one that made it impossible

`doorstep_service_rate.SERVICE_TYPE` is the legacy `LaundryService` column.
`saveRates` sets it to null for any variant that has no laundry equivalent —
which is every variant of every non-laundry profession:

```java
try { rate.setServiceType(LaundryService.valueOf(variant.getCode())); }
catch (IllegalArgumentException ignored) { rate.setServiceType(null); }
```

The entity was updated to match, with a comment reading "Nullable now". **The
column was not.** It was created `NOT NULL` before variants existed, and
`ddl-auto=update` only ever *adds* — it will create a column but never relax a
constraint on one. So the entity said nullable, MySQL said `NOT NULL`, and every
insert failed.

What made it hard to see is that the visible error names the wrong thing:

```
AssertionFailure: null id in DoorstepServiceRate entry
(don't flush the Session after an exception occurs)
```

That is the *flush after* the real failure, not the failure. Fixed in
`V8__doorstep_rate_service_type_nullable.sql` — exactly the category
`application.properties` describes as Flyway's, the changes Hibernate cannot
make.

**This bug had been shipped and undetectable**, because it only bites a
profession nobody had registered for. It is the entire justification for §6.6
being an item.

### The provider screen offered garments for water

The "Item category" dropdown was hardcoded to `Shirt, T-Shirt, Trouser, Jeans,
Saree, …` for every profession. Registering for Water Supply asked the provider
to price a **"Shirt"** against a **"20 litre can"**; Appliance Mechanic, a
"Saree" against a "Geyser".

The comment directly above that list describes this same bug being fixed one
field over — the *service* list had been made catalog-driven and the *item* list
was left hardcoded beside it.

Now driven by the catalog's `pricingUnit`, not by a profession id: `PIECE` means
the price is per garment so which garment is a separate question; `ITEM` and
`VISIT` mean the service already names the thing and there is nothing more to
ask. Two more leftovers went with it — `v ?? 'WASH'` still defaulted a null
selection to laundry, and the price field was labelled "₹ per piece" for
everything.

### `WASH_AND_IRON` was being shown to users

The saved price list printed the raw enum. It could not do better: the screen
only holds the variant list for the profession *currently selected in the form*,
so an existing registration for any other profession had nothing to resolve
against and fell through to the code (DESIGN-RULES §5).

Fixed at the source — `ProviderRateDto` now carries `serviceLabel` and
`pricingUnitLabel` alongside the code, outbound only. "Others — Wash & Iron ·
₹35 per piece" instead of "Others — WASH_AND_IRON · ₹35/pc".

### The booking screen was written for laundry

Every doorstep profession routes through `laundry_booking_screen`. Booking Water
Supply asked **"What needs to be cleaned?"**, instructed the customer to "add
each type of garment separately", labelled the field "Garment / Item type", and
listed the provider's menu as "20 litre can • CAN_20L".

Same rule applied. Where a profession is not priced per garment the dropdown is
gone and the wording becomes "What do you need?" / "Add each thing you need
separately". One consequence worth noting: `description` is what "Continue"
checks and what gets submitted, so hiding the dropdown would have left it empty
and the button permanently disabled. It is now filled from the chosen service,
so the order reads "20 litre can × 2".

### A raw stack trace was the user-facing message

`registerAsProvider`'s catch-all built its message as `"Registration failed: " +
e.getMessage()`. `errorResponse` already takes the technical detail as a
separate argument for the log — concatenating it into the first one put
Hibernate's own words on a provider's screen. The user now gets a sentence and
the exception goes to the log.

### The order could be placed and then never accepted

Booking succeeded and the order reached the provider's list — and stopped dead.
Order #10 sat in "My orders" marked `PENDING` with **no control on it**, and the
"Available" tab said "Nothing waiting to be picked up".

`place-order` auto-assigns the nearest provider, so an assigned order never
appears under Available. And the accept button was gated on the tab:

```dart
if (_activeFilter == 'available' && o.status == 'PENDING') ...
```

So an auto-assigned order could not be accepted by anybody — not by the assignee
(wrong tab) and not by anyone else (not listed). **This is not specific to the
new professions**: laundry order #7 was sitting in exactly the same state.

The server was already right. `accept-order` rejects a different provider
("This order is already assigned to another provider") and permits the one it was
assigned to. The gate existed only in the UI, and only on the half of the
condition that had nothing to do with permission.

### A second `NOT NULL` in the order path, and an audit to end the class

Placing the order then failed the same way registering had:

```
SQL Error: 1048 — Column 'SERVICE_TYPE' cannot be null
```

`pickup_drop_order_item` has its own legacy `SERVICE_TYPE`, with its own entity
comment saying "nullable during the §E-1 migration", and its own column that was
never altered. V9 fixes it.

Two tables changed in code during §E-1 and neither reached the schema, so rather
than wait for a third I compared **every** entity's declared nullability against
`information_schema`. Across 182 NOT NULL columns, these two are the only places
where the Java permits a null the database refuses. That closes the class rather
than the instance.

Worth recording that the first run of that audit reported **four** mismatches.
Three were false — my regex for the annotation body stopped at the first `)`,
which is inside `columnDefinition = "VARCHAR(32)"`, so it never saw the
`nullable = false` that was sitting right there. The edit failing loudly is the
only reason I did not "fix" three columns that were already correct.

### Request ids earned their keep immediately

Both `NOT NULL` failures were found by grepping the log for the id in the failing
response — `60e62ae8`, `8fc30d4b`. T11.4 shipped hours earlier in this same
session and was the reason those two bugs took minutes rather than a hunt through
timestamps.

### One thing I got wrong

I first recorded that the app "showed nothing" on the failed registration. It
did not — the error path calls `_showSnack`, and the snackbar had simply expired
before I took the screenshot ten seconds later. Checking before writing it up is
the only reason that did not become a fix for a bug that was not there.

## 24. §6.2b — the offline gate, and the logout that came with it

§6.2 gave fifteen screens an offline fallback, and verifying it turned up the
fact that **a cold start with no signal never reached any of them**. Fixing that
turned up something worse sitting underneath.

### Losing signal logged people out

`_handleStartupActivity` calls `refreshAuthToken()` and, on `false`, clears the
tokens and goes to the login screen. But `refreshAuthToken` returned `false` for
**every** failure — a 401 from the server and a dead socket alike:

```dart
} catch (e) {
  return false;   // SocketException, TimeoutException, and "you are not you"
}
```

So opening the app inside a building signed the user out — and dropped them on a
login screen that needs an OTP, which needs the network that had just gone. On a
phone in a village with patchy coverage that is the app deleting itself, and the
user has no way to undo it.

Rejection and unreachability are opposite situations, so they are now different
values:

| Result | Meaning | What happens |
|---|---|---|
| `ok` | New tokens saved | Carry on |
| `rejected` | Server was reached and refused | Clear the session — the only case where the tokens are known to be worthless |
| `unreachable` | Never got there | **Keep the session.** We have learned nothing about whether it is valid |

The same distinction was needed one layer down. `ApiService` refreshes on a 412
mid-session and treated a failed refresh as "Session expired. Please login
again." A dropped signal between the request and the refresh now returns an
ordinary connection failure instead, so the screen falls back to its cache and
nobody is signed out for walking behind a building.

### And then the gate itself

The splash pings the server and shows "Could not connect to our Servers" with a
Retry and no way past. That is right for someone *not* signed in — logging in
genuinely needs the server, and pretending otherwise strands them one screen
later with a less honest message.

It is wrong for someone already signed in. Their schedule, register and alerts
are on the phone from the last time they had signal, and §6.2 taught every list
screen to fall back to them. The gate made all of it unreachable: **the data was
on the device and the app refused to show it**, which is worst for exactly the
user with the least coverage.

Now the ping failing only stops someone with no stored token.

### Verified

Network disabled, app force-stopped, cold start:

- **Before:** splash, "Could not connect to our Servers", Retry, nothing else.
- **After:** the home screen with its catalogue, the dashboard reading "2 jobs
  today, 3 tomorrow", and today's visit showing the slot, the household, the
  phone number and the landmark — *"Behind the water tank, next to Sharma
  General Store"* — over **"Showing saved information from 8 hours ago. Check
  your connection."**

Still signed in throughout. Re-enabling the network and pulling to refresh
cleared the banner and brought back live data.

That landmark line is the point of the whole exercise. It is what somebody needs
at 6am on the way to work, and it is the moment they are least likely to have a
signal.

## 25. §7.10 — the household, not the individual

The person who books is very often not the person at home. The son in the city
posts the job and pays for it; the mother-in-law opens the door at seven in the
morning — and until now she could not see when the worker was due, could not
confirm she came, and had no way to tell whether the person at the gate was the
right person. `Task.contactPersonName` recorded that she exists and gave her
nothing.

### Two levels, and only two

Owner does everything. Member can **see the schedule and confirm the work**.
There is deliberately no third tier and no per-capability grid: a permission
model that needs a screen to explain it will be configured wrong by the people
this product is for, and the cost of getting it wrong is somebody's wage.

What a member explicitly **cannot** do, because these end engagements or move
money: change the rate, record or answer an advance, end an engagement, release
a worker, post or withdraw a job.

### How it was made safe

There are 27 places in the backend that check organiser identity. The dangerous
way to build this is to teach all of them about households. Instead
authorisation stays **default-deny** — every one of those checks is untouched —
and exactly **one** was widened: `confirmVisit`, via a single
`householdService.canActFor(viewerId, ownerId)` that also returns true for the
owner, so callers cannot forget to test both cases.

Confirming is the one thing that genuinely has to happen at the door, by whoever
is actually there. Everything else can wait for the account holder.

Two smaller decisions worth recording:

- **The member must already have a Gasta account.** This grants sight of when a
  worker will be alone in a house; that is not something to hand to an
  unverified number somebody typed. When the number is unknown the message says
  what to do — "Ask them to sign up first, then add them" — rather than "not
  found", because the person almost certainly exists, they are in the same house.
- **A failed membership check returns "Visit not found."**, the same words as a
  genuinely missing visit. Whether a given job id exists is not something to
  confirm to somebody who cannot see it.
- **Removing revokes, it does not delete.** Who could see this household's
  schedule last month is a question worth being able to answer, and a row that
  vanishes cannot answer it.

The member is notified when they are added. Being given sight of a household's
schedule without knowing it is not something to do to somebody quietly.

### Both ends on one screen

"Who can see mine" and "whose can I see" are the same question from two ends,
and one person is very often both — the daughter who books for her own house and
helps at her mother's. Two screens would mean finding the right one first.

The "You also help with" section is silent when there is nothing in it: somebody
who helps at no other house should not be shown an empty heading explaining a
thing that has not happened to them.

Wiring that section is also what stops this repeating §6.7's mistake. The
`household-schedule` endpoint was written before it had a caller, which is
exactly the "built but unreachable" shape that audit exists to prevent — caught
in the same session rather than a later one.

### Verified, including one bug I introduced

Owner side: added a member by phone (real account lookup — "Mummyji / Priyank
Tomer / 8191910695"), the member got their notification, and removing set
`ACTIVE=0` with a `REVOKED_DATE` rather than deleting the row.

Member side: the signed-in user, made a member of the other household, saw six
of its nineteen upcoming visits and "and 13 more" — matching the database
exactly.

That second screenshot also showed **BOTTOM OVERFLOWED BY 6.0 PIXELS**, which I
had just caused: the header, the member list and the help section were siblings
in a `Column` with the list in an `Expanded`, so the help section's height was
added on top of space the list had already claimed. It only appeared once
somebody actually belonged to another household — the state the empty database
never produces. One scroll view now owns all three, with only the button pinned.

DESIGN-RULES §6, found the same way as everything else in this plan: by looking
at it on a device with real data in it.

## 26. T11.11 — three slot labels that lied

`Slot` encodes its hours in the constant name and spells them out in a label, so
the two can disagree. Three did:

| Constant | Label said | Should be |
|---|---|---|
| `C_0700_1100` | 07:00 AM – **11:00 PM** | 11:00 AM |
| `C_0730_1130` | 07:30 AM – **11:30 PM** | 11:30 AM |
| `D_12_20` | **12:00 AM** – 08:00 PM | 12:00 PM |

The label is the only part a user sees when choosing when they are willing to
work. Somebody picking the first was agreeing to a sixteen-hour day; somebody
reading the last would turn up at midnight.

Fixed, and then made unable to recur: the constructor re-derives both clock
times from the constant's own name and throws if the label disagrees. It runs at
class-init, so a wrong label fails the first thing that touches the enum rather
than reaching a phone. Names that do not encode hours (`E_1`..`E_4`) are skipped,
because a guard that guesses is worse than no guard.

Verified by putting one of the wrong labels back:

```
GUARD FIRED: Slot C_0700_1100 is labelled "07:00 AM - 11:00 PM" but its name
says "07:00 AM - 11:00 AM". The label is what a user reads when choosing when
to work.
```

and then confirming all 38 pass with the labels correct. A guard that silently
passes everything would have been worth nothing, and the only way to know is to
break it on purpose.

---

## 27. §7.11 — crew booking, server side

Built to the design the product owner approved (PLAN-4 §7.11), which is recorded
there in full. What exists now:

- **`Task.crewAllOrNothing`** — the organiser chooses per job. Transplanting
  needs all ten on the same morning; weeding is happy with six.
- **`TaskAssignment.crewSize`** — how many one leader brings, defaulting to 1 so
  an ordinary hire is simply a crew of one and nothing else special-cases it.
  Asked every time, never stored on the earner: a crew is whoever the leader can
  bring on Tuesday, and last month's answer is a guess about this week.
- **Counting people, not rows.** `sumCrewOnTask` replaces
  `countByTask_IdAndActive` at the two sites that mean "places filled". A crew of
  six against `workersNeeded = 10` used to read as **1 of 10** and keep the job
  open for nine more. The third call site keeps the row count, because there the
  question is "is anybody still on this job", which is a different question.
- **The accept path** validates the group against what is left and says the
  number — "Only 4 more people are needed for this job" — because "too many"
  leaves somebody guessing whether to come back with a smaller group.

### The failure the product owner named

> "Keep in mind scenario where we keep group of 5 we keep on hired/hold while the
> remaining 5 don't get filled till end."

Five people have turned down other work for Thursday. The sixth place never
fills. On Wednesday night the organiser has half a crew and five people have lost
a day's wage — and it is the **earners** who pay for the organiser's job not
filling, which is exactly backwards.

`sweepPartialCrews()` makes holding a crew indefinitely impossible. At the
deadline the organiser is asked once; if they have not answered within
`gasta.crew.decision-hours` (12) the crew is **released, not held**. Silence is
not consent to keep somebody's Thursday.

This needed its own sweep rather than a line in `expireOpenTasks`, because that
one selects `EarnerIsNull` — and a partly-filled crew job *has* an earner, the
first person who took it. So the half-filled case, the entire point of the
feature, never reached the deadline handling at all.

The organiser's answer (`decide-partial-crew`) and the automatic release share
one implementation deliberately: "release them" and saying nothing must produce
the same outcome, or the two drift and one of them stops notifying somebody.

### Verified, both phases

A job needing 10 with a crew of 6 and a passed deadline:

1. **Asked** — organiser notified "Only 6 of 10 so far … If you do not answer,
   they will be released", `crewDecisionAskedAt` stamped, crew still held.
2. **Released** — task closed, assignment ended, and *the earner* told: "…needed
   10 people and only 6 were found, so it is not going ahead. You are free for
   that day." Told, and told why: "you are no longer needed" without a reason
   reads as having been dropped for something they did.

### A bug that compiled perfectly

`findByActiveAndOpenToQuoteAndCrewAllOrNothing` compiles and then fails at bean
creation with **"No property 'crewAll' found for type 'Task'"**: Spring Data
reads the `Or` in `CrewAllOrNothing` as the OR keyword. Replaced with an explicit
`@Query`. PLAN-4 rule 1 again — compiling is not evidence, and this one does not
even reach a screen to be wrong on, it just refuses to start.

### T8.3 wired, and the crew prompt on top of it

`accept-instant-job` had no caller — T8.3 was one of the §6.7 orphans — so the
crew accept path had nothing to ride. Both are done together, because they are
one piece of work:

- **`instantHire` now reaches the app.** The flag had sat on `Task` since Phase 8
  and appeared in no DTO, so the earner could not tell a takeable job from a
  quotable one and there was no button either way. The primary action now reads
  **"Take this job"** on an instant-hire job and "Apply / Make Quote" otherwise.
- **The crew prompt.** "How many of you are coming?", defaulting to the number of
  places actually left rather than to 1 — for a crew job the common answer is
  "all of us", and the field should not make the leader type over a number that
  was never right. Validated client-side for an instant answer and server-side
  under the row lock, which is the one that matters.

### Verified end to end

A job needing all 10 together showed **"Needs all 10 together · 10 left"** in the
Earning Zone, "Take this job" opened the size prompt, and taking it with 6 wrote
`CREW_SIZE = 6`. The database then reported filled 6, remaining 4 — the
people-count working — and on a fresh fetch the job correctly disappeared from
that earner's list, because she is on it.

### Four bugs found doing it

1. **`t.INSTANT_HIRE` does not exist** — the column is `IS_INSTANT_HIRE`. Native
   SQL, so it compiled.
2. **`COALESCE` on a BIT column returns DECIMAL**, and the projection died with
   *"Cannot project java.math.BigDecimal to java.lang.Boolean"* — which took the
   **entire nearby-jobs list** down with a 500, not just the two new fields. The
   BIT columns are now selected raw and null is handled in the mapper.
   `SUM()` needed a `CAST(... AS SIGNED)` for the same family of reason.
3. **A second, near-duplicate badge.** I added a crew pill to the job card before
   noticing `workersBadge` already draws one for D-1. Two near-identical pills is
   the duplication this plan keeps removing, so mine went and the crew wording
   moved into the existing badge instead — one badge, one truth.
4. **A field added in three places and forgotten in the fourth.** The Earning Zone
   builds `Task` field by field rather than through `Task.fromJson`, so
   `crewAllOrNothing` reached the DTO, the wire and the model and still arrived
   as `false`. The badge kept saying "10 places left" on a job that needed all ten
   together, and nothing anywhere reported an error.

Plus one of my own layout bugs: the size dialog overflowed by 31px once the
number pad opened, because `AlertDialog` content does not scroll by itself
(DESIGN-RULES §6).

### Still not built

The organiser's side of the partial-fill question — `decide-partial-crew` exists
and is verified, but there is no screen for it, so today the answer comes only
from the sweep's default. That default is the safe one (release), so the gap
costs an organiser the *option* to go ahead short-handed rather than costing
anybody a day's wage. Worth building next; it is a notification with two buttons.

## 28. The Jackson floor that was not a floor (D-5 / T11.7)

PLAN-3 §20 added this to `application.properties`, with a comment calling it
"the floor for the ones that do not [carry `@JsonFormat`], including fields not
yet written":

```properties
spring.jackson.serialization.write-dates-as-timestamps=false
```

**It does nothing.** Probed by temporarily adding two bare dates to the public
health endpoint:

```
{"probeDate":[2026,8,24],"probeDateTime":[2026,8,24,22,14,49,722809400], ...}
```

Arrays — exactly the shape that broke the advances ledger with *"type
'List&lt;dynamic&gt;' is not a subtype of type 'String?'"*.

### Why, and why it was findable a year ago

`mysql-multitenancy`'s `MvcConfig` carries **`@EnableWebMvc`**, which switches
off Boot's `WebMvcAutoConfiguration` — and that auto-configuration is what
applies `spring.jackson.*` to the HTTP message converters.

**DEFERRED.md D-5 has said so since Phase 4**: *"`spring.mvc.*` and
`spring.jackson.*` properties are inert. Harmless today; it will surprise
someone."* It was right, and I was the someone. I had also mis-recorded D-5 in
PLAN-4 §6.3 as being about `access-app` rather than `mysql-multitenancy`, and
carried that error into PLAN-5 — so the one document that would have warned me
was filed under the wrong library.

### The fix

`config/JacksonWebConfig` — a `WebMvcConfigurer` that disables
`WRITE_DATES_AS_TIMESTAMPS` on the Jackson converter in code.

- **Not in the library.** It is a published, versioned artifact other products
  consume; D-5's own guidance is that config-level fixes are preferred.
- **`WebMvcConfigurer` still works under `@EnableWebMvc`** —
  `DelegatingWebMvcConfiguration` collects them — so this reaches the converters
  without touching `mysql-multitenancy`.
- **`extendMessageConverters`, not `configureMessageConverters`.** The latter
  *replaces* the default list, which would strip every non-JSON converter.

After: `{"probeDate":"2026-08-24","probeDateTime":"2026-08-24T22:17:46.3963205"}`.

The property stays in `application.properties` — it is the correct declaration
and the right thing to read there — but its comment now says plainly that it is
inert on its own and that `JacksonWebConfig` is what holds the line true. Two
things that must not be deleted independently.

**Blast radius: none today.** Every DTO date already carries an explicit
`@JsonFormat`, which is the only reason this was invisible. Verified on the
emulator after the change: the register renders August 2026 with every day in
the right cell and the right status. This is a safety net for the *next* date
field somebody adds — which is what the property was always supposed to be.

### The lesson

Rule 4 says a comment that disagrees with its code is worse than no comment. This
one claimed a guarantee that did not exist, in a file about dates, in a codebase
that had already been bitten by dates once. **A property that is never observed
to take effect is a belief, not a setting** — the same shape as rule 6 about
guards that have never fired.
