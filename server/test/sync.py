#!/usr/bin/python

import json
import os
import psycopg2
import unittest
import urllib
import urllib2
import sqlite3

# This is a fairly invasive test -- it reaches into the server
# database and blows it away and recreates it!

base_url = "http://localhost:8888"
client_db = "test_db.sqlite3"
server_drop_dml = "../db/drop.sql"
server_create_dml = "../db/create.sql"
server_init_sql = "../db/test_data.sql"
server_db = "dbname=speedy_hack user=speedycrew" # TODO find a better way to configure this?
x_id = "12345"

def read_all(path):
    with open(path) as f:
        return f.read()

def reset_server_db():
    """Blow away the server database and restore it to the state we
    use for testing."""
    db = psycopg2.connect(server_db)
    cursor = db.cursor()
    cursor.execute(read_all(server_drop_dml))
    cursor.execute(read_all(server_create_dml))
    cursor.execute(read_all(server_init_sql))

def make_fresh_db():
    """Blow away the client database if it already exists, then
    (re)create it with nothing but a 'control' table."""
    if os.path.isfile(client_db):
        os.unlink(client_db)
    db = sqlite3.connect(client_db)
    cursor = db.cursor()
    cursor.execute("create table control (timeline, sequence)")
    cursor.execute("insert into control (timeline, sequence) values (0, 0)")
    db.commit()
    return db

def device_timeline_and_sequence(db):
    cursor = db.cursor()
    cursor.execute("SELECT timeline, sequence FROM control")
    row = cursor.fetchone()
    if row:
        return row
    else:
        return (0, 0)

def post(url, request):
    try:
        text = urllib2.urlopen(base_url + url, urllib.urlencode(request)).read()
        return json.loads(text)
    except urllib2.HTTPError as e:
        print e.read()
        raise e

def synchronise(db):
    timeline, sequence = device_timeline_and_sequence(db)
    text = urllib2.urlopen(base_url + "/api/1/synchronise?x-id=" + x_id + ";timeline=" + str(timeline) + ";sequence=" + str(sequence)).read()
    object = json.loads(text)
    cursor = db.cursor()
    for statement in object["sql"]:
        cursor.execute(statement)
    return object["operation"]

class Simple(unittest.TestCase):
    def setUp(self):
        reset_server_db()
        self.local_db = make_fresh_db()
        self.cursor = self.local_db.cursor()
        
    def test_smoke(self):
        self.assertEqual("refresh", synchronise(self.local_db))
        self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 0))
        self.assertEqual("incremental", synchronise(self.local_db))
        self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 0))

    def test_update_profile(self):
        self.assertEqual("refresh", synchronise(self.local_db))
        self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 0))
        response = post("/api/1/update_profile",
                        { "x-id" : x_id,
                          "email" : "foo@bar.com",
                          "message" : "foo'bar" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 1))
        # TODO assert things about the changes!
        

    def test_post_search(self):
        # put a matchable query in first
        response = post("/api/1/create_search",
                        { "x-id" : "other-guy",
                          "id" : "00000000-0000-0000-0000-000000000000",
                          "query" : "test1 #tag1 #tag2",
                          "side" : "PROVIDE",
                          "longitude" : "0.01",
                          "latitude" : "50" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("refresh", synchronise(self.local_db))
        self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 0))


        # give that other guy some details so that we can assert that
        # they show up in the client match table
        response = post("/api/1/update_profile",
                        { "x-id" : "other-guy",
                          "username" : "Mr Other Guy",
                          "email" : "other@guy.com",
                          "message" : "foo'bar" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 0)) # no change for mr x_id

        response = post("/api/1/create_search",                        
                        { "x-id" : x_id,
                          "id" : "00000000-0000-0000-0000-000000000001",
                          "query" : "test2 #tag1 #tag2",
                          "side" : "SEEK",
                          "radius" : "10000",
                          "longitude" : "0",
                          "latitude" : "50" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 2))
        self.cursor.execute("""SELECT id, query, side, longitude, latitude FROM search""")
        self.assertEqual(("00000000-0000-0000-0000-000000000001", "test2 #tag1 #tag2", "SEEK", 0, 50), self.cursor.fetchone())
        self.cursor.execute("""SELECT search, other_search, query, email, username FROM match""")
        self.assertEqual(("00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000000", "test1 #tag1 #tag2", "other@guy.com", "Mr Other Guy"), self.cursor.fetchone())

        response = post("/api/1/delete_search",
                        { "x-id" : x_id,
                          "search" : "00000000-0000-0000-0000-000000000001" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 5))
        self.cursor.execute("""SELECT search, other_search, query, email, username FROM match""")
        self.assertEqual(None, self.cursor.fetchone())

        # TODO test delete in here too

if __name__ == "__main__":
    unittest.main()
