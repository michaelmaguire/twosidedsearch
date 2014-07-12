--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: speedycrew; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA speedycrew;


SET search_path = speedycrew, pg_catalog;

--
-- Name: availability_status; Type: TYPE; Schema: speedycrew; Owner: -
--

CREATE TYPE availability_status AS ENUM (
    'AVAILABLE',
    'NOT_AVAILABLE',
    'MAYBE_AVAILABLE'
);


--
-- Name: crew_member_status; Type: TYPE; Schema: speedycrew; Owner: -
--

CREATE TYPE crew_member_status AS ENUM (
    'ACTIVE',
    'LEFT',
    'KICKED_OUT'
);


--
-- Name: event_table; Type: TYPE; Schema: speedycrew; Owner: -
--

CREATE TYPE event_table AS ENUM (
    'PROFILE',
    'MATCH',
    'SEARCH',
    'CREW',
    'MESSAGE',
    'CREW_MEMBER'
);


--
-- Name: event_type; Type: TYPE; Schema: speedycrew; Owner: -
--

CREATE TYPE event_type AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE'
);


--
-- Name: match_status; Type: TYPE; Schema: speedycrew; Owner: -
--

CREATE TYPE match_status AS ENUM (
    'ACTIVE',
    'DELETED'
);


--
-- Name: profile_status; Type: TYPE; Schema: speedycrew; Owner: -
--

CREATE TYPE profile_status AS ENUM (
    'ACTIVE',
    'CANCELLED',
    'BANNED'
);


--
-- Name: search_side; Type: TYPE; Schema: speedycrew; Owner: -
--

CREATE TYPE search_side AS ENUM (
    'SEEK',
    'PROVIDE'
);


--
-- Name: search_status; Type: TYPE; Schema: speedycrew; Owner: -
--

CREATE TYPE search_status AS ENUM (
    'ACTIVE',
    'DELETED'
);


--
-- Name: tag_status; Type: TYPE; Schema: speedycrew; Owner: -
--

CREATE TYPE tag_status AS ENUM (
    'ACTIVE',
    'BANNED',
    'DELETED'
);


--
-- Name: delete_search(uuid); Type: FUNCTION; Schema: speedycrew; Owner: -
--

