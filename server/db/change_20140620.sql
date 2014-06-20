begin;

select speedycrew.require_change('change_20140619.sql');

select speedycrew.provide_change('change_20140620.sql');

alter table speedycrew.profile_sequence alter column low_time drop not null;

alter table speedycrew.profile_sequence alter column low_sequence drop not null;

-- Whenever we fetch the next event sequence for a profile, we also
-- note this new sequence as the low_sequence if it was previously null
create or replace function speedycrew.next_sequence(i_profile_id int) returns int as $$
     update speedycrew.profile_sequence
        set high_sequence = high_sequence + 1,
	    low_sequence = coalesce(low_sequence, high_sequence + 1),
	    low_time = coalesce(low_time, current_timestamp)
      where profile = i_profile_id
  returning high_sequence;
$$
language 'sql';

-- a place for system-wide settings; I figured they might as well go
-- into the database, otherwise they'll need to go into configuration
-- files on every server where speedy-jobs is installed...
create table speedycrew.system_setting (
    name text primary key,
    text_value text,
    interval_value interval
);

insert into speedycrew.system_setting (name, interval_value)
values ('garbage_collection.max_event_age', '7 days'::interval),
       ('garbage_collection.max_deleted_search_age', '7 days'::interval),
       ('garbage_collection.max_search_age_inactive_profile', '30 days'::interval),
       ('garbage_collection.nap_time', '0 seconds');

commit;