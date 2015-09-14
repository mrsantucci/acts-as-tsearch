# Introduction #

By default acts\_as\_tsearch just creates a "vectors" column and performs all searches against that column.  Support multiple vector columns however.  This could be useful for creating searches that are security specific (for logged in, logged out scenarios).

# Single Vector #

By using this syntax you can override the default name of the vectors columns.

Examples:

These two declarations are identical - the last one just explicity states the default:
```
Profile.acts_as_tsearch :fields => [:name, :public_info]
Profile.acts_as_tsearch :vectors => {:fields => [:name, :public_info]}
```

To override the column name simply do:
```
Profile.acts_as_tsearch :my_vector_name => {:fields => [:name, :public_info]}
```

For all examples you still search like:
```
Profile.find_by_tsearch("who what where")
```

# Multiple Vectors #

When you add multiple vectors you need to start specifying which vector you're using.  A RuntimeError will be thrown if you fail to specify a vector on multiple vector tables unless the first vector happens to be named "vectors".

Examples.... let's say we have a **profiles** table and we want to be able to search on public data versus private data.

Table:
```
create_table :profiles do |t|
   t.column :name,   :string
   t.column :public_info,   :string
   t.column :private_info,   :string
end
```

acts\_as\_tsearch declaration:
```
Profile.acts_as_tsearch :public_vector => {:fields => [:name, :public_info]},
                        :private_vector => {:fields => [:name, :private_info]}
```

You then simply specify the vector when search:
```
    #Only search public fields
    p = Profile.find_by_tsearch("ben",nil,{:vector => "public_vector"})

    #Only search private fields
    p = Profile.find_by_tsearch("ben",nil,{:vector => "private_vector"})
```