begin;

insert into skill 
values (1, 'chef', 'Trained chef'),
       (2, 'sous-chef', 'Blah blah'),
       (3, 'sioux-chef', 'Blah blah'),
       (4, 'sushi-chef', 'Blah blah'),
       (5, 'kitchen-hand', 'Able to cut a potato'),
       (6, 'bottle-washer', 'Master dish washer');

insert into person 
values (1, 'maguire_the_knife', 'Michael', 'Maguire', 'mm@chef.com', 'ACTIVE', crypt('foo', gen_salt('md5')), 'Looking to deploy my Ginsu', now(), null, 0),
       (2, 'coulis', 'Dietmar', 'Kuehl', 'dk@chef.com', 'ACTIVE', crypt('foo', gen_salt('md5')), 'You kill it, I''ll grill it', now(), null, 0),
       (3, 'spudpeeler', 'Thomas', 'Munro', 'tm@chef.com', 'ACTIVE', crypt('foo', gen_salt('md5')), 'Will supply own potato peeler and proprietary bottle scrubbing device', now(), null, 0);

insert into person_skill
values (1, 2, now()),
       (1, 3, now()),
       (2, 2, now()),
       (2, 4, now()),
       (3, 5, now()),
       (3, 6, now());

insert into person_day
values (1, DATE '2013-11-10', 'AVAILABLE', 'Anywhere in London', now()),
       (1, DATE '2013-11-11', 'AVAILABLE', 'I may be late getting depending on afterparty for previous gig', now()),
       (2, DATE '2013-11-10', 'AVAILABLE', null, now()),
       (2, DATE '2013-11-11', 'NOT_AVAILABLE', null, now()),
       (2, DATE '2013-11-12', 'NOT_AVAILABLE', null, now()),
       (2, DATE '2013-11-13', 'NOT_AVAILABLE', null, now()),
       (3, DATE '2013-11-10', 'MAYBE_AVAILABLE', 'Double my money and I''ll cancel my previous engagement polishing spoons', now()),
       (3, DATE '2013-11-11', 'AVAILABLE', null, now()),
       (3, DATE '2013-11-12', 'AVAILABLE', null, now());

commit;