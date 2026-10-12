-- Lets the migrations and tests run on plain Postgres (no Supabase needed).
-- Mimics the bits of Supabase we use: the auth.users table, auth.uid(),
-- and the anon/authenticated roles.
create schema auth;
create table auth.users (id uuid primary key);
-- Same as Supabase's: the logged-in user's id from the request's token.
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  )::uuid
$$;
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
end $$;
grant usage on schema public, auth to anon, authenticated;

-- Supabase Storage: the buckets and files tables (just the columns we use).
create schema storage;
create table storage.buckets (
  id text primary key, name text not null, public boolean default false,
  file_size_limit bigint, allowed_mime_types text[]
);
create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id), name text, owner uuid
);
alter table storage.objects enable row level security;
grant usage on schema storage to anon, authenticated;
grant select, insert, update, delete on storage.objects to authenticated;
