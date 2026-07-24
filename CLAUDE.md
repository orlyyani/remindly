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
- **No account, no server, no internet required.** All data lives on the device.
  Notifications are scheduled locally. This is a strict requirement, not a preference.
- **Reliability of reminders is the #1 feature.** If notifications don't fire
  dependably (including after a phone reboot), nothing else matters.

---

## 1b. Repo status & commands

> **Current status (2026-07-24):** toolchain installed and project scaffolded.
> - Flutter **3.44.8** (stable), Dart **3.12.2** — via Homebrew at `/opt/homebrew/bin`.
> - JDK **openjdk@17** at `/opt/homebrew/opt/openjdk@17/...`; Android SDK at
>   `~/Library/Android/sdk` (platform + build-tools **36**, platform-tools, cmdline-tools).
> - `flutter doctor` is green for Android, Chrome, and connected devices. **Xcode is
>   not installed** — iOS builds are unavailable until the full Xcode is installed
>   from the App Store (Android-first, so this is intentionally deferred).
> - Toolchain env vars (`JAVA_HOME`, `ANDROID_HOME`, `PATH`) are appended to `~/.zshrc`.
> - The app is still the default `flutter create` counter — the reminder features in
>   sections 3–6 are not built yet. Dependencies from section 8 are already added.

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
- Don't add a backend, analytics, ads, accounts, or network calls.
- Don't reintroduce mileage/odometer tracking.
- When a decision isn't specified here, pick the simplest reasonable option and
  note it, rather than blocking.
- Prioritize getting a working, installable app on the user's phone early, then iterate.
