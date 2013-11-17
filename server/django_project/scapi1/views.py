from django.db import connection
from django.http import HttpResponse
from django.shortcuts import render
import json
import uuid

def docs(request):
    return render(request, "docs.html", { "test": "foox" })

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
