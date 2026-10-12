-- Checks ward types (the icons on each ward).
-- Uses the hospital and team from test_helpers.sql.

set role authenticated;

select as_user('00000000-0000-0000-0000-000000000001');
update wards set types = '{women,children}';
select check_that((select types from wards) = '{women,children}', 'Admin gives a ward two types');
select check_refused($$update wards set types = '{kitchen}'$$, 'Unknown ward types are refused');
select check_that((select count(*) from audit_log where table_name = 'wards' and action = 'update') >= 1,
  'Ward type changes are in the history');

select as_user('00000000-0000-0000-0000-000000000003');
update wards set types = '{icu}';
select check_that((select types from wards) = '{women,children}', 'Resident cannot change ward types');
