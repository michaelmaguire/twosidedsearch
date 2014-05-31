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
  id serial primary key,
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
  search integer not null references search(id),
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

-- TODO -- drop match.batch_sequence, add a unique single integer ID
-- that can be referenced by event, to make things more uniform

create table match (
  a integer not null references search(id),
  b integer not null references search(id),
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

create or replace function run_search(i_search_id integer) returns void as $$
declare
  v_side speedycrew.search_side;
  v_geography geography;
  v_radius float;
  v_id integer;
  v_tag_ids integer[];
begin
  -- load some data from this search into local variables
  select s.side, s.geography, s.radius
    into v_side, v_geography, v_radius
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
    for v_id in select s.id
                  from speedycrew.search s
                  join speedycrew.search_tag st on st.search = s.id
                 where st_dwithin(s.geography, v_geography, v_radius)
                   and st.tag = any (v_tag_ids)
                   and s.side = 'PROVIDE'
    loop
      begin
        insert into speedycrew.match (a, b, status, created)
        values (i_search_id, v_id, 'ACTIVE', now()),
               (v_id, i_search_id, 'ACTIVE', now());
      exception when unique_violation then
        -- do nothing
      end;
    end loop;
  else
    -- v_side = 'PROVIDE'
    for v_id in select s.id
                  from speedycrew.search s
                  join speedycrew.search_tag st on st.search = s.id
                 where st_dwithin(s.geography, v_geography, s.radius)
                   and st.tag = any (v_tag_ids)                  
                   and s.side = 'SEEK'
    loop
      -- TODO avoid this duplicated code
      begin
        insert into speedycrew.match (a, b, status, created)
        values (i_search_id, v_id, 'ACTIVE', now()),
               (v_id, i_search_id, 'ACTIVE', now());
        exception when unique_violation then
        -- do nothing
      end;
    end loop;
  end if;
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

create table speedycrew.message (
  id serial primary key,
  recipient integer not null references speedycrew.profile(id),
  sender integer null references speedycrew.profile(id),
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
  message integer references message(id),
  search integer references search(id),
  match integer references search(id),
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

comment on table speedycrew.schema_change is 'Track which changes have been applied.';

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