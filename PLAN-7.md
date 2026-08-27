# PLAN-7 — what is left

Written 2026-08-27, at the end of a day that wiped the database, deleted the
migrations, and closed most of PLAN-6.

**This file is only the remainder.** Anything finished is struck through in
[PLAN-6.md](PLAN-6.md) or marked ✅ in [OBSERVATIONS.md](OBSERVATIONS.md), and
is not repeated here. Every item below says *what*, *why*, and *how* — enough
that somebody who was not here can pick one up.

**The ordering claim.** §A is the only section that stops a launch. Everything
else improves an app that already works, and none of it is a reason to wait.

---

## A. Nothing ships until these are done — and none of them are code

### A-0. 🔴 An SMS provider

**The OTP is `000000` for every phone number on the live server.** Anyone who
guesses a number that has signed up is that person. This is the single most
serious open item in the product.

It is deliberate and it is documented ([O-18](OBSERVATIONS.md)) — SMS was
deferred so the rest could be built — but it is now the last thing standing
between the app and real users.

⚠️ **The order matters and getting it wrong locks everyone out.** Wire the
provider first, verify a real message arrives, *then* set `access-app-otp=Yapan`
to leave the fixed-code branch. Flipping the property first means nobody can
sign in, including you.

**What to pick.** MSG91 or Fast2SMS for India; both need a DLT-registered sender
ID and template, which is a registration process with its own lead time. **Start
the DLT registration before writing any code** — it is the long pole, not the
integration.

**How:** `sendOtp` in access-app ends with `// TODO Send OTP to user`. That is
the seam. One HTTP call, plus the template id.

**Size:** a day of code. Two to three weeks of DLT registration.

---

### A-1. 🔴 A lawyer, for six documents

Privacy policy, terms of service, the DPDP notice, the grievance mechanism, the
worker terms, and the refund/cancellation policy.

⚠️ **Not something to draft from a template.** The product handles the personal
data of workers who cannot easily seek redress, and India's DPDP Act carries
real penalties. It also makes promises about deletion that the code now actually
keeps — see [O-29](OBSERVATIONS.md) — which is worth telling the lawyer, because
"we delete your data" is a claim most apps cannot back.

**Size:** weeks, and it is the long pole with A-0.

---

### A-2. 🔴 A named Grievance Officer

A name, an email address and a postal address, published in the app. Legally
required. It is a decision, not a task.

---

### A-4. 🟠 A real domain

`yapan.duckdns.org` is a free dynamic-DNS hostname. It works, and it says
exactly what it is to anybody who looks. ⚠️ It is also a single point of
failure nobody here controls, and the token for it has already been exposed
once ([O-6](OBSERVATIONS.md)).

**How:** buy the domain, point an A record at the instance, and change one line
in `deploy/Caddyfile` — Caddy gets the certificate itself. The `duckdns`
container can then go.

**Size:** an afternoon, once somebody buys it.

---

### A-5. 🟠 One repository secret, or CI stays red

`GH_PACKAGES_TOKEN` is not set on `priyanktomer/JeevikaService`, so **every CI
run has failed for as long as CI has existed** — ten seconds each, at the
workflow's own guard step.

The three `com.actually` libraries live in GitHub Packages under other
repositories, and `GITHUB_TOKEN` can only read packages belonging to the
repository it runs in. A classic PAT with `read:packages`, added under
Settings → Secrets and variables → Actions, is the whole fix.

⚠️ **Until this is set, everything in §C-1 is theatre.** The workflow is
correct — it now runs the right schema test, the right Flutter version and the
l10n and text-style checks — and none of it executes.

**Size:** five minutes, and it needs your account.

---

## B. Product decisions — the work is small, the decision is not

### B-1. L-2, the laundry garment menu

> *"laundry is main in doorstep and this only should be enabled with proper menu
> for wash and iron separately cloth wise like shirt, kurti, saree, trouser"*

