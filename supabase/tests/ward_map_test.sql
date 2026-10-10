-- Checks the ward map rules.
-- Uses the hospital and team from test_helpers.sql.

insert into beds (id, hospital_id, ward_id, label) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', '1'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', '2');

set role authenticated;

select as_user('00000000-0000-0000-0000-000000000001');
update wards set map_rows = 3, map_columns = 5;
update beds set map_row = 0, map_column = 0 where label = '1';
select check_that((select map_column from beds where label = '1') = 0, 'Admin places a bed on the map');
select check_refused($$update beds set map_row = 0, map_column = 0 where label = '2'$$, 'Two beds cannot share a cell');
select check_refused($$update beds set map_row = 1 where label = '2'$$, 'A bed needs both a row and a column');
insert into ward_landmarks (hospital_id, ward_id, label, map_row, map_column)
  values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'Nurse station', 2, 4);
select check_that((select count(*) from ward_landmarks) = 1, 'Admin adds a landmark');
select check_that((select count(*) from audit_log where table_name = 'ward_landmarks') = 1, 'Landmarks are in the history');

-- Others see the map but cannot change it.
select as_user('00000000-0000-0000-0000-000000000003');
select check_that((select count(*) from ward_landmarks) = 1, 'Resident sees the landmark');
update beds set map_row = 2, map_column = 2 where label = '1';
select check_that((select map_row from beds where label = '1') = 0, 'Resident cannot move beds');
select check_refused($$insert into ward_landmarks (hospital_id, ward_id, label, map_row, map_column)
  values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'WC', 0, 1)$$,
  'Resident cannot add landmarks');
