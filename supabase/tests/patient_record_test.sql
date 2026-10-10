-- Checks the patient record sections and the per-patient history.
-- Uses the hospital and team from test_helpers.sql.

set role authenticated;

-- The R3 admits a patient (gets edit access).
select as_user('00000000-0000-0000-0000-000000000003');
create temp table t as select admit_patient('00000000-0000-0000-0000-0000000000b1', 'MRN1', 'Patient One') as pid;

insert into problems (hospital_id, patient_id, diagnosis)
  select '00000000-0000-0000-0000-0000000000a1', pid, 'Community-acquired pneumonia' from t;
insert into notes (hospital_id, patient_id, body)
  select '00000000-0000-0000-0000-0000000000a1', pid, 'Day 1: febrile, started antibiotics.' from t;
insert into vitals (hospital_id, patient_id, temperature, heart_rate, spo2)
  select '00000000-0000-0000-0000-0000000000a1', pid, 38.4, 104, 93 from t;
insert into results (hospital_id, patient_id, kind, name, value)
  select '00000000-0000-0000-0000-0000000000a1', pid, 'lab', 'WBC', '15.2' from t;
insert into medications (hospital_id, patient_id, name, dose, route, frequency)
  select '00000000-0000-0000-0000-0000000000a1', pid, 'Ceftriaxone', '1 g', 'IV', 'daily' from t;
insert into tasks (hospital_id, patient_id, title, assigned_to)
  select '00000000-0000-0000-0000-0000000000a1', pid, 'Repeat CXR', '00000000-0000-0000-0000-000000000004' from t;
select check_that((select created_by from notes) = '00000000-0000-0000-0000-000000000003', 'Author is recorded automatically');
insert into notes (hospital_id, patient_id, body, created_by)
  select '00000000-0000-0000-0000-0000000000a1', pid, 'Pretending to be someone else', '00000000-0000-0000-0000-000000000002' from t;
select check_that((select created_by from notes where body like 'Pretending%') = auth.uid(), 'Cannot write a note in someone else''s name');
update notes set created_by = '00000000-0000-0000-0000-000000000002';
select check_that((select count(*) from notes where created_by = auth.uid()) = 2, 'Cannot change who wrote a note');
delete from notes where body like 'Pretending%';
update tasks set done_at = now(), done_by = auth.uid();
select check_that((select done_at from tasks) is not null, 'Team member completes a task');

-- The R6 oversees the R3, so can read but not write.
select as_user('00000000-0000-0000-0000-000000000006');
select check_that((select count(*) from notes) = 1, 'Senior reads the notes of juniors'' patients');
select check_refused($$insert into notes (hospital_id, patient_id, body)
  select '00000000-0000-0000-0000-0000000000a1', pid, 'x' from t$$, 'Senior cannot write without being on the team');

-- The rotator sees nothing.
select as_user('00000000-0000-0000-0000-000000000005');
select check_that((select count(*) from notes) + (select count(*) from vitals) + (select count(*) from medications) = 0,
  'Rotator sees none of the record');

-- The patient's whole history is one query, readable by those who can see the patient.
select as_user('00000000-0000-0000-0000-000000000006');
select check_that(
  (select count(distinct table_name) from audit_log where patient_id = (select pid from t)) = 8,
  'History covers the patient, team and all six sections');
select as_user('00000000-0000-0000-0000-000000000005');
select check_that((select count(*) from audit_log) = 0, 'Rotator cannot read the history');

-- Deleting an entry keeps it in the history.
select as_user('00000000-0000-0000-0000-000000000003');
delete from notes;
select check_that(
  exists (select 1 from audit_log where table_name = 'notes' and action = 'delete' and old_data->>'body' like 'Day 1%'),
  'A deleted note stays readable in the history');
