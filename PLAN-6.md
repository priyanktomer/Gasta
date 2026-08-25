# PLAN-6 — after the first deployment

**Status: a draft, deliberately.** Written 2026-08-26, the night the backend
went live, before anybody had used the app on a real phone for more than a few
minutes. The product owner said they would come back with "a lot of feedback"
after walking the UI properly — and that feedback should shape this file, not
arrive after it has been committed to.

So: **the inventory below is real, the ordering is not.** Nothing here is
scheduled. Read it as "what is known to be outstanding", and expect the first
session that picks it up to reorder it around what the feedback says.

---

## Where things actually stand

The backend is live at **https://yapan.duckdns.org** and the app talks to it
over HTTPS from a real phone. That was the last structural unknown; everything
below is work, not risk.

| | |
|---|---|
| Backend | Live, Ampere A1 in Mumbai, Let's Encrypt, nightly verified backups off-host |
| Schema | Flyway builds it from nothing; `ddl-auto=validate` passes in production |
| Tests | 77 backend, 27 app, all green |
| App | Signed release build installs on a physical phone |
| Hindi | 720 ARB keys, English and Hindi in exact parity |
| Push | Not built |
| Store listing | Not started |
| Crash reporting | None — a crash on a user's phone is invisible |

### What PLAN-5 has left open

- **Phase 0** — a lawyer for the legal text, and pointing `GASTA_BACKUP_DIR` at
  somewhere other than the server. *Backups are now off-host to Object Storage,
  so the second half is arguably done; the lawyer is not.*
- **Phase 7** — one illustration, crew all-or-nothing.
- **Phase 10** — push. Blocked on a Firebase project.
- **Phase 11** — steps 3–6: crash reporting, store assets, Data Safety, target
  SDK. *Signing is done; the privacy policy URL is now possible.*
- **Phase 14** — item 4 (deliberately not done), 7 (a "consider"), 8 and 12
  (blocked on the lawyer and on appointing a Grievance Officer).

Plus everything in [OBSERVATIONS.md](OBSERVATIONS.md), which is the file for
things noticed in passing.

---

## A. Things that block a store release

These are the only items with a hard external dependency. Everything else can be
done in any order.

### A-1. A lawyer for the six legal documents ⚠️ the long pole

Phase 2 built the whole mechanism — versioned consent, an age gate, a grievance
route with the statutory SLAs, a deletion path that honours the 180-day
retention rule. Six documents ship with **DRAFT banners** and placeholder text.
The mechanism is real; the text has to come from somebody qualified.

**Send them** PLAN-5 §III.C as the brief, along with
`JeevikaService/src/main/resources/legal/`. A draft to correct is a cheaper
thing to hand a lawyer than a blank page.

### A-2. A named Grievance Officer

`gasta.legal.grievance-*` are blank, so the complaint screen degrades to showing
the SLAs with nobody's name on them. The IT Rules 2021 require a named person
with a contact address. This is an appointment, not a code change.

### A-3. Firebase, for push

Phase 10's FCM half needs a project and a `google-services.json`. Free.

**The WorkManager poll fallback needs none of that** and is arguably the more
important half for this audience — a real share of pushes never arrive on
Xiaomi, Oppo, Vivo and Realme. It was deliberately not built ahead of FCM
because the phase's own verification is "disable push at the OS level and
confirm the poll still delivers", which needs both halves to mean anything.
Worth revisiting that judgement if Firebase stalls.

### A-4. A real domain

`yapan.duckdns.org` works and costs nothing. For a store listing it is the
privacy-policy URL and the Data Safety contact, and a duckdns subdomain reads as
temporary because it is. Roughly ₹700–900/year.

---

## B. Known defects and gaps

### B-1. Everything in OBSERVATIONS.md

Nine entries, three fixed. The open ones worth pulling forward:

- **O-1** — sign-up rejects every email that is not Gmail or Outlook
  (`SignUpDto.java:27`). A product decision, not a bug, but it turns people away
  at the second screen with a message that reads like their address is invalid.
- **O-3** — `ddl-auto=update` in development. Production is on `validate`; dev
  is one line away, and that line would have prevented the Phase 9 incident that
  took down the whole test suite.
- **O-5** — profession names arrive as English prose. The most visible remaining
  English on otherwise-Hindi screens.
- **O-6** — regenerate the DuckDNS token; it was pasted into a chat log.

### B-2. The Hindi audit nobody has done

