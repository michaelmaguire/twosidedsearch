begin;

select speedycrew.require_change('change_20140624.sql');

select speedycrew.provide_change('change_20140625.sql');

SET search_path = speedycrew, public, pg_catalog;

drop FUNCTION find_matches(i_search_id uuid);

CREATE FUNCTION find_matches(i_search_id uuid) RETURNS TABLE(search_id uuid, matches integer, distance double precision, score double precision, query text)
    LANGUAGE plpgsql
    AS $$
declare
  v_profile int;
  v_side speedycrew.search_side;
  v_geography geography;
  v_radius float;
  v_tag_ids integer[];
begin
  -- load some data from this search into local variables
  select s.side, s.geography, s.radius, s.owner
    into v_side, v_geography, v_radius, v_profile
    from speedycrew.search s
   where s.id = i_search_id;
  if not found then
    return;
  end if;
  select array_agg(st.tag)
    into v_tag_ids
    from speedycrew.search_tag st
   where st.search = i_search_id;
   -- SEEK has a radius (SEEKers are mobile)
  if v_side = 'SEEK' then
    return query
    select s.id,
           count(*)::int as matches,
           st_distance(s.geography, v_geography)::float as distance,
           (count(*) + 1 / greatest(1, st_distance(s.geography, v_geography)))::float as score,
	   s.query
      from speedycrew.search s
      join speedycrew.search_tag st on st.search = s.id
     where st_dwithin(s.geography, v_geography, v_radius)
       and st.tag = any (v_tag_ids)
       and s.side = 'PROVIDE'
       and s.status = 'ACTIVE'
     group by s.id;
  else
    -- v_side = 'PROVIDE'
    return query
    select s.id,
           count(*)::int as matches,
           st_distance(s.geography, v_geography)::float as distance,
           (count(*) + 1 / greatest(1, st_distance(s.geography, v_geography)))::float as score,
	   s.query
      from speedycrew.search s
      join speedycrew.search_tag st on st.search = s.id
     where st_dwithin(s.geography, v_geography, s.radius)
       and st.tag = any (v_tag_ids)                  
       and s.side = 'SEEK'
       and s.status = 'ACTIVE'
     group by s.id;
  end if;
end;
$$;

drop FUNCTION find_matches_mirrored(i_search_id uuid);

CREATE FUNCTION find_matches_mirrored(i_search_id uuid) RETURNS TABLE(a uuid, b uuid, matches integer, distance double precision, score double precision, message text)
    LANGUAGE plpgsql
    AS $$
declare
  v_search_id uuid;
  v_matches int;
  v_distance float;
  v_score float;
  v_query text;
  v_my_query text;
  v_my_side search_side;
begin
  select s.query, s.side
    into v_my_query, v_my_side
    from search s
   where s.id = i_search_id;
  for v_search_id, v_matches, v_distance, v_score, v_query in
    select t.search_id, t.matches, t.distance, t.score, t.query
      from speedycrew.find_matches(i_search_id) t
  loop
    -- this is the aggressive search
    a := i_search_id;
    b := v_search_id;
    matches = v_matches;
    distance = v_distance;
    score := v_score;
    message := null;
    return next;
    -- the is the passive search
    a := v_search_id;
    b := i_search_id;
    if v_my_side = 'PROVIDE' then
        message := 'Captain sighted: ' || v_my_query;
    else
        message := 'Crew sighted: ' || v_my_query;
    end if;
    return next;
  end loop;
end;
$$;

drop FUNCTION find_matches_mirrored_sorted(i_search_id uuid);

CREATE FUNCTION find_matches_mirrored_sorted(i_search_id uuid) RETURNS TABLE(profile integer, a uuid, b uuid, matches integer, distance double precision, score double precision, message text)
    LANGUAGE plpgsql
    AS $$
begin
  return query
  select s.owner, t.a, t.b, t.matches, t.distance, t.score, t.message
    from speedycrew.find_matches_mirrored(i_search_id) t
    join speedycrew.search s on s.id = t.a
   order by s.owner;
end;
$$;

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
  v_message text;
begin
  -- we compute all the matches, sorted by profile so that we can
  -- generate event sequences for each profile without causing
  -- deadlocks
  for v_profile, v_a, v_b, v_matches, v_distance, v_score, v_message in
    select t.profile, t.a, t.b, t.matches, t.distance, t.score, t.message
      from find_matches_mirrored_sorted(i_search_id) t
  loop
      insert into speedycrew.match (a, b, matches, distance, score, status, created)
      values (v_a, v_b, v_matches, v_distance, v_score, 'ACTIVE', now());
      insert into speedycrew.event (profile, seq, type, search, match, tab)
      values (v_profile, next_sequence(v_profile), 'INSERT', v_a, v_b, 'MATCH');
      insert into speedycrew.tickle_queue (profile, message)
      values (v_profile, v_message);
  end loop;
  notify tickle;
end;
$$;

commit;