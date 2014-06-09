begin;

create schema speedycrew;

set search_path to speedycrew, public;

create type profile_status as enum ('ACTIVE', 'CANCELLED', 'BANNED');

create table profile (
  id serial primary key,
  username text unique,
  real_name text,
  email text unique,
  password_hash text,
  status profile_status not null,
  message text,
  created timestamptz not null default now(),
  modified timestamptz not null default now()
);

comment on table profile is 'A user in our system';

create table device (
  id text primary key,
  profile integer not null references profile(id),
  platform text,
  version text,
  last_seen timestamptz null,
  created timestamptz not null,
  ended timestamptz
);

comment on table device is 'A device used by a person to access the system';

create table client_certificate (
  device text not null references device(id),
  certificate text not null
);

comment on table client_certificate is 'Public certificate data for a device';

create table country (
  id varchar(2) primary key,
  name text not null
);

insert into country values ('GB', 'United Kingdom');

create type tag_status as enum ('ACTIVE', 'BANNED', 'DELETED');

create table tag (
  id serial primary key,
  name text unique not null,
  description text,
  status tag_status not null default 'ACTIVE',
  created timestamptz not null default now(),
  creator integer references profile(id)
);

comment on table tag is 'Tags';

create type search_side as enum ('SEEK', 'PROVIDE');

create type search_status as enum ('ACTIVE', 'DELETED');

create table search (
  id uuid primary key,
  owner integer not null references profile(id),
  query text not null,
  side search_side not null,
  address text,
  postcode text,
  city text,
  country varchar(2) references country(id),
  geography geography not null,
  radius float check ((radius is null) = (side = 'PROVIDE')),
  status search_status not null,
  created timestamptz not null
);

comment on table search is 'A search created by either a seeker or provider of a service';

create table search_tag (
  search uuid not null references search(id),
  tag integer not null references tag(id),
  primary key (search, tag)
);

comment on table search_tag is 'A tag that is part of a search (many-to-many link table)';

create type availability_status as enum ('AVAILABLE', 'NOT_AVAILABLE', 'MAYBE_AVAILABLE');

create table profile_availability (
  profile integer not null references profile(id),
  day date not null,
  availability availability_status not null,
  note text,
  modified timestamptz not null
);

comment on table profile_availability is 'A person''s availability status for each day';

create type match_status as enum ('ACTIVE', 'DELETED');

create table match (
  a uuid not null references search(id),
  b uuid not null references search(id),
  matches int not null,
  distance float not null,
  score float not null,
  status match_status not null,
  created timestamptz not null,
  primary key (a, b)
);

comment on table match is 'A match between two searches';

create table tag_count (
  tag integer not null primary key,
  provide_counter integer not null,
  seek_counter integer not null,
  counter integer not null
);

comment on table tag_count is 'Recent tag usage counters';

create index tag_count_counter_idx on tag_count(counter);

create or replace function make_geo(long double precision, lat double precision)
returns geography as $$
  select st_geographyfromtext('POINT(' || long::text || ' ' || $2::text || ')');
$$
language sql
immutable
returns null on null input;

create or replace function find_matches(i_search_id uuid) returns table (search_id uuid, matches int, distance float, score float) as $$
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
           (count(*) + 1 / greatest(1, st_distance(s.geography, v_geography)))::float as score
      from speedycrew.search s
      join speedycrew.search_tag st on st.search = s.id
     where st_dwithin(s.geography, v_geography, v_radius)
       and st.tag = any (v_tag_ids)
       and s.side = 'PROVIDE'
     group by s.id;
  else
    -- v_side = 'PROVIDE'
    return query
    select s.id,
           count(*)::int as matches,
           st_distance(s.geography, v_geography)::float as distance,
           (count(*) + 1 / greatest(1, st_distance(s.geography, v_geography)))::float as score
      from speedycrew.search s
      join speedycrew.search_tag st on st.search = s.id
     where st_dwithin(s.geography, v_geography, s.radius)
       and st.tag = any (v_tag_ids)                  
       and s.side = 'SEEK'
     group by s.id;
  end if;
end;
$$
language 'plpgsql';

create or replace function find_matches_mirrored(i_search_id uuid)
returns table (a uuid, b uuid, matches int, distance float, score float) as 
$$
declare
  v_search_id uuid;
  v_matches int;
  v_distance float;
  v_score float;
begin
  for v_search_id, v_matches, v_distance, v_score in
    select t.search_id, t.matches, t.distance, t.score
      from speedycrew.find_matches(i_search_id) t
  loop
    a := i_search_id;
    b := v_search_id;
    matches = v_matches;
    distance = v_distance;
    score := v_score;
    return next;
    a := v_search_id;
    b := i_search_id;
    return next;
  end loop;
