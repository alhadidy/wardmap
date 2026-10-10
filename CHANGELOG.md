# Changelog

Every change to Wardmap is listed here, newest first.
Format: what a user would notice, then anything an admin needs to do.

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
