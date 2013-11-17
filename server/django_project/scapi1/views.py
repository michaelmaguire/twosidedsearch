from django.db import connection
from django.http import HttpResponse
from django.shortcuts import render
import json
import uuid

def jsonify(object):
    return json.dumps(object, indent=4)

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
        return HttpResponse(jsonify({ "status" : "EMAIL_IN_USE" }),
                            content_type="application/json")

    # check if the email address is already known to us
    cursor.execute("""SELECT 1
                        FROM person
                       WHERE username = %s""",
                   (request.POST["username"],))
    if cursor.fetchone():
        return HttpResponse(jsonify({ "status" : "USERNAME_IN_USE" }),
                            content_type="application/json")
    
    # clear to proceed
    cursor.execute("""INSERT INTO person (username, firstname, lastname, email, status, password_hash, created, logins)
                      VALUES (%s, %s, %s, %s, 'ACTIVE', crypt(%s, gen_salt('bf')), now(), 0)""",
                   (request.POST["username"],
                    request.POST["firstname"],
                    request.POST["lastname"],
                    request.POST["email"],
                    request.POST["password"]))
    return HttpResponse(jsonify({ "status" : "OK" }),
                        content_type="application/json")

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
        response = { "status": "FAIL" }
    else:
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
            response = { "status" : "OK",
                         "firstname" : firstname,
                         "lastname" : lastname,
                         "email" : email,
                         "token" : token }
        else:
            response = { "status" : "FAIL" }
            # TODO handle this case
    return HttpResponse(json.dumps(response, indent=4), content_type="application/json")

def logout(request):
    cursor = connection.cursor()
    cursor.execute("""UPDATE login_session
                         SET ended = now()
                       WHERE token = %s
                         AND ended IS NULL""",
                   (request.POST["token"],))
    if cursor.rowcount == 1:
        response = { "status" : "OK" }
    else:
        response = { "status" : "FAIL" }
    return HttpResponse(json.dumps(response, indent=4), content_type="application/json")

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
    return HttpResponse(json.dumps(response, indent=4), content_type="application/json")

def find(request, day, skill):
    cursor = connection.cursor()
    cursor.execute(""" SELECT p.username,
                              p.firstname,
                              p.lastname,
                              p.email,
                              p.message
                         FROM person p
                         JOIN person_day pd ON p.id = pd.person
                         JOIN person_skill ps ON p.id = ps.person
                         JOIN skill s ON ps.skill = s.id
                        WHERE pd.availability = 'AVAILABLE'
                          AND pd.day = %s::DATE
                          and s.name = %s
                        ORDER BY p.firstname, p.lastname""",
                   (day, skill))
    response = {}
    response["status"] = "OK"
    response["data"] = [ { "username" : username,
                           "firstname" : firstname,
                           "lastname" : lastname,
                           "email" : email,
                           "message" : message }
                         for username, firstname, lastname, email, message in cursor.fetchall() ]
    cursor.close()
    return HttpResponse(json.dumps(response, indent=4), content_type="application/json")
