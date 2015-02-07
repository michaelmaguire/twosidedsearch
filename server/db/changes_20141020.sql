begin;

select speedycrew.require_change('change_20140717.sql');

select speedycrew.provide_change('change_20141020.sql');

SET search_path = speedycrew, public, pg_catalog;

alter table crew_member add constraint crew_member_uniq unique (crew, profile);

commit;