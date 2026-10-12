# Changelog

Every change to Wardmap is listed here, newest first.
Format: what a user would notice, then anything an admin needs to do.

## 1.3.0 (2026-10-12): Floor-plan look

Changed
- Rooms are drawn like a floor plan seen from above: walls around a tiled
  floor, with each bed shown as a bed (headboard, pillow, blanket).
- Bed colours: light green is free, teal is your patient, grey is taken by a
  patient you can't see. A key above the plan explains them.
- Map labels get an icon from their name (nurse station, WC, entrance, sink,
  stairs, lift, store…).
- A ward with several rooms shows its rooms side by side inside the ward's
  walls, each in miniature with its beds coloured, instead of a plain list.

Admin: nothing to do; no database changes.

## 1.2.0 (2026-10-12): Rooms

Added
- Wards now have rooms, and beds belong to a room. A ward with one room opens
  straight on its beds as before; a ward with several rooms opens on a list
  of its rooms showing free beds in each.
- Admins add, rename and remove rooms, and move a bed to another room from
  Edit map. Each room has its own map.
- When admitting or transferring, beds show their room if the ward has
  several (e.g. "Bed 3 · Side room").

Changed
- Every existing ward becomes a ward with one room ("Room 1") holding all its
  beds and its map, so nothing looks different until a second room is added.

Admin: nothing to do; the "Deploy backend" job moves existing beds into
rooms when this is merged.

## 1.1.0 (2026-10-12): Ward types

Added
- Wards can be tagged with one or more types (Men, Women, Children, Neonatal,
  Maternity, ER, ICU, RCU, CCU, HDU, Medical, Surgical, Neuro, Ortho, Burns,
  Oncology, Renal, Psychiatric, Isolation, Recovery, Day case). Each shows as
  an icon on the Wards tab and the ward board.

Changed
- The ward menu's "Rename" is now "Edit name and type".

Admin: nothing to do; the "Deploy backend" job adds the new database column
when this is merged.

## 1.0.3 (2026-10-12): Fix creating accounts from the web app

Fixed
- Creating accounts, resetting PINs and deactivating staff failed with
  "Something went wrong" in the web app. The browser blocked the request
  because the account function didn't allow one of the headers the app sends.
- Connection problems now say "Could not reach the server" instead.

Admin: nothing to do; the "Deploy backend" job redeploys the function when
this is merged.

## 1.0.2 (2026-10-12): Backend updates itself from GitHub

Added
- "Deploy backend" job on GitHub that creates and updates the database tables
  and the account function whenever `supabase/` changes on main, or on demand.

Admin: add repository secrets `SUPABASE_ACCESS_TOKEN` and
`SUPABASE_DB_PASSWORD`, then run Actions → Deploy backend once.

## 1.0.1 (2026-10-12): Add a hospital without a terminal

Added
- "Add hospital" job on GitHub (Actions tab) that creates a hospital and its
  first admin account with one click.

Admin: add repository secrets `SETUP_KEY` (same as in Supabase) and
`ADMIN_PIN` before running it. See docs/setup.md, section 2.

## 1.0.0 (2026-10-10): Launch

Added
- Automatic logout after 15 minutes without use (adjustable); the PIN screen
  keeps the username filled in.
- Juniors tab for consultants and residents: each junior's current patients
  with open tasks and whether a note was written in the last 24 hours.
- Search patients by name or MRN, optionally including discharged patients.
- More hospitals can be added with the setup key; each sees only its own data.
- Web hosting on GitHub Pages, and automatic checks on every pull request.
- Pilot checklist (docs/pilot.md).

Admin
- No database changes. Set up hosting once (docs/setup.md step 4).

## 0.3.0 (2026-10-10): Full patient record

Added
- Patient screen tabs: Overview, Problems, Notes, Vitals, Results, Meds,
  Tasks and History.
- Add, change and delete entries in each section (care-team editors).
  Tasks can be assigned, given a due time and ticked off.
- Discharge summary on the Overview tab.
- History tab: every change to the patient, with who, when, and before → after.

Changed
- Each history entry now records its patient, so a patient's history is one query.
- The author and time of every record entry come from the login and can't be changed.

Admin
- Apply the new database migration (`supabase db push`).

## 0.2.1 (2026-10-10): Ward map

Added
- Ward map: admins lay each ward out on a grid like a floor plan, placing
  beds and labels (nurse station, entrance, WC…). The ward board then shows
  beds where they really are. Beds not on the map are listed below it.

Admin
- Apply the new database migration (`supabase db push`).

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
