-- Wardmap step 1: hospitals, wards, beds, staff, patients, care teams,
-- access rules, and the permanent change history (audit log).
--
-- Read docs/roles-and-access.md and docs/change-history.md alongside this file.
-- Rule of thumb: every table carries hospital_id, so every access rule starts
-- with "same hospital as me".

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------

create type staff_role as enum (
  'admin',       -- manages the hospital: wards, beds, all accounts
  'consultant',  -- owns patients, oversees all residents
  'r6', 'r5', 'r4', 'r3', 'r2', 'r1',  -- board residents, R6 most senior
  'rotator',     -- pre-board rotating doctor
  'viewer'       -- read-only
);

-- Seniority as a number: higher outranks lower.
create function role_rank(r staff_role) returns int
language sql immutable as $$
  select case r
    when 'admin' then 100
    when 'consultant' then 90
    when 'r6' then 60 when 'r5' then 50 when 'r4' then 40
    when 'r3' then 30 when 'r2' then 20 when 'r1' then 10
    when 'rotator' then 5
    when 'viewer' then 0
  end
$$;

create type team_access as enum (
  'owner',  -- responsible doctor: full control, manages the care team
  'edit',   -- follows the patient, can write
  'view'    -- read-only
);

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table hospitals (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table wards (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references hospitals(id),
  name text not null,
  created_at timestamptz not null default now(),
  unique (hospital_id, name),
  unique (id, hospital_id)
);

create table beds (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  ward_id uuid not null,
  label text not null,
  foreign key (ward_id, hospital_id) references wards(id, hospital_id),
  unique (ward_id, label),
  unique (id, hospital_id)
);

-- One row per person who can log in. id matches the Supabase auth user.
-- Accounts are only created through the manage-staff function.
create table staff (
  id uuid primary key,
  hospital_id uuid not null references hospitals(id),
  username text not null unique check (username ~ '^[a-z0-9._-]{3,32}$'),
  full_name text not null,
  role staff_role not null,
  is_active boolean not null default true,
  created_by uuid references staff(id),
  created_at timestamptz not null default now(),
  unique (id, hospital_id)
);

create table patients (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null references hospitals(id),
  ward_id uuid not null,
  bed_id uuid,
  mrn text not null,
  full_name text not null,
  date_of_birth date,
  sex text check (sex in ('male', 'female')),
  admitted_at timestamptz not null default now(),
  discharged_at timestamptz,
  foreign key (ward_id, hospital_id) references wards(id, hospital_id),
  foreign key (bed_id, hospital_id) references beds(id, hospital_id),
  unique (id, hospital_id)
);

-- Who looks after each patient, and how much they can do.
create table patient_team (
  hospital_id uuid not null,
  patient_id uuid not null,
  staff_id uuid not null,
  access team_access not null,
  added_by uuid references staff(id),
  added_at timestamptz not null default now(),
  primary key (patient_id, staff_id),
  foreign key (patient_id, hospital_id) references patients(id, hospital_id) on delete cascade,
  foreign key (staff_id, hospital_id) references staff(id, hospital_id)
);

-- ---------------------------------------------------------------------------
-- "Who am I" helpers used by the access rules
-- ---------------------------------------------------------------------------

create function my_hospital() returns uuid
language sql stable security definer set search_path = public as $$
  select hospital_id from staff where id = auth.uid() and is_active
$$;

create function my_rank() returns int
language sql stable security definer set search_path = public as $$
  select role_rank(role) from staff where id = auth.uid() and is_active
$$;

create function i_am_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(my_rank() = 100, false)
$$;

-- My access on a patient's care team, or null if I am not on it.
create function my_team_access(p uuid) returns team_access
language sql stable security definer set search_path = public as $$
  select access from patient_team where patient_id = p and staff_id = auth.uid()
$$;

-- Seniors oversee juniors: I can see a patient if a doctor junior to me
-- (not a viewer) is on its care team.
create function i_oversee_patient(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from patient_team t join staff s on s.id = t.staff_id
    where t.patient_id = p
      and s.role <> 'viewer'
      and role_rank(s.role) < my_rank()
      and my_rank() >= role_rank('r1')
  )
$$;

create function can_view_patient(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select i_am_admin() or my_team_access(p) is not null or i_oversee_patient(p)
$$;

create function can_edit_patient(p uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select i_am_admin() or my_team_access(p) in ('owner', 'edit')
$$;

-- ---------------------------------------------------------------------------
-- Access rules (row level security)
-- ---------------------------------------------------------------------------

alter table hospitals enable row level security;
alter table wards enable row level security;
alter table beds enable row level security;
alter table staff enable row level security;
alter table patients enable row level security;
alter table patient_team enable row level security;

-- Hospitals: see your own; admins can rename it.
create policy "see own hospital" on hospitals for select
  using (id = my_hospital());
create policy "admin edits hospital" on hospitals for update
  using (id = my_hospital() and i_am_admin());

-- Wards and beds: everyone in the hospital sees them; admins manage them.
create policy "see wards" on wards for select
  using (hospital_id = my_hospital());
create policy "admin manages wards" on wards for all
  using (hospital_id = my_hospital() and i_am_admin())
  with check (hospital_id = my_hospital() and i_am_admin());

create policy "see beds" on beds for select
  using (hospital_id = my_hospital());
create policy "admin manages beds" on beds for all
  using (hospital_id = my_hospital() and i_am_admin())
  with check (hospital_id = my_hospital() and i_am_admin());

-- Staff: everyone sees colleagues in the same hospital.
-- Creating, resetting and deactivating accounts goes through manage-staff.
create policy "see colleagues" on staff for select
  using (hospital_id = my_hospital());

-- Patients
create policy "see my patients" on patients for select
  using (hospital_id = my_hospital() and can_view_patient(id));
-- New patients are admitted through admit_patient() below, so the admitting
-- doctor is put on the care team in the same step.
create policy "edit my patients" on patients for update
  using (hospital_id = my_hospital() and can_edit_patient(id))
  with check (hospital_id = my_hospital());
create policy "admin deletes patients" on patients for delete
  using (hospital_id = my_hospital() and i_am_admin());

-- Care teams
create policy "see care teams" on patient_team for select
  using (hospital_id = my_hospital() and can_view_patient(patient_id));

-- Admins and owners manage the team freely. Anyone with edit access can add
-- someone junior to them, with edit or view access.
create policy "add to care team" on patient_team for insert
  with check (
    hospital_id = my_hospital() and (
      i_am_admin()
      or my_team_access(patient_id) = 'owner'
      or (
        my_team_access(patient_id) = 'edit'
        and access <> 'owner'
        and (select role_rank(s.role) from staff s where s.id = patient_team.staff_id) < my_rank()
      )
    )
  );
create policy "change care team" on patient_team for update
  using (hospital_id = my_hospital() and (i_am_admin() or my_team_access(patient_id) = 'owner'))
  with check (hospital_id = my_hospital());
create policy "remove from care team" on patient_team for delete
  using (
    hospital_id = my_hospital() and (
      i_am_admin()
      or my_team_access(patient_id) = 'owner'
      or staff_id = auth.uid()  -- anyone can leave a team
    )
  );

-- ---------------------------------------------------------------------------
-- Admitting a patient
-- ---------------------------------------------------------------------------

-- Creates the patient and puts the admitting doctor on the care team.
-- A consultant (or admin) admitting becomes the owner. Anyone else gets edit
-- access, and can name the responsible consultant as owner.
create function admit_patient(
  p_ward_id uuid,
  p_mrn text,
  p_full_name text,
  p_date_of_birth date default null,
  p_sex text default null,
  p_bed_id uuid default null,
  p_owner_id uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  new_id uuid;
  me staff;
begin
  select * into me from staff where id = auth.uid() and is_active;
  if me is null or me.role = 'viewer' then
    raise exception 'Not allowed to admit patients';
  end if;

  insert into patients (hospital_id, ward_id, bed_id, mrn, full_name, date_of_birth, sex)
  values (me.hospital_id, p_ward_id, p_bed_id, p_mrn, p_full_name, p_date_of_birth, p_sex)
  returning id into new_id;

  insert into patient_team (hospital_id, patient_id, staff_id, access, added_by)
  values (me.hospital_id, new_id, me.id,
          case when role_rank(me.role) >= role_rank('consultant') then 'owner' else 'edit' end::team_access,
          me.id);

  if p_owner_id is not null and p_owner_id <> me.id then
    insert into patient_team (hospital_id, patient_id, staff_id, access, added_by)
    values (me.hospital_id, new_id, p_owner_id, 'owner', me.id);
  end if;

  return new_id;
end
$$;

-- ---------------------------------------------------------------------------
-- Change history: every insert, update and delete, kept forever
-- ---------------------------------------------------------------------------

create table audit_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor_id uuid,              -- who made the change (null = system/setup)
  hospital_id uuid,
  table_name text not null,
  row_id text,
  action text not null check (action in ('insert', 'update', 'delete')),
  old_data jsonb,             -- the row before (update, delete)
  new_data jsonb              -- the row after (insert, update)
);

create index audit_log_row on audit_log (table_name, row_id, at);
create index audit_log_hospital on audit_log (hospital_id, at);

create function record_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  old_json jsonb := case when tg_op <> 'INSERT' then to_jsonb(old) end;
  new_json jsonb := case when tg_op <> 'DELETE' then to_jsonb(new) end;
  row_json jsonb := coalesce(new_json, old_json);
begin
  -- Skip updates that changed nothing.
  if tg_op = 'UPDATE' and old_json = new_json then
    return null;
  end if;

  insert into audit_log (actor_id, hospital_id, table_name, row_id, action, old_data, new_data)
  values (
    auth.uid(),
    coalesce(row_json->>'hospital_id', case when tg_table_name = 'hospitals' then row_json->>'id' end)::uuid,
    tg_table_name,
    coalesce(row_json->>'id', row_json->>'patient_id' || ':' || (row_json->>'staff_id')),
    lower(tg_op),
    old_json,
    new_json
  );
  return null;
end
$$;

-- The history can never be edited or deleted, by anyone.
create function refuse_history_change() returns trigger
language plpgsql as $$
begin
  raise exception 'The change history is permanent and cannot be changed';
end
$$;

create trigger audit_log_is_permanent
  before update or delete on audit_log
  for each row execute function refuse_history_change();
create trigger audit_log_no_truncate
  before truncate on audit_log
  for each statement execute function refuse_history_change();

-- Attach the history recorder to every table. Add new tables to this list.
do $$
declare t text;
begin
  foreach t in array array['hospitals', 'wards', 'beds', 'staff', 'patients', 'patient_team'] loop
    execute format(
      'create trigger record_change after insert or update or delete on %I
         for each row execute function record_change()', t);
  end loop;
end
$$;

alter table audit_log enable row level security;
-- Admins read their hospital's history; others see the history of patients they can see.
create policy "read history" on audit_log for select
  using (
    hospital_id = my_hospital() and (
      i_am_admin()
      or can_view_patient(case
           when table_name = 'patients' then row_id::uuid
           when table_name = 'patient_team' then split_part(row_id, ':', 1)::uuid
         end)
    )
  );
revoke update, delete, truncate on audit_log from public;
