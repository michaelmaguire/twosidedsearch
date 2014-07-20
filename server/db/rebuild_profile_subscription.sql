begin transaction isolation level serializable;

delete from speedycrew.profile_subscription;

-- each profile subscribes to itself
select speedycrew.profile_subscription_inc(id, id)
  from speedycrew.profile
 order by id;

-- for each profile, subscribe to every profile that it's in a crew with
select speedycrew.profile_subscription_inc(p.id, cm2.profile)
  from speedycrew.profile p
  join speedycrew.crew_member cm1 on p.id = cm1.profile
  join speedycrew.crew_member cm2 on cm2.crew = cm1.crew;

-- subscribe to every profile that each profile has matches from
select speedycrew.profile_subscription_inc(s1.owner, s2.owner)
  from speedycrew.match m
  join speedycrew.search s1 on m.a = s1.id
  join speedycrew.search s2 on m.b = s2.id;

commit;
