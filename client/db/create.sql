
-- there should only ever be zero or one rows in this table, not sure
-- how to enforce that in sqlite
create table control (
  timeline integer not null,
  sequence integer not null
);

create table profile (
  username text,
  real_name text,
  email text unique,
  password_hash text,
  status text not null,
  message text,
  created timestamptz not null,
  modified timestamptz not null
);

create table search (
  id text primary key,
  query text not null,                -- "I am a #chef"
  side text not null,                 -- "PROVIDE" or "SEEK"
  address text,
  postcode text,
  city text,
  country text,
  radius float,
  latitude float not null,
  longitude float not null
);

create table match (
  id text primary key not null,
  search text references search(id),
  username text,
  fingerprint text,                   -- "12 32 5 325 13452345"
  public_key text,
  query text not null,                -- "I want a #chef"
  latitude float,
  longitude float,
  matches int,
  distance float,
  score double
);

create table message (
  id text primary key not null
);