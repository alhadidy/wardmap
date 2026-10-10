# Roles and access

## Roles, most senior first

| Role | Who | Can do |
|---|---|---|
| Admin | Runs the hospital's setup | Everything in their hospital: wards, beds, all accounts, all patients, full history |
| Consultant | Attending doctor | Owns patients; manages their care teams; creates accounts for residents and below |
| R6 … R1 | Board residents (R6 most senior) | Follow patients on their care teams; oversee juniors; create accounts for juniors |
| Rotator | Pre-board rotating doctor | Follows patients on their care teams |
| Viewer | Read-only (e.g. students, observers) | Reads patients they are added to |

Everyone belongs to exactly one hospital and sees nothing from other hospitals.

## Seeing patients

You can see a patient if **any** of these is true:

1. You are on the patient's care team.
2. A doctor junior to you is on the care team (seniors oversee juniors).
   For example, an R5 sees every patient followed by an R3, R1 or rotator.
3. You are an admin.

## Editing patients

You can edit a patient if you are on the care team with **owner** or **edit**
access, or you are an admin. Overseeing a patient lets you read it, not edit
it; to edit, you are added to the team.

## Care teams

Each patient has a care team. Each member has one access level:

- **owner**: the responsible doctor. Manages the team.
- **edit**: follows the patient up, can write.
- **view**: can read only.

Who can add people to a team:

- Admins and owners can add anyone in the hospital, at any level.
- Members with edit access can add someone **junior to them**, with edit or view.
- Anyone can remove themselves from a team.

When a patient is admitted, the admitting doctor joins the team
automatically (as owner if a consultant, otherwise edit) and can name the
responsible consultant as owner.

## Wards, beds, admitting and discharge

- Admins add, rename and remove wards and beds. A ward or bed still in use
  can't be removed.
- Anyone except viewers can admit a patient.
- Anyone who can edit a patient can transfer them (ward or bed) and discharge them.
- The ward board shows every bed as free or taken. A taken bed whose patient
  you can't see shows as "Occupied", without the name.

## Accounts

There is no self-signup. You create, reset the PIN of, and deactivate
accounts for people **junior to you**. Admins can manage anyone.
A deactivated person is logged out and can no longer log in; their past
work stays in the history.

## Where this is enforced

The rules live in the database (`supabase/migrations/*_foundation.sql`), so
they hold even if someone bypasses the app. Accounts are managed in
`supabase/functions/manage-staff/index.ts`. Tests:
`supabase/tests/access_rules_test.sql`.
