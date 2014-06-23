begin;

select speedycrew.require_change('change_20140620.sql');

select speedycrew.provide_change('change_20140623.sql');

create type speedycrew.event_table as enum (
    'PROFILE',
    'MATCH',
    'SEARCH'
);

alter table speedycrew.event add column tab speedycrew.event_table not null default 'MATCH';

alter table speedycrew.event alter column tab drop default;

SET search_path = speedycrew, pg_catalog;

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
      insert into speedycrew.tickle_queue (profile)
      values (v_profile);
  end loop;
  notify tickle;
end;
$$;

CREATE or replace FUNCTION delete_search(i_search_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  v_profile_id int;
  v_a uuid;
  v_b uuid;
begin
  -- we need to remove all matches that have this search on the a side
  -- or b side, generating events in profile order to avoid deadlocks
  -- when we generate event sequences
  --
  -- we CAN delete the 'match' records now, because -- even though
  -- they may be referenced by 'event' records, the event records
  -- contain pairs of 'search' primary key; if there are still
  -- 'INSERT' events for a match we delete, they will simply be
  -- skipped by future incremental synchronisations
  for v_profile_id, v_a, v_b in
    with relevant_matches as (
                  select s.owner, m.a, m.b
                    from speedycrew.search s
                    join speedycrew.match m on s.id = m.a
                   where m.a = i_search_id
                   union all
                  select s.owner, m.a, m.b
                    from speedycrew.search s
                    join speedycrew.match m on s.id = m.b
                   where m.b = i_search_id)
    select owner, a, b
      from relevant_matches
     order by owner
  loop
    delete from speedycrew.match
     where a = v_a and b = v_b;
    insert into speedycrew.event (profile, seq, type, search, match, tab)
    values (v_profile_id, next_sequence(v_profile_id), 'DELETE', v_a, v_b, 'MATCH');
  end loop;      
  -- we CAN'T delete the 'search' record yet, because it may be
  -- references by events;
  -- TODO when does it actually get deleted? we need some kind of
  -- garbage collector that will sort these out periodically after
  -- finding tthat they are not referenced...  this is one of the
  -- weaker parts of this grand plan
  update speedycrew.search
     set status = 'DELETED'
   where id = i_search_id;
  select owner
    into v_profile_id
    from speedycrew.search
   where id = i_search_id;
  insert into speedycrew.event (profile, seq, type, search, tab)
  values (v_profile_id, next_sequence(v_profile_id), 'DELETE', i_search_id, 'SEARCH');
end;
$$;

commit;