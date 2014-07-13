begin;

set search_path to speedycrew, public;

insert into tag
values (default, 'chef', 'Trained chef', 'ACTIVE'),
       (default, 'sous-chef', 'Blah blah', 'ACTIVE'),
       (default, 'sioux-chef', 'Blah blah', 'ACTIVE'),
       (default, 'sushi-chef', 'Blah blah', 'ACTIVE'),
       (default, 'kitchen-hand', 'Able to cut a potato', 'ACTIVE'),
       (default, 'bottle-washer', 'Master dish washer', 'ACTIVE'),
       (default, 'waiter', 'I know how to wait', 'ACTIVE');

insert into profile (id, fingerprint, username, email, status, message, created)
values (default, '1111', 'maguire_the_knife', 'mm@chef.com', 'ACTIVE', 'Looking to deploy my Ginsu', now()),
       (default, '2222', 'coulis', 'dk@chef.com', 'ACTIVE', 'You kill it, I''ll grill it', now()),
       (default, '3333', 'spudpeeler', 'tm@chef.com', 'ACTIVE', 'Will supply own potato peeler and proprietary bottle scrubbing device', now());

insert into device (profile, id, created)
values (1, '1111', now()),
       (2, '2222', now()),
       (3, '3333', now());

insert into profile_sequence
select id, 0, 0
  from profile;

--insert into search (id, owner, query, side, address, geography, radius, status, created)
--values (default, 1, 'I need a #chef', 'PROVIDE', 'Big Ben', make_geo(-0.1247, 51.5008), null, 'ACTIVE', now()),
--       (default, 2, 'I am a #chef and also a #waiter', 'SEEK', 'Covent Garden', make_geo(-0.1228, 51.5120), 2000, 'ACTIVE', now());

--insert into search_tag values (1, 1), (2, 1), (2, 2);

insert into profile_availability
values (1, DATE '2013-11-10', 'AVAILABLE', 'Anywhere in London', now()),
       (1, DATE '2013-11-11', 'AVAILABLE', 'I may be late getting there depending on afterparty for previous gig', now()),
       (2, DATE '2013-11-10', 'AVAILABLE', null, now()),
       (2, DATE '2013-11-11', 'NOT_AVAILABLE', null, now()),
       (2, DATE '2013-11-12', 'NOT_AVAILABLE', null, now()),
       (2, DATE '2013-11-13', 'NOT_AVAILABLE', null, now()),
       (3, DATE '2013-11-10', 'MAYBE_AVAILABLE', 'Double my money and I''ll cancel my previous engagement polishing spoons', now()),
       (3, DATE '2013-11-11', 'AVAILABLE', null, now()),
       (3, DATE '2013-11-12', 'AVAILABLE', null, now());

insert into control (timeline)
values (1);

commit;