**Half of this is done.** Laundry appears on Doorstep Services with Wash, Iron
and Wash & Iron, all priced `PER_PIECE`, seeded from `ReferenceDataSeeder`.

**What is missing is the garment.** "Wash, 5 pieces" is not what anybody
negotiates — a saree and a handkerchief are not one price, and quoting per piece
across both is how a provider loses money or a customer feels cheated.

**The shape of the fix.** A `garment` table — code, label, sort order — and an
order line that is *(variant × garment × quantity)* rather than
*(variant × quantity)*. `pickup_drop_order_item` already has the shape for it;
it needs one more column and a lookup.

⚠️ **The prices are per provider, not global.** A rate card belongs on
`doorstep_service_rate`, which already exists and is already per provider. Do
not put a price on the garment row — the moment there are two providers in one
town, a global price is either wrong for one of them or a price-fixing problem.

**The part that needs you:** the garment list. Shirt, kurta, kurti, saree,
salwar, trouser, jeans, bedsheet, blanket, towel, and where the line stops.
Roughly a dozen; more than twenty and the screen becomes a form.

**Size:** two days once the list exists.

---

### B-1b. L-4's chip catalog — who curates it, now that it is data

**⚠️ This section was missing from the first draft of PLAN-7 and the product
owner caught it.** L-4 was marked done when only a third of it was.

**What is now finished** (2026-08-27, live and verified):

- The ticked chips are **stored as codes** on `task_note`, not folded into the
  description. They used to be joined into prose at posting time, which threw
  the codes away, froze the language at whatever the organiser was using, and
  made them impossible to draw as chips or to count.
- The **words come from the database** — `LABEL_EN` and `LABEL_HI` on
  `profession_note_option`, seeded once and never overwritten, so an edit on
  the server survives a deploy. The app falls back to its own ARB string when a
  label is missing rather than showing the other language.
- **Sub-profession granularity exists.** An option row can name one; the app
  narrows the list as the organiser ticks, with no extra call.
- The earner sees them **as chips above the description**, in their own
  language.

**What is left, and it is a curation job rather than a coding one.**

The eight codes are still the eight that were guessed at when the feature was
built, and which profession gets which is decided in `ReferenceDataSeeder` by
**matching name fragments** — `'%mistri%'`, `'%harvest%'`. That works and it
breaks the day somebody renames a profession in the admin screen. It is the same
O-23 problem: a profession has no stable code, only a display name.

Two things would finish it:

1. **A `CODE` column on `profession`.** Then note options, headcount flags and
   service variants all attach to something that does not change when a display
   name is edited. ⚠️ This is the single root cause behind O-23 and behind
   every `LIKE '%...%'` in the seeder — worth doing once rather than working
   around a fourth time.
2. **An admin screen for the chips.** The table is configurable now and nothing
   exposes it, so changing a word still means a developer. `AdminController`
   already has the pattern — `add-professions`, `enable-state`.

**The part that needs you:** whether eight is the right set. Sub-profession
rows make things like "the roof, not the walls" or "cows, not the field"
possible, and nobody has decided whether that is useful or clutter.

**Size:** the profession code column is a day. The admin screen is two. The
list itself is a conversation.

---

### B-2. L-3, road distance instead of straight line

The distance filter measures a **straight line**. The label now says so —
"25 km away (direct)" — which was the honest half and is done.

The dishonest half remains: **in hill and river country a straight-line 8 km is
a 40-minute detour**, and an earner who travels for a job that turned out to be
across a river does not come back.

**Why this is not just a code task.** Road distance needs a routing service, and
every option costs money per request:

| Option | Cost | Note |
|---|---|---|
| Google Distance Matrix | ~$5 / 1000 elements | Best data for India by a wide margin |
| Mapbox Matrix | Free tier, then paid | Weaker on rural Indian roads |
| Self-hosted OSRM | Server cost only | ⚠️ Needs an OSM extract and a machine to run it; on the current Ampere box it competes with the API for memory |

