from django.db import connection
from django.http import HttpResponse
import json

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
