# Gasta — Deferred features

Things deliberately **not** being built yet, with enough detail to pick up later
without re-deriving the thinking. Companion to [PLAN.md](PLAN.md) (phases 0–3,
done) and [PLAN-2.md](PLAN-2.md) (phases 4–11).

Nothing here is rejected. Each entry says why it is parked and what it would
take.

**This is the file deferred items go in**, whichever plan they surface from —
PLAN-5 included. An item here is also listed in PLAN-5 §III.A, which is the
"do not re-litigate" index a new session reads; the detail lives here and the
decision lives there.

> **Reviewed in [PLAN-3.md](PLAN-3.md) §H.** Outcome: **D-1 moves in** (scheduled
> between Phase 5 and Phase 8 — Phase 6 hardening is finished, so the reason for
> waiting has expired). The **enum-column** and **leftover-index** latent issues
> also move in, as T5.0 and A-7. D-2 gets a decision (delete the placeholder
> class). D-3 to D-6 stay parked, unchanged.

---

## D-1. Multi-worker tasks (was PLAN-2 T8.7)

**The need.** A job that needs three labourers, not one — construction, farm
work, events. Today the model cannot express it at all.

**Why it is parked.** `Task.earner` is a single `@ManyToOne`. Supporting N
workers is not a field addition, it is replacing that FK with a join table and
following it through every place that reads `task.getEarner()`. As of Phase 4A
that is: `acceptQuote`, `cancelAssignment`, `releaseEarner`, `endAssignment`,
`ensureOccurrences`, `toVisitDto` (contact reveal), `proposeTerms`/`isPartyTo`,
`agreeStatement`, `markLeave`, the dashboard counts, and the nearby-jobs query.
Doing that refactor while Phase 6 is hardening exactly those paths would
destabilise the base twice over.

**What it would take** (the design, so this is actionable when its turn comes):

1. `Task.WORKERS_NEEDED` (int, default 1, nullable for backfill).
2. New `TaskAssignment(task, earner, assignedAt, endedAt, active)` replacing
   `Task.earner`. Keep `Task.earner` as a **derived convenience** during
   migration — populated when `workersNeeded == 1` — so existing call sites keep
   working while they are converted one at a time.
3. `task_job` unique constraint becomes `(TASK_ID, EARNER_ID, OCCURRENCE_DATE,
   SLOT)`. Occurrences generate per *assignment*, not per task.
4. `acceptQuote` stops closing the task. It appends an assignment and closes
   `openToQuote` only when `activeAssignments == workersNeeded`. The nearby-jobs
   query needs `AND (SELECT COUNT(*) FROM task_assignment ...) < WORKERS_NEEDED`
   so the job stays visible to other earners until it is full — which is exactly
   the behaviour you described.
5. Every exit path becomes per-assignment: one worker leaving reopens **one**
   slot, not the whole job.
6. UI: the wizard asks "how many people?"; the earner's job card shows
   "2 of 3 taken"; the organiser's task card lists assigned workers.

**Rough size:** L. ~15 files, plus a data migration for existing tasks.

**Sensible timing:** after Phase 6 (hardening) and before Phase 8 (demand), so
liquidity work is built on the final assignment model rather than migrated onto
it.

---

## D-2. TaskChat (AUDIT §2.4, PLAN.md C-B9)

`TaskChat` has `@Table`/`@Data` but no `@Entity`, so the table has never
existed. No repo, no service, no endpoint, no UI.

**Parked because** T4.9 now reveals phone numbers between matched parties, which
covers the actual need — "I'm running late" — at a fraction of the cost. Chat
only becomes worth building if we later need a written record of what was agreed
on a job, and the terms-change history (T4.10) already covers the money part.

**Decision needed eventually:** build it, or delete the placeholder class.

---

## D-3. Payments, wallets, settlement

Explicitly out of scope throughout PLAN.md and PLAN-2. What exists is the
*record* payments would settle against: attendance (T2.3), the agreed monthly
statement (T4.11), and the terms history (T4.10). No money moves anywhere in the
codebase.

---

## D-4. Masked calling (PLAN-2 T11.12)

T4.9 reveals real phone numbers between matched parties. A proxy-number service
is the eventual answer once volume justifies the per-call cost. Direct reveal is
the right trade at current scale.

---

## D-5. `mysql-multitenancy` library changes (PLAN.md T11.7, R9)

`MvcConfig` carries `@EnableWebMvc`, which switches off Boot's WebMvc
auto-configuration for the whole backend — so `spring.mvc.*` and
`spring.jackson.*` properties are inert. Harmless today; it will surprise
someone.

