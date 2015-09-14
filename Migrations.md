TSearch will create indexes for your table the first time you search but, that's not really practical if you have really large tables.

First - this is what a sample migration table def looks like:
```
    create_table :blog_entries do |t|
      t.column "title",       :string
      t.column "summary",     :text
      t.column "link",        :string
      t.column "vectors",     :tsvector      
    end
```

If you wanted to update the vectors (search indexes) you'd just do:
```
BlogEntry.create_vector  #doesn't hurt to try, even if it exists
BlogEntry.update_vector
```