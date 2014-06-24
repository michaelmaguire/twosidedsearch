begin;

select speedycrew.require_change('change_20140623.sql');

select speedycrew.provide_change('change_20140624.sql');

alter table tickle_queue add column message text;

CREATE or replace FUNCTION run_search(i_search_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
      insert into speedycrew.event (profile, seq, type, search, match, tab)
      values (v_profile, next_sequence(v_profile), 'INSERT', v_a, v_b, 'MATCH');
      insert into speedycrew.tickle_queue (profile, message)
      values (v_profile, 'Hello! A nice message goes here, perhaps with some details about a match.');
  end loop;
  notify tickle;
end;
$$;

commit;