# Architecture

Kept deliberately small: one Flutter app talking directly to one Supabase
project. No other servers.

```
Flutter app (web / Android / iOS)
   │  logins, reads and writes
   ▼
Supabase
   ├─ Postgres: tables + access rules + change history   supabase/migrations/
   ├─ Auth: username + PIN logins
   └─ manage-staff function: creates and manages accounts  supabase/functions/
```

The database enforces who can see and change what (row level security), so
the app does not need its own permission logic beyond hiding buttons.

## Where things are

| Path | What |
|---|---|
| `lib/main.dart` | App start, picks login or home screen |
| `lib/api.dart` | Every backend call, in one place |
| `lib/roles.dart` | Roles and their seniority (mirrors the database) |
| `lib/ui.dart` | Shared dialogs and friendly error messages |
| `lib/screens/` | One file per screen or tab: `wards_tab`, `ward_board_screen`, `admit_screen`, `patient_screen`, `patients_tab`, `team_tab`, `login_screen` |
| `supabase/migrations/` | Database changes, one file per change, applied in order |
| `supabase/functions/manage-staff/` | Account creation, PIN reset, deactivation, first-time setup |
| `supabase/tests/` | Database access-rule tests (plain Postgres) |
| `test/` | Flutter tests |

## Conventions

- Every table has `hospital_id`, so every access rule starts with "my hospital".
- Every table gets the `record_change` trigger (see change-history.md).
- Never edit an applied migration; add a new one.
- Updates and deletes go through `_mustChange` in `api.dart`: the database
  silently skips rows you may not change, so the app checks a row came back.
- Every change updates `CHANGELOG.md`.
