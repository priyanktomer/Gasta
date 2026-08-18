# Gasta — UI Design Rules

Binding rules for every screen in `Yapan/`, and for the API shapes that feed
them. Referenced from [PLAN.md](PLAN.md) §0.1, so every phase task inherits it.

**Who this is for.** A large share of our users are rural, unskilled, and read
slowly or not at all. They learn a screen the way you learn a light switch: *the
thing I want is in that spot*. Anything that changes where a control lives
destroys that learning and puts them back at zero.

Nothing here is about taste. Each rule exists because a moving element costs a
real user a real task.

---

## 1. Controls live in fixed positions

**Rule:** a control must occupy the same screen position every time the screen is
opened, and must not move while the user is looking at it.

### Banned

| Pattern | Why |
|---|---|
| Horizontally scrolling chip/tab rows (`SingleChildScrollView(scrollDirection: Axis.horizontal)` over tappable controls) | Options past the third are invisible until you know to swipe, and every option's position depends on the scroll offset. |
| `Wrap` over controls whose labels can change length | Re-flows to a different row when a label or language changes. |
| Carousels / `PageView` as the *only* way to reach content | The thing you want is at an offset you cannot see. |
| Controls that appear only after scrolling, when they are the screen's primary action | The primary action must be reachable without hunting. |
| Reordering a list as a side effect of an action | The card you just acted on jumps somewhere else. |

### Required

- Use **`Widgets.buildFixedFilterBar`** for every filter / segment control. It
  lays options out in a fixed grid (default 3 per row, equal widths, no
  scrolling) and holds empty trailing cells open so the last row cannot
  re-centre.
- Give each option an **icon** as well as a label (`icons:` parameter). A user
  who cannot read the word can still find the shape, and the shape is always in
  the same cell.
- Minimum tap target **48dp**. `buildFixedFilterBar` enforces this.
- If a set of options genuinely cannot fit on one screen, that is a signal there
  are too many options — cut them, don't add a scrollbar.

### Applied so far

| Screen | Was | Now | Verified |
|---|---|---|---|
| `earner_tasks_screen.dart` | 5 chips, horizontal scroll | fixed 3+2 grid + icons | emulator |
| `posted_tasks_screen.dart` | 5 chips, horizontal scroll | fixed 3+2 grid + icons | emulator |
| `earner_quotations_screen.dart` | 3 chips, horizontal scroll | fixed 1×3 row + icons | emulator |
| `received_quotes_screen.dart` | 2 chips in a bare `Row` (could overflow) | fixed 1×2 row + icons | code |
| `new_task_page.dart` day picker | 7 `ChoiceChip`s in a `Wrap` | fixed 4+3 grid, `Mon`…`Sun` labels | emulator |
| `job_sheet_screen.dart` dashboard chips | `Wrap` — re-flowed as counts gained digits | fixed 2×2 grid | emulator |
| `widgets.dart` `checkBoxGroup` | checkboxes even when single-select | radios when `allowSingleSelect` | emulator |
| `bottom_navigation.dart` | rebuilt the screen on every tab switch | lazy `IndexedStack` | emulator |

`grep -rn "scrollDirection: Axis.horizontal" lib/` returns nothing; no
`FilterChip`/`ChoiceChip` remains in a filter bar; and the only `Wrap` left in
`lib/` is over two `Text` widgets in `worksheet_screen.dart`, not over controls.
Keep all three true.

`singleSelectChoiceChip` and `multiSelectChoiceChip` (the `Wrap`-based helpers)
were **deleted** rather than left unused, so the banned pattern cannot come back
by autocomplete. Use the `*Grid` variants; both take `crossAxisCount`.

**Watch the aliasing.** `multiSelectChoiceChipGrid` mutates the selection list it
is given and passes *that same object* to `onChange` — it is not a copy. A
callback that does `mine..clear()..addAll(selected)` therefore empties the
selection. Just `setState(() {})`; the list is already correct. `flutter
analyze` says nothing about this; the emulator showed it immediately.

**Implementation note:** `buildFixedFilterBar` wraps each row in an
`IntrinsicHeight`. `CrossAxisAlignment.stretch` inside a `Column` otherwise asks
for infinite height and the entire screen fails to lay out — which `flutter
analyze` does not catch. This is why §6 requires an emulator check.

### Known remaining deviations

