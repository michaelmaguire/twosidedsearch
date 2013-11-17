from django.db import connection
from django.http import HttpResponse
from django.shortcuts import render
import json
import uuid

def json_response(object):
    """A convenience function for generating a JSON HTTP response."""
    return HttpResponse(json.dumps(object, indent=4),
                        content_type="application/json")

def docs(request):
    return render(request, "docs.html", { "test": "foox" })

def create_account(request):
    cursor = connection.cursor()
    # TODO reject empty names etc
    # TODO check if the password is not good enough according to some policy
    # TODO likewise for the username

    # the following checks are 'polite' ways to discover emails and
    # username already in use and give a friendly error message:
    # obviously there is also a race here due to concurrency, and the
    # database will enforce uniqueness (the error will just be uglier
    # if we get there); in theory you'd just use the DB and detect
    # those errors specially, a job for another day
    
    # check if the email address is already known to us
    cursor.execute("""SELECT 1
                        FROM person
                       WHERE email = %s""",
                   (request.POST["email"],))
    if cursor.fetchone():
        return json_response({ "status" : "EMAIL_IN_USE" })

    # check if the email address is already known to us
    cursor.execute("""SELECT 1
                        FROM person
                       WHERE username = %s""",
                   (request.POST["username"],))
    if cursor.fetchone():
        return json_response({ "status" : "USERNAME_IN_USE" })
    
    # clear to proceed
    cursor.execute("""INSERT INTO person (username, firstname, lastname, email, status, password_hash, created, logins)
                      VALUES (%s, %s, %s, %s, 'ACTIVE', crypt(%s, gen_salt('bf')), now(), 0)""",
                   (request.POST["username"],
                    request.POST["firstname"],
                    request.POST["lastname"],
                    request.POST["email"],
                    request.POST["password"]))
    return json_response({ "status" : "OK" })

def login(request):
    cursor = connection.cursor()
    cursor.execute("""SELECT id, firstname, lastname, email, status
                        FROM person
                       WHERE username = %s
                         AND password_hash = crypt(%s, password_hash)""",
                  (request.POST["username"], request.POST["password"]))
    row = cursor.fetchone()
    if row == None:
        # TODO count failures, implement back-off
        return json_response({ "status": "FAIL" })
        
    id, firstname, lastname, email, status = row        
    if status == "ACTIVE":
        token = uuid.uuid4().hex
        cursor.execute("""INSERT INTO login_session (token, person, created)
                          VALUES (%s, %s, now())""",
                       (token, id))
        cursor.execute("""UPDATE person
                             SET last_login = now(),
                                 logins = logins + 1
                           WHERE id = %s""",
                       (id,))
        return json_response({ "status" : "OK",
                               "firstname" : firstname,
                               "lastname" : lastname,
                               "email" : email,
                               "token" : token })
    else:
        # TODO handle this case better (say 'you're banned'?)
        return json_response({ "status" : "FAIL" })

def logout(request):
    cursor = connection.cursor()
    cursor.execute("""UPDATE login_session
                         SET ended = now()
                       WHERE token = %s
                         AND ended IS NULL""",
                   (request.POST["token"],))
    if cursor.rowcount == 1:
        return json_response({ "status" : "OK" })
    else:
        return json_response({ "status" : "FAIL" })

def schedule(request, username):
    cursor = connection.cursor()
    cursor.execute("""SELECT pd.day, pd.availability, pd.note
                        FROM person p
                        JOIN person_day pd ON p.id = pd.person
                       WHERE p.username = %s
                       ORDER BY pd.day""",
                   (username,)) 
    response = {}
    response["status"] = "OK"
    response["username"] = username
    response["data"] = [ { "day" : day.isoformat(), 
                           "availability" : availability, 
                           "note" : note } 
                         for day, availability, note in cursor.fetchall() ]
    cursor.close()
    return json_response(response)

def find(request):
    # TODO require valid token, even though we do nothing with your
    # identity here
    cursor = connection.cursor()
    cursor.execute(""" SELECT p.username,
                              p.firstname,
                              p.lastname,
                              p.email,
                              p.message,
                              st_distance(l.geography,
                                          st_geographyfromtext('POINT(' || %s || ' ' || %s || ')'))
                         FROM person p
                         JOIN person_day pd ON p.id = pd.person
                         JOIN person_skill ps ON p.id = ps.person
                         JOIN skill s ON ps.skill = s.id
                         JOIN travel_area ta ON p.id = ta.person
                         JOIN location l ON ta.base = l.id           
                        WHERE pd.availability = 'AVAILABLE'
                          AND pd.day = %s::DATE
                          AND s.name = %s
                          AND st_dwithin(l.geography,
                                         st_geographyfromtext('POINT(' || %s || ' ' || %s || ')'),
                                         ta.max_distance)
                        ORDER BY p.firstname, p.lastname""",
                   (request.POST["longitude"],
                    request.POST["latitude"],
                    request.POST["day"],
                    request.POST["skill"],
                    request.POST["longitude"],
                    request.POST["latitude"]))
    return json_response({ "status" : "OK",
                           "data" : [ { "username" : username,
                                        "firstname" : firstname,
                                        "lastname" : lastname,
                                        "email" : email,
                                        "message" : message,
                                        "distance" : distance }
                                      for username, firstname, lastname, email, message, distance
                                      in cursor.fetchall() ] })
