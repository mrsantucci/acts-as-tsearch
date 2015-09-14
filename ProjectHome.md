![http://farm1.static.flickr.com/141/399803031_cf39d33f39_o.png](http://farm1.static.flickr.com/141/399803031_cf39d33f39_o.png)

**Acts\_as\_tsearch** is a plugin for [Ruby on Rails](http://www.rubyonrails.org/) which makes it simple to implement scalable, full text search for Rails if you're using [PostgreSQL](http://www.postgresql.org/) as your database. It wraps the built-in full text search engine of PostgreSQL with a familiar 'acts\_as' implementation.

The primary author Ben Wiseley of [ActiveRain](http://activerain.com/) explains their motivation:
<i>
While scalability problems with <a href='http://projects.jkraemer.net/acts_as_ferret/wiki'>acts_as_ferret</a> (likely through our own ignorance) led us to develop this we'd love to thank <a href='http://projects.jkraemer.net/acts_as_ferret/wiki'>acts_as_ferret</a> for providing an excellent model on how to do as acts_as_search plugin for Rails and getting us very quickly through our first few months. Their search solution is definitely worth looking at and is much more robust.</i>

# Where to start? #

  1. [Prepare your PostgreSQL database](PreparingYourPostgreSQLDatabase.md)
  1. [Follow the quick start](QuickStart.md)
  1. [Read up advanced acts\_as\_tsearch declarations](ActsAsTsearchMethod.md)
  1. [multi-vector-searching](MultiVectorSearching.md)
  1. [Migrations](Migrations.md) how to migrate your search indexes
  1. [Testing](Testing.md) explains how to get unit tests working
  1. Stuck?  Ask questions on [acts\_as\_tsearch](http://groups.google.com/group/acts_as_tsearch)

# Sample #
```
class BlogEntry < ActiveRecord::Base
   acts_as_tsearch :fields => ['title','description']
end

BlogEntry.find_by_tsearch('who what where')
```