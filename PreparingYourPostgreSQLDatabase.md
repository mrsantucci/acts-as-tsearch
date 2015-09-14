# PostgreSQL 8.3 and newer #

Add a text search configuration 'default':

```
CREATE TEXT SEARCH CONFIGURATION public.default ( COPY = pg_catalog.english )
```

See the PostgreSQL [manual](http://www.postgresql.org/docs/current/static/textsearch-configuration.html) for more information.

For portability issues and converting pre-8.3 installations see the [tsearch2](http://www.postgresql.org/docs/current/static/tsearch2.html) module documentation.


# TSearch installation for PostgreSQL 8.2 and older #

[TSearch](http://www.sai.msu.su/~megera/postgres/gist/tsearch/V2/) is an offical contribution module in [PostgreSQL](http://www.postgresql.org/) 7.4 to 8.2. Depending on how you installed Postgres you might to do some of these steps.

I recently added an experimental shell script to the root of the project called dbsetup.sh... you can give that a shot if you want - it might do this all for you:
```
cd ~/dev/tsearch [or where ever your rails app is]
chmod 755 dbsetup.sh
sudo ./dbsetup.sh your-db-name your-db-username
```

## Step 1: Does TSearch exist? ##

From terminal do:
```
locate tsearch2.sql
```

Which hopefully returns something like:
```
/usr/local/pgsql/share/contrib/tsearch2.sql
/usr/local/pgsql/share/contrib/untsearch2.sql
```

You can skip to Step 2 if it exists

## Step 1.1: Try rebuilding ##
Try rebuilding your code...
```
cd contrib/tsearch2
make
su
make install
```
Goto Step 1

If that didn't work...

## Step 1.2: Another thing to try ##
```
tar xzvf postgresql-version.tgz
cd postgresql-version
./configure
```
Goto Step 1.1

## Step 2: Setup your Database ##
So - you did a `locate tsearch2.sql` and something was found... we'll assume you're on a Mac and something was found at /usr/local/pgsql/share/contrib/

Run the sql script:
```
cd /usr/local/pgsql/share/contrib/
su root
su postgres
psql your_database_name < tsearch2.sql
```

Grant required permissions:
```
su root
su postgres
psql your_database_name

psql> grant all on public.pg_ts_cfg to db_username_from_database_yml;
psql> grant all on public.pg_ts_cfgmap to db_username_from_database_yml;
psql> grant all on public.pg_ts_dict to db_username_from_database_yml;
psql> grant all on public.pg_ts_parser to db_username_from_database_yml;
```

## Step 3: Quick confirmation test ##
Give it a quick test to make sure the basics are there:
```
psql your_database_name
your_data_base_name=# select to_tsvector('default','Our first string used today first string');
                to_tsvector                 
--------------------------------------------
 'use':4 'first':2,6 'today':5 'string':3,7
(1 row)
```