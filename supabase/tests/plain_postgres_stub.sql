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
