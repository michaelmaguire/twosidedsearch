begin;

alter table speedycrew.device add column google_registration_id text;

alter table speedycrew.device add column apple_device_token text;

create or replace function run_search(i_search_id uuid) returns void as $$
declare
  v_profile int;
  v_a uuid;
  v_b uuid;
  v_matches int;
  v_distance float;
  v_score float;
begin
  -- we compute all the matches, sorted by profile so that we can
  -- generate event sequences for each profile without causing
  -- deadlocks
  for v_profile, v_a, v_b, v_matches, v_distance, v_score in
    select t.profile, t.a, t.b, t.matches, t.distance, t.score
      from find_matches_mirrored_sorted(i_search_id) t
  loop
      insert into speedycrew.match (a, b, matches, distance, score, status, created)
      values (v_a, v_b, v_matches, v_distance, v_score, 'ACTIVE', now());
      insert into speedycrew.event (profile, seq, type, search, match)
      values (v_profile, next_sequence(v_profile), 'INSERT', v_a, v_b);
      perform pg_notify('tickle', v_profile::text);
  end loop;  
end;
$$
language 'plpgsql';

select speedycrew.provide_change('change_20140612.sql');

commit;