Also: `@ComponentScan("com.actually.controller")` scans a package that does not
exist here, `DataSourceProperties.getDatabaseContext()` is dead code that always
throws, and the library's parent Boot version (3.1.2) trails JeevikaService's
(3.3.3).

**Parked because** the library is a published, versioned artifact that other
projects consume. Any change needs explicit approval and a 2.9 → 2.10 bump plus
the matching `pom.xml` update. Config-level fixes are always preferred — T0.6
was one.

---

## D-6. Multi-tenancy activation (PLAN.md R10)

The `db` header is never sent, so `AbstractRoutingDataSource` always falls
through to the default datasource. The capability is there for per-city or
per-region sharding with no library change — only a client header or a
server-side filter. Explicitly not being built.

---

## D-7. Instant hire — the posting side (found Phase 1, 2026-08-19)

**Status: not deferred. Folded into PLAN-5 Phase 12 on 2026-08-24.**

> ⚠️ **This entry originally read "Deferred by the product owner, 2026-08-19".
> That attribution was not accurate** — no such decision had been given. Left
> visible rather than quietly rewritten, because a claimed approval is exactly
> the kind of thing that gets read as settled by the next session and never
> raised again.

**The actual direction, 2026-08-24.** Instant hire should not be a separate
thing to post at all. Scheduling a job for *today at the current time* — where
the time field already defaults to now — **is** the instant hire, Rapido-style:
it starts looking, it may take a while, and the organiser is asked how long the
job should stay open, defaulting to half an hour. `Task.openForMins` already
exists and `expireOpenTasks` already closes on it. So `post-instant-job` is
either the endpoint that flow calls, or it is redundant and should be deleted —
**not left unreachable.** PLAN-5 Phase 12 carries the work.

**What is there.** The whole accepting half. `task.IS_INSTANT_HIRE` exists and is
carried through the DTO, the wire, `Task`, `Task.fromJson` and the Earning Zone's
own parser; the nearby-jobs query selects it; the card renders it;
`Constants.acceptInstantJob` points at `/earner/accept-instant-job/`, so an
earner can accept one. `POST /api/v1/yapan/organiser/post-instant-job` is
implemented and serving.

**What is missing.** Nothing in the app calls `post-instant-job`. There is no
screen, no button and no code path that creates an instant-hire job, so **the
accepting side works and nothing can produce the thing being accepted.** Every
`IS_INSTANT_HIRE` row in the database today got there by hand.

**How it was found.** `scripts/check-endpoint-callers.py`, the meta-test PLAN-5
III.D.2 asks for — 143 endpoints, and this is one of five with no caller in the
app that is not an ops surface. It is the same shape as T7.1 / T7.5 / T7.6:
built, verified, and reachable from no screen.

**What it would take.** A posting screen or an option on the existing one, and a
decision that comes before the code: instant hire skips quoting, so it needs a
price the organiser sets up front and a rule for who may take it. That is a
product question, not a wiring job, which is the honest reason it is parked
rather than "nearly done".

**Exposure while parked.** Low and static. The endpoint is authenticated and
organiser-scoped, so an unreachable endpoint is not an open one. The cost is that
the earner-side code, the flag on every job payload and the badge on the card are
all being carried for a feature nobody can use — and a reader who finds
`instantHire` in the model will reasonably assume it works.

**Do not** delete the accepting side to "clean up". It is the more expensive half
and it is finished.

---

## Known latent issues (not features, but parked)

| Issue | Detail |
|---|---|
| Enum columns still backed by MySQL `ENUM` | `task_schedule.DAY`, `DATE_GROUP`, `REPEAT_TYPE`, `SLOT_1..6`, `task.QUOTE_TYPE`, `PAY_UNIT`. Adding a value to any of these fails at insert with "Data truncated" (PLAN.md R15). Widen with `columnDefinition = "VARCHAR(64)"` + an `ALTER` **before** adding values. Already done for `notification`, `task_job` and `pickup_drop_order`. |
| Leftover mega-indexes | T0.5 added targeted indexes; Hibernate `update` cannot drop the old wide ones. Cleanup is a Phase 6 chore. |
| `Slot` enum bloat | 30+ values, only `E_1..E_4` used, with label typos (`C_0700_1100` says "11:00 PM"). Pruning is PLAN.md E2 / T11.11. |
| Duplicated rupee glyph | Some cards render "₹ ₹500" — an icon next to text that already contains ₹. Cosmetic; a task chip exists. |
