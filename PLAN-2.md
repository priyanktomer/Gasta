# Gasta — Plan 2: Phase 4 onward, with human-behaviour coverage

Companion to [PLAN.md](PLAN.md) (phases 0–3, **complete**) and
[DESIGN-RULES.md](DESIGN-RULES.md) (binding UI rules).

PLAN.md phases 4–11 were deliberately left as sketches. This document expands
them **and adds a category the original plan under-covered: what people actually
do**, as opposed to what the happy path assumes they will do.

---

## 0. Where the original plan stands

| Phase | State |
|---|---|
| 0–3 | ✅ Complete and verified in the emulator |
| 4–11 | Sketches only — expanded here |

### Three items that fell through the cracks

Worth naming, because neither will be caught by working through the phase list:

1. **B2 (post-assignment contact) has no task number in any phase.** AUDIT §5-B
   lists it; PLAN.md never assigned it. `VisitDto.counterpartPhone` ships as
   `null` today. An assigned earner cannot phone the customer to say they are
   running late — AUDIT §3.3 called this out and it silently went nowhere.
   **Now T4.9.**
2. **Enum widening is a latent schema trap** (PLAN.md R15). `task_job.STATUS`,
   `SLOT` and `CANCEL_TYPE` are MySQL `ENUM` columns that `ddl-auto=update`
   cannot widen. Every task below that adds an enum value **must** carry an
   explicit `ALTER`, or it will fail at runtime with "Data truncated". Handled
   in T4.1; `pickup_drop_order.STATUS` widened in T4.15.
3. **The doorstep provider side had no UI at all.** `pending-orders`,
   `accept-order`, `update-status` and `my-orders` all existed on the backend
   and no screen called any of them — a registered provider could not see an
   order, let alone act on one. Neither AUDIT nor PLAN caught this because both
   reasoned from the backend outwards. Found while building T4.16, which needed
   a provider screen to attach to; `provider_orders_screen.dart` is that screen.

---

## 1. Human behaviour: what we assume vs what people do

The app currently models a cooperative, decisive, literate user with a stable
phone who changes their mind only at convenient moments. Real users are none of
those things — and the ones we are targeting least of all.

Each row is a thing people *will* do, that the app has no answer for today.

### A. Exit and change of mind

| # | What happens | Today | Gap |
|---|---|---|---|
| A1 | Earner accepts, then gets permanent work elsewhere and wants out | **Nothing.** `mark-leave` gives a day off; there is no exit. | Earner is trapped or simply ghosts — which is what they will actually do. **T4.2** |
| A2 | Organiser wants a *different* worker but still wants the job done | Only `cancel-task`, which kills the task. They must re-post from scratch, re-entering schedule, address and pay. | High-friction path pushes people off-app. **T4.3** |
| A3 | Earner has an emergency mid-visit and must leave | `IN_PROGRESS` can only go to `DONE_BY_EARNER`. | They mark it done (wrong attendance) or abandon it, and auto-confirm marks it `COMPLETED` after 24 h. Attendance data becomes a lie. **T4.4** |
| A4 | Work was done badly; organiser does not want to confirm | Confirm, or do nothing — and doing nothing auto-confirms in 24 h. | The only way to object is to object *loudly and off-app*. **T4.5** |
| A5 | Pay needs renegotiating ("the house is bigger than you said") | Amount is frozen at quote acceptance forever. | Renegotiation happens verbally and the app's record goes stale — which poisons every later payment discussion. **T4.10** |
| A6 | Organiser adds work ad hoc ("also do the terrace today") | No concept. | Same as A5, at visit granularity. Folded into **T4.10**. |

### B. Mistakes and reversibility

| # | What happens | Today | Gap |
|---|---|---|---|
| B1 | Fat-finger "Mark done" on the wrong card | Irreversible; auto-confirms in 24 h. | For a low-literacy user on a small screen this is not an edge case. **T4.6** |
| B2 | Month-end: "I worked 26 days" / "no, 22" | `get-attendance` exists but nobody agrees to it. | No shared, agreed record — the exact artefact payments will later settle against. **T4.11** |

