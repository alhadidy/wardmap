-- Ward map: admins lay out each ward as a grid that matches the real floor,
-- placing beds and landmarks (nurse station, entrance, WC…) in its cells.
-- See docs/ward-board.md.

-- Size of the ward's grid.
alter table wards
  add column map_rows int not null default 4 check (map_rows between 1 and 30),
  add column map_columns int not null default 6 check (map_columns between 1 and 30);

-- Where each bed sits on the grid (both empty = not on the map yet).
alter table beds
  add column map_row int check (map_row >= 0),
  add column map_column int check (map_column >= 0),
  add constraint bed_fully_placed check ((map_row is null) = (map_column is null)),
  add constraint one_bed_per_cell unique (ward_id, map_row, map_column);

-- Non-bed labels on the map.
create table ward_landmarks (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  ward_id uuid not null,
  label text not null,
  map_row int not null check (map_row >= 0),
  map_column int not null check (map_column >= 0),
  foreign key (ward_id, hospital_id) references wards(id, hospital_id) on delete cascade,
  unique (ward_id, map_row, map_column)
);

alter table ward_landmarks enable row level security;
create policy "see landmarks" on ward_landmarks for select
  using (hospital_id = my_hospital());
create policy "admin manages landmarks" on ward_landmarks for all
  using (hospital_id = my_hospital() and i_am_admin())
  with check (hospital_id = my_hospital() and i_am_admin());

create trigger record_change after insert or update or delete on ward_landmarks
  for each row execute function record_change();
