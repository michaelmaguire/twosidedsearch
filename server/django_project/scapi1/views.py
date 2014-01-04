from django.db import connection
from django.http import HttpResponse
from django.shortcuts import render
import json
import uuid

def json_response(object):
    """A convenience function for generating a JSON HTTP response."""
    return HttpResponse(json.dumps(object, indent=4),
                        content_type="application/json")

def begin(request):
    """The prelude to be used by all view functions to obtain or
    create a profile ID using the device ID information present in the
    request."""
    # in development, we use a header or a parameter, but later we
    # will use some fancy-pants certificate stuff
    device_id = request.REQUEST["x-id"]
    # this could be someone we've never heard of, or someone returning
    profile_id = None
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
        cursor.execute("""INSERT INTO speedycrew.device (id, profile, last_seen, created) 
                          VALUES (%s, %s, now(), now())""",
                       (device_id, profile_id))
    cursor.close()
    return profile_id

def docs(request):
    """A view handler for showing the documentation/test interface."""
    # TODO turn this shit off in production
    return render(request, "docs.html", { "test": "foox" })

def profile(request):
    """A view handler for fetching the user's profile data."""
    profile_id = begin(request)
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
    return json_response({ "username" : username,
                           "real_name" : real_name,
                           "email" : email,
                           "status" : status,
                           "message" : message,
                           "created" : created.isoformat() })

def update_profile(request):
    profile_id = begin(request)
    cursor = connection.cursor()
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
            return json_response({ "status" : "ERROR",
                                   "reason" : "EMAIL_IN_USE" })
    if username != None and username != "":
        cursor.execute("""SELECT * FROM speedycrew.profile WHERE username = %s AND id != %s""",
                       (username, profile_id))
        if cursor.fetchone():
            return json_response({ "status" : "ERROR",
                                   "reason" : "USERNAME_IN_USE" })

    # peform the updates (converting empty strings to null, if user
    # wants to forget some settings and go back to nothing/null...)
    if username != None:
        if username == "": username = None
        cursor.execute("""UPDATE speedycrew.profile SET username = %s WHERE id = %s""", 
                       (username, profile_id))
    if real_name != None:
        if real_name == "": real_name = None
        cursor.execute("""UPDATE speedycrew.profile SET real_name = %s WHERE id = %s""",
                       (real_name, profile_id))
    if email != None:
        if email == "": email = None
        cursor.execute("""UPDATE speedycrew.profile SET email = %s WHERE id = %s""",
                       (email, profile_id))
    if message != None:
        if message == "": message = None
        cursor.execute("""UPDATE speedycrew.profile SET message = %s WHERE id = %s""",
                       (message, profile_id))

    return json_response({ "status" : "OK" })

def searches(request):
    """A view handler that returns a summary of the user's currently
    active searches."""
    profile_id = begin(request)
    cursor = connection.cursor()
    cursor.execute("""SELECT s.id, s.name, s.side, s.created, array_agg(t.name) AS tags
                        FROM speedycrew.search s
                        JOIN speedycrew.search_tag st ON st.search = s.id
                        JOIN speedycrew.tag t ON st.tag = t.id
                       WHERE s.owner = %s
                       GROUP BY s.id
                       ORDER BY s.name, s.created""",
                   (profile_id, ))
    searches = []
    for id, name, side, created, tags in cursor:
        searches.append({ "id" : id,
                          "name" : name,
                          "side" : side,
                          "created" : created.isoformat(),
                          "tags" : tags })
    return json_response({ "status" : "OK",
                           "searches" : searches })

def tags(request):
    """A view handler for retrieving tag names, suitable for
    auto-completion."""
    profile_id = begin(request)
    prefix = request.REQUEST["prefix"]
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
    return json_response({ "status" : "OK",
                           "tags" : results })

def param_or_null(request, name):
    if name not in request.REQUEST:
        return None
    else:
        return request.REQUEST[name]

def create_search(request):
    """A view handler to create a new search."""
    profile_id = begin(request)
    cursor = connection.cursor()

    # required parameters
    tags = request.REQUEST["tags"].split(",")
    side = request.REQUEST["side"]
    longitude = request.REQUEST["longitude"]
    latitude = request.REQUEST["latitude"]

    # optional parameters
    name = param_or_null(request, "name")
    address = param_or_null(request, "address")
    city = param_or_null(request, "city")
    country = param_or_null(request, "country")
    postcode = param_or_null(request, "postcode")
    radius = param_or_null(request, "radius") # required if side = PROVIDE

    # resolve tags to tag IDs, creating this if necessary
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
                return json_response({ "status" : "TAG_BLOCKED",
                                       "blocked_tag" : tag,
                                       "message" : "tag is not allowed" })
            tag_ids.append(tag_id)
        
    cursor.execute("""INSERT INTO speedycrew.search (id, owner, name, side, address, postcode, city, country, geography, radius, status, created)
                      VALUES (DEFAULT, %s, %s, %s, %s, %s, %s, %s, speedycrew.make_geo(%s, %s), %s, 'ACTIVE', now())
                   RETURNING id""",
                   (profile_id, name, side, address, postcode, city, country, longitude, latitude, radius))
    search_id = cursor.fetchone()[0]
    for tag_id in tag_ids:
        cursor.execute("""INSERT INTO speedycrew.search_tag VALUES (%s, %s)""",
                       (search_id, tag_id))

    # TODO since the user is waiting, do some kind of limited version
    # of run_search synchronously?
    cursor.execute("""SELECT speedycrew.run_search(%s)""", (search_id, ))

    # TODO feed some actual responses back?  that'd be friendly.  for
    # now, here, take a number, go and get the results with another
    # request!
    return json_response({ "status" : "OK",
                           "search_id" : search_id })

def delete_search(request):
    """End an existing active search."""
    profile_id = begin(request)
    search_id = request.REQUEST["search"]
    cursor = connection.cursor()
    cursor.execute("""UPDATE speedycrew.search
                         SET status = 'DELETED'
                       WHERE id = %s
                         AND owner = %s
                         AND status = 'ACTIVE'""",
                   (search_id, profile_id))
    if cursor.rowcount == 1:
        return json_response({ "status" : "OK" })
    else:
        return json_response({ "status" : "ERROR" })

def search_results(request):
    """A dumb request for all results for a given search ID."""
    profile_id = begin(request)
    search_id = request.REQUEST["search"]
    cursor = connection.cursor()
    cursor.execute("""SELECT s2.id, 
                             p.username, 
                             p.real_name, 
                             p.email, 
                             s2.address, 
                             s2.postcode, 
                             s2.city, 
                             s2.country, 
                             st_distance(s1.geography, s2.geography) AS distance
                        FROM speedycrew.match m
                        JOIN speedycrew.search s1 ON m.a = s1.id
                        JOIN speedycrew.search s2 ON m.b = s2.id
                        JOIN speedycrew.profile p ON s2.owner = p.id
                       WHERE s1.id = %s
                         AND s1.owner = %s
                         AND s2.status = 'ACTIVE'""",
                   (search_id, profile_id))
    results = []
    for id, username, real_name, email, address, postcode, city, country, distance in cursor:
        results.append({ "id" : id,
                         "username" : username,
                         "real_name" : real_name,
                         "email" : email,
                         "address" : address,
                         "postcode" : postcode,
                         "city" : city,
                         "country" : country,
                         "distance" : distance })
    return json_response({ "status" : "OK",
                           "results" : results })                        
