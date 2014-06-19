#!/usr/bin/python

import psycopg2
import sys
import time

# This is the garbage collection script for old events.  We only keep
# events for a limited time, to limit disk usage.

# To avoid creating deadlocks with other activity, we only consider
# one profile per transaction.  We avoid locking the profile_sequence
# record until just before we commit, so that we keep out of the way.

# We never delete the last event for a profile.

# TODO package, cron job, some advisory lock scheme to control how
# many copies of this run at a time

# TODO other cleanup operations we need to do: removing searches
# (using delete_search stored proc which replicates the deletion to
# all devices that might hold matches), and then finally deleting the
# actual search, but that must only be done after we are sure there
# are no events that reference it; how about profiles and devices,
# when (if ever) do we delete those?

MAX_AGE_DAYS = 7
NAP_TIME = 0

def run(connection):
    cursor = connection.cursor()
    cursor.execute("""SET application_name = 'maintain_event.py'""")
    connection.commit()
    cursor.execute("""SELECT profile
                        FROM speedycrew.profile_sequence
                       WHERE low_time < now() - INTERVAL '1 day' * %s
                         AND low_sequence != high_sequence""",
                   (MAX_AGE_DAYS,))
    for profile_id, in cursor.fetchall():
        if NAP_TIME != 0:
            time.sleep(NAP_TIME)
        cursor.execute("""DELETE FROM speedycrew.event
                           WHERE profile = %s
                             AND created < now() - INTERVAL '1 day' * %s""",
                       (profile_id, MAX_AGE_DAYS))
        cursor.execute("""UPDATE speedycrew.profile_sequence
                             SET (low_sequence, low_time) = (e.seq, e.created)
                            FROM (SELECT seq, created
                                    FROM speedycrew.event
                                   WHERE profile = %s
                                   ORDER BY seq
                                   LIMIT 1) AS e
                           WHERE profile = %s""",
                       (profile_id, profile_id))
        connection.commit()

if __name__ == "__main__":
    run(psycopg2.connect(sys.argv[1]))