⚠️ **Do not call a routing API from the list query.** Nearby-jobs returns a
page of jobs; routing every one on every scroll is the cost mistake this becomes
if it is done casually. Route **one** pair, on the detail screen, when somebody
is actually deciding — and cache it on the task, because the two endpoints do
not move.

**Recommended:** Google, one call per task-detail view, cached. At any plausible
volume for the first year this is a few hundred rupees a month.

**Size:** a day, once a key exists and somebody accepts the bill.

---

### B-3. L-8, slots for farm and construction work

Slots are `MORNING / AFTERNOON / EVENING`, which fits domestic work — a maid
comes at eight.

Harvest does not work that way. A crew starts at first light and works until the
field is done, and "afternoon" is not a booking, it is a guess. Construction is
similar: a majdoor is hired for a *day*, not a slot.

**The shape of the fix.** `profession.allowedSlots` already exists and is
already per profession — the machinery is there. What is missing is a
`FULL_DAY` slot, and possibly `FIRST_LIGHT`, offered to the professions that
need them and not to the ones that do not.

⚠️ **Adding an enum constant is not free.** `Slot` is persisted as a string —
see the `preferred_enum_jdbc_type=VARCHAR` note in `application.properties` —
so the column is fine, but every screen that switches on `Slot` needs a case,
and `SlotLabelTest` will name the ones that do not.

**The part that needs you:** whether a farm job is booked as a day, or as a
window, or as "we start at five and you go home when it is done". That is a
question about how the work is actually arranged, and it is not a developer's
to answer.

**Size:** a day of code. The decision is the work.

---

### B-4. L-1's other half — partial fill as an explicit choice

**The honesty half is done.** An assigned earner is now told when a job is still
short: *"This job still needs 2 more of 5 people"*, on their own job card.

What is still missing is the *decision*. A job for five that found two at the
deadline currently just runs, and nobody is asked. The product owner's test —
**do not give fake hope of employment, even for a minute** — is only half met by
telling people; somebody has to decide whether the job happens.

**The shape of the fix.** `CREW_ALL_OR_NOTHING` and `crewDecisionAskedAt`
already implement exactly this for crew jobs: a sweep stamps the task, the
organiser is asked, and answering either way closes it. Extend the same
machinery to headcount jobs.

⚠️ **All-or-nothing must not become the default.** In this market four out of
five is a normal Tuesday, and a job that needed five and found four not
happening means four people lose a day. The organiser chooses; the system does
not choose for them.

**Size:** two days — a sweep, a notification and one screen.

---

### B-5. O-1's real question — what is the email address for?

The Gmail/Outlook rule stays; the message now reads as a rule rather than as
"your address is malformed", which was the immediate defect and is fixed.

⚠️ **But nothing is ever sent to that address.** OTP is SMS. Notifications are
push. So a rule justified by deliverability is guarding a field with no current
purpose, while turning away people with a Rediff or Yahoo address — common in
exactly this audience — at the second screen.

Three coherent answers, and one of them should be picked:

1. **Drop the field.** If nothing is sent, do not collect it. Least data, least
   liability under DPDP.
2. **Keep it, drop the allowlist.** Ordinary email validation, and a denylist
   for known disposable domains if scam signups are the real worry.
3. **Keep it exactly as is**, and write down that the rule is an anti-abuse
   measure rather than a deliverability one — so the next person does not
   "fix" it.

**Size:** an hour, whichever is chosen.

---

## C. Engineering debt, in the order it will hurt

### C-1. A staging database — now the only thing between an entity edit and production

There is one database and it is production.

⚠️ **This got more important on 2026-08-27, not less.** The schema is authored
by the `@Entity` classes now and applied by `ddl-auto=update`
([O-30](OBSERVATIONS.md)). Under Flyway a bad change was a file somebody could
read before it ran. Now a renamed field reaches production as an `ALTER` that
Hibernate issues at startup, with nothing in between.

