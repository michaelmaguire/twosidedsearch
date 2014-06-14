begin;

select speedycrew.require_change('change_20140612.sql');
select speedycrew.provide_change('change_20140614.sql');

-- this table is unlogged (ie will be empty if DB restarted because
-- it's not being logged, which makes it faster, basically memory
-- only: it's really just a way of communicating with speedy_notifier,
-- not being used for 'persistence')

create unlogged table tickle_queue (
  profile integer not null references speedycrew.profile(id),
  created timestamptz default current_timestamp
);

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
      insert into speedycrew.tickle_queue (profile)
      values (v_profile);
  end loop;
  notify tickle;
end;
$$
language 'plpgsql';

commit;