CREATE FUNCTION delete_search(i_search_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  v_profile_id int;
  v_a uuid;
  v_b uuid;
begin
  -- we need to remove all matches that have this search on the a side
  -- or b side, generating events in profile order to avoid deadlocks
  -- when we generate event sequences
  --
  -- we CAN delete the 'match' records now, because -- even though
  -- they may be referenced by 'event' records, the event records
  -- contain pairs of 'search' primary key; if there are still
  -- 'INSERT' events for a match we delete, they will simply be
  -- skipped by future incremental synchronisations
  for v_profile_id, v_a, v_b in
    with relevant_matches as (
                  select s.owner, m.a, m.b
                    from speedycrew.search s
                    join speedycrew.match m on s.id = m.a
                   where m.a = i_search_id
                   union all
                  select s.owner, m.a, m.b
                    from speedycrew.search s
                    join speedycrew.match m on s.id = m.b
                   where m.b = i_search_id)
    select owner, a, b
      from relevant_matches
     order by owner
  loop
    delete from speedycrew.match
     where a = v_a and b = v_b;
    insert into speedycrew.event (profile, seq, type, search, match, tab)
    values (v_profile_id, next_sequence(v_profile_id), 'DELETE', v_a, v_b, 'MATCH');
  end loop;      
  -- we CAN'T delete the 'search' record yet, because it may be
  -- references by events;
  -- TODO when does it actually get deleted? we need some kind of
  -- garbage collector that will sort these out periodically after
  -- finding tthat they are not referenced...  this is one of the
  -- weaker parts of this grand plan
  update speedycrew.search
     set status = 'DELETED'
   where id = i_search_id;
  select owner
    into v_profile_id
    from speedycrew.search
   where id = i_search_id;
  insert into speedycrew.event (profile, seq, type, search, tab)
  values (v_profile_id, next_sequence(v_profile_id), 'DELETE', i_search_id, 'SEARCH');
end;
$$;


--
-- Name: find_matches(uuid); Type: FUNCTION; Schema: speedycrew; Owner: -
--

CREATE FUNCTION find_matches(i_search_id uuid) RETURNS TABLE(search_id uuid, matches integer, distance double precision, score double precision, query text)
    LANGUAGE plpgsql
    AS $$
declare
  v_profile int;
  v_side speedycrew.search_side;
  v_geography geography;
  v_radius float;
  v_tag_ids integer[];
begin
  -- load some data from this search into local variables
  select s.side, s.geography, s.radius, s.owner
    into v_side, v_geography, v_radius, v_profile
    from speedycrew.search s
   where s.id = i_search_id;
  if not found then
    return;
  end if;
  select array_agg(st.tag)
    into v_tag_ids
    from speedycrew.search_tag st
   where st.search = i_search_id;
   -- SEEK has a radius (SEEKers are mobile)
  if v_side = 'SEEK' then
    return query
    select s.id,
           count(*)::int as matches,
           st_distance(s.geography, v_geography)::float as distance,
           (count(*) + 1 / greatest(1, st_distance(s.geography, v_geography)))::float as score,
	   s.query
      from speedycrew.search s
      join speedycrew.search_tag st on st.search = s.id
     where st_dwithin(s.geography, v_geography, v_radius)
       and st.tag = any (v_tag_ids)
       and s.side = 'PROVIDE'
       and s.status = 'ACTIVE'
     group by s.id;
  else
    -- v_side = 'PROVIDE'
    return query
    select s.id,
           count(*)::int as matches,
           st_distance(s.geography, v_geography)::float as distance,
           (count(*) + 1 / greatest(1, st_distance(s.geography, v_geography)))::float as score,
	   s.query
      from speedycrew.search s
      join speedycrew.search_tag st on st.search = s.id
     where st_dwithin(s.geography, v_geography, s.radius)
       and st.tag = any (v_tag_ids)                  
       and s.side = 'SEEK'
       and s.status = 'ACTIVE'
     group by s.id;
  end if;
end;
$$;


--
-- Name: find_matches_mirrored(uuid); Type: FUNCTION; Schema: speedycrew; Owner: -
--

CREATE FUNCTION find_matches_mirrored(i_search_id uuid) RETURNS TABLE(a uuid, b uuid, matches integer, distance double precision, score double precision, message text)
    LANGUAGE plpgsql
    AS $$
declare
  v_search_id uuid;
  v_matches int;
  v_distance float;
  v_score float;
  v_query text;
  v_my_query text;
  v_my_side search_side;
begin
  select s.query, s.side
    into v_my_query, v_my_side
    from search s
   where s.id = i_search_id;
  for v_search_id, v_matches, v_distance, v_score, v_query in
    select t.search_id, t.matches, t.distance, t.score, t.query
      from speedycrew.find_matches(i_search_id) t
  loop
    -- this is the aggressive search
    a := i_search_id;
    b := v_search_id;
    matches = v_matches;
    distance = v_distance;
    score := v_score;
    message := null;
    return next;
    -- the is the passive search
    a := v_search_id;
    b := i_search_id;
    if v_my_side = 'PROVIDE' then
        message := 'Captain sighted: ' || v_my_query;
    else
        message := 'Crew sighted: ' || v_my_query;
    end if;
    return next;
  end loop;
end;
$$;


--
-- Name: find_matches_mirrored_sorted(uuid); Type: FUNCTION; Schema: speedycrew; Owner: -
--

CREATE FUNCTION find_matches_mirrored_sorted(i_search_id uuid) RETURNS TABLE(profile integer, a uuid, b uuid, matches integer, distance double precision, score double precision, message text)
    LANGUAGE plpgsql
    AS $$
begin
  return query
  select s.owner, t.a, t.b, t.matches, t.distance, t.score, t.message
    from speedycrew.find_matches_mirrored(i_search_id) t
    join speedycrew.search s on s.id = t.a
   order by s.owner;
end;
$$;


--
-- Name: make_geo(double precision, double precision); Type: FUNCTION; Schema: speedycrew; Owner: -
--

CREATE FUNCTION make_geo(long double precision, lat double precision) RETURNS public.geography
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
  select st_geographyfromtext('POINT(' || long::text || ' ' || $2::text || ')');
$_$;


--
-- Name: next_sequence(integer); Type: FUNCTION; Schema: speedycrew; Owner: -
--

CREATE FUNCTION next_sequence(i_profile_id integer) RETURNS integer
    LANGUAGE sql
    AS $$
     update speedycrew.profile_sequence
        set high_sequence = high_sequence + 1,
	    low_sequence = coalesce(low_sequence, high_sequence + 1),
	    low_time = coalesce(low_time, current_timestamp)
      where profile = i_profile_id
  returning high_sequence;
$$;


--
-- Name: provide_change(text); Type: FUNCTION; Schema: speedycrew; Owner: -
--

CREATE FUNCTION provide_change(provided_name text) RETURNS void
    LANGUAGE sql
    AS $_$
  insert into speedycrew.schema_change values ($1, now());
$_$;


--
-- Name: require_change(text); Type: FUNCTION; Schema: speedycrew; Owner: -
--

CREATE FUNCTION require_change(required_name text) RETURNS void
    LANGUAGE plpgsql
    AS $$
  begin
    if not exists(select * from speedycrew.schema_change where name = required_name) then
      raise exception 'Required change % has''t been applied yet', required_name;
    end if;
  end;
$$;


--
-- Name: run_search(uuid); Type: FUNCTION; Schema: speedycrew; Owner: -
--

CREATE FUNCTION run_search(i_search_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
  v_profile int;
  v_a uuid;
  v_b uuid;
  v_matches int;
  v_distance float;
  v_score float;
  v_message text;
begin
  -- we compute all the matches, sorted by profile so that we can
  -- generate event sequences for each profile without causing
  -- deadlocks
  for v_profile, v_a, v_b, v_matches, v_distance, v_score, v_message in
    select t.profile, t.a, t.b, t.matches, t.distance, t.score, t.message
      from find_matches_mirrored_sorted(i_search_id) t
  loop
      insert into speedycrew.match (a, b, matches, distance, score, status, created)
      values (v_a, v_b, v_matches, v_distance, v_score, 'ACTIVE', now());
      insert into speedycrew.event (profile, seq, type, search, match, tab)
      values (v_profile, next_sequence(v_profile), 'INSERT', v_a, v_b, 'MATCH');
      insert into speedycrew.tickle_queue (profile, message)
      values (v_profile, v_message);
  end loop;
  notify tickle;
end;
$$;


SET default_with_oids = false;

--
-- Name: client_certificate; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE client_certificate (
    device text NOT NULL,
    certificate text NOT NULL
);


--
-- Name: TABLE client_certificate; Type: COMMENT; Schema: speedycrew; Owner: -
--

COMMENT ON TABLE client_certificate IS 'Public certificate data for a device';


--
-- Name: control; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE control (
    timeline integer NOT NULL
);


--
-- Name: country; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE country (
    id character varying(2) NOT NULL,
    name text NOT NULL
);


--
-- Name: crew; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE crew (
    id uuid NOT NULL,
    name text,
    created timestamp with time zone NOT NULL,
    creator integer NOT NULL
);


--
-- Name: crew_member; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE crew_member (
    crew uuid NOT NULL,
    profile integer NOT NULL,
    status crew_member_status NOT NULL,
    invited_by integer NOT NULL,
    kicked_out_by integer,
    created timestamp with time zone NOT NULL,
    kicked_out_time timestamp with time zone
);


--
-- Name: device; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE device (
    id text NOT NULL,
    profile integer NOT NULL,
    platform text,
    version text,
    last_seen timestamp with time zone,
    created timestamp with time zone NOT NULL,
    ended timestamp with time zone,
    google_registration_id text,
    apple_device_token text
);


--
-- Name: TABLE device; Type: COMMENT; Schema: speedycrew; Owner: -
--

COMMENT ON TABLE device IS 'A device used by a person to access the system';


--
-- Name: event; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE event (
    profile integer NOT NULL,
    seq integer NOT NULL,
    type event_type NOT NULL,
    search uuid,
    match uuid,
    other_profile integer,
    created timestamp with time zone DEFAULT now() NOT NULL,
    tab event_table NOT NULL,
    message uuid,
    crew uuid
);


--
-- Name: file; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE file (
    profile integer NOT NULL,
    name text NOT NULL,
    mime_type text NOT NULL,
    version integer NOT NULL,
    created timestamp with time zone NOT NULL,
    modified timestamp with time zone NOT NULL,
    size integer NOT NULL,
    data bytea NOT NULL,
    public boolean NOT NULL
);


--
-- Name: TABLE file; Type: COMMENT; Schema: speedycrew; Owner: -
--

COMMENT ON TABLE file IS 'Filesystem-like data storage for holding arbitrary profile data';


--
-- Name: match; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE match (
    a uuid NOT NULL,
    b uuid NOT NULL,
    matches integer NOT NULL,
    distance double precision NOT NULL,
    score double precision NOT NULL,
    status match_status NOT NULL,
    created timestamp with time zone NOT NULL
);


--
-- Name: TABLE match; Type: COMMENT; Schema: speedycrew; Owner: -
--

COMMENT ON TABLE match IS 'A match between two searches';


--
-- Name: message; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE message (
    id uuid NOT NULL,
    sender integer NOT NULL,
    crew uuid NOT NULL,
    body text NOT NULL,
    created timestamp with time zone NOT NULL
);


--
-- Name: message_key; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE message_key (
    message uuid NOT NULL,
    recipient integer NOT NULL,
    key text NOT NULL
);


--
-- Name: profile; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE profile (
    id integer NOT NULL,
    username text,
    real_name text,
    email text,
    password_hash text,
    status profile_status NOT NULL,
    message text,
    created timestamp with time zone DEFAULT now() NOT NULL,
    modified timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE profile; Type: COMMENT; Schema: speedycrew; Owner: -
--

COMMENT ON TABLE profile IS 'A user in our system';


--
-- Name: profile_availability; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE profile_availability (
    profile integer NOT NULL,
    day date NOT NULL,
    availability availability_status NOT NULL,
    note text,
    modified timestamp with time zone NOT NULL
);


--
-- Name: TABLE profile_availability; Type: COMMENT; Schema: speedycrew; Owner: -
--

COMMENT ON TABLE profile_availability IS 'A person''s availability status for each day';


--
-- Name: profile_id_seq; Type: SEQUENCE; Schema: speedycrew; Owner: -
--

CREATE SEQUENCE profile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: profile_id_seq; Type: SEQUENCE OWNED BY; Schema: speedycrew; Owner: -
--

ALTER SEQUENCE profile_id_seq OWNED BY profile.id;


--
-- Name: profile_sequence; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE profile_sequence (
    profile integer NOT NULL,
    low_sequence integer,
    high_sequence integer NOT NULL,
    low_time timestamp with time zone DEFAULT now()
);


--
-- Name: TABLE profile_sequence; Type: COMMENT; Schema: speedycrew; Owner: -
--

COMMENT ON TABLE profile_sequence IS 'Counters to keep track of the window of event sequence numbers we have for each profile.';


--
-- Name: schema_change; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE schema_change (
    name character varying NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE schema_change; Type: COMMENT; Schema: speedycrew; Owner: -
--

COMMENT ON TABLE schema_change IS 'Track which changes have been applied to the schema.';


--
-- Name: search; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE search (
    id uuid NOT NULL,
    owner integer NOT NULL,
    query text NOT NULL,
    side search_side NOT NULL,
    address text,
    postcode text,
    city text,
    country character varying(2),
    geography public.geography NOT NULL,
    radius double precision,
    status search_status NOT NULL,
    created timestamp with time zone NOT NULL,
    CONSTRAINT search_check CHECK (((radius IS NULL) = (side = 'PROVIDE'::search_side)))
);


--
-- Name: TABLE search; Type: COMMENT; Schema: speedycrew; Owner: -
--

COMMENT ON TABLE search IS 'A search created by either a seeker or provider of a service';


--
-- Name: search_tag; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE search_tag (
    search uuid NOT NULL,
    tag integer NOT NULL
);


--
-- Name: TABLE search_tag; Type: COMMENT; Schema: speedycrew; Owner: -
--

COMMENT ON TABLE search_tag IS 'A tag that is part of a search (many-to-many link table)';


--
-- Name: system_setting; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE system_setting (
    name text NOT NULL,
    text_value text,
    interval_value interval,
    int_value integer
);


--
-- Name: tag; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE tag (
    id integer NOT NULL,
    name text NOT NULL,
    description text,
    status tag_status DEFAULT 'ACTIVE'::tag_status NOT NULL,
    created timestamp with time zone DEFAULT now() NOT NULL,
    creator integer
);


--
-- Name: TABLE tag; Type: COMMENT; Schema: speedycrew; Owner: -
--

COMMENT ON TABLE tag IS 'Tags';


--
-- Name: tag_count; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE TABLE tag_count (
    tag integer NOT NULL,
    provide_counter integer NOT NULL,
    seek_counter integer NOT NULL,
    counter integer NOT NULL
);


--
-- Name: TABLE tag_count; Type: COMMENT; Schema: speedycrew; Owner: -
--

COMMENT ON TABLE tag_count IS 'Recent tag usage counters';


--
-- Name: tag_id_seq; Type: SEQUENCE; Schema: speedycrew; Owner: -
--

CREATE SEQUENCE tag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_id_seq; Type: SEQUENCE OWNED BY; Schema: speedycrew; Owner: -
--

ALTER SEQUENCE tag_id_seq OWNED BY tag.id;


--
-- Name: tickle_queue; Type: TABLE; Schema: speedycrew; Owner: -
--

CREATE UNLOGGED TABLE tickle_queue (
    profile integer NOT NULL,
    created timestamp with time zone DEFAULT now(),
    message text
);


--
-- Name: id; Type: DEFAULT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY profile ALTER COLUMN id SET DEFAULT nextval('profile_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY tag ALTER COLUMN id SET DEFAULT nextval('tag_id_seq'::regclass);


--
-- Name: country_pkey; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY country
    ADD CONSTRAINT country_pkey PRIMARY KEY (id);


--
-- Name: crew_pkey; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY crew
    ADD CONSTRAINT crew_pkey PRIMARY KEY (id);


--
-- Name: device_pkey; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY device
    ADD CONSTRAINT device_pkey PRIMARY KEY (id);


--
-- Name: event_pkey; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_pkey PRIMARY KEY (profile, seq);


--
-- Name: file_pkey; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY file
    ADD CONSTRAINT file_pkey PRIMARY KEY (profile, name);


--
-- Name: match_pkey; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY match
    ADD CONSTRAINT match_pkey PRIMARY KEY (a, b);


--
-- Name: message_pkey; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY message
    ADD CONSTRAINT message_pkey PRIMARY KEY (id);


--
-- Name: profile_email_key; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY profile
    ADD CONSTRAINT profile_email_key UNIQUE (email);


--
-- Name: profile_pkey; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY profile
    ADD CONSTRAINT profile_pkey PRIMARY KEY (id);


--
-- Name: profile_sequence_pkey; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY profile_sequence
    ADD CONSTRAINT profile_sequence_pkey PRIMARY KEY (profile);


--
-- Name: profile_username_key; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY profile
    ADD CONSTRAINT profile_username_key UNIQUE (username);


--
-- Name: search_pkey; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY search
    ADD CONSTRAINT search_pkey PRIMARY KEY (id);


--
-- Name: search_tag_pkey; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY search_tag
    ADD CONSTRAINT search_tag_pkey PRIMARY KEY (search, tag);


--
-- Name: system_setting_pkey; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY system_setting
    ADD CONSTRAINT system_setting_pkey PRIMARY KEY (name);


--
-- Name: tag_count_pkey; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY tag_count
    ADD CONSTRAINT tag_count_pkey PRIMARY KEY (tag);


--
-- Name: tag_name_key; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY tag
    ADD CONSTRAINT tag_name_key UNIQUE (name);


--
-- Name: tag_pkey; Type: CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY tag
    ADD CONSTRAINT tag_pkey PRIMARY KEY (id);


--
-- Name: control_one_row; Type: INDEX; Schema: speedycrew; Owner: -
--

CREATE UNIQUE INDEX control_one_row ON control USING btree (((timeline IS NOT NULL)));


--
-- Name: tag_count_counter_idx; Type: INDEX; Schema: speedycrew; Owner: -
--

CREATE INDEX tag_count_counter_idx ON tag_count USING btree (counter);


--
-- Name: client_certificate_device_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY client_certificate
    ADD CONSTRAINT client_certificate_device_fkey FOREIGN KEY (device) REFERENCES device(id);


--
-- Name: crew_creator_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY crew
    ADD CONSTRAINT crew_creator_fkey FOREIGN KEY (creator) REFERENCES profile(id);


--
-- Name: crew_member_crew_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY crew_member
    ADD CONSTRAINT crew_member_crew_fkey FOREIGN KEY (crew) REFERENCES crew(id);


--
-- Name: crew_member_invited_by_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY crew_member
    ADD CONSTRAINT crew_member_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES profile(id);


--
-- Name: crew_member_kicked_out_by_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY crew_member
    ADD CONSTRAINT crew_member_kicked_out_by_fkey FOREIGN KEY (kicked_out_by) REFERENCES profile(id);


--
-- Name: crew_member_profile_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY crew_member
    ADD CONSTRAINT crew_member_profile_fkey FOREIGN KEY (profile) REFERENCES profile(id);


--
-- Name: device_profile_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY device
    ADD CONSTRAINT device_profile_fkey FOREIGN KEY (profile) REFERENCES profile(id);


--
-- Name: event_crew_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_crew_fkey FOREIGN KEY (crew) REFERENCES crew(id);


--
-- Name: event_match_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_match_fkey FOREIGN KEY (match) REFERENCES search(id);


--
-- Name: event_message_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_message_fkey FOREIGN KEY (message) REFERENCES message(id);


--
-- Name: event_other_profile_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_other_profile_fkey FOREIGN KEY (other_profile) REFERENCES profile(id);


--
-- Name: event_profile_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_profile_fkey FOREIGN KEY (profile) REFERENCES profile(id);


--
-- Name: event_search_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY event
    ADD CONSTRAINT event_search_fkey FOREIGN KEY (search) REFERENCES search(id);


--
-- Name: file_profile_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY file
    ADD CONSTRAINT file_profile_fkey FOREIGN KEY (profile) REFERENCES profile(id);


--
-- Name: match_a_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY match
    ADD CONSTRAINT match_a_fkey FOREIGN KEY (a) REFERENCES search(id);


--
-- Name: match_b_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY match
    ADD CONSTRAINT match_b_fkey FOREIGN KEY (b) REFERENCES search(id);


--
-- Name: message_crew_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY message
    ADD CONSTRAINT message_crew_fkey FOREIGN KEY (crew) REFERENCES crew(id);


--
-- Name: message_key_message_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY message_key
    ADD CONSTRAINT message_key_message_fkey FOREIGN KEY (message) REFERENCES message(id);


--
-- Name: message_key_recipient_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY message_key
    ADD CONSTRAINT message_key_recipient_fkey FOREIGN KEY (recipient) REFERENCES profile(id);


--
-- Name: message_sender_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY message
    ADD CONSTRAINT message_sender_fkey FOREIGN KEY (sender) REFERENCES profile(id);


--
-- Name: profile_availability_profile_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY profile_availability
    ADD CONSTRAINT profile_availability_profile_fkey FOREIGN KEY (profile) REFERENCES profile(id);


--
-- Name: profile_sequence_profile_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY profile_sequence
    ADD CONSTRAINT profile_sequence_profile_fkey FOREIGN KEY (profile) REFERENCES profile(id);


--
-- Name: search_country_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY search
    ADD CONSTRAINT search_country_fkey FOREIGN KEY (country) REFERENCES country(id);


--
-- Name: search_owner_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY search
    ADD CONSTRAINT search_owner_fkey FOREIGN KEY (owner) REFERENCES profile(id);


--
-- Name: search_tag_search_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY search_tag
    ADD CONSTRAINT search_tag_search_fkey FOREIGN KEY (search) REFERENCES search(id);


--
-- Name: search_tag_tag_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY search_tag
    ADD CONSTRAINT search_tag_tag_fkey FOREIGN KEY (tag) REFERENCES tag(id);


--
-- Name: tag_creator_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY tag
    ADD CONSTRAINT tag_creator_fkey FOREIGN KEY (creator) REFERENCES profile(id);


--
-- Name: tickle_queue_profile_fkey; Type: FK CONSTRAINT; Schema: speedycrew; Owner: -
--

ALTER TABLE ONLY tickle_queue
    ADD CONSTRAINT tickle_queue_profile_fkey FOREIGN KEY (profile) REFERENCES profile(id);


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = speedycrew, pg_catalog;

--
-- Data for Name: schema_change; Type: TABLE DATA; Schema: speedycrew; Owner: speedycrew
--

INSERT INTO schema_change (name, created) VALUES ('change_20140612.sql', '2014-06-14 22:23:52.079374+00');
INSERT INTO schema_change (name, created) VALUES ('change_20140614.sql', '2014-06-14 22:23:55.748962+00');
INSERT INTO schema_change (name, created) VALUES ('change_20140619.sql', '2014-06-19 22:51:50.045155+00');
INSERT INTO schema_change (name, created) VALUES ('change_20140620.sql', '2014-06-22 23:17:09.564901+00');
INSERT INTO schema_change (name, created) VALUES ('change_20140623.sql', '2014-06-23 22:21:11.747446+00');
INSERT INTO schema_change (name, created) VALUES ('change_20140624.sql', '2014-06-24 20:48:45.548335+00');
INSERT INTO schema_change (name, created) VALUES ('change_20140625.sql', '2014-06-26 17:27:20.785124+00');
INSERT INTO schema_change (name, created) VALUES ('change_20140626.sql', '2014-06-26 17:27:33.240717+00');
INSERT INTO schema_change (name, created) VALUES ('change_20140712.sql', '2014-07-12 21:40:24.190482+00');


--
-- PostgreSQL database dump complete
--

