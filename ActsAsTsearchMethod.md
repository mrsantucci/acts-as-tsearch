# Introduction #

This covers the basics of acts\_as\_tsearch declaration and **not** the `find_by_tsearch` method - which has a lot to it.

Also see:
  1. [multi-vector-searching](MultiVectorSearching.md)
  1. [migrations](Migrations.md)

# Ground Rules #
  1. acts\_as\_tsearch will create a new column **vectors** in your table if it doesn't exist and update it with the indexed values.  This column name can be overridden and there can be more than one of these vector columns.  We discuss this in [Multi Vector Searching](MultiVectorSearching.md) and [Migrations](Migrations.md)
  1. acts\_as\_tsearch adds a tsearch\_rank column to all results and default sorts (descending) on that column.
  1. By default acts\_as\_tsearch will update the vector unless told not to (see Method Definition below)

# Simple #

This would search the description field of the blog\_entries table:

```
class BlogEntry < ActiveRecord::Base
   acts_as_tsearch :fields => "description"
end

results = BlogEntry.find_by_tsearch("who what where")
```

# Multiple fields #

This would search multiple fields in blog\_entries table:
```
class BlogEntry < ActiveRecord::Base
   acts_as_tsearch :fields => ["title","description"]
end

results = BlogEntry.find_by_tsearch("who what where")
```

# Weighted search #
_This is still experimental.  Up to 4 weights are supported, weight's are currently ignored and hard coded to the values in the example below._

This will search for fields in the users table, placing more importance on "a", then "b" and so on.  Only four weights are support and only one is required.

```
class User < ActiveRecord::Base
   acts_as_tsearch :fields => {
      "a" => {:columns => [:first_name, :last_name, :company_name], :weight => 1.0},
      "b" => {:columns => [:short_description], :weight => 0.4},
      "c" => {:columns => [:state_name, :county_name, :city_name], :weight => 0.2},
      "d" => {:columns => [:about_me], :weight => 0.1}
      }
end

results = User.find_by_tsearch("who what where")
```

# Multi Table Searches #
_This is very experimental.  I would love help on this from more experienced Rails programmers on how to clean it up_

Say you wanted to search blog\_entries and their comments...

```
BlogEntry.acts_as_tsearch :vectors => {
   :fields => {
      "a" => {:columns => ["blog_entries.title"], :weight => 1},
      "b" => {:columns => ["blog_comments.comment"], :weight => 0.5}
      },
   :tables => {
      :blog_comments => {
         :from => "blog_entries b2 
                   left outer join blog_comments on 
                   blog_comments.blog_entry_id = b2.id",
         :where => "b2.id = blog_entries.id"
      }
    }
}

results = BlogEntry.find_by_tsearch("who what where")
```

As you can see this is pretty hackish.  It's only been lightly tested with two tables so far, still a work in progress.

# Complete Method Definition #
_To Do: needs work_
Fully verbose call example
```
Model.acts_as_tsearch :vectors => {
   :locale => "default",
   :auto_update_index => true,
   :fields => {
      "a" => {:columns => ["blog_entries.title"], :weight => 1},
      "b" => {:columns => ["blog_entries.description"], :weight => 0.4},
      "c" => {:columns => ["blog_entries.name"], :weight => 0.2},
      "d" => {:columns => ["blog_comments.comment"], :weight => 0.1}
   },
   :tables => {
      :blog_comments => {
         :from => "blog_entries b2 left outer join 
                   blog_comments on blog_comments.blog_entry_id = b2.id",
         :where => "b2.id = blog_entries.id"
      }
   },
   :another_vector => {... same format as above ...}
```