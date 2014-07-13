begin;

select speedycrew.require_change('change_20140712.sql');

select speedycrew.provide_change('change_20140713.sql');

SET search_path = speedycrew, public, pg_catalog;

create table profile_subscription (
  profile int not null references profile(id),
  subscribed_to int not null references profile(id),
  created timestamptz not null,
  primary key (profile, subscribed_to)
);

create index profile_subscription_reverse_idx on profile_subscription(subscribed_to, profile);

comment on table profile_subscription is 'Records the subset of profiles that are replicated to each device';

create or replace function profile_subscribe(i_profile_id int, i_subscribed_to_profile_id int) returns void
    language plpgsql
    as $$
begin
  begin
    insert into profile_subscription (profile, subscribed_to, created)
    values (i_profile_id, i_subscribed_to_profile_id, current_timestamp);
    -- if we get here, it didn't exist already, so we replicate the
    -- insertion (this triggers the creation fo a profile on 
    insert into event (profile, seq, type, other_profile, tab)
    values (i_profile_id, next_sequence(i_profile_id), 'INSERT', i_subscribed_to_profile_id, 'PROFILE');
  exception when unique_violation then
    -- do nothing, we were already subscribed
  end;
end;
$$;

-- henceforth, all profiles shall have a fingerprint and the number of
-- the fingerprints shall be one

alter table profile add column fingerprint text;

-- the fingerprint for the profile is the ID for the device (TODO
-- figure out what to do about 'devices'), so we copy those over

update profile set fingerprint = (select id from device d where d.profile = profile.id limit 1);

-- non-null from now on (will be supplied when accounts are created)

alter table profile alter column fingerprint set not null;

-- TODO for now fingerprint is not a foreign key pointing at
-- client_certificate, because we support the x-id thing for
-- development; need to tidy this mess up

commit;