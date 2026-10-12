# Using Wardmap day to day

Tabs at the bottom: **Wards**, **My patients**, **Juniors** (seniors only)
and **Team**. Each patient's record is described in
[patient-record.md](patient-record.md).

## Wards tab

Lists every ward in your hospital with its type icons. Tap a ward to open
its **ward board**. Admins also see **New ward**, and a menu on each ward to
edit its name and type or remove it.

**Ward types.** When adding or editing a ward, pick any types that apply.
A ward can have several, e.g. *Women* and *Children* for a women and
children ward. Each type shows as an icon next to the ward's name:

Men, Women, Children, Neonatal, Maternity, ER, ICU, RCU, CCU, HDU, Medical,
Surgical, Neuro, Ortho, Burns, Oncology, Renal, Psychiatric, Isolation,
Recovery, Day case.

To add a new type, add it to `lib/ward_types.dart` and to a new database
migration (the list in `20261012120000_ward_types.sql` is the starting point).

## Ward board

Shows every bed in the ward:

| Bed shows | Meaning | Tap it to |
|---|---|---|
| A patient's name | Taken by a patient you can see | Open the patient |
| Occupied | Taken by a patient you can't see | Nothing |
| Free | Empty | Admit a patient into it |

Patients in the ward without a bed are listed under **Without a bed**.
Admins add beds with **+** and remove an empty bed with a long press.

### Ward map

Admins can draw each ward like a floor plan so beds appear where they really
are. Tap **Edit map** (the pin icon) on the ward board:

- Set the grid size with the **rows** and **columns** buttons.
- Tap an empty cell to put an existing bed there, add a new bed there, or add
  a label such as *Nurse station*, *Entrance* or *WC*.
- Tap a bed or label to pick it up, then tap an empty cell to move it. While
  picked you can also **Take off map** (beds) or **Delete** it.
- Tap the tick when done.

Beds not yet on the map are listed under **Not on the map**. Until anything
is placed, the board simply lists the beds. Everyone sees the map; only
admins can change it. Map changes are kept in the change history like
everything else.

## Admitting

Tap **Admit** (or a free bed). Fill in MRN and name; date of birth, sex, bed
and responsible consultant are optional. You join the patient's care team
automatically: as owner if you are a consultant, otherwise with edit access.
The consultant you pick becomes the owner.

A bed can only hold one current patient. If two people try to fill the same
bed at once, the second is told it's taken.

## Patient screen

Shows the patient's details and care team. From the **⋮** menu (if you can
edit the patient):

- **Transfer / change bed**: pick a ward and a free bed, or no bed.
- **Discharge**: frees the bed. The patient leaves the ward board and
  everyone's lists; the record and its history stay.

### Care team

- **Add**: owners add anyone with any access; editors add people junior to
  them, with edit or view.
- Owners can change anyone's access or remove them.
- Anyone can **Leave team** from the menu on their own name.

See [roles-and-access.md](roles-and-access.md) for the full rules.

## My patients tab

Every current patient you can see across all wards: those on your care teams
plus those followed by juniors you oversee. Search by name or MRN. Switch on
**Include discharged** to find past patients and their records.

## Juniors tab (seniors)

Consultants and residents with juniors below them see each junior doctor and
the current patients they follow, with:

- the ward and bed,
- how many tasks are still open,
- when the last progress note was written, or **No note in 24h** in red.

Tap a patient to open them.

## Automatic logout

After 15 minutes without a tap or key press, the app logs out and asks for
the PIN again (username already filled in). This protects patient data on
shared ward computers and lost phones.

## Everything is recorded

Admissions, transfers, discharges and care-team changes are all in the change
history with who did them and when. See [change-history.md](change-history.md).