### C. Reachability and identity

| # | What happens | Today | Gap |
|---|---|---|---|
| C1 | Earner is 20 minutes late and wants to call | `counterpartPhone` is `null`. | **T4.9** (the orphaned B2). |
| C2 | Someone else is at home (elderly parent, child, neighbour) | Task has one organiser, one phone. | Worker arrives and cannot reach whoever is actually there. **T4.9** |
| C3 | Phone number changes, or phone is lost | Phone **is** the identity. No recovery. | Account and all work history are simply gone. Very common in this segment. **T5.7** |
| C4 | One phone shared by a family | No account switching; unclear who is logged in. | Wife's jobs on husband's phone. **T5.8** |
| C5 | User is stuck and cannot read the screen | Support is a Phase 10 ticket form — text. | This user rings someone. A visible phone number beats a ticket queue. **T5.9** |

### D. Reliability of commitments

| # | What happens | Today | Gap |
|---|---|---|---|
| D1 | Earner accepts and then never opens the app again | Nothing detects it. | Organiser discovers it at the locked door. **T4.7** |
| D2 | Organiser gets quotes and never responds | Quotes sit forever. | Earners wait on dead leads. **T4.8** (uses existing `openForDays`) |
| D3 | Earner accepts two jobs in the same slot | Nothing prevents or warns. | Guaranteed no-show for one of them. **T4.7** |
| D4 | "Come for 3 days, then we'll decide" | No trial concept; acceptance is a full commitment. | This is how domestic hiring actually starts. **T4.12** |

### E. Shape of the work

| # | What happens | Today | Gap |
|---|---|---|---|
| E1 | A job needs 3 labourers, not 1 | One earner per task. | Whole categories (construction, farm, events) cannot be expressed. **T8.7** |
| E2 | Both sides go off-app after the first match | Nothing. | Not fixable by force; fixable by making the app more useful than WhatsApp — attendance record, agreed statement, repeat booking. Addressed indirectly by T4.11 / T8.2. |

---

## 2. What this changes about priority

**Proposal, not a decision — say the word and I will reorder.**

The original Phase 4 was doorstep re-confirmation and expiry. I would put the
behaviour work first, because:

- It affects the **core marketplace** (tasks/visits), not only the doorstep
  vertical, so it touches every user.
- A1 and A3 are actively **corrupting attendance data right now**. Every day the
  app runs, a trapped earner ghosts or a mid-visit abandon auto-confirms as
  completed. Later phases (trust scores, payment settlement) build directly on
  that data.
- A2's missing "release worker" is a friction cliff exactly where a customer is
  most likely to give up on the app.

So Phase 4 splits:

- **Phase 4A — Exits, corrections and reachability** (new, below)
- **Phase 4B — Doorstep reliability** (the original T4.1–T4.5, unchanged, renumbered T4.13–T4.17)

Nothing else renumbers.

---

## 3. Phase 4A — Exits, corrections and reachability

Implementation-ready, same detail level as PLAN.md phases 0–3. Order as listed.

---

### T4.1 — Widen the enum columns (do this first)

**Why first:** T4.4 and T4.5 add `JobStatus` values. `task_job.STATUS` is a MySQL
`ENUM` and `ddl-auto=update` will not widen it — the insert fails at runtime with
"Data truncated for column 'STATUS'". PLAN.md R15.

**Files:** `entity/TaskJob.java`

**Spec:** pin the three enum-backed columns to VARCHAR, as already done for
`Notification.notificationType`:

```java
@Enumerated(EnumType.STRING)
@Column(name = "STATUS", nullable = false, columnDefinition = "VARCHAR(64)")
private JobStatus status = JobStatus.SCHEDULED;

@Enumerated(EnumType.STRING)
@Column(name = "CANCEL_TYPE", columnDefinition = "VARCHAR(64)")
private CancelType cancelType;

@Enumerated(EnumType.STRING)
@Column(name = "SLOT", columnDefinition = "VARCHAR(64)")
private Slot slot;
```

