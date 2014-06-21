#!/usr/bin/python

import datetime
import psycopg2
import re
import sys
import time

# This is the garbage collection script for keeping the event history
# limited to a time window, and deleting abandoned user data.  Clean
# up has to be done in a carefully controlled order, because of:
#
# * foreign key dependencies between objects
# * the need to be able to replicate the deletions to devices
# * the need to avoid deadlocks when locking certain objects
#
# To avoid creating deadlocks with other activity, we usually only
# consider one profile per transaction: that way we avoid locking the
# profile_sequence record until just before we commit, so that we
# minimise the contention we create on those rows, because they are
# points of serialisation for all sessions that write data.  (This
# complexity does make garbage collection into a major effort for our
# system though, and we may finish up needing to do some more
# industrial scale garbage collection to keep up with a busy system if
# we get a lot of users.)
#
# Life cycle of events:
# 
# * Events are kept max_event_age days (devices that have missed
#   events need to resynchronise)
#
# Life cycle of searches:
#
# * Searches begin as ACTIVE
#
# * Searches whose owners have not been seen (ie any contact from any
#   devices) for max_search_age_inactive_profile are deleted with the
#   'delete_search' stored procedure, which sets their status to
#   DELETED, and deletes their matches, generating delete events which
#   will remove those matches from all devices; note that merely
#   having the app installed and receiving tickles which cause it to
#   synchronise would keep your searches alive, since synchronisation
#   updates our 'last seen' flag; if that is not what we want then we
#   may need to distinguish between 'last seen' (active use) and 'last
#   synchronised'
#
# * Searches which are explicitly deleted by users have their
# * associated matches physically deleted, and the search record is
# * updated to DELETED status
#
# * Searches in DELETED status are finally physically deleted after...
#   no event references them.  Which sucks, I should find a cheaper
#   way (like: wait until last modified time (which we don't have
#   yet...) is older than the max event age, so that there should be
#   no event that references them assuming no other events are
#   possible after search is in DELETED status).  TODO
#
# Life cycle of profiles and devices:
#
# * for now they live forever -- but in theory we could delete them
#   when Google or Apple tell us the app was uninstalled, or after a
#   large period of inactivity
#
# Life cycle of messages:
#
# * TODO

# TODO package, cron job, some advisory lock scheme to control how
# many copies of this run at a time

def get_interval(cursor, name):
    """Get an interval value from the system_setting table."""
    cursor.execute("""SELECT interval_value
                        FROM speedycrew.system_setting
                       WHERE name = %s""",
                   (name,))
    row = cursor.fetchone()
    if row:
        if row[0] is not None:
            return row[0]
        else:
            raise Exception("Expected system setting %s to have a non-NULL interval_value" % name)
    else:
        raise Exception("Expected there to be a system setting called %s" % name)

def most_recent_midnight():
    return datetime.date.today().isoformat() + " 00:00:00Z"

def collect_old_events(connection, reference_time, max_event_age, nap_time):
    cursor = connection.cursor()
    cursor.execute("""SELECT profile
                        FROM speedycrew.profile_sequence
                       WHERE low_time < %s::timestamptz - %s::interval""",
                   (reference_time, max_event_age))
    # TODO arbitrarily large result set pulled into RAM
    for profile_id, in cursor.fetchall():
        time.sleep(nap_time.total_seconds())
        cursor.execute("""DELETE FROM speedycrew.event
                           WHERE profile = %s
                             AND seq <= (SELECT seq
                                           FROM speedycrew.event
                                          WHERE profile = %s
                                            AND created < %s::timestamptz - %s::interval
                                          ORDER BY seq DESC
                                          LIMIT 1)""",
                       (profile_id, profile_id, reference_time, max_event_age))
        # lock the profile_sequence row briefly, to prevent new events
        # from being inserted while we decide what the new
        # low_sequence and low_time should be (this prevents the
        # following unlikely race, in READ COMMITTED isolation: we
        # deleted some events above, and then below we check what the
        # new lowest sequence and time are, and find none: then we
        # write NULLs in those fields after that, but between those
        # last two steps, another session inserted one or more events,
        # and set a new low_sequence and low_time, which we would
        # overwrite with NULL); I thought of some cleverer ways to do
        # this without the lock but I'm don't have the time to
        # prove/test that they work so going for this blunt solution
        cursor.execute("""SELECT 1
                            FROM speedycrew.profile_sequence
                           WHERE profile = %s
                             FOR UPDATE""",
                       (profile_id,))
        # find the new lower bounds for the event history we hold
        # (should be able to fold the following two statements into
        # one SQL statement, but I lack the skillz this morning); this
        # should be a super fast index scan that pulls only one row
        cursor.execute("""SELECT seq, created
                            FROM speedycrew.event
                           WHERE profile = %s
                           ORDER BY seq
                           LIMIT 1""",
                       (profile_id,))
        row = cursor.fetchone()
        if row:
            low_sequence, low_time = row
        else:
            low_sequence, low_time = None, None        
        cursor.execute("""UPDATE speedycrew.profile_sequence
                             SET (low_sequence, low_time) = (%s, %s)
                           WHERE profile = %s""",
                       (low_sequence, low_time, profile_id))
        connection.commit()

def delete_inactive_searches(connection, max_search_age_inactive_profile, nap_time):
    cursor = connection.cursor()
    cursor.execute("""SELECT s.id, MAX(d.last_seen)
                        FROM speedycrew.search s
                        JOIN speedycrew.device d ON s.owner = d.profile
                       WHERE s.status = 'ACTIVE'
                       GROUP BY s.id
                      HAVING MAX(d.last_seen) < CURRENT_TIMESTAMP - %s::interval""",
                   (max_search_age_inactive_profile,))
    for search_id, last_seen in cursor:
        time.sleep(nap_time.total_seconds())
        cursor.execute("SELECT speedycrew.delete_search(%s)",
                       (search_id,))
        connection.commit()

def collect_deleted_searches(connection):
    # this could be quite a slow query; but it shouldn't hold any
    # locks on anything that any other session could be interested in,
    # because it works only on DELETED searches
    cursor = connection.cursor()
    cursor.execute("""DELETE FROM speedycrew.search
                       WHERE status = 'DELETED'
                         AND NOT EXISTS (SELECT *
                                           FROM speedycrew.event e
                                          WHERE search.id = e.search
                                             OR search.id = e.match)""")
    connection.commit()

def run(connection):
    cursor = connection.cursor()
    cursor.execute("""SET application_name = 'garbage_collector.py'""")
    connection.commit()

    max_event_age = get_interval(cursor, "garbage_collection.max_event_age")
    max_deleted_search_age = get_interval(cursor, "garbage_collection.max_deleted_search_age")
    max_search_age_inactive_profile = get_interval(cursor, "garbage_collection.max_search_age_inactive_profile")
    nap_time = get_interval(cursor, "garbage_collection.nap_time")

    reference_time = most_recent_midnight()

    collect_old_events(connection, reference_time, max_event_age, nap_time)
    delete_inactive_searches(connection, max_search_age_inactive_profile, nap_time)
    collect_deleted_searches(connection)

if __name__ == "__main__":
    config_path = sys.argv[1]
    config = {}
    execfile(config_path, config)
    dsn = config["POSTGRES_DSN"]
    run(psycopg2.connect(dsn))
