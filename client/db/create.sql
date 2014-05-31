
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
  query text,                         -- "I am a #chef"
  side text,                          -- "PROVIDE" or "SEEK"
  latitude float,
  longitude float
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
  distance float,                     -- or compute on fly?
  score double                        -- for now, how many tags in intersection
);

create table message (
  id text primary key not null
);