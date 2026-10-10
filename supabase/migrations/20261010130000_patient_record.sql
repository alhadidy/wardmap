-- Wardmap step 3: the full patient record.
-- Every record table has the same shape and the same rules:
--   id, hospital_id, patient_id, created_by, created_at + its own columns.
--   Read: anyone who can see the patient. Write: anyone who can edit them.
--   Every change goes to the change history.
-- See docs/patient-record.md.

-- Problem list / diagnoses
create table problems (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  patient_id uuid not null,
  created_by uuid default auth.uid() references staff(id),
  created_at timestamptz not null default now(),
  diagnosis text not null,
  status text not null default 'active' check (status in ('active', 'resolved')),
  details text
);

-- Daily progress notes
create table notes (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  patient_id uuid not null,
  created_by uuid default auth.uid() references staff(id),
  created_at timestamptz not null default now(),
  body text not null
);

-- Vital signs
create table vitals (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  patient_id uuid not null,
  created_by uuid default auth.uid() references staff(id),
  created_at timestamptz not null default now(),
  taken_at timestamptz not null default now(),
  temperature numeric(4,1),   -- °C
  heart_rate int,             -- beats/min
  systolic int,               -- mmHg
  diastolic int,              -- mmHg
  respiratory_rate int,       -- breaths/min
  spo2 int,                   -- %
  note text
);

-- Lab and imaging results
create table results (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  patient_id uuid not null,
  created_by uuid default auth.uid() references staff(id),
  created_at timestamptz not null default now(),
  kind text not null check (kind in ('lab', 'imaging')),
  name text not null,         -- e.g. "Hb", "CXR"
  value text not null,        -- e.g. "11.2 g/dL", "No consolidation"
  taken_at timestamptz not null default now()
);

-- Medications
create table medications (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  patient_id uuid not null,
  created_by uuid default auth.uid() references staff(id),
  created_at timestamptz not null default now(),
  name text not null,
  dose text,
  route text,
  frequency text,
  started_at timestamptz not null default now(),
  stopped_at timestamptz
);

-- Team tasks / to-dos
create table tasks (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  patient_id uuid not null,
  created_by uuid default auth.uid() references staff(id),
  created_at timestamptz not null default now(),
  title text not null,
  assigned_to uuid references staff(id),
  due_at timestamptz,
  done_at timestamptz,
  done_by uuid references staff(id)
);

-- Discharge summary: one per patient, kept on the patient.
alter table patients add column discharge_summary text;

-- The author and time of an entry are always the real ones: set on insert
-- from the login, and never changeable afterwards.
create function keep_author() returns trigger
language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.created_by);
    new.created_at := now();
  else
    new.created_by := old.created_by;
    new.created_at := old.created_at;
  end if;
  return new;
end
$$;

-- Same links, rules and history for every record table.
do $$
declare t text;
begin
  foreach t in array array['problems', 'notes', 'vitals', 'results', 'medications', 'tasks'] loop
    execute format('alter table %I add foreign key (patient_id, hospital_id)
                      references patients(id, hospital_id) on delete cascade', t);
    execute format('create index on %I (patient_id, created_at)', t);
    execute format('alter table %I enable row level security', t);
    execute format('create policy "read" on %I for select
                      using (hospital_id = my_hospital() and can_view_patient(patient_id))', t);
    execute format('create policy "add" on %I for insert
                      with check (hospital_id = my_hospital() and can_edit_patient(patient_id))', t);
    execute format('create policy "change" on %I for update
                      using (hospital_id = my_hospital() and can_edit_patient(patient_id))
                      with check (hospital_id = my_hospital() and can_edit_patient(patient_id))', t);
    execute format('create policy "remove" on %I for delete
                      using (hospital_id = my_hospital() and can_edit_patient(patient_id))', t);
    execute format('create trigger keep_author before insert or update on %I
                      for each row execute function keep_author()', t);
    execute format('create trigger record_change after insert or update or delete on %I
                      for each row execute function record_change()', t);
  end loop;
end
$$;

-- ---------------------------------------------------------------------------
-- History: tag each entry with its patient, so a patient's whole history
-- (record, care team, every section) is one simple query.
-- ---------------------------------------------------------------------------

alter table audit_log add column patient_id uuid;
create index audit_log_patient on audit_log (patient_id, at);

-- Fill in the patient for entries written before this step. This is the only
-- time history rows are touched, so the permanence guard is paused for it.
alter table audit_log disable trigger audit_log_is_permanent;
update audit_log set patient_id = case
    when table_name = 'patients' then row_id::uuid
    when table_name = 'patient_team' then split_part(row_id, ':', 1)::uuid
  end
where table_name in ('patients', 'patient_team');
alter table audit_log enable trigger audit_log_is_permanent;

create or replace function record_change() returns trigger
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

  insert into audit_log (actor_id, hospital_id, patient_id, table_name, row_id, action, old_data, new_data)
  values (
    auth.uid(),
    coalesce(row_json->>'hospital_id', case when tg_table_name = 'hospitals' then row_json->>'id' end)::uuid,
    coalesce(row_json->>'patient_id', case when tg_table_name = 'patients' then row_json->>'id' end)::uuid,
    tg_table_name,
    coalesce(row_json->>'id', row_json->>'patient_id' || ':' || (row_json->>'staff_id')),
    lower(tg_op),
    old_json,
    new_json
  );
  return null;
end
$$;

drop policy "read history" on audit_log;
-- Admins read their hospital's whole history; anyone who can see a patient
-- reads that patient's history.
create policy "read history" on audit_log for select
  using (
    hospital_id = my_hospital()
    and (i_am_admin() or (patient_id is not null and can_view_patient(patient_id)))
  );
