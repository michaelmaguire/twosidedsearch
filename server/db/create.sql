begin;

create type person_status as enum ('ACTIVE', 'CANCELLED', 'BANNED');

create table person (
  id serial primary key,
  username text unique not null,
  firstname text not null,
  lastname text not null,
  email text unique not null,
  status person_status not null,
  password_hash text not null,
  message text null,
  created timestamptz not null,
  last_login timestamptz null,
  logins integer not null
);

comment on table person is 'A user in our system';

create table login_session (
  token text primary key,
  person integer not null references person(id),
  platform text,
  version text,
  created timestamptz not null,
  ended timestamptz
);

comment on table login_session is 'An authenticated session';

create table location (
  id serial primary key,
  owner integer not null references person(id),
  name text not null,
  address text,
  postcode text,
  country varchar(2), -- references country(id)
  longitude float not null,
  latitude float not null,
  geography geography not null,
  created timestamptz not null
);

comment on table location is 'A location configured by a user';

create table travel_area (
  person integer not null primary key references person(id),
  base integer not null references location(id), 
  max_distance float not null,
  created timestamptz not null,
  modified timestamptz not null
);

comment on table travel_area is 'The current base location setting, per person, and how far they are prepared to travel from it';

create table skill (
  id serial primary key,
  name text unique not null,
  description text not null
);

comment on table skill is 'Skill tags';

create table person_skill (
  person integer not null references person(id),
  skill integer not null references skill(id),
  created timestamptz not null
);

comment on table person_skill is 'The skills declared by a user';

create type availability_status as enum ('AVAILABLE', 'NOT_AVAILABLE', 'MAYBE_AVAILABLE');

create table person_day (
  person integer not null references person(id),
  day date not null,
  availability availability_status not null,
  note text,
  modified timestamptz not null
);

comment on table person_day is 'A person''s availability status for each day';

create table project (
  id serial primary key,
  owner integer not null references person(id),
  name text not null,
  location integer not null references location(id),
  created timestamptz not null
);

comment on table project is 'An event or project being organised by *owner*';

create table project_requirement (
  id serial primary key,
  project integer not null references project(id),
  day date not null,
  count integer,
  short_description text not null,
  long_description text,
  created timestamptz not null
);

comment on table project_requirement is 'A slot to be filled by one person, on one day';

create table project_requirement_skill (
  project_requirement integer not null references project_requirement(id),
  skill integer not null references skill(id)
);

comment on table project_requirement_skill is 'Skill tags desired for a requirement';

commit;