begin;

select speedycrew.require_change('change_20140625.sql');

select speedycrew.provide_change('change_20140626.sql');

SET search_path = speedycrew, public, pg_catalog;

alter table system_setting add column int_value int;

commit;