And `update` **never drops or renames**. So the failure mode is not a crash —
it is a new column appearing quietly beside the old one, the old one still
holding every row of real data, and no error anywhere.

**How:** a second compartment on the same Oracle tenancy, free tier, and a
`docker-compose.staging.yml`. Deploy there first.

**Size:** a day.

---

### C-2. Extend the from-nothing test to cover the catalog

`SchemaBuiltFromEntitiesTest` builds an untouched schema and asserts the tables,
the seed rows and the column defaults arrive. It does **not** call
`initial-setup`, and that gap is exactly where the 2026-08-27 rebuild broke
three separate ways ([O-31](OBSERVATIONS.md)) — the doorstep flag, two missing
professions and ten missing service variants, each found by hand.

**How:** one more test in that class — POST `initial-setup`, then assert 52
professions, 104 sub-professions, 36 states, 10 service variants, 3 doorstep
professions and 4 headcount professions.

⚠️ **Assert the counts, not just "more than zero".** Every one of the three
failures produced a non-empty catalog that was quietly missing something.

**Size:** an hour, and it is the highest-value hour in this section.

---

### C-3. The remaining 71 ad-hoc text styles

154 became 71, and `tool/check_text_styles.py` holds that as a ratchet in CI.

The rest are concentrated in `worksheet_screen.dart` (18) and `widgets.dart`
(14). They are not a rendering bug — the theme sets `fontFamily` globally, so a
bare `TextStyle` still inherits Comfortaa — but each one is a size that does not
move with the screen.

**Size:** an afternoon, and safe to do gradually because the ratchet stops it
going the other way.

---

### C-4. Push has never been proved to arrive

[O-15](OBSERVATIONS.md). `FcmPushSender` builds a correct HTTP v1 payload, the
token round trip works, and **nobody has ever watched a notification land on a
phone.** The failure modes it cannot see are all silent: a wrong `channel_id`,
a missing APNs key, a token registered against the wrong project.

**How:** send one, to your own phone, from the live server. It costs ten
minutes and either confirms the whole feature or finds the one thing wrong with
it.

---

### C-5. The APK is 65 MB

[O-16](OBSERVATIONS.md). Large for this audience — many will install over a
patchy connection with a data cap, and download size is a real reason not to.

An App Bundle cuts the delivered size substantially, because Play ships only the
architecture and density each device needs. That is a Play Console setting plus
`flutter build appbundle`, not a code change.

⚠️ **The bundled fonts are worth keeping** even though they are part of the
size. The system-font detour was tried and reverted, for good reasons recorded
in the tokens file.

---

## D. Records, not tasks

These are written down, understood, and need nothing:

- **[O-28](OBSERVATIONS.md)** — the MySQL `IF NOT EXISTS` outage. Resolved; the
  guard against a repeat is C-2 above.
- **[O-30](OBSERVATIONS.md)** — why the schema went back to Hibernate, and what
  that costs. C-1 is the mitigation.
- **[O-31](OBSERVATIONS.md)** — what the wipe found. C-2 is the mitigation.
- **[O-20](OBSERVATIONS.md), [O-21](OBSERVATIONS.md)** — the home IP rotating
  and the build machine filling up. Both have tools now
  (`deploy/allow-my-ip.py`, and knowing to clear the Gradle cache).
- **[O-27](OBSERVATIONS.md)** — seeding demo data fights the rate limiters.
  Working as designed; the limiter is doing its job.

---

## What "done" would mean

The app works. It is live, it has demo data, 84 backend tests pass, the
database rebuilds itself from code, and every screen has been through a design
pass.

It cannot launch, and the reason is entirely §A: there is no way to send a real
OTP, no privacy policy, no named grievance officer and no domain. Three of those
four need a person rather than a developer, and two of them have lead times
measured in weeks.

**The single most useful thing to start today is the DLT sender-ID registration
for A-0**, because it is the longest wait and nothing else depends on it being
finished before it can begin.