Seven screens were translated because somebody happened to be working on them.
**No one has walked the whole app in Hindi with fresh eyes.** That is the single
highest-value thing the next round of feedback can produce, and it needs a
person using the app, not a grep.

The recurring trap, twice now: **text that is composed cannot be translated.**
The posting wizard compared against the English words *on screen* to decide
which form fields to draw. The visits screen glued `"$when"` and `", $slot"`
onto a sentence with adjacent-string concatenation. Both had to be restructured
before a single word could be replaced. Expect more of these.

### B-3. No crash reporting

A crash on a user's phone is invisible. Two routes, both free:

- **Sentry free tier** — needs an account, nothing else. Least work.
- **Self-hosted GlitchTip** — would sit in the same compose stack on the VM,
  which has ~8 GB spare. No account, no third party, but it needs Postgres plus
  a worker and is meaningfully more to run.

Deliberately not started: half-built error reporting is worse than none, because
it looks like coverage.

### B-4. No monitoring

`docker compose logs` is the whole story. The health endpoint exists and is
honest — it does a real round trip to MySQL — but nothing watches it. A cron
that curls it and shouts would be a start and is nearly free.

---

## C. Deployment work that is worth doing next

### C-1. CI — GitHub Actions building into GHCR

`deploy.sh` ships a **~200 MB tar** on every deploy because there is no
registry. It works and takes under two minutes, which is why it was the first
step rather than this. Actions building the arm64 image into GHCR makes deploys
incremental and removes the laptop from the path.

Deliberately second: the first deploy should not also be the first time CI has
ever run.

### C-2. SSH is pinned to one IP

Correct, and it will lock the product owner out the first time their ISP hands
them a different address. The runbook says how to move it. A better answer is
OCI Bastion (Always Free), which needs no standing rule at all.

### C-3. `ddl-auto` and a second environment

There is one database and it is production. A staging compartment on the same
tenancy would cost nothing in Always Free terms and would let a migration be
tried before it runs against real work records. Worth it the moment there is
real data worth protecting — which is roughly now.

---

## D. Product work, unranked

Nothing here has been agreed. It is written down so it is not re-derived.

- **Phase 7's last illustration** — crew all-or-nothing, one line of drawing.
- **The two remaining Phase 5 gaps** — a declined consent still does not stop
  the app using the data (Phase 14 item 8), which needs the lawyer's text to say
  which features depend on it.
- **`OrganiserServiceImpl` is ~2,400 lines** (Phase 14 item 7). Not a defect.
  Three of one session's bugs lived there.
- **The `Slot` enum has 38 values for about four in use** (Phase 14 item 4).
  Deliberately not trimmed: doing it would delete `SlotLabelTest`, which
  documents three real 16-hour label defects, for cosmetic gain.

---

## E. On retiring PLAN 1–5

The product owner asked whether the old plan files can be removed now that the
main development phase is over.

**Recommendation: mark them historical, do not delete them.** Two reasons.

The plans are not only task lists — they carry the *reasoning*, and several
decisions in this codebase are only defensible because the argument is written
down somewhere. PLAN-4 holds the product thesis and the rules learned the hard
way. DEFERRED.md holds what was consciously not built, which is the file that
stops a future session cheerfully rebuilding something that was rejected for a
good reason. AUDIT.md is the provenance of a great many small fixes.

And the cost of keeping them is close to zero: a line in the README saying which
file is current. The cost of deleting them is discovering in four months that
nobody remembers why `ddl-auto` is what it is, why the Slot enum was not
trimmed, or why there is no load balancer.

**What is worth doing** is making the entry point unambiguous, so a fresh
session reads *this* file and not a finished one. That is a README change, and
it is the only part of this recommendation that should happen without
discussion.

---

## Questions for the product owner

Left here rather than asked in conversation, so they are not lost:

1. **The Gmail/Outlook restriction (O-1)** — what is it for? If it is to block
   disposable addresses, a denylist does that without also blocking Rediff and
   Yahoo, which plenty of this audience have.
2. **`ddl-auto=validate` in development (O-3)** — it would mean writing the
   migration before the entity, every time. That is already the stated discipline
   after Phase 9. Make it enforced?
3. **A real domain** — worth ₹700–900/year now, or stay on DuckDNS until closer
   to a store submission?
4. **Crash reporting** — Sentry's free tier (an account, no infrastructure) or
   self-hosted GlitchTip on the same VM (no third party, more to run)?
5. **Phase 10** — build the WorkManager poll half now without FCM, or keep them
   together?
