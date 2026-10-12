-- Images and videos on lab and imaging results (e.g. a photo of a lab
-- report, CT slices, an echo clip). See docs/patient-record.md.
--
-- The files live in a private storage bucket, "record-files", at
--   <hospital id>/<patient id>/<random name>.<ext>
-- and each one has a row in result_files saying which result it belongs to.
-- Who can open or add a file follows the same rules as the rest of the
-- record: read if you can see the patient, add if you can edit them.
-- Removing a file removes its row (kept in the history); the file itself is
-- never deleted, so history stays reviewable.

-- The bucket. 50 MB per file, images and videos only.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('record-files', 'record-files', false, 52428800, array['image/*', 'video/*'])
on conflict (id) do nothing;

-- The patient a stored file belongs to, from the second part of its path.
create function record_file_patient(path text) returns uuid
language sql immutable as $$
  select case when split_part(path, '/', 2) ~ '^[0-9a-f-]{36}$'
    then split_part(path, '/', 2)::uuid end
$$;

create policy "wardmap: read patient files" on storage.objects for select
  using (
    bucket_id = 'record-files'
    and split_part(name, '/', 1) = public.my_hospital()::text
    and public.can_view_patient(public.record_file_patient(name))
  );

create policy "wardmap: add patient files" on storage.objects for insert
  with check (
    bucket_id = 'record-files'
    and split_part(name, '/', 1) = public.my_hospital()::text
    and public.can_edit_patient(public.record_file_patient(name))
  );

-- One row per file, same shape and rules as the other record tables.
alter table results add unique (id, patient_id);

create table result_files (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  patient_id uuid not null,
  created_by uuid default auth.uid() references staff(id),
  created_at timestamptz not null default now(),
  result_id uuid not null,
  path text not null unique,
  file_name text not null,
  content_type text not null
    check (content_type like 'image/%' or content_type like 'video/%'),
  size_bytes bigint,
  foreign key (patient_id, hospital_id) references patients(id, hospital_id) on delete cascade,
  -- The result must be this patient's.
  foreign key (result_id, patient_id) references results(id, patient_id) on delete cascade,
  -- The file must be stored under this hospital and patient.
  check (path like hospital_id::text || '/' || patient_id::text || '/%')
);

create index on result_files (result_id);

alter table result_files enable row level security;
create policy "read" on result_files for select
  using (hospital_id = my_hospital() and can_view_patient(patient_id));
create policy "add" on result_files for insert
  with check (hospital_id = my_hospital() and can_edit_patient(patient_id));
create policy "remove" on result_files for delete
  using (hospital_id = my_hospital() and can_edit_patient(patient_id));

create trigger keep_author before insert or update on result_files
  for each row execute function keep_author();
create trigger record_change after insert or update or delete on result_files
  for each row execute function record_change();
