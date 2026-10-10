# Changelog

Every change to Wardmap is listed here, newest first.
Format: what a user would notice, then anything an admin needs to do.

## 0.2.0 (2026-10-10): Ward board and patient flow

Added
- Wards tab. Admins add, rename and remove wards and beds.
- Ward board showing every bed as free, taken (with name), or occupied by a
  patient you can't see.
- Admit a patient into a ward and bed, naming the responsible consultant.
- Patient screen: details, care team (add, change access, remove, leave),
  transfer to another ward or bed, discharge.
- My patients tab opens each patient.

Changed
- A bed holds at most one current patient, and must belong to the patient's ward.
- Discharging frees the bed.
- Lists are sorted alphabetically and beds in natural order (2 before 10).
- Clearer error messages, including when you try something you aren't allowed to do.

Admin
- Apply the new database migration (`supabase db push`).

## 0.1.0 (2026-10-10): Foundation

Added
- Hospitals, wards, beds, staff, patients and care teams in the database.
- Roles: Admin, Consultant, R6 to R1, Rotator, Viewer. Seniors can see the
  patients of the juniors they oversee.
- Username + PIN login. Seniors create, reset and deactivate accounts for
  people junior to them (Team tab).
- Permanent change history: every insert, edit and delete is stored with who,
  when, and the before and after values. It cannot be edited or deleted.
- Patients tab listing current patients you can see.

Admin
- First-time setup is described in docs/setup.md.
