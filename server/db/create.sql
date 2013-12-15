begin;

create schema speedycrew;

set search_path to speedycrew, public;

create type profile_status as enum ('ACTIVE', 'CANCELLED', 'BANNED');

create table profile (
  id serial primary key,
  username text unique,
  real_name text,b
  email text unique,
  password_hash text,
  status profile_status not null,
  message text,
  created timestamptz not null
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
  certificate bytea not null
);

comment on table client_certificate is 'Public certificate data for a device';

create table country (
  id varchar(2) primary key,
  name text not null
);

insert into country values ('GB', 'United Kingdom');

create table location (
  id serial primary key,
  owner integer not null references profile(id),
  name text not null,
  address text,
  postcode text,
  country varchar(2) references country(id),
  longitude float not null,
  latitude float not null,
  geography geography not null,
  created timestamptz not null
);

comment on table location is 'A location configured by a user';

create table tag (
  id serial primary key,
  name text unique not null,
  description text not null
);

comment on table tag is 'Tags';

create type search_side as enum ('SEEK', 'PROVIDE');

create table search (
  id serial primary key,
  owner integer not null references profile(id),
  name text,
  side search_side,
  location integer not null references location(id),
  radius float,
  created timestamptz not null
);

comment on table search is 'A search created by either a seeker or provider of a service';

create table search_tag (
  search integer not null references search(id),
  tag integer not null references tag(id)
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






-- not sure if we still want to track projects at all?  maybe this is dead

--create table project (
--  id serial primary key,
--  owner integer not null references profile(id),
--  name text not null,
--  location integer not null references location(id),
--  created timestamptz not null
--);

--comment on table project is 'An event or project being organised by *owner*';

--create table project_requirement (
--  id serial primary key,
--  project integer not null references project(id),
--  day date not null,
--  count integer,
--  short_description text not null,
--  long_description text,
--  created timestamptz not null
--);

--comment on table project_requirement is 'A slot to be filled by one person, on one day';

--create table project_requirement_skill (
--  project_requirement integer not null references project_requirement(id),
--  skill integer not null references skill(id)
--);

--comment on table project_requirement_skill is 'Skill tags desired for a requirement';

commit;