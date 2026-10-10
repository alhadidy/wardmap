# Change history

Every insert, edit and delete on every table is written to the `audit_log`
table automatically by the database. Nothing in the app has to remember to
do it.

## What each entry holds

| Column | Meaning |
|---|---|
| `at` | When it happened |
| `actor_id` | Who did it (staff id; empty for system setup) |
| `table_name` | What kind of record (`patients`, `patient_team`, `notes`, `vitals`, `wards`, …; `accounts` for logins created, PINs reset, accounts deactivated) |
| `patient_id` | The patient it belongs to, if any, so a patient's full history is one query |
| `row_id` | Which record |
| `action` | `insert`, `update` or `delete` |
| `old_data` | The whole record before the change |
| `new_data` | The whole record after the change |

PINs are never stored in the history.

## It cannot be changed

The database refuses any update, delete or truncate on `audit_log`, even
from the database owner. Entries are only ever added.

## Who can read it

- Admins read their whole hospital's history.
- Anyone who can see a patient can read that patient's whole history.

## Reviewing it

In the app: open a patient and choose the **History** tab.

In the Supabase SQL editor, for example everything that happened to one
patient, with names:

```sql
select a.at, s.full_name as who, a.table_name, a.action, a.old_data, a.new_data
from audit_log a left join staff s on s.id = a.actor_id
where a.patient_id = '<patient id>'
order by a.at;
```

## Adding a new table

Add a `record_change` trigger for it in its migration:

```sql
create trigger record_change after insert or update or delete on <table>
  for each row execute function record_change();
```
