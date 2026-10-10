# The patient record

Open a patient (from a ward board or **My patients**). The tabs across the top are:

| Tab | Holds |
|---|---|
| Overview | Details, discharge summary, care team |
| Problems | Diagnoses and problems, active or resolved |
| Notes | Daily progress notes, with author and time |
| Vitals | Temperature, heart rate, blood pressure, respiratory rate, SpO₂ |
| Results | Lab and imaging results |
| Meds | Medications with dose, route, frequency, start and stop |
| Tasks | Team to-dos, optionally assigned and with a due time; tick when done |
| History | Every change ever made to this patient (see below) |

## Who can do what

- **Read** a tab: anyone who can see the patient (their care team, seniors
  overseeing a junior on the team, admins).
- **Add, change or delete** entries: care-team members with owner or edit
  access, and admins. Use **+** to add; tap an entry to change or delete it.
- After discharge the record is read-only, except the discharge summary.
- Each entry's author and time are set from the login and can't be changed
  or faked.

## History tab

Lists every change to the patient newest first: who, when, and what
changed (for example `Status: active → resolved`). Deleted entries remain
readable here. Nobody can edit or remove history. See
[change-history.md](change-history.md).

## Adding a field or section (for developers)

All six sections share one table shape and one set of rules
(`supabase/migrations/*_patient_record.sql`). The app builds each tab's list
and form from `lib/record_sections.dart`:

1. Add the column in a **new** migration.
2. Add a `RecordField` for it in `record_sections.dart`.

A new section is a new table in the migration's list plus a new
`RecordSection` entry.