**Migration (dev DB, mandatory):**
```sql
ALTER TABLE task_job MODIFY COLUMN STATUS      VARCHAR(64) NOT NULL;
ALTER TABLE task_job MODIFY COLUMN CANCEL_TYPE VARCHAR(64) NULL;
ALTER TABLE task_job MODIFY COLUMN SLOT        VARCHAR(64) NULL;
```

**Acceptance:** `SHOW COLUMNS FROM task_job` reports `varchar(64)` for all three;
existing rows still readable; `get-my-visits` unchanged.

**Size:** S · **Touches:** DB

---

### T4.2 — Earner exits an assignment (A1)

**Goal:** an earner who cannot continue has an honest way out, instead of
ghosting.

**Files:** `dto/CancelAssignmentDto.java` (new), `entity/AssignmentExit.java`
(new), `repo/AssignmentExitRepo.java` (new), `EarnerService`/`Impl`,
`EarnerController`

**Spec — endpoint:** `POST /api/v1/yapan/earner/cancel-assignment`
```json
{ "taskId": 5, "reason": "Got permanent work elsewhere", "cancelType": "PERMANENTLY" }
```

Behaviour, in one transaction:
1. Ownership — caller must be `task.earner`, else 400 "You are not assigned to this task."
2. Record an `AssignmentExit` **before** clearing anything:
   `(task, earner, organiser, exitedBy=EARNER, reason, cancelType, noticeDays, createdDate)`
   where `noticeDays` = days between now and the next live `TaskJob`. Zero-notice
   exits are the ones ops will care about (T10.4 penalty ledger).
3. `task.setEarner(null)`, `task.setOpenToQuote(true)`,
   `task.setOccurrencesGeneratedUpto(null)` so the task re-enters the pool.
4. Clear `earner` on active `TaskSchedule` rows.
5. Future live `TaskJob`s → `CANCELED` via `applyStatus`, note = reason.
   **Past jobs untouched** — attendance history is immutable.
6. The earner's accepted `TaskQuote` → `revoked = true`, so it does not show as
   an active quotation.
7. Notify organiser: `JOB_CANCELED`, "‹name› can no longer continue ‹task›. Your
   job is open for quotes again."

**Response payload:** `{ "visitsCanceled": 8, "taskReopened": true }`

**Acceptance:**
1. Earner cancels → `task.EARNER_ID` null, `IS_OPEN_TO_QUOTE` 1, future jobs
   `CANCELED`, past `COMPLETED` jobs unchanged.
2. Task reappears in another earner's `get-nearby-jobs`.
3. Organiser's `get-my-posted-tasks-filtered/open` includes it again.
4. A non-assigned user → 400.
5. `assignment_exit` has one row with a plausible `noticeDays`.

**Size:** M · **Touches:** DB (1 table), API, UI (T4.8)

---

### T4.3 — Organiser releases the earner, keeps the task (A2)

**Goal:** "I want someone else" must not require destroying and re-creating the job.

**Files:** `OrganiserService`/`Impl`, `OrganiserController`

**Spec — endpoint:** `POST /api/v1/yapan/organiser/release-earner`
```json
{ "taskId": 5, "reason": "Not a good fit" }
```

Same mechanics as T4.2 but `exitedBy = ORGANISER`, and the notification goes to
the earner: `JOB_CANCELED`, "‹organiser› has ended your assignment for ‹task›."

**Explicitly distinct from `cancel-task`:**

| | `release-earner` | `cancel-task` |
|---|---|---|
| `task.active` | stays `true` | `false` |
| `task.openToQuote` | `true` — back in the pool | `false` |
| Schedule, address, pay | kept | kept but unusable |
| Organiser's next step | wait for new quotes | re-post from scratch |

