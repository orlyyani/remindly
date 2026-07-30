# CLAUDE.md — Reminders / Vehicle & Life Maintenance App

This file is guidance for Claude Code (or any AI coding assistant) building this app.
Read it fully before writing code. Follow the decisions here unless the user overrides them.

---

## 1. What we're building

A dead-simple personal reminder app for recurring things that are easy to forget.
The anchor use case is **vehicle maintenance and renewals** (car PMS, motorcycle
maintenance, LTO registration renewal, insurance renewal), but the same mechanism
also covers **personal recurring dates** (birthdays, anniversaries).

The core idea: everything in the app is the same kind of thing — **a named event
that repeats on a schedule, and reminds you a set number of days before it's due.**

The whole point of the app is that the user adds something once and then *forgets
about it* — the app is responsible for nudging them in time. If the user has to
remember to open the app to stay on top of things, the app has failed.

### Guiding principles
- **Simplicity over features.** A very straightforward, uncluttered UI. No hassle.
- **Offline-first, local source of truth.** All reminder data lives on the device
  (Hive) and notifications are scheduled locally. The app never *requires* an
  account, server, or internet to do its job.
  - **Updated by the user:** optional, opt-in *online* features may layer on top
    as long as the core stays fully functional offline and the app remains the
    notifier. Shipped so far: **local file backup/restore** and **Google Calendar
    sync** (the app calls the Calendar API directly — **no self-run backend / no
    AWS / no Laravel**). See §10.
- **Reliability of reminders is the #1 feature.** If notifications don't fire
  dependably (including after a phone reboot), nothing else matters. Calendar sync
  is a *mirror*, never a replacement for local notifications.

---

## 1b. Repo status & commands

> **Current status (2026-07-24):** shipped and running on a real device (Xiaomi 12,
> Android 15). The app has been rebranded **"Remindly"** with a purple + orange
> design (see §5/§10). Sections 2–9 below are the *original spec*; where they
> disagree with what's built, **§10 is authoritative.**
>
> - Flutter **3.44.8** (stable), Dart **3.12.2** — via Homebrew at `/opt/homebrew/bin`.
> - JDK **openjdk@17**; Android SDK at `~/Library/Android/sdk` (build-tools **36**).
>   Toolchain env vars are in `~/.zshrc`. **Xcode not installed** — iOS deferred.
> - **Verified on device:** local notifications fire (incl. the scheduled path);
>   Welcome, Upcoming, New Reminder, Detail, Settings all render. Old data migrates
>   safely (Hive `defaultValue`). `flutter analyze` clean, tests pass, release APK builds.
> - **Still unverified:** reboot-survival test; Google Calendar live sign-in (needs
>   the OAuth client — see `docs/google_calendar_setup.md`).
> - Note: sideloading to Xiaomi/MIUI requires approving an "Install via USB" prompt,
>   and each fresh install may clear app data (normal for dev installs).

Everyday commands:

```bash
flutter run                       # run on connected device / emulator
flutter analyze                   # static analysis / lint
dart format .                     # format
flutter test                      # run all unit/widget tests
flutter test test/utils/date_math_test.dart         # run a single test file
flutter build apk --release       # sideloadable APK
dart run build_runner build --delete-conflicting-outputs   # regen Hive adapters

# Build with Google Calendar sync enabled: the Web OAuth client id lives in a
# gitignored dart_defines.json (copy dart_defines.example.json). Always pass it
# so a plain build doesn't silently disable sync ("Not set up on this build yet").
flutter build apk --release --dart-define-from-file=dart_defines.json
```

The date/recurrence math (`lib/utils/date_math.dart`) is the "brain" — unit-tested
in `test/utils/`. Notification firing / reboot behaviour must be trusted only on a
**real Android device**.

Everyday commands:

```bash
flutter run                       # run on connected device / emulator
flutter analyze                   # static analysis / lint
dart format .                     # format
flutter test                      # run all unit/widget tests
flutter test test/utils/next_occurrence_test.dart   # run a single test file
flutter test --plain-name "advances 6 months"       # run tests matching a name
flutter build apk --release       # sideloadable APK for the user's phone
dart run build_runner build --delete-conflicting-outputs   # regen Hive adapters
```

