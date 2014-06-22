from django.db import connection
from django.http import HttpResponse, HttpResponseNotFound, HttpResponseForbidden
from django.shortcuts import render
import hashlib
import json
import uuid
import re
from M2Crypto import X509

MAX_FETCH_EVENTS = 100

def json_response(object):
    """A convenience function for generating a JSON HTTP response."""
    return HttpResponse(json.dumps(object, indent=4),
                        content_type="application/json")

def param_or_null(request, name):
    if name not in request.REQUEST:
        return None
    else:
        return request.REQUEST[name]

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
        cursor.execute("""INSERT INTO speedycrew.profile (id, status, created) 
                          VALUES (DEFAULT, 'ACTIVE', now())
                       RETURNING id""",
                       (device_id, ))
        profile_id = cursor.fetchone()[0]
        cursor.execute("""INSERT INTO speedycrew.profile_sequence (profile, low_sequence, high_sequence)
                          VALUES (%s, 0, 0)""",
                       (profile_id,))
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
    elif s is str:    
        return "'" + s.replace("'", "''") + "'"
    else:
        return "'" + str(s) + "'"

def param(fmt, values):
    """Something for building SQL strings with literals, similar to DB
    module execute."""
    return fmt % tuple(map(escape, values)) # TODO this is not the modern way, use .format

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
    print device_timeline, device_sequence

    cursor = connection.cursor()
    metadata = [] # messages to tell the app which objects changed
    sql = []      # statements for the device to feed to sqlite

    need_full_resync = False
    cursor.execute("""SELECT low_sequence, high_sequence
                        FROM speedycrew.profile_sequence
                       WHERE profile = %s""",
                   (profile_id, ))
    low_sequence, high_sequence = cursor.fetchone()
    if low_sequence > device_sequence:
        # TODO think about whether we want low_sequence to be the
        # lowest event we have, or the highest event that we have
        # deleted (probably need to try implementing the trimming code
        # to decide which is more convenient)
        need_full_resync = True
        print "need full resync because low_sequence > device_sequence"
    cursor.execute("""SELECT timeline
                        FROM speedycrew.control""")
    timeline = cursor.fetchone()[0]
    if timeline != device_timeline:
        # either the device has never been synced or there has been
        # some kind of server-side problem major enough to require all
        # clients to resync (example: database restored from backups,
        # some data lost)
        print "got timeline = ", timeline, " device_timeline = ", device_timeline
        print "so need full resync"
        need_full_resync = True
    
    if need_full_resync:

        sql.append("DELETE FROM profile")
        sql.append("DELETE FROM message")
        sql.append("DELETE FROM match")
        sql.append("DELETE FROM search")
        sql.append("DELETE FROM control")

        # TODO messages etc

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

        cursor.execute("""SELECT s2.id AS other_search_id,
                                 s1.id AS my_search_id,
                                 p2.username,
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
            sql.append(param("INSERT INTO match (id, search, username, fingerprint, query, longitude, latitude, matches, distance, score) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                             row))    

        cursor.execute("""SELECT username, real_name, email, status, message, created, modified
                            FROM speedycrew.profile
                           WHERE id = %s""",
                       (profile_id, ))
        username, real_name, email, status, message, created, modified = cursor.fetchone()
        sql.append(param("INSERT INTO profile (username, real_name, email, status, message, created, modified) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                         (username, real_name, email, status, message, created, modified)))

        sql.append(param("INSERT INTO control (timeline, sequence) VALUES (%s, %s)",
                         (timeline, high_sequence,)))

    else:
        # build incremental results

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
                                 match_device.id AS match_fingerprint,
                                 match_search.query,
                                 st_x(match_search.geography::geometry) AS longitude,
                                 st_y(match_search.geography::geometry) AS latitude,
                                 match.matches,
                                 match.distance,
                                 match.score
                            FROM speedycrew.event e
                       LEFT JOIN speedycrew.message ON e.message = message.id
                       LEFT JOIN speedycrew.search my_search ON e.search = my_search.id
                       LEFT JOIN speedycrew.search match_search ON e.match = match_search.id
                       LEFT JOIN speedycrew.profile match_profile ON match_search.owner = match_profile.id
                       LEFT JOIN speedycrew.device match_device ON match_profile.id = match_device.profile
                       LEFT JOIN speedycrew.match ON e.search = match.a AND e.match = match.b
                           WHERE e.profile = %s
                             AND e.seq > %s
                           ORDER BY e.seq
                           LIMIT %s""",
                       (profile_id, device_sequence, MAX_FETCH_EVENTS))
        count = 0
        highest_sequence = None
        for sequence, type, message_body, my_search_id, my_search_query, my_search_side, my_search_address, my_search_postcode, my_search_city, my_search_country, my_search_radius, my_search_latitude, my_search_longitude, match_search_id, match_username, match_fingerprint, match_query, match_longitude, match_latitude, match_matches, match_distance, match_score in cursor:
            count += 1
            highest_sequence = sequence
            if match_search_id:
                print "match thingee"
                if type == "INSERT":
                    metadata.append({ "INSERT" : "match/%s" % match_search_id })
                    sql.append(param("INSERT INTO match (id, search, username, fingerprint, query, latitude, longitude, distance, matches, distance, score) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                                     (match_search_id, my_search_id, match_username, match_fingerprint, match_query, match_distance, match_longitude, match_latitude, match_matches, match_distance, match_score)))
                elif type == "UPDATE":
                    # TODO update for matches
                    pass
                elif type == "DELETE":
                    header += "-- @DELETE match/%s\n" % match_search_id
                    sql += param("DELETE FROM match WHERE id = %s;\n", (match_search_id,))
            elif my_search_id:
                print "search thingee"
                if type == "INSERT":
                    metadata.append({ "INSERT" : "search/%s" % my_search_id })
                    sql.append(param("INSERT INTO search (id, query, side, address, postcode, city, country, radius, latitude, longitude) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                                     (my_search_id, my_search_query, my_search_side, my_search_address, my_search_postcode, my_search_city, my_search_country, my_search_radius, my_search_latitude, my_search_longitude)))
                elif type == "UPDATE":
                    metadata.append({ "UPDATE" : "search/%s" % my_search_id })
                    # TODO update for searches
                elif type == "DELETE":
                    metadata.append({ "DELETE" : "search/%s" % my_search_id })
             
        if count == MAX_FETCH_EVENTS:
            # this means please call again immediately as there are
            # probably more events for you
            metadata.append({ "more" : True })
        if highest_sequence:
            sql.append(param("UPDATE control SET sequence = %s", (highest_sequence,)))

    if need_full_resync:
        operation = "refresh"
    else:
        operation = "incremental"
    return json_response({ "message_type" : "synchronise_response",
                           "status" : "OK",
                           "metadata" : metadata,
                           "operation" : operation,
                           "sql" : sql })

def docs(request):
    """A view handler for showing the documentation/test interface."""
    # TODO turn this shit off in production
    return render(request, "docs.html", { "test": "foox" })

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

    return json_response({ "message_type" : "update_profile_response",
                           "request_id" : request_id,
                           "status" : "OK" })

# TODO this will be removed (made obsolete by the new synchronisation
# system)
def searches(request):
    """A view handler that returns a summary of the user's currently
    active searches."""
    profile_id = begin(request)
    request_id = param_or_null(request, "request_id")
    cursor = connection.cursor()
    cursor.execute("""SELECT s.id, s.query, s.side, s.created, array_agg(t.name) AS tags, s.status
                        FROM speedycrew.search s
                        JOIN speedycrew.search_tag st ON st.search = s.id
                        JOIN speedycrew.tag t ON st.tag = t.id
                       WHERE s.owner = %s
                         AND s.status = 'ACTIVE'
                       GROUP BY s.id
                       ORDER BY s.created DESC""",
                   (profile_id, ))
    searches = []
    for id, query, side, created, tags, status in cursor:
        searches.append({ "id" : id,
                          "query" : query,
                          "side" : side,
                          "created" : created.isoformat(),
                          "tags" : tags,
                          "status" : status })
    return json_response({ "message_type" : "searches_response",
                           "request_id" : request_id,
                           "status" : "OK",
                           "searches" : searches })

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
    query = request.REQUEST["query"]
    side = request.REQUEST["side"]
    longitude = request.REQUEST["longitude"]
    latitude = request.REQUEST["latitude"]

    # optional parameters
    id = param_or_null(request, "id")
    request_id = param_or_null(request, "request_id")
    address = param_or_null(request, "address")
    city = param_or_null(request, "city")
    country = param_or_null(request, "country")
    postcode = param_or_null(request, "postcode")
    radius = param_or_null(request, "radius") # required if side = PROVIDE


    if id == None:
        # device should supply this, but for a short time only i'll
        # make one up if none was included in the request
        id = str(uuid.uuid4())

    tags = re.findall(r"#(\w+)", query)    
    if not tags:
        return json_response({ "message_type" : "create_search_response",
                               "request_id" : request_id,
                               "status" : "ERROR",
                               "message" : "query contains no tags" })

    # resolve tags to tag IDs, creating them if necessary
    tag_ids = []
    for tag in tags:
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
            if tag_status != "ACTIVE":
                return json_response({ "message_type" : "create_search_response",
                                       "request_id" : request_id,
                                       "status" : "TAG_BLOCKED",
                                       "blocked_tag" : tag,
                                       "message" : "tag is not allowed" })
            tag_ids.append(tag_id)

    cursor.execute("""INSERT INTO speedycrew.search (id, owner, query, side, address, postcode, city, country, geography, radius, status, created)
                      VALUES (%s, %s, %s, %s, %s, %s, %s, %s, speedycrew.make_geo(%s, %s), %s, 'ACTIVE', now())""",
                   (id, profile_id, query, side, address, postcode, city, country, longitude, latitude, radius))

    for tag_id in tag_ids:
        cursor.execute("""INSERT INTO speedycrew.search_tag VALUES (%s, %s)""",
                       (id, tag_id))

        
    # TODO review lock duration on profile records
    cursor.execute("""UPDATE speedycrew.profile_sequence
                         SET high_sequence = high_sequence + 1
                       WHERE profile = %s
                   RETURNING high_sequence""",
                   (profile_id, ))
    next_sequence, = cursor.fetchone()
    cursor.execute("""INSERT INTO speedycrew.event (profile, seq, type, search)
                      VALUES (%s, %s, 'INSERT', %s)""",
                   (profile_id, next_sequence, id))

    # TODO since the user is waiting, do some kind of limited version
    # of run_search synchronously?
    cursor.execute("""SELECT speedycrew.run_search(%s::uuid)""", (id, ))

    # TODO feed some actual responses back?  that'd be friendly.  for
    # now, here, take a number, go and get the results with another
    # request!
    return json_response({ "message_type" : "create_search_response",
                           "request_id" : request_id,
                           "status" : "OK",
                           "search_id" : id })

def delete_search(request):
    """End an existing active search."""
    profile_id = begin(request)
    search_id = request.REQUEST["search"]
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

# TODO this will be removed (made obsolete by the new synchronisation
# system)
def search_results(request):
    """A dumb request for all results for a given search ID."""
    profile_id = begin(request)
    search_id = request.REQUEST["search"]
    request_id = param_or_null(request, "request_id")
    cursor = connection.cursor()
    cursor.execute("""SELECT s2.id, 
                             p.username, 
                             p.real_name,
                             d.id,
                             p.email, 
                             s2.address, 
                             s2.postcode, 
                             s2.city, 
                             s2.country, 
                             st_distance(s1.geography, s2.geography) AS distance,
                             st_x(s2.geography::geometry) AS longitude,
                             st_y(s2.geography::geometry) AS latitude
                        FROM speedycrew.match m
                        JOIN speedycrew.search s1 ON m.a = s1.id
                        JOIN speedycrew.search s2 ON m.b = s2.id
                        JOIN speedycrew.profile p ON s2.owner = p.id
                        JOIN speedycrew.device d ON p.id = d.profile -- TODO!
                       WHERE s1.id = %s
                         AND s1.owner = %s
                         AND s2.status = 'ACTIVE'""",
                   (search_id, profile_id))
    # TODO -- this will return a row for each device the user has
    # since each has its own fingerprint; I need to invent the concept
    # of a primary/per profile fingerprint
    results = []
    for id, username, real_name, fingerprint, email, address, postcode, city, country, distance, longitude, latitude in cursor:
        results.append({ "id" : id,
                         "fingerprint" : fingerprint,
                         "username" : username,
                         "real_name" : real_name,
                         "email" : email,
                         "address" : address,
                         "postcode" : postcode,
                         "city" : city,
                         "country" : country,
                         "distance" : distance,
                         "longitude" : longitude,
                         "latitude" : latitude })
    return json_response({ "message_type" : "search_results_response",
                           "request_id" : request_id,
                           "status" : "OK",
                           "results" : results })

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
        return HttpResponseNotFound("Profile not found -- 404")
    
    if request.method == "GET":
        # which file is it?
        cursor.execute("""SELECT mime_type, data, modified, public
                            FROM speedycrew.file
                           WHERE profile = %s
                             AND name = %s""",
                       (media_profile_id, name))
        row = cursor.fetchone()
        if row == None:
            return HttpResponseNotFound("File not found -- 404")
        mime_type, data, modified, public = row
        if profile_id != media_profile_id and not public:
            return HttpResponseForbidden("Access denied -- 403")
        # TODO: do something with modified time; also support HTTP HEAD so
        # that clients can check if media has changed without fetching it?
        return HttpResponse(data, content_type=mime_type)
    elif request.method == "PUT":
        # you can only PUT your own media
        if profile_id != media_profile_id:
            return HttpResponseForbidden("You are not allowed to do that -- 403")

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
            return HttpResponseForbidden("You are not allowed to do that -- 403")
        cursor.execute("""DELETE
                            FROM speedycrew.file
                           WHERE profile = %s
                             AND name = %s""",
                       (media_profile_id, name))
        if cursor.rowcount == 1:
            return HttpResponse("OK")
        else:
            return HttpResponseNotFound("File not found -- 404")
        

            