**Acceptance:** after release, the task is visible to other earners and its
schedule/address/amount are unchanged; `cancel-task` still behaves as before.

**Size:** S/M · **Touches:** API, UI

---

### T4.4 — Mid-visit abandon (A3)

**Goal:** stop recording abandoned work as completed.

**Depends on:** T4.1

**Spec:**
- New `JobStatus.ABANDONED("Left early")`.
- Extend the earner transition table: `IN_PROGRESS → ABANDONED`.
- `POST /earner/update-visit-status` accepts it with a **required** `note`.
- `applyStatus` must set `completed = false`; `ABANDONED` is terminal.
- **`autoConfirmStaleVisits` must skip it** — only `DONE_BY_EARNER` auto-advances.
- Attendance (T2.3) gains an `abandoned` count.
- Notify organiser: `JOB_CANCELED`, "‹name› had to leave ‹task› early: ‹note›".

**Acceptance:**
1. `IN_PROGRESS → ABANDONED` with a note → 200; without a note → 400.
2. The visit is **not** auto-confirmed after the window.
3. `get-attendance` reports it under `abandoned`, not `completed`.

**Size:** S/M · **Touches:** DB (enum value — see T4.1), API, UI

---

### T4.5 — Organiser rejects a completed visit (A4)

**Goal:** "not done properly" is a first-class answer, not silence.

**Depends on:** T4.1

**Spec:**
- New `JobStatus.DISPUTED("Not accepted")`.
- `POST /organiser/reject-visit/{jobId}` body `{ "reason": "..." }`, allowed only
  from `DONE_BY_EARNER`.
- Sets `DISPUTED`, stamps `organiserConfirmedAt = null`, stores the reason.
- **Blocks auto-confirm** — a disputed visit never silently completes.
- Notify earner: `JOB_CANCELED`, "‹organiser› did not accept ‹task› on ‹date›: ‹reason›".
- Attendance gains a `disputed` count.
- Resolution (who is right) is **Phase 10**; this task only records the disagreement.

> Deliberately *not* auto-penalising the earner. One unhappy customer is not
> evidence, and a punitive default would push workers off the platform. The
> record is what matters now.

**Acceptance:** reject a `DONE_BY_EARNER` visit → `DISPUTED`, earner notified,
auto-confirm leaves it alone, attendance counts it separately. Rejecting a
`SCHEDULED` visit → 400.

**Size:** S/M · **Touches:** DB (enum value), API, UI

---

### T4.6 — Undo window on visit actions (B1)

**Goal:** an accidental tap costs seconds, not a day's attendance record.

**Spec:**
- Two nullable columns on `TaskJob`: `PREVIOUS_STATUS` (VARCHAR 64),
  `STATUS_CHANGED_AT` (datetime). `applyStatus` populates both.
- `POST /earner/undo-visit-status/{jobId}` reverts to `PREVIOUS_STATUS` if
  `STATUS_CHANGED_AT` is within `gasta.visit.undo-window-seconds` (default 120)
  **and** the visit has not since been confirmed by the organiser.
- Property: `gasta.visit.undo-window-seconds=120`.
- UI: the existing success `SnackBar` gains an **UNDO** action for the window
  duration. No new screen, no new button to learn — the standard, discoverable
  pattern.

**Acceptance:** mark done → undo within 2 min → back to `IN_PROGRESS`; after the
window → 400 "Too late to undo."; after organiser confirmation → 400.

**Size:** S/M · **Touches:** DB (2 nullable columns), API, UI

---

### T4.7 — Commitment guards: ghosting and double-booking (D1, D3)

**Goal:** catch broken commitments before the locked-door moment.

**Spec — double-booking (D3):**
- On `accept-quote`, check whether the earner already has a live `TaskJob` at any
  (date, slot) the new task would generate.
- **Warn, do not block** — the organiser is the one accepting, and only they can
  judge. Response payload gains
  `{ "conflictWarning": "This worker already has work in the Early Morning slot on 3 of these days." }`
  and the app shows a confirm dialog before proceeding.
