-- Shared by every *_test.sql file. Loaded after the migrations.

grant select, insert, update, delete on all tables in schema public to authenticated;
grant execute on all functions in schema public to authenticated;

-- Act as a given staff member ('' = logged out).
create function as_user(u text) returns void language sql as $$
  select set_config('request.jwt.claim.sub', u, false);
$$;

-- Stop with an error if a check fails.
create function check_that(ok boolean, what text) returns void language plpgsql as $$
begin
  if not coalesce(ok, false) then raise exception 'FAILED: %', what; end if;
  raise notice 'ok: %', what;
end $$;

-- Check that a statement is refused.
create function check_refused(stmt text, what text) returns void language plpgsql as $$
begin
  execute stmt;
  raise exception 'FAILED: %', what;
exception when others then
  if sqlerrm like 'FAILED%' then raise; end if;
  raise notice 'ok: %', what;
end $$;

grant execute on function as_user, check_that, check_refused to authenticated;

-- One hospital, one ward, and a small team, used by every test.
insert into hospitals (id, name) values ('00000000-0000-0000-0000-0000000000a1', 'General Hospital');
insert into wards (id, hospital_id, name) values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 'Ward 5');
insert into staff (id, hospital_id, username, full_name, role) values
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'admin', 'Admin', 'admin'),
  ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1', 'dr.cons', 'Consultant', 'consultant'),
  ('00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-0000000000a1', 'dr.r6', 'Senior Resident', 'r6'),
  ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a1', 'dr.r3', 'Resident R3', 'r3'),
  ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000a1', 'dr.r1', 'Resident R1', 'r1'),
  ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-0000000000a1', 'dr.rot', 'Rotator', 'rotator');
