#!/usr/bin/python

import psycopg2
import sys

def run(connection):
    cursor = connection.cursor()
    cursor.execute("""DELETE FROM speedycrew.tag_count""")
    cursor.execute("""INSERT INTO speedycrew.tag_count (tag, provide_counter, seek_counter, counter)
                      SELECT st.tag,
                             SUM(CASE s.side WHEN 'PROVIDE' THEN 1 ELSE 0 END),
                             SUM(CASE s.side WHEN 'SEEK' THEN 1 ELSE 0 END),
                             COUNT(*)
                        FROM speedycrew.search s
                        JOIN speedycrew.search_tag st ON s.id = st.search
                       WHERE created > now() - INTERVAL '7 days'
                       GROUP BY st.tag""")
    connection.commit()

if __name__ == "__main__":
    run(psycopg2.connect(sys.argv[1]))