- Needs `countByEarner_IdAndOccurrenceDateInAndSlotAndStatusIn` on `TaskJobRepo`.

**Spec — ghosting (D1):**
- Scheduled sweep (the T3.6 scheduler already exists): any `SCHEDULED` `TaskJob`
  whose date is **yesterday or earlier** and which never left `SCHEDULED` →
  `MISSED`, both parties notified.
- This is R7 in PLAN.md ("automatic no-show marking becomes possible once T3.6 is
  live") — T3.6 is live, so this is now unblocked.
- Cron: `gasta.noshow.cron=0 30 1 * * *` (after the 02:00 occurrence top-up would
  be wrong — run before it, so a missed day is closed before new rows appear).

**Acceptance:** accepting a conflicting quote returns the warning and still
succeeds if confirmed; a `SCHEDULED` visit left untouched past its date becomes
`MISSED` on the next sweep and both parties are notified.

**Size:** M · **Touches:** API, UI

---

### T4.8 — Task and quote expiry (D2, the original T4.3)

**Goal:** enforce `openForDays`/`openForMins`, which are collected and ignored today.

**Spec:** scheduled job closes open, unassigned tasks past their window
(`openToQuote = false`), notifies the organiser with `TASK_EXPIRED` and a one-tap
repost. Pending quotes on an expired task → `revoked`, earners notified so they
stop waiting on a dead lead.

**Size:** S/M · **Touches:** API

---

### T4.9 — Contact between matched parties (C1, C2 — the orphaned B2)

**Goal:** the two people who have to meet can reach each other.

**Spec:**
- Populate `VisitDto.counterpartPhone` **only** once `task.earner != null`, in
  both directions. Before assignment it stays null.
- Add to `Task` (both nullable): `CONTACT_PERSON_NAME`, `CONTACT_PERSON_PHONE` —
  "who will actually be there", which is frequently not the account holder
  (elderly parent, child, neighbour). Optional field in the new-task wizard's
  address step; falls back to the organiser.
- `VisitDto` gains `onSitePersonName` / `onSitePersonPhone`.
- UI: a **call button** on the visit card for both roles (`url_launcher`,
  `tel:` — already a dependency? if not, add it). Icon + word, per
  DESIGN-RULES §5.

> Privacy note: numbers are revealed **only** between two people already matched
> on a specific task, never in browse or quote lists. Masked calling is a
> Phase 11 concern; direct reveal is the right trade now.

**Acceptance:** before assignment `counterpartPhone` is null for both; after,
each sees the other's; the call button dials; a third user sees neither.

**Size:** M · **Touches:** DB (2 nullable columns), API, UI

---

### T4.10 — Change of terms (A5, A6)

**Goal:** renegotiation lives in the app instead of drifting out of it.

**Spec:**
- New `TermsChangeRequest`: `(task, proposedBy, proposedAmount, proposedPayUnit,
  note, status ∈ PENDING/ACCEPTED/DECLINED, createdDate, respondedDate)`.
- `POST /authenticated/propose-terms` `{taskId, amount, payUnit, note}` — either
  party; must be the task's organiser or assigned earner.
- `POST /authenticated/respond-terms/{requestId}` `{accept: true|false}` — the
  *other* party only.
- On accept: update `task.fixedQuoteAmount` / `payUnit`; both notified; the
  request row is kept as history so "what did we agree, and when" is answerable.
- Only one `PENDING` request per task at a time.

**Acceptance:** earner proposes ₹700, organiser accepts → task amount is 700 and
new visits show it; organiser declines → amount unchanged, earner notified;
proposing while one is pending → 400.

**Size:** M · **Touches:** DB (1 table), API, UI

---

### T4.11 — Agreed monthly statement (B2, E2)

**Goal:** produce the artefact both parties will actually argue about, before
they argue about it — and make the app more useful than a WhatsApp thread.

**Spec:**
- `GET /organiser/get-attendance` already computes the numbers (T2.3).
- New `MonthlyStatement`: `(task, month, totalWorked, leave, skipped, missed,
  disputed, agreedAmount, organiserAgreedAt, earnerAgreedAt, createdDate)`.
- `POST /authenticated/agree-statement` `{taskId, month}` — stamps the caller's
  side. When both have stamped, the statement is locked.
- Either party can view it; both see identical numbers.
- **No payment, no wallet** — payments stay out of scope. This is the record a
  future settlement would read.

**Acceptance:** both parties agree → both timestamps set and the row is
immutable; numbers match `get-attendance` for the same month.

**Size:** M · **Touches:** DB (1 table), API, UI

---

### T4.12 — Trial period (D4)

**Goal:** match how domestic hiring actually starts.

**Spec:**
- `Task.TRIAL_DAYS` (nullable int), offered in the wizard as "Try for a few days
  first?" with 0 / 3 / 7 options.
- During the trial window (from first visit), `cancel-assignment` and
  `release-earner` write `AssignmentExit.duringTrial = true` and **skip** the
  penalty record entirely.
- Both parties see "Trial — N days left" on the visit card.
- At trial end, both get a notification: "Trial over — continue?" Doing nothing
  continues (the low-friction default); either party can exit.

**Acceptance:** a task with `trialDays = 3` shows the badge; exiting on day 2
records `duringTrial = true`; the notification fires at end of day 3.

**Size:** M · **Touches:** DB (1 nullable column + 1 on exit table), API, UI

---

### Phase 4A exit criteria

- [ ] An earner can leave an accepted engagement, and the task returns to the pool.
- [ ] An organiser can swap workers without re-creating the job.
- [ ] A mid-visit abandon is never recorded as completed.
- [ ] A rejected visit is never auto-confirmed.
- [ ] An accidental status tap can be undone within 2 minutes.
- [ ] Matched parties can phone each other; nobody else can.
- [ ] A pay change agreed in the app updates the task and is auditable.
- [ ] Missed visits are closed automatically, not left as `SCHEDULED` forever.

---

## 4. Phase 4B — Doorstep reliability

The original T4.1–T4.5, unchanged in intent, renumbered to avoid collision.

| ID | Item | Size |
|---|---|---|
| T4.13 | Provider re-confirmation (OP6b) — `CONFIRM_REQUESTED_AT` / `PROVIDER_CONFIRMED_AT` / `CONFIRM_DEADLINE`; ask ~24 h before pickup; decline or silence → back to `PENDING`, reassign, `ORDER_REASSIGNED` to customer | M/L |
| T4.14 | Doorstep order expiry — `PENDING` past its pickup date → `CANCELLED` + customer notified | S |
| T4.15 | Doorstep status-transition validation (D6, AUDIT §4.18) — currently `DELIVERED` can go back to `PENDING` | S |
| T4.16 | Re-confirmation UI — provider "Still available?" card; customer sees "Confirmed ✓" / "Provider changed" | M |
| T4.17 | Doorstep cancel-with-reason, mirroring T4.2/T4.3 for the pickup-drop vertical | M |

---

## 5. Phases 5–11, revised

Changes from PLAN.md are marked **NEW** or **MOVED**.

### Phase 5 — Substitution, flexibility, and identity

| ID | Item | Size |
|---|---|---|
| T5.1–T5.6 | Unchanged from PLAN.md: substitute task, temporary badge, substitute lifecycle, reschedule, availability windows, doorstep provider choice | L |
| **T5.7** | **NEW — Identity recovery (C3).** Phone change and lost-phone flows. Verify via the old number if reachable, else an admin-assisted path (T10.2) with the work history as evidence. Today a lost phone means a lost account and lost earnings history. | M |
| **T5.8** | **NEW — Shared-device account switching (C4).** Multiple saved accounts on one device with a clear "you are ‹name›" indicator on every screen. One phone per family is the norm, not the exception. | M |
| **T5.9** | **NEW — Call-for-help (C5).** A permanent, visible support phone number in Profile and on every error state, plus a "request a callback" button. Ticket forms (T10.1) assume the user can write; many cannot. | S |

### Phase 6 — Correctness, authz, performance, caching

Unchanged (T6.1–T6.13). Add:

| ID | Item |
|---|---|
| **T6.14** | ✅ **Done.** DESIGN-RULES.md compliance sweep. Found and fixed three §1 violations the earlier pass missed, all `Wrap` over tappables: the **day picker** (7 chips that re-flowed, and whose `M T W T F S S` labels had two Ts and two Ss — now a fixed 4+3 grid of `Mon`…`Sun`), the **dashboard count chips** (which moved between rows as a number gained a digit — now a fixed 2×2 grid), and `checkBoxGroup` drawing checkboxes for single-select (now radios). Deleted the two `Wrap`-based chip helpers outright so the pattern cannot return. The two *known* deviations stand as documented — `worksheet_screen`'s PageView has fixed tap zones and `laundry_booking_screen`'s sheet has fixed buttons, so the controls do not move in either. Recorded a new trap in DESIGN-RULES: the grid helper hands back **the same list object** it mutated, so a callback that clears-and-re-adds wipes the selection — which is exactly what happened, and only the emulator showed it. |

### Phase 7 — Trust and reputation

Unchanged (T7.1–T7.6). Add:

| ID | Item |
|---|---|
| **T7.7** | **NEW — Reliability signals from real behaviour.** `EarnerStats` / a matching organiser-side table gain: exits-with-short-notice, no-show count, abandon count, dispute count, trial-conversion rate — all sourced from `AssignmentExit` and `TaskJob`, which Phase 4A starts recording. **Show sparingly and never as a single punitive score**; the goal is informing a choice, not blacklisting people. |

### Phase 8 — Demand and liquidity

Unchanged (T8.1–T8.6). Add:

| ID | Item |
|---|---|
| ~~T8.7~~ | **Multi-worker tasks — moved to [DEFERRED.md](DEFERRED.md) §D-1** with a full design. It is a core-model refactor (single FK → join table) touching every path Phase 6 is hardening; the sensible slot is after Phase 6 and before Phase 8. |
| **T8.8** | **NEW — Referral / "introduce a worker".** Word of mouth is how this market actually hires. Let an organiser vouch for an earner to another organiser. |

### Phases 9–11

Unchanged from PLAN.md, except:

| ID | Item |
|---|---|
| **T9.0** | **NEW — Language picker before login.** English is the default. The picker appears on first launch and stays reachable until login/signup completes — login itself has to be readable before anything else can be. Persisted through the T6.10 cache helper. Comes first in Phase 9. |
| **T9.2 (decided)** | All seven regional languages get **generated** ARBs rather than being left empty. ⚠️ **Generated translations are a starting point, not a finished product** — for a low-literacy audience a confidently wrong word is worse than an English one they half-recognise. Every file ships marked `needs-native-review`; the visit-action verbs ("On my way", "Mark done") and all money wording need a native speaker before release. |
| **T10.4 (revised)** | Penalty ledger now has real inputs — `AssignmentExit.noticeDays`, `duringTrial`, no-show and abandon counts. Still **records only**, no charging. |
| **T10.7** | **NEW — Dispute resolution.** Work the `DISPUTED` queue from T4.5: ops sees both sides, marks an outcome, writes `AdminAuditLog`. Without this, T4.5 records disagreements nobody ever resolves. |
| **T11.12** | **NEW — Masked calling.** Once volume justifies it, replace the direct number reveal from T4.9 with a proxy number. |

---

## 6. Suggested order

1. **T4.1** (enum widening) — everything after it depends on this.
2. **T4.2, T4.3** — the trapped-earner and swap-worker gaps. Highest value.
3. **T4.4, T4.5, T4.6** — stop corrupting attendance data.
4. **T4.9** — reachability. Small, and removes a daily irritation.
5. **T4.7, T4.8** — commitment guards, now that the scheduler exists.
6. **T4.10, T4.11, T4.12** — terms, statements, trials.
7. **Phase 4B** — doorstep reliability.
8. Phase 5 onward.

---

## 7. Progress tracker

| Phase | Task | Status |
|---|---|---|
| 4A | T4.1 Widen enum columns — STATUS/CANCEL_TYPE/SLOT now `varchar(64)`, 40 rows preserved | ☑ |
| 4A | T4.2 Earner exits an assignment — 10 visits cancelled, task back in the pool, 2 days notice recorded | ☑ |
| 4A | T4.3 Organiser releases the earner — task kept its ₹800/DAY and address | ☑ |
| 4A | T4.4 Mid-visit abandon — note required, `IS_COMPLETED` stays 0 | ☑ |
| 4A | T4.5 Organiser rejects a visit — `DISPUTED`; verified it does **not** auto-confirm, with a control that does | ☑ |
| 4A | T4.6 Undo window — reverts in-app via SnackBar; "Too late to undo" past the window | ☑ |
| 4A | T4.7 Ghosting + double-booking guards — conflict warning on accept, no-show sweep at 01:30 | ☑ |
| 4A | T4.8 Task and quote expiry — `openForDays`/`openForMins` finally enforced | ☑ |
| 4A | T4.9 Contact between matched parties — phone revealed only after matching; call button both sides | ☑ |
| 4A | T4.10 Change of terms — ₹600 → ₹750 accepted, task updated, history kept | ☑ |
| 4A | T4.11 Agreed monthly statement — locks once both sides stamp; re-agreeing → 400 | ☑ |
| 4A | T4.12 Trial period — `TRIAL_DAYS` + penalty-free exit inside the window | ☑ |
| 4B | T4.13 Provider re-confirmation — asked 24h out, decline → reassigned **and repriced ₹20→₹25** | ☑ |
| 4B | T4.14 Doorstep order expiry — stale PENDING cancelled by the sweep | ☑ |
| 4B | T4.15 Status-transition validation — `DELIVERED → PENDING` now rejected | ☑ |
| 4B | T4.16 Re-confirmation UI — **required building the provider orders screen, which did not exist** | ☑ |
| 4B | T4.17 Doorstep cancel/decline with reason + registered-provider check on accept | ☑ |
| 5 | T5.1–T5.6 Substitute, reschedule, availability | ☐ |
| 5 | T5.7–T5.9 Identity recovery, shared device, call-for-help | ☐ |
| 6 | T6.1–T6.14 Correctness, authz, N+1, caching, design sweep — **T6.12 not started** (refactor-only), T6.8 was delivered as T4.15 | ☑ |
| 7 | T7.1–T7.7 Trust, reputation, reliability signals | ☐ |
| 8 | T8.1–T8.8 Demand, liquidity, multi-worker, referral | ☐ |
| 9 | T9.0 Language picker before login (**new**) + T9.1–T9.6 Accessibility and language | ☐ |
| 10 | T10.1–T10.7 Ops, support, disputes | ☐ |
| 11 | T11.1–T11.12 Scale and hardening | ☐ |

---

## 8. Open questions for you

1. **Priority swap** — do you accept putting Phase 4A ahead of doorstep
   reliability? It delays the doorstep vertical.
2. **Trial default** — should a trial be opt-in (default none) or suggested by
   default for recurring work? I have assumed opt-in.
3. **Dispute outcomes** — when an organiser rejects a visit, does the earner get
   marked absent for attendance, or does it stay pending until ops rules? I have
   assumed it stays separate (`disputed`) and neither counts as worked nor absent
   until resolved.
4. **Multi-worker (T8.7)** — is this a real near-term need, or is Gasta
   one-worker-per-job for the foreseeable future? It is a large change and I do
   not want to build it speculatively.
