-- Checks beds, transfers and discharge from the ward board migration.
-- Uses the hospital and team from test_helpers.sql.

insert into wards (id, hospital_id, name) values ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a1', 'Ward 6');
insert into beds (id, hospital_id, ward_id, label) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', '1'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', '2'),
  ('00000000-0000-0000-0000-0000000000c6', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b2', '1');

set role authenticated;

-- The consultant admits a patient to Ward 5, bed 1.
select as_user('00000000-0000-0000-0000-000000000002');
select admit_patient('00000000-0000-0000-0000-0000000000b1', 'MRN1', 'Patient One',
  p_bed_id => '00000000-0000-0000-0000-0000000000c1');
select check_that((select access from patient_team where staff_id = auth.uid()) = 'owner', 'Consultant admitting becomes owner');

select check_refused($$select admit_patient('00000000-0000-0000-0000-0000000000b1', 'MRN2', 'Patient Two',
  p_bed_id => '00000000-0000-0000-0000-0000000000c1')$$, 'A taken bed cannot be given to a second patient');

select check_refused($$select admit_patient('00000000-0000-0000-0000-0000000000b1', 'MRN2', 'Patient Two',
  p_bed_id => '00000000-0000-0000-0000-0000000000c6')$$, 'A bed from another ward is refused');

-- The rotator cannot see the patient but sees that bed 1 is taken.
select as_user('00000000-0000-0000-0000-000000000005');
select check_that((select count(*) from patients) = 0, 'Rotator does not see the patient');
select check_that(
  (select array_agg(b) from ward_occupied_beds('00000000-0000-0000-0000-0000000000b1') b)
    = array['00000000-0000-0000-0000-0000000000c1'::uuid],
  'Rotator sees bed 1 is taken');
select check_refused($$select admit_patient('00000000-0000-0000-0000-0000000000b1', 'MRN2', 'Patient Two',
  p_bed_id => '00000000-0000-0000-0000-0000000000c1')$$, 'Rotator cannot double-book bed 1 either');

-- Owner transfers the patient to Ward 6, bed 1.
select as_user('00000000-0000-0000-0000-000000000002');
update patients set ward_id = '00000000-0000-0000-0000-0000000000b2', bed_id = '00000000-0000-0000-0000-0000000000c6';
select check_that((select count(*) from ward_occupied_beds('00000000-0000-0000-0000-0000000000b1')) = 0, 'Transfer frees the old bed');

-- Discharge must free the bed.
select check_refused($$update patients set discharged_at = now()$$, 'Discharging while still in a bed is refused');
update patients set discharged_at = now(), bed_id = null;
select check_that((select count(*) from ward_occupied_beds('00000000-0000-0000-0000-0000000000b2')) = 0, 'Discharge frees the bed');

-- The history shows the whole journey.
select check_that(
  (select count(*) from audit_log where table_name = 'patients') = 3,
  'Admission, transfer and discharge are all in the history');