end;
$$
language 'plpgsql';

create or replace function find_matches_mirrored_sorted(i_search_id uuid)
returns table (profile int, a uuid, b uuid, matches int, distance float, score float) as 
$$
begin
  return query
  select s.owner, t.a, t.b, t.matches, t.distance, t.score
    from speedycrew.find_matches_mirrored(i_search_id) t
    join speedycrew.search s on s.id = t.a
   order by s.owner;
end;
$$
language 'plpgsql';

-- this information is functionally dependent on profile.id, but is
-- kept in a separate table because it will be frequently updated and
-- I'm guessing up front without testing that keeping it small will be
-- a good idea
create table speedycrew.profile_sequence (
  profile integer primary key references speedycrew.profile(id) not null,
  low_sequence integer not null,
  high_sequence integer not null
);

comment on table speedycrew.profile_sequence is 'Counters to keep track of the window of event sequence numbers we have for each profile.';

-- Increment the high water sequence for a profile, and return it so
-- that it can be used for a new event record.  This locks the
-- profile_sequence row so care must be taken to avoid deadlocks when
-- using this in a transaction involving more than one profile.
create or replace function next_sequence(i_profile_id int) returns int as $$
     update speedycrew.profile_sequence
        set high_sequence = high_sequence + 1
      where profile = i_profile_id
  returning high_sequence;
$$
language 'sql';

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
  end loop;  
end;
$$
language 'plpgsql';

create or replace function delete_search(i_search_id uuid) returns void as $$
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
    insert into speedycrew.event (profile, seq, type, search, match)
    values (v_profile_id, next_sequence(v_profile_id), 'DELETE', v_a, v_b);
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
  insert into speedycrew.event (profile, seq, type, search)
  values (v_profile_id, next_sequence(v_profile_id), 'UPDATE', i_search_id);
end;
$$
language 'plpgsql';

create table speedycrew.file (
  profile integer not null references speedycrew.profile(id),
  name text not null,
  mime_type text not null,
  version integer not null,
  created timestamptz not null,
  modified timestamptz not null,
  size integer not null,
  data bytea not null,
  public boolean not null,
  primary key (profile, name)
);

comment on table speedycrew.file is 'Filesystem-like data storage for holding arbitrary profile data';

create table speedycrew.room (
  id uuid primary key,
  name text,
  creator int not null references speedycrew.profile(id),
  created timestamptz not null
);

comment on table speedycrew.room is 'A chat room or channel for discussion.';

create table speedycrew.room_member (
  room uuid references speedycrew.room(id),
  profile int references speedycrew.profile(id),
  creator int not null references speedycrew.profile(id),
  created timestamptz not null
);

-- messages can either be in a room (instant messenger style) or free
-- floating (more like an email); even when they are sent to a 'room',
-- they must be sent to each other user in the room, because they need
-- to be encrypted separately for each recipient by the sender device

create table speedycrew.message (
  id uuid primary key,
  recipient integer not null references speedycrew.profile(id),
  sender integer null references speedycrew.profile(id),
  room uuid references speedycrew.room(id),
  body text not null,
  is_read boolean not null,
  is_starred boolean not null,
  created timestamptz not null
);

comment on table speedycrew.message is 'A message for delivery to a user.';

-- the event stream delivered to end users

create type event_type as enum ('INSERT', 'UPDATE', 'DELETE');

create table speedycrew.event (
  profile integer not null references speedycrew.profile(id),
  seq integer not null, 
  type event_type not null,
  message uuid references message(id),
  search uuid references search(id),
  match uuid references search(id),
  room uuid references room(id),
  other_profile int references profile(id),
  primary key (profile, seq)
);

create table speedycrew.control	(
  timeline integer not null
);

create unique index control_one_row on speedycrew.control((timeline is not null));

-- some bits and pieces for tracking schema evolution once we have
-- something solid enough to try for stable rollouts of schema changes
-- (ie beta, prod etc)

CREATE TABLE speedycrew.schema_change (
    name character varying NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL
);

comment on table speedycrew.schema_change is 'Track which changes have been applied to the schema.';

CREATE FUNCTION speedycrew.provide_change(provided_name text) RETURNS void
    LANGUAGE sql
    AS $_$
  insert into speedycrew.schema_change values ($1, now());
$_$;

CREATE FUNCTION speedycrew.require_change(required_name text) RETURNS void
    LANGUAGE plpgsql
    AS $$
  begin
    if not exists(select * from speedycrew.schema_change where name = required_name) then
      raise exception 'Required change % has''t been applied yet', required_name;
    end if;
  end;
$$;

commit;