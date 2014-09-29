#!/usr/bin/python

import json
import os
import psycopg2
import unittest
import urllib
import urllib2
import sqlite3
import time

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
        #self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 0))
        self.assertEqual("incremental", synchronise(self.local_db))
        #self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 0))

    def test_update_profile(self):
        self.assertEqual("refresh", synchronise(self.local_db))
        #self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 0))
        response = post("/api/1/update_profile",
                        { "x-id" : x_id,
                          "email" : "foo@bar.com",
                          "message" : "foo'bar" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        #self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 1))
        # TODO assert things about the changes!

    def test_create_crew(self):
        # create a crew
        response = post("/api/1/create_crew",
                        { "x-id" : x_id,
                          "crew_id" : "00000000-0000-0000-0000-000000000000",
                          "name" : "My chat room",
                          "fingerprints" : "a,b" })
        self.assertEqual(response["status"], "OK")

        # check it shows up when we replicate
        self.assertEqual("refresh", synchronise(self.local_db))
        #self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 2))
        self.cursor.execute("SELECT * FROM crew ORDER BY id")
        self.assertEqual(("00000000-0000-0000-0000-000000000000", "My chat room"), self.cursor.fetchone())
        self.assertEqual(None, self.cursor.fetchone())

        # create another one just to check it works also via incremental
        response = post("/api/1/create_crew",
                        { "x-id" : x_id,
                          "crew_id" : "00000000-0000-0000-0000-00000000000f",
                          "name" : "zoo",
                          "fingerprints" : "a,b" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        self.cursor.execute("SELECT * FROM crew ORDER BY id")
        self.assertEqual(("00000000-0000-0000-0000-000000000000", "My chat room"), self.cursor.fetchone())
        self.assertEqual(("00000000-0000-0000-0000-00000000000f", "zoo"), self.cursor.fetchone())
        self.assertEqual(None, self.cursor.fetchone())

        # invite someone else
        response = post("/api/1/invite_crew",
                        { "x-id" : x_id,
                          "crew_id" : "00000000-0000-0000-0000-000000000000",
                          "fingerprints" : "1111" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        self.cursor.execute("SELECT crew, fingerprint, status FROM crew_member WHERE crew = '00000000-0000-0000-0000-000000000000' ORDER BY crew, fingerprint")
        self.assertEqual(("00000000-0000-0000-0000-000000000000", "1111", "ACTIVE"), self.cursor.fetchone())
        self.assertEqual(("00000000-0000-0000-0000-000000000000", x_id, "ACTIVE"), self.cursor.fetchone())
        self.assertEqual(None, self.cursor.fetchone())

        # leave the crew
        response = post("/api/1/leave_crew",
                        { "x-id" : x_id,
                          "crew_id" : "00000000-0000-0000-0000-000000000000" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        self.cursor.execute("SELECT crew, fingerprint, status FROM crew_member WHERE crew = '00000000-0000-0000-0000-000000000000' ORDER BY crew, fingerprint")
        self.assertEqual(("00000000-0000-0000-0000-000000000000", "1111", "ACTIVE"), self.cursor.fetchone())
        self.assertEqual(("00000000-0000-0000-0000-000000000000", x_id, "LEFT"), self.cursor.fetchone())
        self.assertEqual(None, self.cursor.fetchone())

        # now that we're out, we can't invite people anymore...
        response = post("/api/1/invite_crew",
                        { "x-id" : x_id,
                          "crew_id" : "00000000-0000-0000-0000-000000000000",
                          "fingerprints" : "2222" })
        self.assertEqual(response["status"], "ERROR")

        # try to leave the crew again, but we can't
        response = post("/api/1/leave_crew",
                        { "x-id" : x_id,
                          "crew_id" : "00000000-0000-0000-0000-000000000000" })
        self.assertEqual(response["status"], "ERROR")

        # also can't leave crews that don't exist (sort of redundant
        # considering the above but it reaches a different code path)
        response = post("/api/1/leave_crew",
                        { "x-id" : x_id,
                          "crew_id" : "00000000-0000-0000-0000-000000000666" })
        self.assertEqual(response["status"], "ERROR")

        # that other guy is going to invite us back...
        response = post("/api/1/invite_crew",
                        { "x-id" : "1111",
                          "crew_id" : "00000000-0000-0000-0000-000000000000",
                          "fingerprints" : x_id })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        self.cursor.execute("SELECT crew, fingerprint, status FROM crew_member WHERE crew = '00000000-0000-0000-0000-000000000000' ORDER BY crew, fingerprint")
        self.assertEqual(("00000000-0000-0000-0000-000000000000", "1111", "ACTIVE"), self.cursor.fetchone())
        self.assertEqual(("00000000-0000-0000-0000-000000000000", x_id, "ACTIVE"), self.cursor.fetchone())
        self.assertEqual(None, self.cursor.fetchone())

        # now that we're back in, we can invite people again...
        response = post("/api/1/invite_crew",
                        { "x-id" : x_id,
                          "crew_id" : "00000000-0000-0000-0000-000000000000",
                          "fingerprints" : "2222" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        self.cursor.execute("SELECT crew, fingerprint, status FROM crew_member WHERE crew = '00000000-0000-0000-0000-000000000000' ORDER BY crew, fingerprint")
        self.assertEqual(("00000000-0000-0000-0000-000000000000", "1111", "ACTIVE"), self.cursor.fetchone())
        self.assertEqual(("00000000-0000-0000-0000-000000000000", x_id, "ACTIVE"), self.cursor.fetchone())
        self.assertEqual(("00000000-0000-0000-0000-000000000000", "2222", "ACTIVE"), self.cursor.fetchone())
        self.assertEqual(None, self.cursor.fetchone())

        # that other guy is going to invite us to another crew...
        response = post("/api/1/create_crew",
                        { "x-id" : "1111",
                          "crew_id" : "00000000-0000-0000-0000-000000000042",
                          "name" : "My other chat room",
                          "fingerprints" : "" })
        self.assertEqual(response["status"], "OK")
        response = post("/api/1/invite_crew",
                        { "x-id" : "1111",
                          "crew_id" : "00000000-0000-0000-0000-000000000042",
                          "fingerprints" : x_id })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        self.cursor.execute("SELECT crew, fingerprint, status FROM crew_member ORDER BY crew, fingerprint")
        self.assertEqual(("00000000-0000-0000-0000-000000000000", "1111", "ACTIVE"), self.cursor.fetchone())
        self.assertEqual(("00000000-0000-0000-0000-000000000000", x_id, "ACTIVE"), self.cursor.fetchone())
        self.assertEqual(("00000000-0000-0000-0000-000000000000", "2222", "ACTIVE"), self.cursor.fetchone())
        self.assertEqual(("00000000-0000-0000-0000-00000000000f", x_id, "ACTIVE"), self.cursor.fetchone())
        self.assertEqual(("00000000-0000-0000-0000-000000000042", "1111", "ACTIVE"), self.cursor.fetchone())
        self.assertEqual(("00000000-0000-0000-0000-000000000042", x_id, "ACTIVE"), self.cursor.fetchone())
        self.assertEqual(None, self.cursor.fetchone())

    def test_rename_crew(self):
        # create a crew
        response = post("/api/1/create_crew",
                        { "x-id" : x_id,
                          "crew_id" : "00000000-0000-0000-0000-000000000000",
                          "name" : "My chat room",
                          "fingerprints" : "a,b" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("refresh", synchronise(self.local_db))
        self.cursor.execute("SELECT id, name FROM crew")
        self.assertEqual(("00000000-0000-0000-0000-000000000000", "My chat room"), self.cursor.fetchone())
        self.assertEqual(None, self.cursor.fetchone())
        # rename it
        response = post("/api/1/rename_crew",
                        { "x-id" : x_id,
                          "crew_id" : "00000000-0000-0000-0000-000000000000",
                          "name" : "Blah" })        
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        self.cursor.execute("SELECT id, name FROM crew")
        self.assertEqual(("00000000-0000-0000-0000-000000000000", "Blah"), self.cursor.fetchone())
        self.assertEqual(None, self.cursor.fetchone())
        # unknown crew -> fail
        response = post("/api/1/rename_crew",
                        { "x-id" : x_id,
                          "crew_id" : "00000000-0000-0000-5555-000000000000",
                          "name" : "Blah" })        
        self.assertEqual(response["status"], "ERROR")
        # known crew, but not a member -> fail
        response = post("/api/1/rename_crew",
                        { "x-id" : "999",
                          "crew_id" : "00000000-0000-0000-0000-000000000000",
                          "name" : "Blah" })        
        self.assertEqual(response["status"], "ERROR")

    def test_send_message(self):
        # create a crew
        response = post("/api/1/create_crew",
                        { "x-id" : x_id,
                          "crew_id" : "00000000-0000-0000-0000-000000000000",
                          "name" : "My chat room",
                          "fingerprints" : "1111,2222" })
        self.assertEqual(response["status"], "OK")
        # that 1111 guy sends me a message
        response = post("/api/1/send_message",
                        { "x-id" : "1111",
                          "crew_id" : "00000000-0000-0000-0000-000000000000",
                          "message_id" : "00000000-0000-0000-0000-000000000009",
                          "body" : "This is the body of a message" })
        self.assertEqual(response["status"], "OK")
        # I receive it, via refresh...
        self.assertEqual("refresh", synchronise(self.local_db))
        self.cursor.execute("SELECT id, sender, crew, body FROM message ORDER BY id")
        self.assertEqual(("00000000-0000-0000-0000-000000000009", "1111", "00000000-0000-0000-0000-000000000000", "This is the body of a message"), self.cursor.fetchone())
        self.assertEqual(None, self.cursor.fetchone())
        # one from 2222 so we can test incremental sync...
        response = post("/api/1/send_message",
                        { "x-id" : "2222",
                          "crew_id" : "00000000-0000-0000-0000-000000000000",
                          "message_id" : "00000000-0000-0000-0000-00000000000a",
                          "body" : "Foo bar" })
        self.assertEqual(response["status"], "OK")
        # I receive it, via incremental...
        self.assertEqual("incremental", synchronise(self.local_db))
        self.cursor.execute("SELECT id, sender, crew, body FROM message ORDER BY id")
        self.assertEqual(("00000000-0000-0000-0000-000000000009", "1111", "00000000-0000-0000-0000-000000000000", "This is the body of a message"), self.cursor.fetchone())
        self.assertEqual(("00000000-0000-0000-0000-00000000000a", "2222", "00000000-0000-0000-0000-000000000000", "Foo bar"), self.cursor.fetchone())
        self.assertEqual(None, self.cursor.fetchone())
        # mr 3333 sends a message to me with just a fingerprint, no crew
        self.cursor.execute("SELECT COUNT(*) FROM crew")
        self.assertEqual(1, self.cursor.fetchone()[0])
        self.cursor.execute("SELECT id FROM crew")
        crew_id = self.cursor.fetchone()[0]
        response = post("/api/1/send_message",
                        { "x-id" : "3333",
                          "fingerprint" : x_id,
                          "message_id" : "00000000-0000-0000-0000-00000000000b",
                          "body" : "Foo bar foo" })
        self.assertEqual(response["status"], "OK")
        # a new crew has been created with me and 3333 in it
        self.assertEqual("incremental", synchronise(self.local_db))
        self.cursor.execute("SELECT COUNT(*) FROM crew")
        self.assertEqual(2, self.cursor.fetchone()[0])
        self.cursor.execute("SELECT id FROM crew WHERE id != ?", (crew_id,))
        new_crew_id = self.cursor.fetchone()[0]
        # both x_id and 3333 are in it
        self.cursor.execute("SELECT COUNT(*) FROM crew_member WHERE crew = ? AND fingerprint IN (?, ?)", (new_crew_id, x_id, 3333))
        self.assertEqual(2, self.cursor.fetchone()[0])
        # I received a message
        self.cursor.execute("SELECT id, sender, crew, body FROM message WHERE id = '00000000-0000-0000-0000-00000000000b'")
        self.assertEqual(("00000000-0000-0000-0000-00000000000b", "3333", new_crew_id, "Foo bar foo"), self.cursor.fetchone())
        # mr 3333 sends another message to me with just a fingerprint, no crew
        response = post("/api/1/send_message",
                        { "x-id" : "3333",
                          "fingerprint" : x_id,
                          "message_id" : "00000000-0000-0000-0000-00000000000c",
                          "body" : "Foo bar foo2" })
        self.assertEqual(response["status"], "OK")
        # I received a message in the same crew as before, a new one wasn't created
        self.assertEqual("incremental", synchronise(self.local_db))
        self.cursor.execute("SELECT id, sender, crew, body FROM message WHERE id = '00000000-0000-0000-0000-00000000000c'")
        self.assertEqual(("00000000-0000-0000-0000-00000000000c", "3333", new_crew_id, "Foo bar foo2"), self.cursor.fetchone())

    def test_post_search(self):
        # put a matchable query in first
        response = post("/api/1/create_search",
                        { "x-id" : "other-guy",
                          "search_id" : "00000000-0000-0000-0000-000000000000",
                          "query" : "test1 #tag1 #tag2",
                          "side" : "PROVIDE",
                          "longitude" : "0.01",
                          "latitude" : "50" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("refresh", synchronise(self.local_db))
        #self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 0))


        # give that other guy some details so that we can assert that
        # they show up in the client match table
        response = post("/api/1/update_profile",
                        { "x-id" : "other-guy",
                          "username" : "Mr Other Guy",
                          "email" : "other@guy.com",
                          "message" : "foo'bar" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        #self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 0)) # no change for mr x_id

        response = post("/api/1/create_search",                        
                        { "x-id" : x_id,
                          "search_id" : "00000000-0000-0000-0000-000000000001",
                          "query" : "test2 #tag1 #tag2",
                          "side" : "SEEK",
                          "radius" : "10000",
                          "longitude" : "0",
                          "latitude" : "50" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        #self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 2))
        self.cursor.execute("""SELECT id, query, side, longitude, latitude FROM search""")
        self.assertEqual(("00000000-0000-0000-0000-000000000001", "test2 #tag1 #tag2", "SEEK", 0, 50), self.cursor.fetchone())
        self.cursor.execute("""SELECT search, other_search, query, email, username FROM match""")
        self.assertEqual(("00000000-0000-0000-0000-000000000001", "00000000-0000-0000-0000-000000000000", "test1 #tag1 #tag2", "other@guy.com", "Mr Other Guy"), self.cursor.fetchone())
        # we should have other-guy's profile
        self.cursor.execute("""SELECT 1 FROM profile WHERE fingerprint = 'other-guy'""")
        self.assertEqual((1,), self.cursor.fetchone())

        response = post("/api/1/delete_search",
                        { "x-id" : x_id,
                          "search_id" : "00000000-0000-0000-0000-000000000001" })
        self.assertEqual(response["status"], "OK")
        self.assertEqual("incremental", synchronise(self.local_db))
        #self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 5))
        self.cursor.execute("""SELECT search, other_search, query, email, username FROM match""")
        self.assertEqual(None, self.cursor.fetchone())
        self.cursor.execute("""SELECT 1 FROM search""")
        self.assertEqual(None, self.cursor.fetchone())
        # we should no longer have other-guy's profile
        self.cursor.execute("""SELECT 1 FROM profile WHERE fingerprint = 'other-guy'""")
        self.assertEqual(None, self.cursor.fetchone())

        # TODO test delete in here too

if __name__ == "__main__":
    unittest.main()