- `worksheet_screen.dart` uses a `PageView` to move between nearby jobs. It has
  tap-left / tap-right zones as well as swipe, so the *controls* are fixed even
  though the content pages. Acceptable for now; revisit when that screen is
  reworked.
- `laundry_booking_screen.dart` uses a `DraggableScrollableSheet`. Same
  reasoning — the sheet moves, its buttons do not.

Do not add new instances of either pattern.

---

## 2. Lists come back in the same order every time

**Rule:** every query that feeds a list must have a total, deterministic sort. An
unordered query lets the database choose, so the same list can return in a
different order on the next fetch — and after an action, cards visibly swap.

- Visit queries sort on **(occurrenceDate, slot, id)** — date alone leaves ties
  to the database.
- Task lists sort **oldest-first** (`OrderByCreatedDateAsc`). A card the user has
  learned the position of keeps that position permanently; a new task appends at
  the end rather than pushing every existing card down. This is a deliberate
  trade against "newest first" — revisit only with a reason.
- Catalog reads sort by name (PLAN.md T0.8). Alphabetical here means *stable*,
  not final; real popularity ordering is T8.6 and must still be deterministic.
- Never sort in Java after fetching unless the sort is also total. `groupingBy`
  into a `HashMap` keyed by an enum reshuffles between JVM runs — use `TreeMap`.

---

## 3. One primary action, always in the same place

- A card's primary action is **one full-width button at the bottom of the card**,
  labelled with the single next step ("On my way", "I have arrived", "Start
  work", "Mark done"). No dropdowns, no status pickers, no free text.
- Secondary actions sit below the primary one, visually de-emphasised
  (outlined, not filled) — never beside it, where the two compete.
- Destructive or rarely-used actions belong in the app bar, not in the card.

---

## 4. Dialogs and sheets

- Anything that can overflow must be wrapped so it cannot. Five 38px stars
  overflowed a dialog by 8px on a 720px screen; a `FittedBox` fixed it.
- Every modal must be dismissible without completing it ("Skip" / "Cancel"), and
  the dismiss control goes in the same corner every time.
- Never trap a user: if a flow can fail because someone else is unavailable,
  give an explicit escape hatch (e.g. the "Customer not available" link on the
  start-code sheet).

---

## 5. Text

- No text-only affordances for anything a user must find repeatedly — pair with
  an icon.
- Backend must send **codes plus labels** (`status` + `statusLabel`,
  `slot` + `slotLabel`) so the app can supply its own wording in Phase 9 without
  a backend change. Never send prose the client has to parse.
- Avoid ambiguous abbreviations. Single-letter day chips (`M T W T F S S`) have
  two `T`s and two `S`s and are English-only — replacing them is T9.4.

---

## 6. Checklist for any new screen

- [ ] Every control is in a fixed position; nothing tappable scrolls sideways.
- [ ] Filters use `Widgets.buildFixedFilterBar` with icons.
- [ ] The list query has a total, deterministic sort.
- [ ] Tap targets are ≥48dp.
- [ ] One primary action per card, full width, at the bottom.
- [ ] Nothing overflows at 720×1280 (the `Small_Phone` AVD).
- [ ] Verified in the emulator, not just `flutter analyze`.

## 7. Numerals are always Latin digits (T9.7)

**Rule.** Amounts, dates, times, phone numbers, counts and OTPs are rendered in
Latin digits — `500`, `30-Jul-2026`, `9000000001` — in **every** language,
including Hindi and every regional language added later. Never Devanagari or any
other local numeral set.

**Why.** Money and phone numbers are read in Latin digits by essentially
everyone in this market, including people who read no Latin letters at all. A
digit set that changes with the interface language is a new thing to learn at
exactly the moment somebody is deciding whether to trust a number. Mixed
numerals — a Devanagari amount beside a Latin phone number on the same card —
are a documented source of misreading a figure by a factor of ten, and this app
shows amounts and phone numbers side by side constantly.

**How it binds.** The Hindi ARB file uses Latin digits in every placeholder and
literal. `Task.monthlyEstimate` groups with Indian conventions (`₹15,000`,
`₹1,50,000`) but in Latin digits. Do not pass a locale to `NumberFormat` that
would substitute digits, and do not add a per-language numeral setting: the
whole value of this rule is that it is decided once and never varies.

**Not covered.** Ordinals and words for numbers in prose ("one worker", "एक
मज़दूर") are translated normally — this rule is about digits, not about counting
words.

---
