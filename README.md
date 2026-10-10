# Wardmap

A simple app for managing patients on hospital wards. Works in the browser and
on Android and iOS from one Flutter codebase.

- Hospitals have wards, wards have beds, beds have patients.
- Each patient has a care team: a responsible consultant plus the residents
  following them up.
- Seniors oversee juniors: R6 down to R1, then rotators.
- No email signup. Seniors create username + PIN logins for people below them.
- Every change to every record is kept forever in the change history.

## Documentation

| Read this | To learn |
|---|---|
| [docs/setup.md](docs/setup.md) | How to set up the backend, run and host the app, add hospitals |
| [docs/pilot.md](docs/pilot.md) | Checklist for trying it on your ward |
| [docs/ward-board.md](docs/ward-board.md) | Using the app day to day: wards, admitting, care teams, discharge |
| [docs/patient-record.md](docs/patient-record.md) | The patient record tabs, and how to add a field |
| [docs/roles-and-access.md](docs/roles-and-access.md) | Who can see and do what |
| [docs/change-history.md](docs/change-history.md) | How every change is recorded and how to review it |
| [docs/architecture.md](docs/architecture.md) | How the pieces fit together, and where to find things |
| [CHANGELOG.md](CHANGELOG.md) | What changed in the app, version by version |

## Project status

Built in four steps:

1. **Foundation and access rules** (done): database, roles, change history, login, accounts.
2. **Ward board and patient flow** (done): wards and beds, admit, transfer, discharge, care teams.
3. **Full patient record** (done): problems, notes, vitals, results, meds, tasks, discharge summary, history.
4. **Launch** (done): web hosting, automatic logout, Juniors overview for seniors, search, more hospitals. Pilot checklist: [docs/pilot.md](docs/pilot.md).

## Rule for every change

Every pull request updates `CHANGELOG.md`, and updates the docs when behaviour
changes. Database changes are new files in `supabase/migrations/` (never edit
an old one), so the database has its own step-by-step history too.