The date/recurrence math (`lib/utils`) and notification-time computation are the
"brain" of the app — cover them with unit tests (section 7). Notification firing
and reboot rescheduling can only be trusted after verifying on a **real Android
device**, not an emulator.

---

## 2. Tech stack (decided)

- **Framework:** Flutter (Dart). One codebase, targets Android first; keep an
  eventual iOS build possible (don't do anything Android-only in the app logic
  unless necessary, isolate platform specifics).
- **State management:** Keep it simple. `provider` or Riverpod is fine; do not
  introduce heavy architecture. For an app this small, plain `setState` +
  a small repository class is acceptable.
- **Local storage:** Use a lightweight local DB. Recommended: **Hive** (simplest)
  or **Isar/Drift** if the assistant prefers typed queries. Do NOT use any
  cloud/remote database.
- **Notifications:** `flutter_local_notifications` + `timezone` package for
  correct scheduled (zoned) notifications.
- Target a **recent stable Flutter SDK** and recent stable Android (compileSdk
  current). Confirm versions at build time.

---

## 3. Data model

One central entity. Call it `ReminderItem` (adjust naming as idiomatic).

Fields:
- `id` — unique id.
- `title` — e.g. "Car PMS", "LTO Registration", "Mom's Birthday".
- `category` — enum/string for grouping and color: e.g. `car`, `motorcycle`,
  `personal`. Keep the list editable/extensible but ship with these three.
