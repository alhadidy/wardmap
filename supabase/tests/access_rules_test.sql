-- Checks the access rules and change history from the foundation migration.
-- Run with ./run_tests.sh. Any failed check stops with an error.

grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on all functions in schema public to authenticated;

-- One hospital, one ward, and a small team.
insert into hospitals (id, name) values ('00000000-0000-0000-0000-0000000000a1', 'General Hospital');
insert into wards (id, hospital_id, name) values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 'Ward 5');
insert into staff (id, hospital_id, username, full_name, role) values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'admin', 'Admin', 'admin'),
  ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1', 'dr.cons', 'Consultant', 'consultant'),
  ('00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-0000000000a1', 'dr.r6', 'Senior Resident', 'r6'),
  ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a1', 'dr.r3', 'Resident R3', 'r3'),
  ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000a1', 'dr.r1', 'Resident R1', 'r1'),
  ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-0000000000a1', 'dr.rot', 'Rotator', 'rotator');

create function as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u, false);
$$;
create function check_that(ok boolean, what text) returns void language plpgsql as $$
begin
  if not coalesce(ok, false) then raise exception 'FAILED: %', what; end if;
  raise notice 'ok: %', what;
end $$;
grant execute on function check_that, as_user to authenticated;

set role authenticated;

-- The R3 admits a patient and names the consultant as owner.
select as_user('00000000-0000-0000-0000-000000000003');
create temp table t as select admit_patient('00000000-0000-0000-0000-0000000000b1', 'MRN1', 'Patient One',
  p_owner_id => '00000000-0000-0000-0000-000000000002') as pid;
select check_that((select count(*) from patients) = 1, 'R3 sees the patient they admitted');
select check_that((select access from patient_team where staff_id = auth.uid()) = 'edit', 'R3 gets edit access');

-- R3 adds the R1 (junior) to follow up.
insert into patient_team (hospital_id, patient_id, staff_id, access)
  select '00000000-0000-0000-0000-0000000000a1', pid, '00000000-0000-0000-0000-000000000004', 'edit' from t;
select check_that(true, 'R3 can add a junior to the care team');

-- R3 cannot add the R6 (senior) to the team.
do $$ begin
  insert into patient_team (hospital_id, patient_id, staff_id, access)
    select '00000000-0000-0000-0000-0000000000a1', pid, '00000000-0000-0000-0000-000000000006', 'view' from t;
  raise exception 'FAILED: R3 added a senior';
exception when insufficient_privilege then raise notice 'ok: R3 cannot add a senior';
end $$;

-- The R6 is not on the team but oversees the R3 and R1, so can see the patient.
select as_user('00000000-0000-0000-0000-000000000006');
select check_that((select count(*) from patients) = 1, 'R6 oversees juniors'' patients');
update patients set full_name = 'Changed by R6';
select check_that((select full_name from patients) = 'Patient One', 'R6 cannot edit without being on the team');

-- The rotator is below everyone on the team, so sees nothing.
select as_user('00000000-0000-0000-0000-000000000005');
select check_that((select count(*) from patients) = 0, 'Rotator does not see others'' patients');

-- The R1 can edit the patient.
select as_user('00000000-0000-0000-0000-000000000004');
update patients set bed_id = null, full_name = 'Patient One (edited)';
select check_that((select full_name from patients) = 'Patient One (edited)', 'R1 on the team can edit');
select check_that(
  (select count(*) from audit_log where table_name = 'patients' and action = 'update'
     and actor_id = '00000000-0000-0000-0000-000000000004'
     and old_data->>'full_name' = 'Patient One' and new_data->>'full_name' = 'Patient One (edited)') = 1,
  'Edit is in the history with who, before and after');

-- Nobody can change or delete the history, not even the database owner.
reset role;
do $$ begin
  delete from audit_log;
  raise exception 'FAILED: history deleted';
exception when raise_exception then
  if sqlerrm like 'FAILED%' then raise; end if;
  raise notice 'ok: history cannot be deleted';
end $$;
do $$ begin
  update audit_log set actor_id = null;
  raise exception 'FAILED: history changed';
exception when raise_exception then
  if sqlerrm like 'FAILED%' then raise; end if;
  raise notice 'ok: history cannot be changed';
end $$;

-- Admin sees the whole hospital history.
set role authenticated;
select as_user('00000000-0000-0000-0000-000000000001');
select check_that((select count(*) from audit_log) > 5, 'Admin reads the full history');
select check_that((select count(*) from patients) = 1, 'Admin sees every patient');

-- Logged-out users see nothing.
select as_user('');
select check_that((select count(*) from patients) = 0 and (select count(*) from staff) = 0, 'Logged-out sees nothing');
