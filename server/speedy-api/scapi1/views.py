from django.db import connection
from django.db.utils import IntegrityError
from django.http import HttpResponse, HttpResponseNotFound, HttpResponseForbidden, HttpResponseBadRequest
from django.shortcuts import render
import hashlib
import json
import uuid
import re
from M2Crypto import X509

def json_response(object):
    """A convenience function for generating a JSON HTTP response."""
    return HttpResponse(json.dumps(object, indent=4),
                        content_type="application/json")

def param_required(request, names):
    if isinstance(names, basestring):
        names = (names,)
    for name in names:
        if name in request.REQUEST:
            return request.REQUEST[name]
    raise Exception("Expected one of %s" % str(names))

def param_or_null(request, names):
    if isinstance(names, basestring):
        names = (names,)
    for name in names:
        if name in request.REQUEST:
            return request.REQUEST[name]
    return None

def is_well_formed_uuid(s):
    """Check if a string is a valid RFC 4122 UUID."""
    return re.match(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$', s) != None

def get_device_id(request):
    """Extract the device ID and certificate from a request."""
    # in development, we use a header or a parameter, but later we
    # will use some fancy-pants certificate stuff
    certificate = None
    if "SSL_CLIENT_CERT" in request.META:
        certificate = request.META["SSL_CLIENT_CERT"]
        x509 = X509.load_cert_string(certificate, X509.FORMAT_PEM)
        device_id = x509.get_fingerprint("sha1")
    else:
        # TODO check we are in a dev system before allowing this
        device_id = request.REQUEST["x-id"]
    # this could be someone we've never heard of, or someone returning
    return device_id, certificate

def begin(request):
    """The prelude to be used by all view functions to obtain or
    create a profile ID using the device ID information present in the
    request."""
    device_id, certificate = get_device_id(request)
    cursor = connection.cursor()
    # note that this actually serializes all access for a given device
    # since it locks the device row.  is that a bad thing?  could do
    # better if necessary, not real need to update that last_seen
    # thing for every request anyway
    cursor.execute("""UPDATE speedycrew.device
                         SET last_seen = now()
                       WHERE id = %s
                   RETURNING profile""",
                   (device_id, ))
    if cursor.rowcount == 1:
        profile_id = cursor.fetchone()[0]
    else:
        # new device ID, so we create a new profile
        cursor.execute("""INSERT INTO speedycrew.profile (id, status, fingerprint, created) 
                          VALUES (DEFAULT, 'ACTIVE', %s, now())
                       RETURNING id""",
                       (device_id, ))
        profile_id = cursor.fetchone()[0]
        # every profile needs a sequence number range tracking record
        cursor.execute("""INSERT INTO speedycrew.profile_sequence (profile, low_sequence, high_sequence)
                          VALUES (%s, NULL, 0)""",
                       (profile_id,))
        # every profile 'subscribes' to itself, so that devices receive
        # notifications of changes to their own profile
        cursor.execute("""SELECT speedycrew.profile_subscription_inc(%s, %s)""",
                       (profile_id, profile_id))
        # TODO the following statement can produce an error if an
        # unknown device makes two simultaneous queries, since only
        # once of them can succeed (and there is a race above);
        # various ways to fix this (serialize all profile creation, or
        # handle constraint violation in a stored procedure (but we
        # already created the profile above!), or ...?)
        cursor.execute("""INSERT INTO speedycrew.device (id, profile, last_seen, created) 
                          VALUES (%s, %s, now(), now())""",
                       (device_id, profile_id))
        if certificate:
            cursor.execute("""INSERT INTO speedycrew.client_certificate (device, certificate)
                              VALUES (%s, %s)""",
                           (device_id, certificate))
    cursor.close()
    return profile_id

def escape(s):
    """A dodgy incomplete string escape for SQLite strings."""
    # TODO this is probably insecure/broken/whatever
    if s == None:
        return "NULL"
    elif isinstance(s, basestring):    
        return "'" + s.replace("'", "''") + "'"
    else:
        return "'" + str(s) + "'"

def param(fmt, values):
    """Something for building SQL strings with literals, similar to DB
    module execute."""
    return fmt % tuple(map(escape, values)) # TODO this is not the modern way, use .format

def do_refresh(cursor, profile_id, timeline, high_sequence, sql, metadata):
    sql.append("DROP TABLE IF EXISTS profile")
    sql.append("DROP TABLE IF EXISTS match")
    sql.append("DROP TABLE IF EXISTS search")
    sql.append("DROP TABLE IF EXISTS crew_member")
    sql.append("DROP TABLE IF EXISTS message")
    sql.append("DROP TABLE IF EXISTS crew")
    sql.append("DROP TABLE IF EXISTS control")
    sql.append("create table control (timeline integer not null, sequence integer not null)")
    sql.append("create table profile (fingerprint text primary key, username text, real_name text, email text unique, password_hash text, status text not null, message text, created timestamptz not null, modified timestamptz not null)")
    sql.append("create table search (id text primary key, query text not null, side text not null, address text, postcode text, city text, country text, radius float, latitude float not null, longitude float not null)")
    sql.append("create table match (search text references search(id), other_search text, username text, email text, fingerprint text, public_key text, query text not null, latitude float, longitude float, matches int, distance float, score double, primary key (search, other_search))")
    sql.append("create table crew (id text primary key, name text)")
    sql.append("create table crew_member (crew text not null references crew(id), fingerprint text not null references profile(fingerprint), status text not null, primary key (crew, fingerprint))")
    sql.append("create table message (id text not null primary key, sender text not null references profile(fingerprint), crew text not null references crew(id), body text not null, created timestamptz not null)")

    # we only send you the crew records for crews that you're a member
    # of (which makes synchronisation tricky...)
    cursor.execute("""SELECT c.id, c.name
                        FROM speedycrew.crew c
                        JOIN speedycrew.crew_member cm ON c.id = cm.crew
                       WHERE cm.profile = %s""",
                   (profile_id,))
    for crew_id, crew_name in cursor:
        sql.append(param("INSERT INTO crew (id, name) VALUES (%s, %s)", (crew_id, crew_name)))
                          
    # we send you the profiles that you're "subscribed" to (which includes your own)
    cursor.execute("""SELECT p.fingerprint, p.username, p.real_name, p.email, p.status, p.message, p.created, p.modified
                        FROM speedycrew.profile p
                        JOIN speedycrew.profile_subscription ps ON p.id = ps.subscribed_to
                       WHERE ps.profile = %s""",
                   (profile_id,))
    fingerprint, username, real_name, email, status, message, created, modified = cursor.fetchone()
    sql.append(param("INSERT INTO profile (fingerprint, username, real_name, email, status, message, created, modified) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                     (fingerprint, username, real_name, email, status, message, created, modified)))

    # it is now safe to send your crew_member records, for all crews
    # you're a member of, because all crews and potentially relevant
    # profiles have been inserted
    cursor.execute("""SELECT cm.crew, p.fingerprint, cm.status
                        FROM speedycrew.crew_member cm
                        JOIN speedycrew.profile p ON cm.profile = p.id
                       WHERE cm.crew IN (SELECT cm.crew
                                           FROM speedycrew.crew_member cm2
                                          WHERE cm2.profile = %s)""",
                   (profile_id,))
    for crew_id, fingerprint, status in cursor:
        sql.append(param("INSERT INTO crew_member (crew, fingerprint, status) VALUES (%s, %s, %s)", (crew_id, fingerprint, status)))

    # insert messages (TODO: exclude messages from crews we've left)        
    cursor.execute("""SELECT m.id, p.fingerprint, m.crew, m.body, m.created
                        FROM speedycrew.message m
                        JOIN speedycrew.profile p ON m.sender = p.id
                       WHERE m.crew IN (SELECT cm.crew
                                          FROM speedycrew.crew_member cm
                                         WHERE cm.profile = %s)""",
                   (profile_id,))
    for row in cursor:
        sql.append(param("INSERT INTO message (id, sender, crew, body, created) VALUES (%s, %s, %s, %s, %s)", row))

    # insert searches
    cursor.execute("""SELECT s.id, 
                             s.query, 
                             s.side, 
                             s.address, 
                             s.postcode, 
                             s.city, 
                             s.country, 
                             st_x(s.geography::geometry) AS longitude,
                             st_y(s.geography::geometry) AS latitude,
                             s.radius
                        FROM speedycrew.search s
                       WHERE s.owner = %s
                         AND s.status = 'ACTIVE'""",
                   (profile_id, ))
    for row in cursor:
        sql.append(param("INSERT INTO search (id, query, side, address, postcode, city, country, longitude, latitude, radius) VALUES (%s, %s, %s, %s, %s ,%s, %s, %s, %s, %s)",
                         row))                    

    cursor.execute("""SELECT s1.id AS my_search_id,
                             s2.id AS other_search_id,
                             p2.username,
                             p2.email,
                             d2.id AS fingerprint,
                             s2.query,
                             st_x(s2.geography::geometry) AS longitude,
                             st_y(s2.geography::geometry) AS latitude,
                             m.matches,
                             m.distance,
                             m.score
                        FROM speedycrew.match m
                        JOIN speedycrew.search s2 ON m.b = s2.id
                        JOIN speedycrew.profile p2 ON s2.owner = p2.id
                        JOIN speedycrew.device d2 ON p2.id = d2.profile
                        JOIN speedycrew.search s1 ON m.a = s1.id
                       WHERE s1.owner = %s
                         AND s1.status = 'ACTIVE'
                         AND s2.status = 'ACTIVE'""",
                   (profile_id, ))
    for row in cursor:
        sql.append(param("INSERT INTO match (search, other_search, username, email, fingerprint, query, longitude, latitude, matches, distance, score) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                         row))    

    sql.append(param("INSERT INTO control (timeline, sequence) VALUES (%s, %s)",
                     (timeline, high_sequence,)))

def do_incremental(cursor, profile_id, device_sequence, sql, metadata):

    # find the configured maximum number of events to send
    cursor.execute("""SELECT int_value
                        FROM speedycrew.system_setting
                       WHERE name = 'synchronise.max_fetch_events'
                         AND int_value IS NOT NULL""")
    row = cursor.fetchone()
    if row == None:
        max_fetch_events = 50
    else:
        max_fetch_events = row[0]

    # maybe there is a better way to do this... it sure looks
    # overgrown/ugly... the basic idea here is to read the
    # appropriate range of events from the event table, LEFT
    # JOINed against the various things it refers to (messages,
    # searches, ...), so we can generate the necessary
    # INSERT/UPDATE/DELETE statements for the denormalised data we
    # push to the device database
    #
    # TODO: assumes one device per profile, need to fix
    cursor.execute("""SELECT e.seq,
                             e.type,
                             e.tab,
                             message.body,
                             my_search.id,
                             my_search.query,
                             my_search.side,
                             my_search.address,
                             my_search.postcode,
                             my_search.city,
                             my_search.country,
                             my_search.radius,
                             st_x(my_search.geography::geometry) AS my_search_longitude,
                             st_y(my_search.geography::geometry) AS my_search_latitude,                           
                             match_search.id,
                             match_profile.username,
                             match_profile.email,
                             match_profile.fingerprint AS match_fingerprint,
                             match_search.query,
                             st_x(match_search.geography::geometry) AS longitude,
                             st_y(match_search.geography::geometry) AS latitude,
                             match.matches,
                             match.distance,
                             match.score,
                             my_profile.fingerprint,
                             my_profile.username,
                             my_profile.real_name,
                             my_profile.email,
                             my_profile.status,
                             my_profile.message,
                             my_profile.created,
                             my_profile.modified,
                             crew.id, crew.name,
                             crew_member.status,
                             message.id, sender_profile.fingerprint, message.crew, message.body, message.created
                            
                             
                        FROM speedycrew.event e
                   LEFT JOIN speedycrew.message ON e.message = message.id
                   LEFT JOIN speedycrew.profile sender_profile ON message.sender = sender_profile.id
                   LEFT JOIN speedycrew.search my_search ON e.search = my_search.id
                   LEFT JOIN speedycrew.search match_search ON e.match = match_search.id
                   LEFT JOIN speedycrew.profile match_profile ON match_search.owner = match_profile.id
                   LEFT JOIN speedycrew.match ON e.search = match.a AND e.match = match.b
                   LEFT JOIN speedycrew.profile my_profile ON e.other_profile = my_profile.id
                   LEFT JOIN speedycrew.crew ON e.crew = crew.id
                   LEFT JOIN speedycrew.crew_member ON e.crew = crew_member.crew AND e.other_profile = crew_member.profile
                       WHERE e.profile = %s
                         AND e.seq > %s
                       ORDER BY e.seq
                       LIMIT %s""",
                   (profile_id, device_sequence, max_fetch_events))
    count = 0
    highest_sequence = None
    for sequence, type, tab, message_body, my_search_id, my_search_query, my_search_side, my_search_address, my_search_postcode, my_search_city, my_search_country, my_search_radius, my_search_longitude, my_search_latitude, match_search_id, match_username, match_email, match_fingerprint, match_query, match_longitude, match_latitude, match_matches, match_distance, match_score, my_fingerprint, my_username, my_real_name, my_email, my_status, my_message, my_created, my_modified, crew_id, crew_name, member_status, message_id, message_sender_fingerprint, message_crew, message_body, message_created in cursor:
        count += 1
        highest_sequence = sequence
        if tab == "MATCH":
            if type == "INSERT":
                metadata.append({ "INSERT" : "match/%s/%s" % (my_search_id, match_search_id) })
                sql.append(param("INSERT INTO match (search, other_search, username, email, fingerprint, query, longitude, latitude, distance, matches, score) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                                 (my_search_id, match_search_id, match_username, match_email, match_fingerprint, match_query, match_longitude, match_latitude, match_distance, match_matches, match_score)))
            elif type == "UPDATE":
                # TODO update for matches
                pass
            elif type == "DELETE":
                metadata.append({ "DELETE" : "match/%s/%s" % (my_search_id, match_search_id) })
                sql.append(param("DELETE FROM match WHERE search = %s AND other_search = %s;\n", (my_search_id, match_search_id)))
        elif tab == "SEARCH":
            if type == "INSERT":
                metadata.append({ "INSERT" : "search/%s" % my_search_id })
                sql.append(param("INSERT INTO search (id, query, side, address, postcode, city, country, radius, longitude, latitude) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                                 (my_search_id, my_search_query, my_search_side, my_search_address, my_search_postcode, my_search_city, my_search_country, my_search_radius, my_search_longitude, my_search_latitude)))
            elif type == "UPDATE":
                metadata.append({ "UPDATE" : "search/%s" % my_search_id })
                # TODO update for searches
            elif type == "DELETE":
                metadata.append({ "DELETE" : "search/%s" % my_search_id })
                sql.append(param("DELETE FROM search WHERE id = %s",
                                 (my_search_id,)))
        elif tab == "PROFILE":
            if type == "UPDATE":
                metadata.append({ "UPDATE" : "profile/%s" % my_fingerprint })
                sql.append(param("UPDATE profile SET username = %s, real_name = %s, email = %s, status = %s, message = %s, created = %s, modified = %s WHERE fingerprint = %s",
                                 (my_username, my_real_name, my_email, my_status, my_message, my_created, my_modified, my_fingerprint)))
            elif type == "INSERT":
                metadata.append({ "INSERT" : "profile/%s" % my_fingerprint })
                sql.append(param("INSERT INTO profile (fingerprint, username, real_name, email, status, message, created, modified) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                                 (my_fingerprint, my_username, my_real_name, my_email, my_status, my_message, my_created, my_modified)))
            elif type == "DELETE":
                metadata.append({ "DELETE" : "profile/%s" % my_fingerprint })
                sql.append(param("DELETE FROM profile WHERE fingerprint = %s",
                                 (my_fingerprint,)))
        elif tab == "CREW":
            if type == "INSERT":
                metadata.append({ "INSERT" : "crew/%s" % crew_id })
                sql.append(param("INSERT INTO crew (id, name) VALUES (%s, %s)", (crew_id, crew_name)))
            elif type == "UPDATE":
                metadata.append({ "UPDATE" : "crew/%s" % crew_id })
                sql.append(param("UPDATE crew SET name = %s WHERE id = %s", (crew_name, crew_id)))
        elif tab == "CREW_MEMBER":
            if type == "INSERT":
                metadata.append({ "INSERT" : "crew_member/%s/%s" % (crew_id, my_fingerprint) })
                sql.append(param("INSERT INTO crew_member (crew, fingerprint, status) VALUES (%s, %s, %s)", (crew_id, my_fingerprint, member_status)))
            elif type == "UPDATE":
                metadata.append({ "UPDATE" : "crew_member/%s/%s" % (crew_id, my_fingerprint) })
                sql.append(param("UPDATE crew_member SET status = %s WHERE crew = %s AND fingerprint = %s", (member_status, crew_id, my_fingerprint)))
        elif tab == "MESSAGE":
            if type == "INSERT":
                metadata.append({ "INSERT" : "message/%s/%s" % (crew_id, message_id) })
                sql.append(param("INSERT INTO message (id, sender, crew, body, created) VALUES (%s, %s, %s, %s, %s)", (message_id, message_sender_fingerprint, message_crew, message_body, message_created)))
            # TODO DELETE?  is UPDATE needed?
                
    if count == max_fetch_events:
        # this means please call again immediately as there are
        # probably more events for you
        metadata.append({ "more" : True })
    if highest_sequence:
        sql.append(param("UPDATE control SET sequence = %s", (highest_sequence,)))

def do_synchronise(profile_id, device_timeline, device_sequence):
    cursor = connection.cursor()
    metadata = [] # messages to tell the app which objects changed
    sql = []      # statements for the device to feed to sqlite

    need_refresh = False
    cursor.execute("""SELECT low_sequence, high_sequence
                        FROM speedycrew.profile_sequence
                       WHERE profile = %s""",
                   (profile_id, ))
    low_sequence, high_sequence = cursor.fetchone()
    if low_sequence > device_sequence:
        need_refresh = True
    cursor.execute("""SELECT timeline
                        FROM speedycrew.control""")
    timeline = cursor.fetchone()[0]
    if timeline != device_timeline:
        # either the device has never been synced or there has been
        # some kind of server-side problem major enough to require all
        # clients to resync (example: database restored from backups,
        # some data lost)
        need_refresh = True
    
    if need_refresh:
        do_refresh(cursor, profile_id, timeline, high_sequence, sql, metadata)
        operation = "refresh"
    else:
        do_incremental(cursor, profile_id, device_sequence, sql, metadata)
        operation = "incremental"

    return operation, metadata, sql

def synchronise(request):
    """A view handler for synchronising device data with the server."""
    profile_id = begin(request)

    # TODO investigate size of int and better options
    device_sequence = 0
    device_timeline = 0
    print request.REQUEST
    if "sequence" in request.REQUEST:
        device_sequence = int(request.REQUEST["sequence"])
    if "timeline" in request.REQUEST:
        device_timeline = int(request.REQUEST["timeline"])

    operation, metadata, sql = do_synchronise(profile_id, 
                                              device_timeline, 
                                              device_sequence)

    return json_response({ "message_type" : "synchronise_response",
                           "status" : "OK",
                           "metadata" : metadata,
                           "operation" : operation,
                           "sql" : sql })

def docs(request):
    """A view handler for showing the documentation/test interface."""
    # TODO turn this shit off in production
    return render(request, "docs.html", { "test": "foox" })

def dashboard(request):
    """A view handler for our cheap and cheerful dashboard web page."""
    cursor = connection.cursor()
    # TODO figure out what we want to show...
    return render(request, "dashboard.html", { "test": "foox" })

def profile(request):
    """A view handler for fetching the user's profile data."""
    profile_id = begin(request)
    request_id = param_or_null(request, "request_id")
    cursor = connection.cursor()
    cursor.execute("""SELECT p.username,
                             p.real_name,
                             p.email,
                             p.status,
                             p.message,
                             p.created
                        FROM speedycrew.profile p
                       WHERE p.id = %s""",
                   (profile_id, ))
    username, real_name, email, status, message, created = cursor.fetchone()
    return json_response({ "message_type" : "profile_response",
                           "request_id" : request_id,
                           "username" : username,
                           "real_name" : real_name,
                           "email" : email,
                           "status" : status,
                           "message" : message,
                           "created" : created.isoformat() })

def update_profile(request):
    profile_id = begin(request)
    cursor = connection.cursor()
    request_id = param_or_null(request, "request_id")
    username = param_or_null(request, "username")
    real_name = param_or_null(request, "real_name")
    email = param_or_null(request, "email")
    message = param_or_null(request, "message")
    timeline = param_or_null(request, "timeline")
    sequence = param_or_null(request, "sequence")

    # TODO what constraints should we place on the form of email
    # addresses and usernames?

    # check uniqueness for email and username (of course there is a
    # race condition here, but we try to give a friendly error reason
    # that the GUI can work with; if someone races us and takes the
    # username after our check then we'll get an ugly error, but there
    # will be no corruption of the uniqueness which is enforced by the
    # database's unique constraints)
    if email != None and email != "":
        cursor.execute("""SELECT * FROM speedycrew.profile WHERE email = %s AND id != %s""",
                       (email, profile_id))
        if cursor.fetchone():
            return json_response({ "message_type" : "update_profile_response",
                                   "request_id" : request_id,
                                   "status" : "ERROR",
                                   "reason" : "EMAIL_IN_USE" })
    if username != None and username != "":
        cursor.execute("""SELECT * FROM speedycrew.profile WHERE username = %s AND id != %s""",
                       (username, profile_id))
        if cursor.fetchone():
            return json_response({ "message_type" : "update_profile_response",
                                   "request_id" : request_id,
                                   "status" : "ERROR",
                                   "reason" : "USERNAME_IN_USE" })

    # peform the updates (converting empty strings to null, if user
    # wants to forget some settings and go back to nothing/null...)
    if username != None:
        if username == "": username = None
        cursor.execute("""UPDATE speedycrew.profile 
                             SET username = %s,
                                 modified = now()
                           WHERE id = %s""", 
                       (username, profile_id))
    if real_name != None:
        if real_name == "": real_name = None
        cursor.execute("""UPDATE speedycrew.profile 
                             SET real_name = %s,
                                 modified = now()
                           WHERE id = %s""",
                       (real_name, profile_id))
    if email != None:
        if email == "": email = None
        cursor.execute("""UPDATE speedycrew.profile 
                             SET email = %s,
                                 modified = now()
                           WHERE id = %s""",
                       (email, profile_id))
    if message != None:
        if message == "": message = None
        cursor.execute("""UPDATE speedycrew.profile 
                             SET message = %s,
                                 modified = now()
                           WHERE id = %s""",
                       (message, profile_id))

    # replicate this profile change to everyone who is 'subscribed'
    # (this includes ourselves, as we must be treated the same way for
    # deadlock avoidance reasons)
    cursor.execute("""SELECT profile
                        FROM speedycrew.profile_subscription
                       WHERE subscribed_to = %s
                       ORDER BY profile""",
                   (profile_id,))
    for subscriber, in cursor.fetchall():
        cursor.execute("""INSERT INTO speedycrew.event (profile, seq, type, other_profile, tab)
                          VALUES (%s, speedycrew.next_sequence(%s), 'UPDATE', %s, 'PROFILE')""",
                       (subscriber, subscriber, profile_id))

    if timeline and sequence:
        operation, metadata, sql = do_synchronise(profile_id, int(timeline), int(sequence))
    else:
        operation, metadata, sql = None, None, None
                      
    return json_response({ "message_type" : "update_profile_response",
                           "request_id" : request_id,
                           "status" : "OK",
                           "operation" : operation,
                           "metadata" : metadata,
                           "sql" : sql })

def tags(request):
    """A view handler for retrieving tag names, suitable for
    auto-completion."""
    profile_id = begin(request)
    prefix = request.REQUEST["prefix"]
    request_id = param_or_null(request, "request_id")
    # TODO sanitise?    
    cursor = connection.cursor()
    # TODO should probably try to suggest popular tags
    cursor.execute("""SELECT t.name
                        FROM speedycrew.tag t
                       WHERE t.name LIKE %s || '%%'
                         AND t.status = 'ACTIVE'
                    ORDER BY t.name
                       LIMIT 20""",
                   (prefix, ))
    results = []
    for name, in cursor:
        results.append(name)
    return json_response({ "message_type" : "tags_response",
                           "request_id" : request_id,
                           "status" : "OK",
                           "tags" : results })

def create_search(request):
    """A view handler to create a new search."""
    profile_id = begin(request)
    cursor = connection.cursor()

    # required parameters
    id = param_or_null(request, ("search_id", "id")) # TODO remove deprecated form
    query = param_or_null(request, "query")
    side = param_or_null(request, "side")
    longitude = param_or_null(request, "longitude")
    latitude = param_or_null(request, "latitude")

    # optional parameters
    request_id = param_or_null(request, "request_id")
    address = param_or_null(request, "address")
    city = param_or_null(request, "city")
    country = param_or_null(request, "country")
    postcode = param_or_null(request, "postcode")
    radius = param_or_null(request, "radius") # required if side = SEEK

    timeline = param_or_null(request, "timeline")
    sequence = param_or_null(request, "sequence")

    # for a limited time only, make up an id if none was provided
    if id == None:
        id = str(uuid.uuid4())

    # validate inputs
    if id == None or query == None or side == None or longitude == None or latitude == None:
        return json_response({ "message_type" : "create_search_response",
                               "status" : "ERROR",
                               "message" : "Expected search_id, query, side, longitude, latitude" })
    if not is_well_formed_uuid(id):
        return json_response({ "message_type" : "create_search_response",
                               "status" : "ERROR",
                               "message" : "Malformed UUID" })
    if side not in ("SEEK", "PROVIDE"):
        return json_response({ "message_type" : "create_search_response",
                               "status" : "ERROR",
                               "message" : "Expected side=SEEK or side=PROVIDE" })
    if side == "SEEK" and radius == None:
        return json_response({ "message_type" : "create_search_response",
                               "status" : "ERROR",
                               "message" : "Expected radius to be provided for side=SEEK" })
    if side == "PROVIDE" and radius != None:
        return json_response({ "message_type" : "create_search_response",
                               "status" : "ERROR",
                               "message" : "Did not expect radius for side=PROVIDE" })
    # TODO validate the wellformedness of latitude, longitude

    tags = re.findall(r"(\w+)", query)    
    if not tags:
        return json_response({ "message_type" : "create_search_response",
                               "request_id" : request_id,
                               "status" : "ERROR",
                               "message" : "query contains no words" })

    # resolve tags to tag IDs, creating them if necessary
    tag_ids = []
    processed_tags = [tag.lower() for tag in tags] # also remove accents?
    processed_tags.sort() # deadlock avoidance
    for tag in processed_tags:
        cursor.execute("""SELECT id, status
                            FROM speedycrew.tag
                           WHERE name = %s""",
                       (tag,))
        row = cursor.fetchone()
        if row == None:
            cursor.execute("""INSERT INTO speedycrew.tag (id, name, status, created, creator)
                              VALUES (DEFAULT, %s, 'ACTIVE', now(), %s)
                           RETURNING id""",
                           (tag, profile_id))
            tag_id = cursor.fetchone()[0]
            tag_ids.append(tag_id)
        else:
            tag_id, tag_status = row
            if tag_status == "BANNED":
                return json_response({ "message_type" : "create_search_response",
                                       "request_id" : request_id,
                                       "status" : "TAG_BLOCKED",
                                       "blocked_tag" : tag,
                                       "message" : "tag is not allowed" })
            elif tag_status == "ACTIVE":
                tag_ids.append(tag_id)
            else:
                # DELETED or IGNORED
                pass

    if len(tag_ids) == 0:
        return json_response({ "message_type" : "create_search_response",
                               "request_id" : request_id,
                               "status" : "ERROR",
                               "message" : "Query contains no indexable words" })

    try:
        cursor.execute("""INSERT INTO speedycrew.search (id, owner, query, side, address, postcode, city, country, geography, radius, status, created)
                          VALUES (%s, %s, %s, %s, %s, %s, %s, %s, speedycrew.make_geo(%s, %s), %s, 'ACTIVE', now())""",
                       (id, profile_id, query, side, address, postcode, city, country, longitude, latitude, radius))
    except IntegrityError, e:
        if e.message.find('"search_pkey"') != -1:
            return json_response({ "message_type" : "create_search_response",
                                   "request_id" : request_id,
                                   "status" : "ERROR",
                                   "message" : "Search ID already exists" })
        else:
            raise e

    for tag_id in tag_ids:
        cursor.execute("""INSERT INTO speedycrew.search_tag VALUES (%s, %s)""",
                       (id, tag_id))
        
    cursor.execute("""INSERT INTO speedycrew.event (profile, seq, type, search, tab)
                      VALUES (%s, speedycrew.next_sequence(%s), 'INSERT', %s, 'SEARCH')""",
                   (profile_id, profile_id, id))

    # TODO since the user is waiting, do some kind of limited version
    # of run_search synchronously?
    cursor.execute("""SELECT speedycrew.run_search(%s::uuid)""", (id, ))

    if timeline and sequence:
        operation, metadata, sql = do_synchronise(profile_id, int(timeline), int(sequence))
    else:
        operation, metadata, sql = None, None, None

    # TODO feed some actual responses back?  that'd be friendly.  for
    # now, here, take a number, go and get the results with another
    # request!
    return json_response({ "message_type" : "create_search_response",
                           "request_id" : request_id,
                           "status" : "OK",
                           "search_id" : id,
                           "operation" : operation,
                           "metadata" : metadata,
                           "sql" : sql })

def delete_search(request):
    """End an existing active search."""
    profile_id = begin(request)
    search_id = param_required(request, ("search_id", "search")) # TODO remove deprecated form
    request_id = param_or_null(request, "request_id")
    cursor = connection.cursor()
    # make sure the search belongs to this profile and it's in the
    # right status
    cursor.execute("""SELECT 1
                        FROM speedycrew.search
                       WHERE id = %s
                         AND owner = %s
                         AND status = 'ACTIVE'
                         FOR UPDATE""",
                   (search_id, profile_id))
    if cursor.rowcount == 1:
        cursor.execute("""SELECT speedycrew.delete_search(%s::uuid)""",
                       (search_id,))
        return json_response({ "message_type" : "delete_search_response",
                               "request_id" : request_id,
                               "status" : "OK" })
    else:
        return json_response({ "message_type" : "delete_search_response",
                               "request_id" : request_id,
                               "status" : "ERROR" })

def set_notification(request):
    """Update the notification tokens for devices."""
    profile_id = begin(request)
    device_id, certificate = get_device_id(request)
    google_registration_id = param_or_null(request, "google_registration_id")
    apple_device_token = param_or_null(request, "apple_device_token")
    cursor = connection.cursor()
    cursor.execute("""UPDATE speedycrew.device
                         SET google_registration_id = %s,
                             apple_device_token = %s
                       WHERE id = %s""",
                   (google_registration_id, apple_device_token, device_id))
    return json_response({ "message_type" : "set_notification_response",
                           "status" : "OK" })

def create_crew(request):
    profile_id = begin(request)
    id = param_required(request, ("crew_id", "id")) # TODO remove deprecated form
    name = request.REQUEST["name"]
    fingerprints = request.REQUEST["fingerprints"].split(",")
    cursor = connection.cursor()
    cursor.execute("""INSERT INTO speedycrew.crew (id, name, created, creator)
                      VALUES (%s, %s, now(), %s)""",
                   (id, name, profile_id))
    # resolve the fingerprints to profile IDs
    member_profile_ids = [profile_id] # we invite ourselves!
    if len(fingerprints) > 0 and fingerprints[0] != "":
        cursor.execute("""SELECT p.id
                            FROM speedycrew.profile p
                           WHERE p.fingerprint = ANY (%s)""",
                       (fingerprints,))
        for member_profile_id, in cursor:
            member_profile_ids.append(member_profile_id)
    # TODO if len(profile_ids) != len(fingerprints) + 1 then some of
    # your fingerprints are unrecognised
    for member_profile_id in member_profile_ids:
        cursor.execute("""INSERT INTO speedycrew.crew_member (crew, profile, status, invited_by, created)
                          VALUES (%s, %s, 'ACTIVE', %s, now())""",
                       (id, member_profile_id, profile_id))
    # now we need to replicate the information to each profile, in
    # sort order (deadlock avoidance), and for each, we must replicate
    # details of all the others, so this is a nested loop
    member_profile_ids.sort()
    for member_profile_id in member_profile_ids:
        # replicate the crew creation
        cursor.execute("""INSERT INTO speedycrew.event (profile, seq, type, tab, crew)
                          VALUES (%s, speedycrew.next_sequence(%s), 'INSERT', 'CREW', %s)""",
                       (member_profile_id, member_profile_id, id))
        for other_member_profile_id in member_profile_ids:
            # make sure that this profile is subscribed to every other
            # (no-op if already so), because devices must know about
            # profiles before they are referenced by crew_member
            cursor.execute("""SELECT speedycrew.profile_subscription_inc(%s, %s)""",
                           (member_profile_id, other_member_profile_id))
            # replicate crew membership
            cursor.execute("""INSERT INTO speedycrew.event (profile, seq, type, crew, other_profile, tab)
                              VALUES (%s, next_sequence(%s), 'INSERT', %s, %s, 'CREW_MEMBER')""",
                           (member_profile_id, member_profile_id, id, other_member_profile_id))
    return json_response({ "message_type" : "create_crew_response",
                           "status" : "OK" })

def invite_crew(request):
    profile_id = begin(request)
    crew_id = param_required(request, ("crew_id", "crew")) # TODO remove deprecated form
    fingerprints = request.REQUEST["fingerprints"].split(",")
    # resolve the fingerprints to profile IDs
    profile_ids = []
    cursor = connection.cursor()
    if len(fingerprints) > 0 and fingerprints[0] != "":
        cursor.execute("""SELECT p.id
                            FROM speedycrew.profile p
                           WHERE p.fingerprint = ANY (%s)""",
                       (fingerprints,))
        for invited_profile_id, in cursor:
            profile_ids.append(invited_profile_id)
    # this is somewhat lame but I am going to lock the crew record
    # while processing this request to avoid having to think about
    # concurrency/skew problems; also a chance to check that the crew
    # ID is valid and return a friendlier error if not
    cursor.execute("""SELECT 1 FROM speedycrew.crew WHERE id = %s FOR UPDATE""",
                   (crew_id,))
    if cursor.fetchone() == None:
        return json_response({ "message_type", "invite_crew_response",
                               "status", "ERROR",
                               "message", "Unknown crew_id" })
    # check that you're actually a member and ACTIVE...
    cursor.execute("""SELECT 1
                        FROM speedycrew.crew_member
                       WHERE crew = %s
                         AND profile = %s
                         AND status = 'ACTIVE'""",
                   (crew_id, profile_id))
    if cursor.fetchone() == None:
        return json_response({ "message_type": "invite_crew_response",
                               "status": "ERROR",
                               "message": "Cannot invite" })        
    # the order of operations in delicate here: first, we will create
    # all the crew_member records (it doesn't matter in which order
    # this is done)
    profiles_needing_crew_insert = set()
    crew_member_inserts = []
    crew_member_updates = []
    for invited_profile_id in profile_ids:
        cursor.execute("""SELECT status
                            FROM speedycrew.crew_member
                           WHERE crew = %s
                             AND profile = %s""",
                       (crew_id, invited_profile_id))
        row = cursor.fetchone()
        if row == None:
            # not already a member, so we need to create the crew on
            # that profile's device(s), and then add the profile as a
            # member
            profiles_needing_crew_insert.add(invited_profile_id)
            crew_member_inserts.append(invited_profile_id)
            cursor.execute("""INSERT INTO speedycrew.crew_member (crew, profile, status, invited_by, created)
                              VALUES (%s, %s, 'ACTIVE', %s, CURRENT_TIMESTAMP)""",
                           (crew_id, invited_profile_id, profile_id))
        elif row[0] == "ACTIVE":
            # already a member, nothing to do
            pass
        else:
            # was a member, but had left or been kicked out; reactivate
            crew_member_updates.append(invited_profile_id)
            cursor.execute("""UPDATE speedycrew.crew_member
                                 SET status = 'ACTIVE',
                                     invited_by = %s
                               WHERE crew = %s
                                 AND profile = %s""",
                           (profile_id, crew_id, invited_profile_id))

    # now, in profile ID order (deadlock avoidance), feed replication
    # data out to all profiles in the crew (including our newly added
    # ones)
    cursor.execute("""SELECT profile
                        FROM speedycrew.crew_member
                       WHERE crew = %s
                       ORDER BY profile""",
                   (crew_id,))
    for member_profile_id, in cursor.fetchall():
        if member_profile_id in profiles_needing_crew_insert:
            cursor.execute("""INSERT INTO speedycrew.event (profile, seq, type, tab, crew)
                              VALUES (%s, next_sequence(%s), 'INSERT', 'CREW', %s)""",
                           (member_profile_id, member_profile_id, crew_id))
            # write out the full set of members
            cursor.execute("""SELECT profile
                                FROM speedycrew.crew_member
                               WHERE crew = %s
                               ORDER BY profile""",
                           (crew_id,))
            for other_member_profile_id, in cursor.fetchall():
                cursor.execute("""SELECT speedycrew.profile_subscription_inc(%s, %s)""",
                               (member_profile_id, other_member_profile_id))
                cursor.execute("""INSERT INTO speedycrew.event (profile, seq, type, tab, crew, other_profile)
                                  VALUES (%s, next_sequence(%s), 'INSERT', 'CREW_MEMBER', %s, %s)""",
                               (member_profile_id, member_profile_id, crew_id, other_member_profile_id))
        else:
            for crew_member_insert in crew_member_inserts:
                cursor.execute("""SELECT speedycrew.profile_subscription_inc(%s, %s)""",
                               (member_profile_id, crew_member_insert))
                cursor.execute("""INSERT INTO speedycrew.event (profile, seq, type, tab, crew, other_profile)
                              VALUES (%s, next_sequence(%s), 'INSERT', 'CREW_MEMBER', %s, %s)""",
                               (member_profile_id, member_profile_id, crew_id, crew_member_insert))
            for crew_member_update in crew_member_updates:
                cursor.execute("""SELECT speedycrew.profile_subscription_inc(%s, %s)""",
                               (member_profile_id, crew_member_update))
                cursor.execute("""INSERT INTO speedycrew.event (profile, seq, type, tab, crew, other_profile)
                              VALUES (%s, next_sequence(%s), 'UPDATE', 'CREW_MEMBER', %s, %s)""",
                               (member_profile_id, member_profile_id, crew_id, crew_member_update))

    return json_response({ "message_type" : "invite_crew_response",
                           "status" : "OK" })

def leave_crew(request):
    profile_id = begin(request)
    crew_id = param_required(request, ("crew_id", "crew")) # TODO remove deprecated form
    cursor = connection.cursor()
    # lock crew row so membership doesn't change...
    cursor.execute("""SELECT 1 FROM speedycrew.crew WHERE id = %s FOR UPDATE""",
                   (crew_id,))
    if cursor.fetchone() == None:
        return json_response({ "message_type": "leave_crew_response",
                               "status": "ERROR",
                               "message": "Unknown crew ID" })
    # mark ours as LEFT
    cursor.execute("""UPDATE speedycrew.crew_member
                         SET status = 'LEFT'
                       WHERE crew = %s AND profile = %s AND status = 'ACTIVE'""",
                   (crew_id, profile_id))
    if cursor.rowcount != 1:
        return json_response({ "message_type": "leave_crew_response",
                               "status": "ERROR",
                               "message": "Not a member" })
    # in profile_id order, tell everyone (including ourselves!) to
    # update our crew_member record
    cursor.execute("""SELECT profile
                        FROM speedycrew.crew_member
                       WHERE crew = %s
                       ORDER BY profile""",
                   (crew_id,))
    for member_profile_id, in cursor.fetchall():
        cursor.execute("""INSERT INTO speedycrew.event (profile, seq, type, tab, crew, other_profile)
                          VALUES (%s, next_sequence(%s), 'UPDATE', 'CREW_MEMBER', %s, %s)""",
                       (member_profile_id, member_profile_id, crew_id, profile_id))

    return json_response({ "message_type" : "leave_crew_response",
                           "status" : "OK" })

def rename_crew(request):
    profile_id = begin(request)
    crew_id = param_required(request, "crew_id")
    name = param_required(request, "name")
    cursor = connection.cursor()
    # lock crew row so membership doesn't change
    cursor.execute("""SELECT 1 FROM speedycrew.crew WHERE id = %s FOR UPDATE""",
                   (crew_id,))
    if cursor.fetchone() == None:
        return json_response({ "message_type": "rename_crew_response",
                               "status": "ERROR",
                               "message": "Unknown crew_id" })
    # make sure that the caller is a member
    cursor.execute("""SELECT 1 FROM speedycrew.crew_member WHERE crew = %s AND profile = %s""",
                   (crew_id, profile_id))
    if cursor.fetchone() == None:
        return json_response({ "message_type": "rename_crew_response",
                               "status": "ERROR",
                               "message": "Negative, permission denied" })
    # update the crew
    cursor.execute("""UPDATE speedycrew.crew SET name = %s WHERE id = %s""",
                   (name, crew_id))
    # tell everyone who needs to know
    cursor.execute("""SELECT profile
                        FROM speedycrew.crew_member
                       WHERE crew = %s
                       ORDER BY profile""",
                   (crew_id,))
    for member_profile_id, in cursor.fetchall():
        cursor.execute("""INSERT INTO speedycrew.event (profile, seq, type, tab, crew)
                          VALUES (%s, next_sequence(%s), 'UPDATE', 'CREW', %s)""",
                       (member_profile_id, member_profile_id, crew_id))
    return json_response({ "message_type" : "rename_crew_response",
                           "status" : "OK" })

def send_message(request):
    profile_id = begin(request)
    crew_id = param_or_null(request, ("crew_id", "crew")) # TODO remove deprecated form
    fingerprint = param_or_null(request, "fingerprint")
    id = param_required(request, ("message_id", "id")) # TODO remove deprecated form
    body = request.REQUEST["body"]
    timeline = param_or_null(request, "timeline")
    sequence = param_or_null(request, "sequence")

    if (crew_id == None) == (fingerprint == None):
        return HttpResponseBadRequest("400: Expected exactly one of crew, fingerprint")

    # if you provided a recipient in fingerprint, then we will try to
    # find a suitable crew: one that has the requestor, the recipient,
    # and no one else as members
    cursor = connection.cursor()
    if fingerprint:
        cursor.execute("""SELECT p.id
                            FROM speedycrew.profile p
                           WHERE p.fingerprint = %s""",
                       (fingerprint,))
        row = cursor.fetchone()
        if row == None:
            return HttpResponseBadRequest("400: Unknown fingerprint")
        recipient_profile_id, = row
        cursor.execute("""SELECT cm.crew
                            FROM speedycrew.crew_member cm
                           WHERE cm.crew IN (SELECT cm2.crew
                                               FROM speedycrew.crew_member cm2
                                              WHERE cm2.profile = %s
                                                AND cm2.status = 'ACTIVE') -- recipient is one of them
                             AND cm.status = 'ACTIVE'
                           GROUP BY cm.crew
                          HAVING BOOL_AND(cm.profile IN (%s, %s)) -- no other profiles
                             AND BOOL_OR(cm.profile = %s)         -- sender is one of them""",
                       (recipient_profile_id, profile_id, recipient_profile_id, profile_id))
        row = cursor.fetchone()
        if row == None:
            # no suitable crew already exists, so we create one and
            # invite both members (or just the sender if sending to
            # self...)
            crew_id = str(uuid.uuid4())
            cursor.execute("""INSERT INTO speedycrew.crew (id, created, creator)
                              VALUES (%s, CURRENT_TIMESTAMP, %s)""",
                           (crew_id, profile_id))
            # make sure we do things in the right order...  but also
            # make sure that if we are sending a message to ourselves,
            # we don't create a group with ourselves twice!
            member_profile_ids = [profile_id]
            if profile_id != recipient_profile_id:
                member_profile_ids.append(recipient_profile_id)
            member_profile_ids.sort()
            for member_profile_id in member_profile_ids:
                cursor.execute("""INSERT INTO speedycrew.crew_member (crew, profile, status, invited_by, created)
                                  VALUES (%s, %s, 'ACTIVE', %s, CURRENT_TIMESTAMP)""",
                               (crew_id, member_profile_id, profile_id))
                cursor.execute("""INSERT INTO speedycrew.event (profile, seq, type, tab, crew)
                                  VALUES (%s, speedycrew.next_sequence(%s), 'INSERT', 'CREW', %s)""",
                               (member_profile_id, member_profile_id, crew_id))
                for other_member_profile_id in member_profile_ids:
                    cursor.execute("""SELECT speedycrew.profile_subscription_inc(%s, %s)""",
                                   (member_profile_id, other_member_profile_id))
                    cursor.execute("""INSERT INTO speedycrew.event (profile, seq, type, crew, other_profile, tab)
                                      VALUES (%s, next_sequence(%s), 'INSERT', %s, %s, 'CREW_MEMBER')""",
                                   (member_profile_id, member_profile_id, crew_id, other_member_profile_id))                    
        else:
            crew_id, = row                      

    try:
        cursor.execute("""INSERT INTO speedycrew.message (id, sender, crew, body, created)
                          VALUES (%s, %s, %s, %s, CURRENT_TIMESTAMP)""",
                       (id, profile_id, crew_id, body))
    except IntegrityError, e:
        if e.message.find('"message_pkey"') != -1:
            return json_response({ "message_type": "send_message_response",
                                   "status": "ERROR",
                                   "message": "Message ID already exists" })
        else:
            raise e

    cursor.execute("""SELECT profile
                        FROM speedycrew.crew_member
                       WHERE crew = %s
                       ORDER BY profile""",
                   (crew_id,))
    for member_profile_id, in cursor.fetchall():
        cursor.execute("""INSERT INTO speedycrew.event (profile, seq, type, tab, message, crew)
                          VALUES (%s, next_sequence(%s), 'INSERT', 'MESSAGE', %s, %s)""",
                       (member_profile_id, member_profile_id, id, crew_id))
        cursor.execute("""INSERT INTO speedycrew.tickle_queue (profile, message)
                          VALUES (%s, 'You have a new message')""",
                       (member_profile_id,))

    cursor.execute("""NOTIFY tickle""")

    if timeline and sequence:
        operation, metadata, sql = do_synchronise(profile_id, int(timeline), int(sequence))
    else:
        operation, metadata, sql = None, None, None

    return json_response({ "message_type" : "send_message_response",
                           "status" : "OK",
                           "crew_id" : crew_id,
                           "message_id" : id,
                           "operation" : operation,
                           "metadata" : metadata,
                           "sql" : sql })

def trending(request):
    """A dump of popular tags."""
    profile_id = begin(request)
    request_id = param_or_null(request, "request_id")
    results = []
    cursor = connection.cursor()
    cursor.execute("""SELECT t.name, tc.provide_counter, tc.seek_counter, tc.counter
                        FROM speedycrew.tag t
                        JOIN speedycrew.tag_count tc ON t.id = tc.tag
                    ORDER BY tc.counter
                       LIMIT 100""")
    for name, provide_counter, seek_counter, counter in cursor:
        results.append({ "tag" : name,
                         "provide_counter" : provide_counter,
                         "seek_counter" : seek_counter,
                         "counter" : counter })
    return json_response({ "message_type" : "trending_response",
                           "request_id" : request_id,
                           "status" : "OK",
                           "results" : results })

def get_media_profile_id(cursor, fingerprint):
    """Resolve the fingerprint provided in a media URL to a profile
    ID, or -1 if unknown or banned/cancelled profile."""
    # TODO the identifiers here are based on fingerprints for
    # per-device certificates, so we work our way back to a profile
    # that way (ie you could use the fingerprint for any of the user's
    # devices); but in discussions we have assumed that there would be
    # a special fingerprint for a profile, which hasn't been figured
    # out/implemented yet
    cursor.execute("""SELECT p.id
                        FROM speedycrew.profile p
                        JOIN speedycrew.device d ON d.profile = p.id
                       WHERE d.id = %s
                         AND p.status = 'ACTIVE'""",
                   (fingerprint,))
    row = cursor.fetchone()
    if row == None:
        return -1
    media_profile_id, = row
    return media_profile_id
    
def media_list(request, fingerprint):
    """List the media stored for a given profile."""
    profile_id = begin(request)
    request_id = param_or_null(request, "request_id")
    cursor = connection.cursor()

    # whose media are we looking at?
    media_profile_id = get_media_profile_id(cursor, fingerprint)
    if media_profile_id == -1:
        return json_response({ "message_type" : "media_response",
                               "request_id" : request_id,
                               "status" : "ERROR",
                               "reason" : "No such profile" })

    # find all files for that profile
    cursor.execute("""SELECT name, mime_type, CAST(created AS TEXT), CAST(modified AS TEXT), version, size, public
                        FROM speedycrew.file
                       WHERE profile = %s
                       ORDER BY name""",
                   (media_profile_id,))
    results = []
    for name, mime_type, created, modified, version, size, public in cursor:
        # if this is not your profile, you can only see things that
        # are public
        if public or profile_id == media_profile_id:
            results.append({ "name" : name,
                             "size" : size,
                             "mime_type" : mime_type,
                             "created" : created,
                             "modified" : modified,
                             "version" : version })
    return json_response({ "message_type" : "media_list",
                           "request_id" : request_id,
                           "results" : results } )

def media(request, fingerprint, name):
    """GET, PUT or DELETE a file (media) for a given profile with a
    given name."""
    profile_id = begin(request)
    cursor = connection.cursor()

    # whose media are we looking at?
    media_profile_id = get_media_profile_id(cursor, fingerprint)
    if media_profile_id == -1:
        return HttpResponseNotFound("404: Profile not found")
    
    if request.method == "GET":
        # which file is it?
        cursor.execute("""SELECT mime_type, data, modified, public
                            FROM speedycrew.file
                           WHERE profile = %s
                             AND name = %s""",
                       (media_profile_id, name))
        row = cursor.fetchone()
        if row == None:
            return HttpResponseNotFound("404: File not found")
        mime_type, data, modified, public = row
        if profile_id != media_profile_id and not public:
            return HttpResponseForbidden("403: Access denied")
        # TODO: do something with modified time; also support HTTP HEAD so
        # that clients can check if media has changed without fetching it?
        return HttpResponse(data, content_type=mime_type)
    elif request.method == "PUT":
        # you can only PUT your own media
        if profile_id != media_profile_id:
            return HttpResponseForbidden("403: You are not allowed to do that")

        public = True # TODO get from a header!
        data = request.raw_post_data
        size = len(data)
        mime_type = "plain/text" # TODO get from a header!
        # this is a lame UPSERT
        cursor.execute("""SELECT 1
                            FROM speedycrew.file
                           WHERE profile = %s
                             AND name = %s""",
                       (media_profile_id, name))
        row = cursor.fetchone()
        if row == None:
            cursor.execute("""INSERT INTO speedycrew.file (profile, name, mime_type, version, created, modified, size, data, public)
                              VALUES (%s, %s, %s, 1, now(), now(), %s, %s, %s)""",
                           (media_profile_id, name, mime_type, size, data, public))
        else:
            cursor.execute("""UPDATE speedycrew.file
                                 SET data = %s,
                                     size = %s,
                                     version = version + 1,
                                     modified = now(),
                                     public = %s,
                                     mime_type = %s
                               WHERE profile = %s
                                 AND name = %s""",
                           (data, size, public, mime_type, media_profile_id, name))
        return HttpResponse('Thank you!')
    elif request.method == "DELETE":
        # you can only DELETE your own media
        if profile_id != media_profile_id:
            return HttpResponseForbidden("403: You are not allowed to do that")
        cursor.execute("""DELETE
                            FROM speedycrew.file
                           WHERE profile = %s
                             AND name = %s""",
                       (media_profile_id, name))
        if cursor.rowcount == 1:
            return HttpResponse("OK")
        else:
            return HttpResponseNotFound("404: File not found")
        

            