- `notes` — optional free text (plate number, insurance policy #, shop name, etc.).
- `nextDueDate` — the next date this is due (DateTime, date-level granularity).
- `recurrence` — how it repeats:
  - `type`: `none` (one-time), `everyNMonths`, `everyNYears` (and optionally
    `everyNDays`/`everyNWeeks` for flexibility).
  - `interval`: integer N (e.g. every **6** months for PMS, every **1** year
    for registration/insurance/birthday).
- `leadTimes` — one or more "remind me this many days before" values.
  Default: **7 days before**. Allow the user to add extra nudges (e.g. also
  **1 day before**) especially for renewals. Store as a list of ints (days).
- `notificationTimeOfDay` — what time of day the reminder fires (default e.g.
  09:00 local). A single app-wide default is fine for v1; per-item is a nice-to-have.
- `isActive` — bool, so the user can pause an item without deleting it.
- `lastCompletedDate` — optional, set when the user marks it done.

### Recurrence behavior
- When the user marks an item **done** (or when its due date passes), compute the
  **next** `nextDueDate` by advancing from the due date by the recurrence interval,
  and reschedule notifications.
- For yearly items tied to a fixed calendar date (birthdays, registration month),
  advancing by 1 year should keep the same month/day.
- Handle edge cases: Feb 29, end-of-month rollovers — clamp sensibly.

> NOTE: There is intentionally **no odometer / mileage tracking**. PMS is handled
> purely as a time interval (e.g. "every 6 months"). This was a deliberate scope
> decision to keep the app simple and reliable. Do not add mileage logic in v1.

---

## 4. Notifications (get this right)

This is the highest-risk area. Implement carefully.

- Use `flutter_local_notifications` with `zonedSchedule` and the `timezone`
  package. Initialize timezone data on startup and resolve the device's local zone.
- For each active item, schedule a notification for **each lead time**
  (dueDate − leadTimeDays at the configured time of day). Skip times already in
  the past.
- **Android permissions / manifest:**
  - `POST_NOTIFICATIONS` runtime permission (Android 13+) — request on first run.
  - Exact alarms (Android 12+): request/handle `SCHEDULE_EXACT_ALARM` /
    `USE_EXACT_ALARM` appropriately, or fall back to inexact scheduling with a
    clear rationale. Prefer exact for date-sensitive reminders.
  - `RECEIVE_BOOT_COMPLETED` — **reschedule all notifications after device reboot**,
    since local schedules are cleared on reboot. Implement a boot receiver /
    on-launch reconciliation that rebuilds the schedule from stored items.
- On every app launch, **reconcile**: recompute what should be scheduled from the
  stored items and (re)schedule. Treat the stored items as the source of truth,
  notifications as derived state.
- Tapping a notification should open the app to that item.

---

## 5. Screens / UX

Keep it to a few screens. Minimal, clean, readable at a glance.

1. **Home / list** — the main screen.
   - A list of upcoming reminders sorted by due date (soonest first).
   - Each row: title, category color/icon, due date, and a friendly "in X days"
     or "due today"/"overdue" label.
   - Optional grouping or filter chips by category (Car / Motorcycle / Personal).
   - A prominent "+" to add a new reminder.
   - Quick action to mark an item **done** (which rolls it to its next occurrence).
2. **Add / edit reminder** — a single simple form:
   - Title, category, next due date (date picker), recurrence (type + interval),
     lead time(s), optional notes, active toggle.
   - Sensible defaults so a new item can be created in seconds
     (e.g. category Car, every 6 months, remind 7 days before).
3. **Settings** (small) — default reminder time of day, default lead time,
   manage categories (optional), maybe a "test notification" button.
4. (Optional) **Item detail** — view one item, its history / next occurrence,
   edit or delete.

### Visual style
- Clean, modern Material 3. Light and dark mode.
- Category → color coding for fast scanning.
- Big legible dates and "days remaining." Prioritize glanceability.
- No login screen, no onboarding walls. Open → see your reminders → add one.

---

## 6. MVP scope (build this first)

Ship the smallest thing that actually removes the "I forgot" problem:

1. Add / edit / delete reminders with the fields above.
2. Persist them locally (survives app restart).
3. Recurrence: one-time, every N months, every N years.
4. Local notifications at a default lead time (7 days before), reliable and
   surviving reboot.
5. Home list sorted by soonest due, with "in X days" labels and mark-as-done that
   rolls to the next occurrence.

Get that working end-to-end and installed on a real phone before adding polish.

### Later / nice-to-have (not v1)
- Multiple lead times per item and per-item notification time.
- Per-vehicle grouping and a vehicles concept (v1 can just use categories).
- Editable categories with custom colors/icons.
- LTO registration helper: derive the renewal month from plate number ending
  (Philippines schedule) instead of manual entry.
- Backup/export & restore (e.g. export to a file) — still no server.
- Home-screen widget showing the next due item.
- iOS build.

---

## 7. Suggested project structure

```
lib/
  main.dart
  models/            # ReminderItem, Recurrence, Category
  data/              # local DB / repository (Hive boxes, etc.)
  services/          # NotificationService (schedule/cancel/reconcile)
  screens/           # home, add_edit, settings, (detail)
  widgets/           # reusable UI pieces (reminder tile, category chip)
  utils/             # date math (next occurrence), formatting
```

Keep date/recurrence math in one well-tested place (`utils`) — it's the brain of
the app. Write unit tests for the "compute next occurrence" and "compute scheduled
notification times" functions; these are where bugs hide.

---

## 8. Getting started

```bash
flutter create . # or start a fresh project and merge
flutter pub add flutter_local_notifications timezone hive hive_flutter
flutter pub add --dev hive_generator build_runner   # if using Hive typed adapters
flutter run
```

- Test notifications on a **real Android device** (emulators can be unreliable for
  scheduled/exact alarms and reboot behavior).
- Verify the reboot case: schedule something, reboot the phone, confirm it still fires.
- The app can be **sideloaded onto the user's own phone** (`flutter build apk`
  then install) — Play Store publishing is optional and a later, separate step.

---

## 9. Working agreement for the AI assistant

- Favor clarity and small, readable files over cleverness. This is a first app for
  the user; keep the code approachable and commented where non-obvious.
