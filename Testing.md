# Introduction #

Unit testing has some gotchas with tsearch - but they're not too bad.  The dbsetup.sh script will modify your postgres template1 database as well as tsearch'ify your current db.  It's a good idea to **backup** before running any of this.

# Details #

Before running your unit tests you need to make sure your test db is setup with tsearch.  This shell script is included in the source code but is still pretty beta (I've only tested this on my Mac).  You need to run it as root... and the general warnings around that apply. :)

You should do a "createdb [dbname](dbname.md)" if it doesn't exist yet.

The plugin has some unit tests you can try... you need to do a few things first:
```
createdb acts_as_tsearch_test
cd ~/dev/tsearch/vendor/plugins/acts_as_tsearch  #assumes app is ~/dev/tsearch
chmod 755 dbsetup.sh
sudo ./dbsetup.sh acts_as_tsearch_test acts_as_tsearch_test
rake
```

If anyone has ideas on how to simplify this I'd love to hear them!

# Running your unit tests #

You can also use dbsetup.sh on your test database.
```
cd ~/dev/tsearch/vendor/plugins/acts_as_tsearch  #assumes app is ~/dev/tsearch
chmod 755 dbsetup.sh
sudo ./dbsetup.sh yourapp_development yourusername
```

# Why is this necessary? #

The reason you need to do all this crap is that tsearch adds custom column types.  If you don't modify template1 (the master template in postgres) when you go to test your application rails will do it's drop/create on test, loose the tsearch columns and bail (without notice) part of the way through creating the new test db when it hits a tsearch column.  Craig Barber did up some custom rake stuff that tries to work around this but I was having a hell of a time getting working, so, I switched the code over to.  It's currently commented out if you want to give it a try.

# dbsetup.sh #

Here's the dbsetup.sh script that's in the root of the source code (in the sample application)

```
#
# See if tsearch2.sql exists on the system
#
sqlfile=$(locate /tsearch2.sql)
if [ -z "$sqlfile"]
then
	echo "tsearch2.sql was not found on this system - please see http://code.google.com/p/acts-as-tsearch/wiki/PreparingYourPostgreSQLDatabase for details."
	exit 
fi

#
# Check that they ran this as postgres
#
if [ "$LOGNAME" != "root" ]
then
	echo "This script needs to be run as user root"
	echo "Try "
	echo "    su root"
	echo "      or"
	echo "    sudo su root"
	exit 
fi

#
# Check required parameters
#
db=${1}
un=${2}
if [ -z "$1" "$2" ]
then
	echo "Usage: `basename $0 $1` db-name db-username"
	echo "Example: `basename $0 $1` tsearch wiseleyb"
	echo "     would setup database tsearch for database username wiseleyb"
	echo "Note: the username and database need to exist"
	exit $E_NOARGS
fi

echo "grant all on database $db to $un;
grant all on public.pg_ts_cfg to $un;
grant all on public.pg_ts_cfgmap to $un; 
grant all on public.pg_ts_dict to $un; 
grant all on public.pg_ts_parser to $un;" > tmp_db_setup_grant_file.sql

su postgres << EOF
#
# Load sql file
#
psql $db < $sqlfile

#
# Grant permissions
#
psql $db < tmp_db_setup_grant_file.sql

#
# Fix template1
#
psql template1 < $sqlfile

EOF
rm tmp_db_setup_grant_file.sql
```