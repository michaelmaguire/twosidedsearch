#!/usr/bin/python

import os
import psycopg2
import unittest
import urllib2
import sqlite3

# This is a fairly invasive test -- it reaches into the server
# database and blows it away and recreates it!

base_url = "http://localhost:8888"
client_db = "test_db.sqlite3"
client_create_dml = "../../client/db/create.sql"
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
    """Blow away the client database if it already exists, then create
    it, then run the create statements to create the schema."""
    if os.path.isfile(client_db):
        os.unlink(client_db)
    db = sqlite3.connect(client_db)
    db.executescript(read_all(client_create_dml))
    return db

def device_timeline_and_sequence(db):
    cursor = db.cursor()
    cursor.execute("SELECT timeline, sequence FROM control")
    row = cursor.fetchone()
    if row:
        return row
    else:
        return (0, 0)

def fetch_sync_data(db):
    timeline, sequence = device_timeline_and_sequence(db)
    script = urllib2.urlopen(base_url + "/api/1/synchronise?x-id=" + x_id + ";timeline=" + str(timeline) + ";sequence=" + str(sequence)).read()
    print script
    db.executescript(script)

class Simple(unittest.TestCase):
    def setUp(self):
        reset_server_db()
        self.local_db = make_fresh_db()
        self.cursor = self.local_db.cursor()
        
    def test_smoke(self):
        fetch_sync_data(self.local_db)
        self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 0))
        fetch_sync_data(self.local_db)
        self.assertEqual(device_timeline_and_sequence(self.local_db), (1, 0))

    def test_post_search(self):
        pass

if __name__ == "__main__":
    unittest.main()
