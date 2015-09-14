# Introduction #

After you've [set-up your database](PreparingYourPostgreSQLDatabase.md) follow these quick steps to get up and running.

## Get the plugin ##

```
ruby script/plugin install git://github.com/pka/acts_as_tsearch.git
```

## Add acts\_as\_tsearch to a model ##

```
class BlogEntry < ActiveRecord::Base
   acts_as_tsearch :fields => ["title","description"]
end
```

## Do a search ##
```
blog_entries = BlogEntry.find_by_tsearch("bob")
puts blog_entries.tsearch_rank
puts blog_entries.size
puts blog_entries[0].title
...etc...
```

## Note extra column ##
Searches are default sorted by the added column tsearch\_rank.


# Sample Project #

A sample project to help you get started, especially if you're using PostgreSQL 8.2 or older. Just grab the whole project with a
```
mkdir tsearch
cd tsearch
svn export --force http://acts-as-tsearch.googlecode.com/svn/trunk/ .
```

and read the README.