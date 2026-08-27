# Gasta — things noticed in passing

Defects and questions found while doing something else, written down instead of
mentioned once in conversation and lost.

**This is not a plan and nothing here is scheduled.** Each entry is a thing
somebody looked at, thought "that is not right", and did not stop to fix because
it was not what they were doing. Some are two-minute changes. Some are product
decisions that are not a developer's to make.

Companion to [DEFERRED.md](DEFERRED.md), which is different: that file holds
things **deliberately not built yet**, with the reasoning. This file holds
things nobody has decided about at all.

**Format.** Newest first. Each entry says what was seen, why it matters, and how
much work it looks like. When one is fixed, say so and leave it — "we looked at
this and it was fine" is worth as much as the fix.

---

## Open

### O-33. The two Home tiles are drawn in two different visual languages

**2026-08-27, seen during the screenshot pass.** "Doorstep Services" carries a
colour emoji (a door and a plant), like every profession tile below it.
"Reserve or Schedule" carries a **monochrome outline SVG** — a flat grey shape
that, sitting beside colour artwork, reads as an icon that failed to load
rather than as a deliberate choice.

They are the **first two things on the first screen**, side by side and the same
size, which is exactly where a mismatch is most visible.

⚠️ **This is data, not code.** Both come from `get-home-screen-menu`; the icon
is a base64 SVG stored on the row. Nothing in the app decides it, so nothing in
the app can fix it — it is a matter of replacing the stored artwork, and which
artwork is a product decision rather than a developer's.

**Two ways to settle it**, and either is fine as long as it is *one* of them:

- Give RESERVE a colour emoji, matching everything else on the screen.
- Or give every tile a monochrome icon, which is the more restrained look and
  a much larger change.

**Size:** minutes, once somebody picks the artwork.

---

### O-34. ~~The consent screen looks like it cuts a card in half~~ — looked at, and it is not a bug

**2026-08-27.** On first sight the "We do not sell your data" card is sliced
across the middle by the button bar, mid-sentence, which reads as a layout
fault on a screen where completeness matters legally.

**Scrolled it, and the whole thing is there.** The card, "The full text"
heading, Terms of Use and Privacy Notice all appear, and the buttons stay
fixed. The scroll view ends where the bar begins, so nothing is hidden *behind*
anything — it is ordinary scrolling, and the cut is just where the fold happens
to land.

⚠️ Written down rather than fixed, deliberately. The one thing that could be
said against it is that there is **no affordance saying it scrolls** — no
indicator, and the fold lands mid-sentence. If a user ever reports not finding
the documents, this is the entry to reopen; changing it now would be fixing an
appearance rather than a fault.

**Worth keeping as an example** of a thing that looked wrong in a screenshot and
was right in the app. It was checked before being touched, which is the whole
point of doing this with screenshots.

---

### O-32. ~~Step 3's chips were never actually stored~~ ✅ fixed 2026-08-27

Found by the product owner asking the right question: *"step 3 checkboxes are
more imp than description, so i hope values of those being store and shown."*

They were not. `new_task_page.dart` joined the ticked **labels** with newlines
and posted the result as `description`. There was no notes column on `task` at
all.

⚠️ **The language froze at posting time.** An organiser posting in Hindi
produced Hindi sentences that an English-reading earner saw in Hindi — in an app
whose entire localisation design is code-plus-label, and in the one place that
had quietly opted out of it.

⚠️ **And they could not be drawn as chips**, only as prose, so the thing an
earner most needs at a glance — a dog, stairs, bring your own tools — was buried
in a paragraph. Nothing could be counted either: "how many jobs involve heavy
lifting" was unanswerable.

**Also wrong, and also his:** he had asked for the chip **strings** to come from
the database, and I had shipped codes-only with the labels in the app's ARB
files — documenting the decision carefully, which made it look considered rather
than contrary to what was asked. Adding or rewording a chip needed an app
release. And sub-profession granularity, which he asked for in the same
sentence, I skipped outright and recorded as "left out".

⚠️ **None of it was carried into PLAN-7 either**, so it would have been lost
rather than deferred. That is the worse half of this entry: a thing left undone
and written down is a decision, and a thing left undone and not written down is
just a thing left undone.

**Fixed:** codes on `task_note`, `LABEL_EN`/`LABEL_HI` on the option rows,
sub-profession narrowing in the app, chips above the description on the job.
What is still open — a stable profession code, and an admin screen for the
words — is [PLAN-7 §B-1b](PLAN-7.md).

---

### O-31. Wiping the database is what proved the rebuild works — and it did not, three times over

