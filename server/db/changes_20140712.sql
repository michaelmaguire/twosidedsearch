begin;

select speedycrew.require_change('change_20140626.sql');

select speedycrew.provide_change('change_20140712.sql');

SET search_path = speedycrew, public, pg_catalog;

-- drop a bunch of old junk I created before we really agreed how this
-- stuff was going to work

alter table event drop column message;

alter table event drop column room;

drop table message;

drop table room_member;

drop table room;

-- create the new stuff we figured out for MVP

create table crew (
  id uuid primary key,
  name text,
  created timestamptz not null,
  creator int not null references profile(id)
);

create type crew_member_status as enum ('ACTIVE', 'LEFT', 'KICKED_OUT');

create table crew_member (
  crew uuid references crew(id) not null,
  profile int references profile(id) not null,
  status crew_member_status not null,
  invited_by int not null references profile(id),
  kicked_out_by int references profile(id),
  created timestamptz not null,
  kicked_out_time timestamptz
);

create table message (
  id uuid primary key,
  sender int not null references profile(id),
  crew uuid not null references crew(id),
  body text not null,
  created timestamptz not null
);

create table message_key (
  message uuid not null references message(id),
  recipient int not null references profile(id),
  key text not null
);

alter type event_table add value 'CREW';

alter type event_table add value 'CREW_MEMBER';

alter type event_table add value 'MESSAGE';

alter table event add column crew uuid references crew(id);

alter table event add column message uuid references message(id);

commit;