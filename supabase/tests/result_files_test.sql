-- Checks images and videos on results: the stored files and their rows.
-- Uses the hospital and team from test_helpers.sql.

set role authenticated;

-- The R3 admits a patient and adds an imaging result.
select as_user('00000000-0000-0000-0000-000000000003');
create temp table t as select admit_patient('00000000-0000-0000-0000-0000000000b1', 'MRN1', 'Patient One') as pid;
insert into results (hospital_id, patient_id, kind, name, value)
  select '00000000-0000-0000-0000-0000000000a1', pid, 'imaging', 'CT head', 'See images' from t;
create temp table f as select
  '00000000-0000-0000-0000-0000000000a1/' || pid || '/scan1.png' as path,
  (select id from results) as rid
  from t;
grant select on t, f to authenticated;

-- Upload the file, then its row.
insert into storage.objects (bucket_id, name) select 'record-files', path from f;
insert into result_files (hospital_id, patient_id, result_id, path, file_name, content_type)
  select '00000000-0000-0000-0000-0000000000a1', pid, rid, path, 'scan1.png', 'image/png' from t, f;
select check_that((select count(*) from result_files) = 1, 'Care team attaches an image to a result');
select check_refused($$insert into result_files (hospital_id, patient_id, result_id, path, file_name, content_type)
  select '00000000-0000-0000-0000-0000000000a1', pid, rid, 'elsewhere/x.png', 'x.png', 'image/png' from t, f$$,
  'A file row must point inside the patient''s folder');
select check_refused($$insert into result_files (hospital_id, patient_id, result_id, path, file_name, content_type)
  select '00000000-0000-0000-0000-0000000000a1', pid, rid, path || '.pdf', 'x.pdf', 'application/pdf' from t, f$$,
  'Only images and videos');
select check_refused($$insert into storage.objects (bucket_id, name)
  select 'record-files', '00000000-0000-0000-0000-0000000000a1/' || gen_random_uuid() || '/x.png'$$,
  'Cannot upload into another patient''s folder');

-- The R6 oversees the R3: can open the file, cannot add one.
select as_user('00000000-0000-0000-0000-000000000006');
select check_that((select count(*) from storage.objects) = 1, 'Senior opens the file');
select check_that((select count(*) from result_files) = 1, 'Senior sees the file list');
select check_refused($$insert into storage.objects (bucket_id, name)
  select 'record-files', '00000000-0000-0000-0000-0000000000a1/' || pid || '/scan2.png' from t$$,
  'Senior cannot upload without being on the team');

-- The rotator sees nothing.
select as_user('00000000-0000-0000-0000-000000000005');
select check_that((select count(*) from storage.objects) + (select count(*) from result_files) = 0,
  'Rotator cannot open or list files');

-- Removing the file keeps it in the history, and the stored file stays.
select as_user('00000000-0000-0000-0000-000000000003');
delete from result_files;
delete from storage.objects;
select check_that((select count(*) from storage.objects) = 1, 'Stored files cannot be deleted');
select check_that(exists (select 1 from audit_log where table_name = 'result_files' and action = 'delete'),
  'A removed file stays in the history');
