-- Wardmap step 2: ward board and patient flow (admit, transfer, discharge).
-- See docs/ward-board.md.

-- A patient's bed must be in the patient's ward.
alter table beds add constraint beds_id_ward_unique unique (id, ward_id);
-- This replaces the step 1 bed link (the ward already ties the bed to the
-- hospital), so each patient has exactly one link to beds.
alter table patients drop constraint patients_bed_id_hospital_id_fkey;
alter table patients add constraint patient_bed_in_ward
  foreign key (bed_id, ward_id) references beds(id, ward_id);

-- One current patient per bed.
create unique index one_patient_per_bed on patients (bed_id)
  where discharged_at is null and bed_id is not null;

-- Discharging a patient frees their bed. The old bed stays in the history.
alter table patients add constraint discharged_has_no_bed
  check (discharged_at is null or bed_id is null);

-- The ward board shows every bed as free or taken. A taken bed may hold a
-- patient you are not allowed to see, so this tells you only that it is
-- taken, never who is in it.
create function ward_occupied_beds(p_ward_id uuid) returns setof uuid
language sql stable security definer set search_path = public as $$
  select bed_id from patients
  where ward_id = p_ward_id
    and hospital_id = my_hospital()
    and discharged_at is null
    and bed_id is not null
$$;