**2026-08-27.** The product owner asked for a complete wipe and said the catalog
was in the code. I said it was not. **He was right and I was wrong** — see the
correction in [O-30](#o-30). `InitServiceImpl` holds 50 professions, 104
sub-professions, 36 states and the countries, and runs when the account
`8191910695` signs up.

But the wipe did what only a wipe can: it found the parts that were **not** in
any code, each of which had been quietly carried by a migration.

1. **`SUPPORTS_PICKUP_DROP` came from V20.** Rebuilt database, zero doorstep
   professions, an empty Doorstep grid — [O-23](#o-23) returning by a different
   route within a day of being fixed.
2. **Two professions existed only in production.** Water Supply and Cylinder
   and Heavy Item Delivery were added through the admin API and never written
   down, so the live database had 52 and the code produced 50. They would have
   been gone for good.
3. **Ten `service_variant` rows came from V5.** Wash, iron and wash-and-iron
   under laundry; cans, cylinders, documents and tiffin under the others.
   Without them Doorstep Services lists a profession with nothing orderable
   under it.

All three are in Java now, and a wipe-and-rebuild reproduces **52 professions,
104 sub-professions, 36 states, 10 variants, 35 note chips, 3 doorstep, 4
headcount** — verified by doing it twice.

⚠️ **Two ordering bugs fell out of it, and both are the same shape.**

- `ReferenceDataSeeder` runs at startup, which on an empty database is *before*
  any profession exists — so it attached nothing, and the catalog arrived later
  over HTTP. `InitServiceImpl` calls it explicitly now.
- The variant match was a bare `contains("wash")`, which handed **Automobile
  Washer** a laundry menu priced per garment.

⚠️ **The lesson worth keeping.** Every one of these was invisible on the live
database, which already had the rows. "It works in production" says nothing
about whether production could be rebuilt — and until yesterday nobody had ever
tried. `SchemaBuiltFromEntitiesTest` builds an untouched schema for exactly this
reason, but it does not call `initial-setup`; **extending it to assert the full
catalog comes back is the obvious next guard** and is written up in PLAN-7.

---

### O-28. ~~🔴 A one-word MySQL incompatibility took the live API down~~ ✅ resolved 2026-08-27

**2026-08-27, during §L-1.** `V22__profession_asks_headcount.sql` was written as
`ALTER TABLE profession ADD COLUMN IF NOT EXISTS ...`. **MySQL 8 has no
`IF NOT EXISTS` on `ADD COLUMN`** — that is MariaDB. It parses as a column named
`IF`, fails with a 1064, and Flyway records a `success = 0` row.

Two things about that are worth more than the typo:

⚠️ **A failed migration is a latch, not a retry.** Every subsequent start fails
validation with *"Detected failed migration to version 22"* until the row is
deleted by hand. And it latches on the **old image too** — rolling back does not
help, because the row is in the database, not the jar. There is no way out
except touching `flyway_schema_history`.

⚠️ **The migration was never run before it was deployed.** V21 the same day was
fine, which is luck: `CREATE TABLE IF NOT EXISTS` *is* valid MySQL. The
difference between the two files was invisible to review and would have taken
one second to catch against a real MySQL 8.

**What actually prevents this**, cheapest first:

1. **Run the migrations against MySQL 8 in a test.** `docker-compose.local.yml`
   already stands one up. A single test that boots the context against it turns
   this class of bug from an outage into a red build. This is §C-1's real value
   and it is the reason to do it.
2. Deploy to a staging database first — §C-3, already on the plan.

⚠️ **The health watcher (§B-4) did its job and nobody was there to read it.**
It logged `DOWN http=502` to `/var/log/gasta-health.log` exactly as designed.
That is the gap §B-4 names in its own footer: it reaches a person only if a
person reads the file.

---

### O-29. ~~🔴 "Delete my account" had never worked for anyone who posted a job~~ ✅ fixed 2026-08-27

**2026-08-27, found while re-seeding demo data.** Five demo accounts, five
failures, identical message: *"Something went wrong. Please try again."*

`ComplianceServiceImpl.deleteMyAccount` hard-deleted the user's addresses:

```java
appUserAddressRepo.deleteByUser_Id(id);
```

`task.ADDRESS_ID` is a foreign key onto `app_user_address`. So for **anybody who
had ever posted a job** the delete threw a constraint violation — and because
the method is one `@Transactional` unit, the violation rolled back *every other
deletion in it*. The user asked to be erased, saw an error, and kept the account
intact.

⚠️ **This is the DPDP Act deletion path.** Not a convenience feature: the
legally required one, and the one §A-1's privacy policy will promise.

⚠️ **It reported the failure honestly and nobody was listening.** The catch
block logs `Could not delete account` at ERROR with the stack trace. It has been
doing that for as long as the feature has existed. §B-4's watcher checks whether
the API answers, not whether it answers *correctly* — a 500 on one endpoint is
invisible to it.

**The fix** follows the rule the same method already states for work and money
records: an address attached to a task **is not this person's record alone** —
it is where somebody else went to work, and the earner keeps that history. So it
is scrubbed rather than deleted. Coordinates are zeroed rather than nulled
because both columns are `NOT NULL`, which has the useful side effect that a
task from a deleted account falls outside every distance filter.

**What this says about the rest of the deletion path.** The same pattern —
`deleteByUser_Id` on a table something else references — is used four more times
in that method for preferences, notifications, connections and household
members. None of them threw today, because no demo account had rows in the
tables that reference them. That is luck, not proof.

⚠️ **Worth an explicit test**, and it is the one test in the codebase most worth
writing: create a user, give them a job, a quote, a notification, a household
and a connection, then delete the account and assert it succeeds. It would have
caught this on the day it was written.

---

### O-30. The schema went back to Hibernate, and what that costs

**2026-08-27.** After [O-28](#o-28), `ddl-auto=update` in both profiles and
`spring.flyway.enabled=false`. Recorded here because a future reader will find
twenty-two migrations in the tree and reasonably assume they run.

The instruction was explicit — *"any schema change shouldn't be done through sql
unless i say so only through spring boot"* — and it is a reasonable answer to
what happened: for a solo developer shipping daily, one hand-written SQL file
per column is a per-change tax that bought an outage.

⚠️ **What is genuinely lost**, so it is not discovered the hard way:

- **Renames and drops.** `update` only adds. A renamed field leaves the old
  column populated and nothing moves the data.
- **Reviewable schema history.** The change is now a diff on an entity rather
  than a file whose whole purpose is the change.
- **The order guarantee.** Flyway applies changes in a fixed sequence across
  every environment. Hibernate applies whatever the entities currently say,
  which is the same thing right up until two databases have diverged.

Data seeding moved to `ReferenceDataSeeder` — idempotent, guarded by a read,
never fatal. That is the sanctioned way to put rows in a table now.

⚠️ ~~**The profession catalog is still not owned by anything.**~~ **Wrong — I
checked the wrong places.** `InitServiceImpl` holds the whole catalog as Java:
50 professions, 104 sub-professions, 36 states and the countries. It runs from
`POST /admin-user/super-user/initial-setup`, and automatically when the account
`8191910695` signs up. A wiped database rebuilds itself.

I had searched for `new Profession(` and for seed files, and the catalog is
built from `AddProfessionDto` — so both searches missed it and I told the
product owner a database drop would lose 52 professions permanently. He said
the code had it. He was right.

⚠️ **One real gap did exist**, found by looking properly: the ten
`service_variant` rows — the wash / iron / wash-and-iron options under laundry,
and the cans and cylinders under the other doorstep services — came from
`V5__service_variants.sql` and were in no Java at all. Deleting the migrations
would have left Doorstep Services showing professions with nothing orderable
under them. They are in `ReferenceDataSeeder` now.

**What turning Flyway off silently dropped**, found the same day by running the
integration suite against a database built from nothing:

- **The `system-migration` audit actor**, the single INSERT in V1.
  `profession.UPDATED_BY` and `location_state.UPDATED_BY` are NOT NULL foreign
  keys onto it, so the first reference write on a fresh database fails.
- **Nine column defaults** declared in SQL and not on the entity. Hibernate
  created them NOT NULL with no default, and every raw INSERT that omitted one
  died with 1364 *"doesn't have a default value"*. JPA never hits this because
  it writes every column — which is exactly why nobody noticed.

⚠️ **Neither was visible on the live database**, which already had all of it
from the Flyway era. The divergence only exists between production and any
database built after the switch — the quietest possible failure, and the reason
`SchemaBuiltFromEntitiesTest` builds an untouched schema rather than reusing the
suite's.

⚠️ Declared against the live schema rather than from memory. `location_country
.IS_ENABLED` really is `tinyint(1) DEFAULT 0` and not a BIT like every other
flag, and guessing would have produced a fresh database that differed from
production in a way nothing would report.

---

### O-27. Seeding demo data means fighting our own rate limiters

Building the demo scenario took a dozen runs, and most of them failed on the
OTP limits rather than on anything wrong: **6 OTP requests per phone per hour,
40 per caller per hour, 5 verifies per phone per 15 minutes**. Each demo account
costs one of each per run.

⚠️ **I cleared `gasta-rate:otp-*` from production Redis** several times to keep
going. That is a live system and it is worth writing down: it resets nothing but
the counters, it affects no user data, and it would be the wrong habit if there
were real users.

```bash
sudo docker exec gasta-redis-1 sh -c   'redis-cli -a "$REDIS_PASSWORD" --scan --pattern "gasta-rate:otp-*" | xargs -r redis-cli -a "$REDIS_PASSWORD" DEL'
```

**The limits are correct** — they are what stops somebody's phone ringing all
night, and they did their job here. The problem is that a seeding tool and an
abuse limiter want opposite things from the same endpoint.

**Two ways out, when it next matters:**

- **A dev-only bypass keyed on a header the server only honours off production.**
  Small, and the kind of thing that leaks into production if it is not guarded
  by profile rather than by config.
- **Seed once and never re-run.** Most of my runs were fixing the script, not
  adding data. A local environment (`docker-compose.local.yml` exists) would
  have absorbed all of them.

The second is the honest answer: the script should have been debugged against a
local stack and pointed at production once.

**Size:** none today. Worth a note before anybody seeds again.

---

### O-26. ◐ ~~"Any" on the distance filter does not say so~~ ✅ label fixed 2026-08-26; **is 25 km right** is still a product decision

The Earning Zone's widest band is labelled **Any**. It is not: `DistanceBucket`
tops out at `VERY_LONG` = 9-25 km, so selecting Any asks for 0-25 km and
anything further is silently absent.

Found the hard way. Demo jobs were seeded at Bijnor while the test phone was in
Noida, 130 km away, and the screen said **"No jobs found nearby"** with Any
selected — which reads as "there is no work" rather than "there is work, further
than we will show you". The data was there the whole time.

**Why it matters beyond testing:** an earner in a small town with nothing within
25 km sees the same screen as an earner in a town with no jobs at all. The three
suggestions it offers — look further away, change working hours, pick more kinds
of work — are all things the user cannot use to fix it, because the cap is not
theirs to move.

**This is the same family as [PLAN-6 §L-3](PLAN-6.md)**: a distance number that
does not say what it means. Two things would fix it:

- **Say the cap.** "Any (up to 25 km)" on the chip, or "No jobs within 25 km" in
  the empty state. An afternoon, and it removes the dishonesty.
- **Decide whether 25 km is right.** It is a reasonable daily-commute bound for
  domestic work and probably wrong for a harvest crew that travels for a season.
  A per-profession ceiling would fit the existing rules machinery.

**Size:** the label is an afternoon. The band itself is a product decision.

---

### O-25. The version code was 1 in pubspec and 2001 on the phone

Installing on the product owner's handset failed with
`INSTALL_FAILED_VERSION_DOWNGRADE: Update version code 1 is older than current
2001`. Every APK built this session would have been refused by that phone.

`pubspec.yaml` said `version: 1.0.0+1`, so Android's **versionCode** was 1,
while the build already on the device carried 2001 — put there by some earlier
build passing `--build-number`. A versionCode may only ever go up.

⚠️ **The worse half is crash reporting.** Builds were being made with
`--dart-define=GASTA_APP_VERSION=1.0.0+2` while the installed app was
versionCode 2001. Every crash report would have been attributed to a build that
was never on anybody's phone — which is precisely the failure the comment on
`Constants.appVersion` warns about, happening anyway because two numbers that
must agree were set in two places.

**Fixed** to `1.0.0+2002`, with the constraint written into `pubspec.yaml`.

**Still open:** nothing enforces that `GASTA_APP_VERSION` matches `version:`.
Deriving it from pubspec at build time would need `package_info_plus` — a
dependency for one string, which rung 5 of the house rules says not to take. A
one-line check in the build command would do it, and belongs with CI (§C-1).

**Size:** done. The enforcement is an hour, with CI.

---

### O-24. Long profession names break mid-word on the tiles — ⚠️ my fix was worse, reverted

"Construction Laborer" renders as **"Constructio / n Laborer"** on the Post New
Task grid — Flutter breaks inside the word when a line will not fit, rather than
moving the whole word down.

Seen while fixing [L-7](PLAN-6.md). Anything long enough will do it; that tile
happens to be the first one that does.

**Why it matters:** it reads as a rendering fault, and this grid is how somebody
chooses what they are posting. It is also worse in Hindi, where compound
profession names are longer.

**The fix is a choice, not a bug hunt:** a slightly smaller label style on the
tile, or three lines instead of two, or shorter names in the catalog. The last
one is probably right for "Construction Laborer" — "Labourer" alone would do,
since the category heading already says Construction.

**Size:** minutes, once somebody picks.

**Fixed 2026-08-27 — and none of the three options above was the right one.**
All of them are a size somebody has to re-pick every time a name is added.

`FittedBox(fit: BoxFit.scaleDown)` on the three grid labels shrinks a label
only when it does not fit, never scales it up, and holds for Hindi — where
compound profession names are longer still.

⚠️ **Reverted the same evening. It was worse than the bug.**

`scaleDown` shrinks each label *independently*, so the Popular Pros grid came
out with "Maid" and "Painter" at full size next to "Construction Laborer" and
"Agricultural Machinery" visibly smaller. **Twelve identical tiles, six
different type sizes.** The product owner saw it immediately and was right: a
grid of matching cards with mismatched text reads as broken in a way that one
badly-wrapped word never did.

**What that teaches for the next attempt.** The constraint is not "make this
label fit" — it is **"every tile in the grid must share one size"**. So the fix
has to be chosen for the whole grid at once: measure the longest label, pick one
size that fits it, and apply that size to all twelve. Per-widget auto-fitting
cannot get there by construction, and neither can a shorter name in the catalog
— that fixes one tile and leaves the next to be found by a user.

⚠️ And it should be verified on a **device screenshot** before being called
done. This looked correct in code and in review, and was obviously wrong the
moment somebody looked at the screen.

---

### O-23. ~~Laundry is missing from Doorstep Services~~ ✅ fixed 2026-08-27 — ⚠️ regressed the same day on the wipe, see [O-31](#o-31)

The Doorstep grid lists **Cylinder and Heavy Item Delivery** and **Water
Supply**, both "Coming soon". Laundry and Appliance Mechanic do not appear at
all — though `V5__service_variants.sql` sets `SUPPORTS_PICKUP_DROP = TRUE` on
all four, and laundry is the service this whole feature was built around. The
banner icon on the screen is still a washing machine, left over from when it
was laundry-only.

**Why it matters:** the product owner's words are *"laundry is main in
doorstep"*. A customer opening Doorstep Services today sees two things that do
not exist yet and not the one that does.

**Most likely cause:** V5 matches laundry by the exact name `'Pickup Drop Cloth
Wash and Ironing'`, and **professions were never seeded by a migration** — V1 is
schema-only, so the table was populated some other way. If production's name
differs by a word, the `UPDATE` matched nothing and reported success.

⚠️ **Worth fixing at the root rather than by patching the name.** Professions
are catalog data the whole product depends on, and no migration owns them — so
nobody can say what a fresh database should contain. That is also why
`deploy/demo-data.py` asks the server which professions exist rather than
assuming any.

**Fixed by V20**, and the answer was almost the guess: the row exists under
exactly the name V5 looked for — "Pickup Drop Cloth Wash and Ironing" — and
`SUPPORTS_PICKUP_DROP` was simply never true on it. V5's UPDATE either ran
before that row existed or matched nothing for another reason; either way it
reported success.

V20 matches on **what the row is about** rather than one spelling — `LIKE`
against `wash`, `iron`, `laundr`, `dhobi`, excluding `automobile`/`car`/
`vehicle` so "Automobile Washer" is not swept in — and re-inserts the
WASH/IRON/WASH_AND_IRON variants if they are missing too, since those were
keyed on the same failed match. Idempotent.

It now shows on the grid, marked **Coming soon**, which is correct: no provider
has registered nearby. To test the booking flow somebody has to register as a
laundry provider first.

⚠️ **The underlying problem is untouched.** The catalog every screen depends on
is still owned by no migration, so nobody can say what a fresh database should
contain, and the next feature keyed on a profession name will fail the same
silent way. That is the part worth a day.

**Size:** done. Seeding the catalog properly is still open.

---

### O-22. ~~A single-option dropdown that is not a choice~~ ✅ answered 2026-08-26

The country code on the login screen is a `DropdownButtonFormField` whose
`items` list is `['+91']`. Tapping it opens a menu with one entry.

Found while fixing the clipping the font change caused (it rendered as "+9" —
Comfortaa is wider than the face the box was measured against, now fixed). The
clipping was a bug; this is a design question and not a developer's to answer.

**Why it matters:** it takes up a fifth of the row and looks like something the
user has to get right, on the very first screen. If India is the only market for
now, a fixed `+91` prefix inside the mobile field would be smaller, faster and
one less thing to be uncertain about.

**Against removing it:** if a second country is ever coming, taking the control
out and putting it back is churn, and users who learned where it was lose it.

**Answered in the feedback round: the control stays, but the list comes from
the database.** V19 adds `IS_ENABLED` and `DIAL_CODE` to `location_country`,
`GET /common/countries` returns the enabled rows, and India is the only one
enabled — so opening a second market is an UPDATE rather than a release.

While there is only one country the dropdown is **disabled** rather than
offering a menu with a single item, which was the actual complaint. It becomes
a real control the moment a second country is switched on.

See [PLAN-6 §L-6](PLAN-6.md).

---

### O-21. The build machine ran out of disk, twice, mid-upgrade

The Flutter 3.27 → 3.47 upgrade filled the C: drive completely. Every command
started failing — including the tooling's own, which could not write a temp
file — and Gradle reported it as *"daemon disappeared unexpectedly"* and
*"Could not download ... .jar"*, neither of which says "disk full".

Where it went, measured:

| | |
|---|---|
| `~/.gradle/caches` | **12.4 GB** — one subdirectory per Gradle version ever used |
| `~/.gradle/wrapper/dists` | **2.7 GB** — 8.3, 8.11.1, 8.12, 8.13, 8.14.3, all kept |
| Docker (WSL2 vdisk) | 6.9 GB reclaimable |
| `Yapan/build` | ~2 GB |

Freed ~9 GB by deleting the Gradle caches for versions no longer used
(`8.3`, `8.11.1`, `8.12`, `8.13`, `transforms-3`, `jars-9`) and the matching
wrapper distributions. **None of it is precious** — Gradle re-downloads what a
build actually needs.

```powershell
# Keep only the Gradle version the project uses; the rest are dead weight.
Get-ChildItem "$env:USERPROFILE\.gradle\caches" -Directory |
  Where-Object { $_.Name -match '^\d+\.\d+' -and $_.Name -ne '8.14.3' } |
  Remove-Item -Recurse -Force
Get-ChildItem "$env:USERPROFILE\.gradle\wrapper\dists" |
  Where-Object { $_.Name -notlike 'gradle-8.14.3*' } | Remove-Item -Recurse -Force
```

⚠️ **`docker system prune` reported 6.9 GB reclaimed and the free space on C:
did not move.** Docker Desktop's WSL2 virtual disk grows and never shrinks
itself, so pruning frees space *inside* the VM and returns none of it. "Prune
said it freed 7 GB" is misleading and it cost time here.

Compacting it did work, and it is the single largest reclaim available on this
machine — `docker_data.vhdx` went **16.57 GB → 8.22 GB**, taking C: from 3.6 GB
free to 13.1 GB. It needs admin:

```powershell
# Docker Desktop must be stopped first, and WSL shut down.
Get-Process "Docker Desktop","com.docker.backend" | Stop-Process -Force
wsl --shutdown
# then, as administrator:
#   diskpart
#   select vdisk file="%LOCALAPPDATA%\Docker\wsl\disk\docker_data.vhdx"
#   attach vdisk readonly
#   compact vdisk
#   detach vdisk
```

⚠️ Worth repeating every few months, not once. The vhdx regrows with every
image build, and `deploy.sh` builds one every time.

⚠️ **`docker system prune -af` was run**, so the next `deploy.sh` rebuilds the
API image from scratch — a slower first deploy, nothing lost.

**Worth doing:** this machine has 16 GB of RAM and was down to 1.7 GB free with
the emulator running, which is what killed the Gradle daemon before the disk
did. `org.gradle.jvmargs` was asking for 4 GB heap plus 2 GB metaspace; it is
now 2 GB plus 1 GB, which this project builds in comfortably.

⚠️ **The headroom is thinner than the numbers suggest.** After all of the
above, one emulator boot and three release builds took C: from 13.1 GB back down
to 5.8 GB in about forty minutes. Building and running an emulator at the same
time is roughly what this machine can do and no more.

**Size:** done, but it will recur — the caches grow with every toolchain bump
and the Docker vhdx grows with every deploy.

---

### O-20. The home IP changed and locked us out of the server

Mid-session on 2026-08-26 `deploy.sh` began timing out. Not the server — the
broadband address had rotated, 49.36.188.40 → 49.36.188.196, and the OCI
security list allows port 22 from one `/32`.

This was a known gotcha and it still cost time, because a connection timeout
looks identical to a dead host. Two things came out of it:

- **`deploy/allow-my-ip.py`** — points the rule at the current address in one
  command. It finds the SSH rule by port rather than by position (rule order is
  not stable, and an index would eventually move the wrong rule), and refuses
  rather than adding one if there is no port-22 rule to move.
- **The OCI command-line tool is not actually installed here.** The README told
  us to run `oci network security-list update`; only `~/.oci/config` and the API
  key exist. The script uses the Python SDK against the same config.

⚠️ What made this recoverable at all: only the *cloud* side restricts SSH by
address. The host's own iptables allows 22 from anywhere. A host-level IP rule
would have locked the machine away with no way back short of the serial console.
Worth remembering before anybody tightens it.

**Should the rule move to a wider range?** A `/24` covering the ISP pool would
stop this recurring, at the cost of allowing the whole pool to reach a port that
is key-only anyway. Left as-is; the script makes it a ten-second fix.

**Size:** done.

---

### O-19. Two startup warnings looked at; one is deliberate, one is real debt

Cleared three of the four warnings the server logs on boot (2026-08-26).

**Fixed:** the MySQL `TINYINT(1)` display-width deprecation (V18 aligns
`device_token` with the `BIT(1)` every other table uses), and both Hibernate
dialect warnings — `spring.jpa.properties.hibernate.dialect` is gone, because
Hibernate 6 picks the dialect from JDBC metadata including the server version,
which is more than a hardcoded name can do when MySQL is upgraded under us.

**`spring.jpa.open-in-view`** is now set explicitly to `true`, which is not the
right long-term answer and says so in a comment. Open-in-view keeps the
EntityManager open through response rendering, so a lazy association still loads
while Jackson serialises — which several endpoints returning raw entities depend
on. Turning it off is correct for a REST service and would surface those as
`LazyInitializationException`. That belongs with PLAN-6 §G's conversion to
projections, with a pass over every endpoint — not as a side effect of silencing
a warning.

**The Spring Security warning is deliberate and staying.** `Global
AuthenticationManager configured with an AuthenticationProvider bean.
UserDetailsService beans will not be used` — `AccessAppAuthenticationProvider`
calls `accessAppUserDetailsService.loadUserByUsername` itself, so the
`UserDetailsService` *is* used, just not by the path Spring is describing.
Restructuring a shared security library to quiet a message about a configuration
that works is a risk with no gain.

**Size:** the open-in-view change is a day of checking endpoints, and it is
PLAN-6 §G's day.

---

### O-18. 🟠 The OTP is `000000` for every phone number — **known, and held deliberately**

Found while trying to sign in on the emulator to test push, and it is the most
serious thing in this file.

`OtpServiceImpl.generateOtp()` (access-app) reads:

```java
if (appName.equals("Yapan")) {
    otp = new DecimalFormat("000000").format(new SecureRandom().nextInt(999999));
} else {
    otp = "000000";
}
```

`appName` is `@Value("${access-app-otp}")`, and `application.properties` line 89
says `access-app-otp=false`. `"false"` is not `"Yapan"`, so **the else branch is
what runs** — everywhere, including the live server. I signed up a working
account on production with the code `000000` and no SMS.

There is a second half to it. `sendOtp` ends:

```java
storeInRedis(mobNo, hashedOtp);
// TODO Send OTP to user
```

**No SMS is sent by anything.** So the two facts fit together: the fixed code is
what makes the app usable at all right now, and it is the only reason anybody
has been able to log in.

**Why it matters:** anyone who knows a Gasta user's phone number can sign in as
them and see their address, their household, their work record and their
earnings. It is not a weakness in the OTP, it is the absence of one. The rate
limit added this week (5 verify attempts per phone per 15 minutes) does nothing
here — the attacker needs one attempt.

**Decision, 2026-08-26: `000000` stays for now, for all numbers.** The product
owner is taking SMS up next week. Nothing here is being changed in the meantime,
because the fixed code is currently the only way anybody signs in.

That is a reasonable call while the only accounts are ours. It stops being one
the moment a real user has an account, so this stays open and loud until SMS
lands. **Do not put this build on a stranger's phone.**

**Two things, in order, when SMS is ready:**

1. Wire the provider (MSG91 and Fast2SMS are the usual Indian choices; both need
   DLT template registration, which is days of paperwork — start that first,
   it is the long pole, not the code). `sendOtp` has the seam already.
2. Set `access-app-otp=Yapan` so the random branch runs. ⚠️ Doing this *first*
   locks everybody out, including us, because nothing delivers the code. The
   order is not optional.

**Worth considering at step 2:** keep the fixed code working for an explicit
allow-list of test numbers. Otherwise every future test of the sign-up flow
needs a real handset and a real SMS, which is a slow way to test a screen.

**Size:** the config change is one line. The SMS integration is a day of code
and a week of DLT paperwork.

---

### O-17. ~~The app fails Android's 16 KB page-size check~~ ✅ fixed 2026-08-26

Every launch on the Android 16 emulator opens with a system dialog:

> This app isn't 16 KB compatible. APK alignment check failed.
> • lib/x86_64/libapp.so : Uncompressed library not aligned
> • lib/x86_64/libflutter.so : Uncompressed library not aligned
> • lib/x86_64/libdatastore_shared_counter.so : Unknown error

`libflutter.so` is the engine's own — nothing in our code causes this. Flutter
3.27.1 (December 2024) predates 16 KB alignment; Flutter 3.29 and later produce
aligned engines.

**Why it matters:** Google Play requires 16 KB page-size support for apps
targeting Android 15+, and this is a submission-time rejection rather than a
runtime failure. It also greets every user on a new phone with a system warning
dialog before they have seen the app.

**Fixed 2026-08-26 by the Flutter 3.47 upgrade** — there was no flag that would
make 3.27 emit an aligned engine, which is why this forced [O-11](#o-11-flutter-is-3271-from-december-2024)
rather than waiting for it. All 12 native libraries in the release APK are now
STORED, 16 KB-aligned in the zip, and linked with PT_LOAD alignment of 16384 or
65536. The Android 16 emulator no longer shows the warning dialog.

`Yapan/tool/check_16kb.py` is that check, kept as a pre-upload gate. Nothing in
a normal build or test run reports this, and a toolchain that is aligned today
is not guaranteed to stay aligned.

---

### O-16. The release APK is 60 MB

Measured after adding Firebase: `app-release.apk` is 60.3 MB, a single fat APK
carrying arm64, armv7 and x86_64 native libraries at once.

**Why it matters:** this audience is on metered mobile data and on phones with
little free storage. 60 MB is a download somebody thinks about, and thinking
about it is where installs are lost.

**The fix is nearly free.** An Android App Bundle (`flutter build appbundle`)
lets Play ship each phone only its own ABI — roughly 25 MB delivered instead of
60. Play requires AAB for new apps anyway, so this is on the path regardless.
`--split-per-abi` does the same for APKs distributed by hand.

**Asked 2026-08-26: does an App Bundle mean the phone downloads something extra
later? No.** Play splits the bundle at *install* time and hands the device one
install containing only its own ABI, screen density and language. Nothing is
fetched afterwards, nothing depends on a component being present, and it works
on every device that has the Play Store — which is every device that can run
this app, since it needs Play Services for FCM anyway. (The feature that *does*
download later is dynamic feature modules, which this app does not use and
should not.)

**iOS already does exactly this** and always has — App Store thinning ships each
device its own slice. Nothing to configure.

**⚠️ It only applies to Play.** A sideloaded APK — how the app gets onto a phone
today — is still a fat one. `--split-per-abi` produces per-ABI APKs for that
case; `app-arm64-v8a-release.apk` is the one for any phone worth testing on.

**Size:** a different build command, and a note in `deploy/README.md`.

---

### O-15. Nothing has verified that a push actually arrives

The registration half is proven end to end: the app requests
`POST_NOTIFICATIONS`, gets an FCM token, posts it, and the server logged
`register-device | 200 OK | Success | 9000000001`. The row is in `device_token`.

The **send** half — `FcmPushSender` minting an OAuth token from the mounted
service-account key and posting to FCM — is deployed with its key readable
inside the container, and has never run. Every notification in the product needs
a second party to trigger it (a job offer, a confirmation, a notice), and the
test account is alone on the system.

It is not silent if it fails: a refusal logs `FCM refused a push (<status>)`
with Google's reason, and a dead token is deleted rather than retried.

**The poll fallback is now verified**, which covers the half that fails
silently: the worker fired on schedule and its authenticated request reached
the server (`get-unread-notification-count | 200 OK | 9000000001`), so the Dart
background isolate, the entry point and the stored session all work.

What remains unproven is specifically **FCM delivering a push**.

**How to close it:** the first real notification between two accounts confirms
it. If nothing appears, `sudo docker logs gasta-api-1 | grep -i fcm` says why —
`FcmPushSender` logs Google's own refusal reason.

**Size:** none — it needs two accounts doing something, not code.

---

### O-14. ~~A test account sits on the production database~~ ✅ gone 2026-08-27

`9000000001` / "PushTest" / `gastapushtest@gmail.com`, created on 2026-08-26 to
verify push registration end to end, because there was no other way to obtain a
signed-in session on the live server.

Harmless, and worth deleting before real users exist so it never becomes a row
somebody wonders about. Deleting it also exercises the account-deletion path,
which is not a bad thing to have run once.

**Size:** one delete, whenever.

**Gone 2026-08-27**, along with everything else — the database was wiped and
rebuilt from code. It now holds `system-migration`, the setup account and the
five demo accounts, and nothing else.

---

### O-10. ~~"Set as home address" and "Delete address" did nothing at all~~ ✅ fixed 2026-08-26

Found while translating `address_screen.dart`. Both menu items ran a handler
that called **`GET /get-user-address`** — the *list* endpoint — and then showed
`"Address marked as home."` or `"Address deleted."` regardless of what came
back. One of them still carried a `// Optional: Refresh address list` note, so
the list did not even reload to reveal that nothing had changed.

**There are no such endpoints.** The server's only address routes are
`add-address`, `get-user-address` and `get-user-address/{id}`. Nothing on the
backend can set a home address or delete one.

So the app confirmed, twice, work that nobody did — including a **delete**, the
one action where a false confirmation is worst, because the user stops looking
for the thing they think they removed.

**Fixed.** `PATCH /set-home-address/{id}` and `DELETE /delete-address/{id}`
(V15), and the menu is back against them.

**Delete is soft**, at the product owner's instruction — `IS_ENABLED = false`.
That was the open design question and it is the right answer: addresses are
referenced by tasks, visits and doorstep orders, so a hard delete would be
refused by a foreign key or orphan the history. A worker's evidence that she
went to a particular house for three years must not depend on the household
never having tidied up its address list.

`IS_HOME_ADDRESS` had never been written by anything, so every row held NULL —
and NULL is neither TRUE nor FALSE, meaning a query for "the home address" and a
query for "not the home address" would *both* have found nothing. Both columns
are NOT NULL with a default now.

Verified against production: the row survives a delete with `IS_ENABLED=0`,
moving home clears the previous one, and another account gets a 400.

---

### O-13. ~~`google_maps_flutter` is a dead dependency~~ ✅ fixed 2026-08-26

The only `GoogleMap(` in the app is **commented out**
(`new_address_screen_2.dart`), along with its `onTap` handler. What remains is a
`_mapController` that is always null — correctly guarded, so nothing crashes —
and a dependency that still pulls the Google Maps SDK into every build.

**Why it matters:** the Maps SDK is one of the larger things an Android or iOS
app can carry, and this audience is on cheap phones and metered data. There is
also no Maps API key configured on either platform, so the map could not render
even if uncommented.

**Answered 2026-08-26 — the map is back, on OpenStreetMap.** The product owner
asked for a free alternative rather than paying for the Maps SDK, and
`flutter_map` + OSM tiles needs no API key, no billing account and no per-load
charge. `google_maps_flutter` is gone from the pubspec, `_selectLocation` does
what its note said it should, and the pin drops and reverse-geocodes.

⚠️ OSM's public tile server is a volunteer service with a usage policy — fine
at this scale, and something to move off (a paid tile host, or self-hosting)
before the app has real traffic. Noted in PLAN-6.

---

### O-12. ~~`POST_NOTIFICATIONS` is not declared~~ ✅ fixed 2026-08-26

Android 13+ requires it before an app may show a notification. It is absent from
the manifest, so the moment push or any local notification is added, nothing
will appear on a modern phone and nothing will say why.

**Fixed 2026-08-26**, with the feature rather than ahead of it. Declared in the
manifest, and `PushService.registerWithBackend` asks for it **after sign-in** —
not on first launch, because a prompt before the user knows what the app is for
is how an app gets a permanent no, and a denied notification permission can only
be reversed in system settings.

Verified on the emulator: the prompt appears once after sign-in, and granting it
is followed by `register-device | 200 OK`.

---

### O-11. ~~Flutter is 3.27.1, from December 2024~~ ✅ upgraded 2026-08-26

Everything is pinned to it, including the iOS minimum deployment target of 12.0
— which is why raising that target would break the build rather than modernise
it.

An upgrade wants doing **before** a store submission rather than after: target
SDK requirements, plugin compatibility and the iOS minimum all move together,
and discovering that during a release is the expensive time to discover it.

**Done 2026-08-26 — 3.27.1 → 3.47.1, Dart 3.6 → 3.13**, brought forward because
[O-17](#o-17-the-app-fails-androids-16-kb-page-size-check--fixed-2026-08-26)
made it a hard Play blocker rather than housekeeping.

149 packages upgraded, six with breaking API changes (`local_auth`,
`geocoding`, `flutter_local_notifications`, `geolocator`, `location`, and
Flutter's own Radio and l10n changes). The toolchain floors move together and
Flutter reports them one at a time: Gradle 8.14.3, AGP 8.11.1, Kotlin 2.2.20.

minSdk is **24** (Android 7), not the 23 it was — Flutter 3.47's default, and
flutter_local_notifications 22 declares 24 anyway. Android 10+ was the
requirement, so there is room.

⚠️ The explicit `minSdk = 23` and its reasoning were **deleted by the Flutter
migrator**, which replaced the line with `flutter.minSdkVersion`. That is how a
deliberate floor quietly becomes a toolchain default. Written out again.

⚠️ **The iOS deployment target has not been revisited.** It was pinned at 12.0
by the old Flutter and nothing here changed it; that belongs with §I and a Mac.

---

### O-1. ◐ Sign-up rejects every email except Gmail and Outlook — ✅ message fixed 2026-08-27, policy stands

**Answered 2026-08-26 — deliberate, and staying.** Those are what ordinary
people use; the long tail of other providers is where scam signups come from. So
this is a policy, not a defect.

The rule is **server-side**: `SignUpDto.java:27` carries
`@Pattern(regexp = "^[a-zA-Z0-9._%+-]+@(gmail\.com|outlook\.com)$")`, and the
app only shows the message the server sends back.

**One thing still worth changing:** the message reads like the address is
*invalid* rather than like a rule. "Please use a Gmail or Outlook address —
those are the ones we can verify" costs nothing and stops a legitimate user
thinking they mistyped.

**Why it matters.** The audience is rural and semi-urban India. Plenty of people
have a Yahoo address, a Rediff address, an address their employer or college
gave them, or one their nephew made on whatever was open at the time. This turns
them away at the second screen with a message that reads like their address is
invalid rather than like a policy.

Worth asking what the rule is *for*. If it is to block disposable domains, a
denylist does that without also blocking Rediff. If it is because only those two
providers are trusted to deliver, that reasoning disappears the moment email
stops being used for anything (nothing is sent to it today — OTP is SMS).

**Size:** the check is one condition. The decision is the work.

**Message fixed 2026-08-27; the policy stays**, as decided. It now reads *"We
only accept Gmail or Outlook addresses at the moment — those are the ones we can
verify. Your address is fine, it is our rule."*

⚠️ I hit this myself the same day: setting up the wiped database needed the
account `8191910695` to sign up, and `setup@example.com` was rejected with what
read like a malformed-address error. The message being wrong is not theoretical.

The underlying question in this entry is still open and still worth an answer:
**nothing is sent to the email address today**, so a rule justified by
deliverability is guarding a field nobody uses. Carried to PLAN-7.

---

### O-2. ~~An expired session returns 500, not 401~~ ✅ fixed 2026-08-26

Seen in the container logs on first launch with a stale token:

```
refresh-token | 500 INTERNAL_SERVER_ERROR | Could not refresh token.
payload: "Failure, exception occured: Invalid Session"
```

**Why it matters.** Three separate things:

- A session that has expired is the most ordinary thing that can happen to a
  token. It is a **401**. Returning 500 says the server broke.
- Any monitoring added later will treat this as an error rate. Every user who
  leaves the app for a week will generate one.
- `"Failure, exception occured: Invalid Session"` reaches the client. Besides
  the typo, PLAN.md T6.3 was a whole pass to stop internal text escaping into
  responses, and this one survived it.

PLAN.md T6.3 already corrected exactly this shape once — a wrong OTP returned
500 because the access library reports bad credentials that way, and it was
mapped to 401 in `LoginServiceImpl`. This is the same defect one endpoint over.

**Fixed** in `LoginServiceImpl.refreshToken`, the same way and for the same
reason as the wrong-OTP branch a few methods above: access-app *throws* for this
rather than returning a non-200, so it landed in the catch-all. Matched narrowly
on the message — the only signal the library gives — so a genuine fault is still
a 500, and anything unmatched is now logged with its stack trace instead of
disappearing. Deployed.

---

### O-3. ~~`ddl-auto=update` in development is a loaded gun~~ ⚠️ **reversed 2026-08-27 — see [O-30](#o-30)**

Production is on `validate` and starts clean. Development is still on `update`,
so Hibernate will silently create a column for a new `@Entity` field.

**Why it matters.** This has already gone off once. In PLAN-5 Phase 9 Hibernate
created the columns before Flyway ran, the migration then failed on a duplicate
column, wrote `success=0` into `flyway_schema_history`, and took down **every**
`@SpringBootTest` in the suite. The V14 comment says "write the migration before
the entity, deliberately" — which is the discipline `validate` would enforce for
free.

**The argument against** is real: `update` means adding a field does not stop you
mid-thought. But the migration has to be written before the change can ship
anyway, and `SchemaBuiltByFlywayOnlyTest` only catches it at test time, which is
later than the moment you would rather know.

**Fixed** at the product owner's instruction — *"I always want the Spring Boot
entities to match the actual DB schema."* Development is on `validate` now.

Day to day: **write the migration first, then the entity.** Add a field without
one and the application will not start, naming the column it cannot find — ten
seconds after the change rather than on a deploy weeks later. Both V15 and V16
were written that way.

---

⚠️ **This entry is history. It was undone the next day and the advice above is
now wrong** — do not write a migration.

The Flyway era lasted about thirty hours. On 2026-08-27 a hand-written migration
used `ALTER TABLE ... ADD COLUMN IF NOT EXISTS`, which is MariaDB syntax MySQL
rejects, and the failed row Flyway recorded then blocked every start including
the previous image ([O-28](#o-28)). The product owner reversed the policy:
`ddl-auto=update`, Flyway off, **no hand-written SQL**. See [O-30](#o-30) for
what that costs and what moved to `ReferenceDataSeeder` to cover it.

Worth keeping the entry rather than deleting it, because the argument it makes
is still the correct argument — `validate` really would have caught a missing
column in ten seconds. What it did not weigh is that the same mechanism turns a
typo in a SQL file into an outage that a rollback cannot fix, and that a solo
developer shipping daily pays the per-change tax on every single column.

---

### O-4. ◐ Whole screens were still English — mostly fixed 2026-08-26

PLAN-5 Phase 4 was "Hindi where the money is" and reached the money screens. It
did not reach these, and the gap is most visible exactly where it hurts most —
the **sign-up screen**, which is the second thing a brand-new user ever sees, is
entirely English: *Full Name · Email · Date of birth · OTP · Proceed · Hi,
Welcome to Gasta · Login to your account*.

Others found while working nearby:

| Screen | State |
|---|---|
| `signup_screen.dart` | ✅ done |
| `user_account_screen.dart` | ✅ done — 31 strings |
| `job_sheet_screen.dart` | ✅ done — 33 strings, and the hand-rolled `_plural` replaced with ICU forms |
| `task_visits_screen.dart` | ✅ done — 59 strings |
| `posted_tasks_screen.dart` | ✅ done |
| `grievance_screen.dart` | ✅ done |
| login screen | ✅ done — and three copies of the legal-document labels became one shared lookup |
| **everything else** | **not audited.** These were the screens noticed in passing; nobody has walked the whole app counting. |

The ARB files went from 467 keys to **720**, English and Hindi in exact parity.

**Why it matters.** A half-translated app is arguably worse than an English one:
it looks like it speaks Hindi, so somebody commits to it, and then the screen
where they have to type their name does not.

**What is left** is an audit rather than a task: no one has walked every screen
with fresh eyes to see what was missed. That is a job for somebody using the app
in Hindi and writing down what jumps out — which is exactly what the next round
of feedback will be.

**The recurring trap**, worth restating because it caught two screens: text that
is *composed* cannot be translated. The posting wizard compared against the
English words on screen to decide which fields to draw; the visits screen glued
`"$when"` and `", $slot"` onto a sentence with adjacent-string concatenation.
Both had to be restructured before a single word could be replaced.

---

### O-5. Profession names reach the app as English prose

`Maid`, `Chef/Cook`, `Agricultural Machinery`, `Sweep-Mop` — the `profession`
table has `NAME` and no code, so there is nothing for the app to translate
against. This is **PLAN-5 Phase 14 item 11**, half of which is now done (`Slot`
labels), and it is listed here because it is the most visible remaining English
on otherwise-Hindi screens: the home grid, the wizard's first step, and the work
record card.

**Not purely mechanical.** For several the Hindi *is* the common word (मिस्त्री),
and for others the English is what people actually say. Inventing fifty
translations without somebody who knows local usage would produce a worse
result than leaving them.

**Size:** a migration and a map, plus a content decision.

---

### O-6. The DuckDNS token was pasted into a chat log

`efea25dc-…` was shared in conversation on 2026-08-26 to configure the deploy.
It is in `deploy/.env` (gitignored) and works, but a DuckDNS token can repoint
the domain at anybody's server, and it now exists somewhere other than the
places secrets are supposed to live.

**Size:** one click. Regenerate it at duckdns.org and update `deploy/.env` on the
server. Worth doing before the domain points at anything real.

---

### O-7. ~~The clock picker reads "PM 11:25"~~ — looked at, and it is not a bug

`digitalClockPicker` renders `selectedTime.format(context)`, which asks
`MaterialLocalizations` for the pattern. **Hindi genuinely puts the meridiem
first** — so the order is the locale doing its job, not the widget getting it
backwards, and forcing English ordering onto a Hindi screen would be the actual
defect.

What is worth a second look is that the marker rendered as the English "PM"
rather than अपराह्न. That is a localisation-data question, not a layout one.
Left here because "we looked at this and it was fine" is worth writing down.

---

### O-8. `HealthController` explains itself with a reason that may have expired

Its comment says Actuator was not used because "the cached artifact on this
machine is 3.1.2 against a 3.3.3 application, and the build runs offline". That
was true when written. If the dependency resolves now, Actuator would give
readiness/liveness probes properly — which matters more once this is a container
that an orchestrator restarts.

Not urgent: the hand-written endpoint does a real database round trip and is the
one the container healthcheck uses, so it is doing its job. But the comment is a
`TODO` wearing an explanation, and somebody should check whether the reason
still holds.

**Size:** check the dependency; then either delete the paragraph or keep it.

---

### O-9. ~~A stale build artifact sits in `target/`~~ ✅ fixed 2026-08-27 — and it bit first

`gasta-api-0.1.0-SNAPSHOT.jar`, dated 2026-07-19, beside the current
`Yapan-0.0.1-SNAPSHOT.jar`. Harmless — `Dockerfile` names the jar explicitly —
but a `target/` with two fat jars in it is a directory where somebody eventually
ships the wrong one.

**Size:** `mvn clean` once.

**Fixed 2026-08-27, and it was not cosmetic.** The full suite failed with 18
errors — `NoClassDefFoundError: ScheduleExpansionServiceImpl$1`, an anonymous
inner class that a stale `target/` no longer held. Nothing was wrong with the
code: `mvn clean test` passes 84 tests. ⚠️ **That is the real cost of stale
build output** — it produces failures that look like defects in files nobody
touched, and the reflex is to go looking for the bug rather than to clean.

CI is unaffected: a fresh runner has no `target/` to be stale.

