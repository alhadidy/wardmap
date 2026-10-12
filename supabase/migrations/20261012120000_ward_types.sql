-- Ward types, shown as icons next to the ward's name.
-- A ward can have several, e.g. a women and children ward.
-- The app has the same list with labels and icons (lib/ward_types.dart);
-- add new types in both places.

alter table wards
  add column types text[] not null default '{}',
  add constraint ward_types_known check (types <@ array[
    'men', 'women', 'children', 'neonatal', 'maternity',
    'er', 'icu', 'rcu', 'ccu', 'hdu',
    'medical', 'surgical', 'neuro', 'ortho', 'burns', 'oncology',
    'renal', 'psychiatric', 'isolation', 'recovery', 'day_case'
  ]::text[]);