- **No self-run backend, analytics, or ads.** Network calls are allowed *only* for
  opt-in features the user has approved (currently Google Calendar sync, via the
  Google API directly from the device). Keep every such feature optional and
  best-effort — the app must work fully offline with it turned off. Do **not**
  stand up AWS/Laravel/etc. for this app (the user weighed and rejected that).
- Don't reintroduce mileage/odometer tracking.
- When a decision isn't specified here, pick the simplest reasonable option and
  note it, rather than blocking.
- Prioritize getting a working, installable app on the user's phone early, then iterate.

---

## 10. As-built architecture & decisions (authoritative — supersedes 2–9 on conflict)

The app grew beyond the original MVP at the user's direction. Current reality:

### Branding & design
- Named **"Remindly"**. Material 3, **purple primary (#6C5CE7) + orange accent
  (#F5A623)**, warm off-white surfaces, pastel category tints, soft shadows, and a
  hand-painted alarm-clock mascot (`widgets/alarm_clock.dart`, no image assets).
  Theme in `lib/theme/app_theme.dart`.
- A **one-time, skippable Welcome screen** exists (Get Started / Restore). This
  intentionally overrides the old "no onboarding" rule — it is *not* a wall.

### Screens (`lib/screens/`)
- `welcome_screen` → `home_shell` (bottom nav: **Upcoming · Calendar · center + · Done ·
  Settings**). `upcoming_screen` (greeting + featured card for the soonest/overdue
  item + soft "Next up" cards + empty-state with quick-add suggestion chips),
  `detail_screen` (status, mark-done incl. keep-original-schedule, snooze, history,
  nudge plan), `add_edit_screen` (Name/Group/Repeats/last-done/Nudge, live "next
  due / first nudge"), `calendar_screen`, `done_screen`, `settings_screen`.

### Data model — `ReminderItem` (Hive typeId 0) beyond the original fields
- Enums stored as primitives: `categoryName` (String), `recurrenceTypeIndex` (int).
- `notificationBaseId` (stable id range for this item's notifications).
- `completions` (`List<CompletionRecord>`, typeId 1) — history with on-time/late.
- `snoozedUntil` (DateTime?), `escalateWhenOverdue` (bool, **defaultValue: true** so
  upgrades read old data safely), `googleEventId` (String?, calendar mirror id).
- **Adding a new persisted field:** give non-nullable fields a `defaultValue` in the
  `@HiveField` annotation, then re-run build_runner — otherwise old records crash.

### Notifications (`services/notification_service.dart`)
- `flutter_local_notifications` **v22** (all-named params: `zonedSchedule(id:,
  scheduledDate:, notificationDetails:, …)`), `timezone` + **flutter_timezone v5**
  (`getLocalTimezone().identifier`). Core-library desugaring is enabled in Gradle.
- Per item: lead-time nudges + **escalating daily nudges once overdue** (bounded),
  or a single nudge when **snoozed**. Copy is friendly/category-aware
  (`utils/friendly_copy.dart`). App is the sole notifier.

### Persistence & sync (`lib/data/`)
- `reminder_repository` is the single mutation point; keeps notifications AND (best-
  effort) the calendar mirror in sync on every change.
- `backup_service` — **local file** export/restore of everything as JSON via
  `share_plus` + **`file_selector`** (NOT file_picker — its old versions break the
  Gradle build). This is the "Restore" on Welcome and in Settings.
- `google_calendar_service` — optional mirror via **google_sign_in v7** +
  **googleapis** + `extension_google_sign_in_as_googleapis_auth`. Events use RRULE
  and carry **no reminders** (no double-nudge). Gated on `GOOGLE_SERVER_CLIENT_ID`
  (dart-define); off ⇒ Settings shows "Not set up on this build yet". Setup steps:
  `docs/google_calendar_setup.md`.

### Settings extras
- Optional local **display name** (greeting only, no account), test notification,
  default time/lead, backup/restore, Google Calendar connect/disconnect/sync.

### Known follow-ups
- Reboot-survival test on the physical device; custom launcher icon (still default
  Flutter icon); editable/custom categories (the "+" group chip) intentionally omitted.
