# Google Calendar sync — one-time setup

The app can mirror reminders to your Google Calendar. Sync is **opt-in** and the
app talks to the Google Calendar API **directly from the phone** — there is no
backend/server. It stays off until you complete this OAuth setup and connect
under **Settings → Connect Google Calendar**.

The app is always the notifier; calendar events are created **without** their own
reminders, so you won't get double-nudged.

## What you need

- App package name: `com.orlyanson.reminder_app`
- Debug signing SHA-1 (used by the current release build):
  `20:78:B4:02:0F:26:BD:BF:0B:82:F8:85:38:91:3A:9F:40:4E:01:49`

  Re-derive any time with:
  ```bash
  keytool -list -v -keystore ~/.android/debug.keystore \
    -alias androiddebugkey -storepass android -keypass android | grep SHA1
  ```
  (If you later sign with a real release keystore, add that keystore's SHA-1 too.)

## Steps (Google Cloud console, ~10 min)

1. Go to <https://console.cloud.google.com/> and **create a project** (any name).
2. **APIs & Services → Library →** search **Google Calendar API →** **Enable**.
3. **APIs & Services → OAuth consent screen:**
   - User type **External**, fill the required app name + your email.
   - **Add scope** `https://www.googleapis.com/auth/calendar.events`.
   - **Test users → add your own Google account.** (Testing mode is fine for
     personal use — no Google verification needed for your own test account.)
4. **APIs & Services → Credentials → Create credentials → OAuth client ID**, twice:
   - **Android** client — package `com.orlyanson.reminder_app`, SHA-1 above.
     (This authorizes the on-device Calendar API access.)
   - **Web application** client — needed by Android sign-in as the
     `serverClientId`. Copy its **Client ID** (looks like
     `1234-abcd.apps.googleusercontent.com`).

## Build with the Web client ID

The client ID lives in a **gitignored** `dart_defines.json` at the repo root, so
every build picks it up automatically and you can't forget the flag. Create it
once by copying the template:

```bash
cp dart_defines.example.json dart_defines.json
# then edit dart_defines.json and paste your Web client ID
```

`dart_defines.json`:

```json
{
  "GOOGLE_SERVER_CLIENT_ID": "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"
}
```

Then always build/run with `--dart-define-from-file`:

```bash
flutter build apk --release --dart-define-from-file=dart_defines.json

# or while developing:
flutter run --dart-define-from-file=dart_defines.json
```

Without this (a plain `flutter build apk --release`),
`GoogleCalendarService.isConfigured` is false and Settings shows **"Not set up on
this build yet"** — the rest of the app works normally. This is the #1 way sync
silently "breaks": rebuilding without the define. Prefer the file so it's baked in.

## Use it

On the phone: **Settings → Connect Google Calendar → sign in → allow Calendar
access.** The app pushes all reminders, then keeps them in sync as you add, edit,
complete, or delete. **Disconnect** stops syncing (existing events stay on the
calendar).

## Notes / limits

- **Testing-mode tokens** can expire after ~7 days; if sync stops, reconnect.
  Publishing the OAuth app removes that, but isn't necessary for personal use.
- Marking done / editing updates the same event (tracked via `googleEventId`).
- Recurrence maps to RRULE (monthly/yearly/etc.); one-time reminders are single
  all-day events.
- Deleting a reminder removes its calendar event; pausing (inactive) removes it
  too and re-creates on reactivation.
