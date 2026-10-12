-- Checks rooms: every ward has at least one, beds sit in a room of their ward.
-- Uses the hospital and team from test_helpers.sql.

select check_that((select count(*) from rooms where ward_id = '00000000-0000-0000-0000-0000000000b1') = 1,
  'A new ward starts with one room');

insert into beds (hospital_id, ward_id, label) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', '1');
select check_that((select room_id from beds where label = '1') = (select id from rooms),
  'A bed added without a room goes into the ward''s room');

insert into wards (id, hospital_id, name) values
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a1', 'Ward 6');
select check_refused($$insert into beds (hospital_id, ward_id, room_id, label) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
   (select id from rooms where ward_id = '00000000-0000-0000-0000-0000000000b2'), '2')$$,
  'A bed cannot be in a room of another ward');

set role authenticated;

select as_user('00000000-0000-0000-0000-000000000001');
insert into rooms (hospital_id, ward_id, name) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'Room 2');
select check_that((select count(*) from rooms where ward_id = '00000000-0000-0000-0000-0000000000b1') = 2,
  'Admin adds a second room');
update beds set room_id = (select id from rooms where name = 'Room 2' and ward_id = '00000000-0000-0000-0000-0000000000b1')
  where label = '1';
select check_that((select r.name from beds b join rooms r on r.id = b.room_id where b.label = '1') = 'Room 2',
  'Admin moves a bed to another room');
select check_refused($$delete from rooms where name = 'Room 2'$$, 'A room with beds cannot be removed');
delete from rooms where name = 'Room 1' and ward_id = '00000000-0000-0000-0000-0000000000b1';
select check_that((select count(*) from rooms where ward_id = '00000000-0000-0000-0000-0000000000b1') = 1,
  'Admin removes an empty room');
select check_that((select count(*) from audit_log where table_name = 'rooms') >= 3, 'Rooms are in the history');

delete from wards where id = '00000000-0000-0000-0000-0000000000b2';
select check_that((select count(*) from rooms where ward_id = '00000000-0000-0000-0000-0000000000b2') = 0,
  'Removing an empty ward removes its room');

select as_user('00000000-0000-0000-0000-000000000003');
select check_that((select count(*) from rooms) = 1, 'Resident sees the rooms');
update rooms set name = 'Side room';
select check_that((select name from rooms) = 'Room 2', 'Resident cannot rename rooms');
select check_refused($$insert into rooms (hospital_id, ward_id, name) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', 'Room 3')$$,
  'Resident cannot add rooms');
