-- Rooms: a ward has one or more rooms, and each room has its beds.
-- The floor map moves from the ward to each room. A ward with a single room
-- looks the same as before: the app opens its beds directly.
-- See docs/ward-board.md.

create table rooms (
  id uuid primary key default gen_random_uuid(),
  hospital_id uuid not null,
  ward_id uuid not null,
  name text not null,
  map_rows int not null default 4 check (map_rows between 1 and 30),
  map_columns int not null default 6 check (map_columns between 1 and 30),
  created_at timestamptz not null default now(),
  -- Removing a ward removes its (empty) rooms. Beds still block removal.
  foreign key (ward_id, hospital_id) references wards(id, hospital_id) on delete cascade,
  unique (ward_id, name),
  unique (id, ward_id)
);

alter table rooms enable row level security;
create policy "see rooms" on rooms for select
  using (hospital_id = my_hospital());
create policy "admin manages rooms" on rooms for all
  using (hospital_id = my_hospital() and i_am_admin())
  with check (hospital_id = my_hospital() and i_am_admin());

create trigger record_change after insert or update or delete on rooms
  for each row execute function record_change();

-- Every existing ward gets one room holding its beds and its map.
insert into rooms (hospital_id, ward_id, name, map_rows, map_columns)
  select hospital_id, id, 'Room 1', map_rows, map_columns from wards;

-- Beds and map labels belong to a room in their ward.
alter table beds add column room_id uuid;
update beds b set room_id = r.id from rooms r where r.ward_id = b.ward_id;
alter table beds
  alter column room_id set not null,
  add constraint bed_room_in_ward foreign key (room_id, ward_id) references rooms(id, ward_id),
  drop constraint one_bed_per_cell,
  add constraint one_bed_per_cell unique (room_id, map_row, map_column);

alter table ward_landmarks add column room_id uuid;
update ward_landmarks l set room_id = r.id from rooms r where r.ward_id = l.ward_id;
alter table ward_landmarks
  alter column room_id set not null,
  add constraint landmark_room_in_ward foreign key (room_id, ward_id)
    references rooms(id, ward_id) on delete cascade,
  drop constraint ward_landmarks_ward_id_map_row_map_column_key,
  add constraint one_landmark_per_cell unique (room_id, map_row, map_column);

-- The map size now lives on each room.
alter table wards drop column map_rows, drop column map_columns;

-- A ward always starts with one room, so single-room wards never need
-- rooms set up. A bed or label added without a room goes into the ward's
-- first room.
create function first_room(p_ward_id uuid) returns uuid
language sql stable as $$
  select id from rooms where ward_id = p_ward_id order by created_at, name limit 1
$$;

create function add_first_room() returns trigger language plpgsql as $$
begin
  insert into rooms (hospital_id, ward_id, name) values (new.hospital_id, new.id, 'Room 1');
  return new;
end
$$;

create trigger add_first_room after insert on wards
  for each row execute function add_first_room();

create function fill_room() returns trigger language plpgsql as $$
begin
  if new.room_id is null then
    new.room_id := first_room(new.ward_id);
  end if;
  return new;
end
$$;

create trigger fill_room before insert on beds
  for each row execute function fill_room();
create trigger fill_room before insert on ward_landmarks
  for each row execute function fill_room();
