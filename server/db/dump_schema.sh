#!/bin/bash
DB="$1"
if [ "$DB" ==  "" ] ; then
  DB=speedy_hack
fi
pg_dump --schema-only --no-owner --no-privileges --no-tablespaces --schema=speedycrew -U speedycrew $DB > create.sql && \
pg_dump --data-only --column-inserts --table=speedycrew.schema_change -U speedycrew $DB >> create.sql
