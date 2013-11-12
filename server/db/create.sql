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
  modified timestamptz not null
);

create table skill (
  id serial primary key,
  name text unique not null,
  description text not null
);

create table person_skill (
  person integer not null references person(id),
  skill integer not null references skill(id),
  created timestamptz not null
);

create type availability_status as enum ('AVAILABLE', 'NOT_AVAILABLE', 'MAYBE_AVAILABLE');

create table person_day (
  person integer not null references person(id),
  day date not null,
  availability availability_status not null,
  note text,
  modified timestamptz not null
);

create table area (
  id serial primary key,
  name text not null
);

create table project (
  id serial primary key,
  owner integer not null references person(id),
  name text not null,
  address text,
  postcode text,
  city text,
  country varchar(2),
  area integer not null references area(id),
  created timestamptz not null
);

create table project_requirement (
  project integer not null references project(id),
  day date not null,
  count integer,
  short_description text not null,
  long_description text,
  created timestamptz not null
);

commit;