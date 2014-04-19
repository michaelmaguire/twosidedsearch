Instructions on how to set up the Speedycrew server stack for
development, on a Debian or Ubuntu system.  

1.  Install packages.

    sudo apt-get install postgresql-9.3 postgresql-contrib-9.3 \
    python-django python-psycopg2 postgresql-9.3-postgis-2.1 \
    python-m2crypto

Note about postgresql-9.3: the package name changes for each Debian or
Ubuntu release (see how the version is included in the package name --
this is because you can run 9.2 and 9.3 in parallel, for example as
part of an upgrade strategy, and with the PostGIS extension you get
into combinations of versions... all because these things own binary
data on disks and the format changes).  If your distribution doesn't
have 9.3 you could use a different version like 9.1 or 9.2, or you
could add the Postgres project's apt repo to your system, see
http://wiki.postgresql.org/wiki/Apt

2.  Create a user and a database and enable spatial and crypto support.

    $ sudo su - postgres           # become the postgres superuser
    $ psql
    postgres# create user speedycrew;
    postgres# create database speedcrew_dev owner speedycrew encoding 'utf8';
    postgres# \c speedycrew_dev
    speedycrew_dev# create extension postgis;
    speedycrew_dev# create extension pgcrypto; 

If the 'create database' step gives you problems relating to character
encoding (because the encoding doesn't match the template database's
encoding, which depends on choices you made when you installed your
OS), then stick "template template0" on the end of the "create
database" statement, or leave out "encoding 'utf8'".

Alternatively, create a user with the same name as your Unix username,
and make it the owner of speedycrew_dev.  Then you won't have to
mention it on the "psql" command line as it will be the default.

3.  Configure PG to allow that user to connect from localhost.

    $ sudo vi /etc/postgresql/9.3/main/pg_hba.conf
    -> near the end somewhere add a line like this:
       local all speedycrew trust
    $ sudo /etc/init.d/postgresql reload

Note: that says that a user merely claiming to be speedycrew can
connect to ANY database without a password or SSL cert or identd
check, via Unix domain sockets only, which is possibly not how we set
up real systems but for a dev stack, who cares?

If you used your Unix account name in step 2, do it here too, instead
of speedycrew.

4.  Check that user speedycrew can connect to database speedycrew_dev.

    $ psql speedycrew_dev [speedycrew]

The square brackets are just to indicate that he username is optional,
defaulting to your Unix user.

5.  Create the "speedycrew" schema and insert test data.

   $ cd server/db
   $ psql speedycrew_dev [speedycrew] -f create.sql
   $ psql speedycrew_dev [speedycrew] -f test_data.sql

Or leave out "speedycrew" if you're using your own account name.

6.  Blow away the "speedycrew" schema (and everything in it) so you
    can recreate them as part of iterative development.

   $ psql speedycrew_dev [speedycrew] -f drop.sql

7.  Start up a Django testing web server.

   $ cd server/django_project
   $ python manage.py runserver 0.0.0.0:8000

Before doing that, you should edit speedycrew/settings.py and set NAME
to the database name "speedycrew_dev", and USER to "speedycrew" or
your Unix account name if you're using that.

8.  Point your web browser at http://hostname:8000/api/1/docs

Note: if you're running inside a virtual machine that has NAT routing
only, then it won't have a network interface visible from the host OS.
If the host OS is a Mac that you're physically logged into, then you
might solve that problem by creating an SSH tunnel from the host OS's
localhost network interface.  Something like this, from the guest
system (not tested):

    $ ssh -R8000:localhost:8000 host
