begin;

select speedycrew.require_change('change_20140614.sql');

select speedycrew.provide_change('change_20140619.sql');

alter table speedycrew.event add column created timestamptz not null default current_timestamp;

alter table speedycrew.profile_sequence add column low_time timestamptz not null default current_timestamp;

commit;