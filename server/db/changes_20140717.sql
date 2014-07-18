begin;

select speedycrew.require_change('change_20140715.sql');

select speedycrew.provide_change('change_20140717.sql');

SET search_path = speedycrew, public, pg_catalog;

alter table speedycrew.profile_subscription add column ref_count int not null default 0;

alter table speedycrew.profile_subscription alter column ref_count drop default;

drop function profile_subscribe(int, int);

create or replace function profile_subscription_inc(i_profile_id int, i_subscribed_to_profile_id int) returns void
    language plpgsql
    as $$
begin
  begin
    -- I guess that this will be called most often in cases where the
    -- record doesn't yet exist (new matches against people you don't
    -- know) so I will try to INSERT first
    insert into profile_subscription (profile, subscribed_to, created, ref_count)
    values (i_profile_id, i_subscribed_to_profile_id, current_timestamp, 1);
    -- if we get here, it didn't exist already, so we replicate the
    -- insertion (this triggers the creation fo a profile on 
    insert into event (profile, seq, type, other_profile, tab)
    values (i_profile_id, next_sequence(i_profile_id), 'INSERT', i_subscribed_to_profile_id, 'PROFILE');
  exception when unique_violation then
    -- we were already subscribed, so increase the reference count
    update profile_subscription
       set ref_count = ref_count + 1
     where profile = i_profile_id
       and subscribed_to = i_subscribed_to_profile_id;
    if not found then
      -- if we get here, there was a row already when we tried to
      -- insert, and then it was gone when we tried up update it, so
      -- in theory we should retry the whole operation (forever) but
      -- due to laziness today I will bail out here
      raise exception 'Race condition in profile_subscription_increment';
    end if;
  end;
end;
$$;

create or replace function profile_subscription_dec(i_profile_id int, i_subscribed_to_profile_id int) returns void
    language plpgsql
    as $$
declare
  v_ref_count int;
begin
  update speedycrew.profile_subscription
     set ref_count = ref_count - 1
   where profile = i_profile_id
     and subscribed_to = i_subscribed_to_profile_id
  returning ref_count into v_ref_count;
  if not found then
    raise exception 'profile_subscription_dec -- expected to decrement row for %, % but there was none', i_profile_id, i_subscribed_to_profile_id;
  end if;
  if v_ref_count = 0 then
    delete from speedycrew.profile_subscription
     where profile = i_profile_id
       and subscribed_to = i_subscribed_to_profile_id;
    insert into speedycrew.event (profile, seq, type, other_profile, created, tab)
    values (i_profile_id, speedycrew.next_sequence(i_profile_id), 'DELETE', i_subscribed_to_profile_id, current_timestamp, 'PROFILE');
  end if;
end;
$$;

CREATE or replace FUNCTION delete_search(i_search_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  v_profile_id int;
  v_a uuid;
  v_b uuid;
  v_referenced_profile_id int;
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
  for v_profile_id, v_a, v_b, v_referenced_profile_id in
    with relevant_matches as (
                  select s.owner, m.a, m.b, s2.owner owner2
                    from speedycrew.search s
                    join speedycrew.match m on s.id = m.a
                    join speedycrew.search s2 on s2.id = m.b
                   where m.a = i_search_id
                   union all
                  select s.owner, m.a, m.b, s2.owner owner2
                    from speedycrew.search s
                    join speedycrew.match m on s.id = m.a
		    join speedycrew.search s2 on s2.id = m.b
                   where m.b = i_search_id)
    select owner, a, b, owner2
      from relevant_matches
     order by owner
  loop
    delete from speedycrew.match
     where a = v_a and b = v_b;
    insert into speedycrew.event (profile, seq, type, search, match, tab)
    values (v_profile_id, next_sequence(v_profile_id), 'DELETE', v_a, v_b, 'MATCH');
    perform speedycrew.profile_subscription_dec(v_profile_id, v_referenced_profile_id);
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

drop function find_matches_mirrored_sorted(uuid);

CREATE or replace FUNCTION find_matches_mirrored_sorted(i_search_id uuid) RETURNS TABLE(profile integer, a uuid, b uuid, matches integer, distance double precision, score double precision, message text, referenced_profile integer)
    LANGUAGE plpgsql
    AS $$
begin
  return query
  select s.owner, t.a, t.b, t.matches, t.distance, t.score, t.message, s2.owner
    from speedycrew.find_matches_mirrored(i_search_id) t
    join speedycrew.search s on s.id = t.a
    join speedycrew.search s2 on s2.id = t.b
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
  v_referenced_profile int;
begin
  -- we compute all the matches, sorted by profile so that we can
  -- generate event sequences for each profile without causing
  -- deadlocks
  for v_profile, v_a, v_b, v_matches, v_distance, v_score, v_message, v_referenced_profile in
    select t.profile, t.a, t.b, t.matches, t.distance, t.score, t.message, t.referenced_profile
      from find_matches_mirrored_sorted(i_search_id) t
  loop
      perform speedycrew.profile_subscription_inc(v_profile, v_referenced_profile);
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