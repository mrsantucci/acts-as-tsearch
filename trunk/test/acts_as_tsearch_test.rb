#########################################
# To run this you first need to create a database and set it up for tsearch.
# 
# Tsearch comes with Postgres now.  From terminal try a "locate tsearch2.sql".  If nothing is found then you need
# recompile postgres.  More information on that coming.
# 
# If you found tsearch2.sql then you just need to do this:
# >> su postgres  (or su root, then su postgres - if you don't know the postgres password)
# >> psql acts_as_tsearch_test < tsearch2.sql
# >> psql acts_as_tsearch_test
# 	grant all on public.pg_ts_cfg to acts_as_tsearch_test;
# 	grant all on public.pg_ts_cfgmap to acts_as_tsearch_test;
# 	grant all on public.pg_ts_dict to acts_as_tsearch_test;
# 	grant all on public.pg_ts_parser to acts_as_tsearch_test;
#
#########################################
require File.dirname(__FILE__) + '/test_helper'

class ActsAsTsearchTest < Test::Unit::TestCase

  fixtures :blog_entries
  
  # Is your db setup properly for tests?
  def test_is_db_working
    create_fixtures(:blog_entries)
    assert BlogEntry.count > 0
  end
  
  # Do the most basic search
  def test_simple_search
    BlogEntry.acts_as_tsearch :fields => "title"
    BlogEntry.update_vectors
    b = BlogEntry.find_by_tsearch("bob")[0]
    assert b.id == 1, b.to_yaml
  end
  
  # Do a simple multi-field search
  def test_simple_search_two_fields
    BlogEntry.acts_as_tsearch :fields => [:title, :description]
    BlogEntry.update_vectors
    b = BlogEntry.find_by_tsearch("bob")[0]
    assert b.id == 1, b.to_yaml
    b = BlogEntry.find_by_tsearch("dined")[0]
    assert b.id == 1, b.to_yaml
    assert BlogEntry.find_by_tsearch("shared").size == 2
    b = BlogEntry.find_by_tsearch("zippy")[0]
    assert b.id == 2, b.to_yaml
  end

  # Test the auto-update functionality
  def test_add_row_and_search
    BlogEntry.acts_as_tsearch :fields => [:title, :description]
    BlogEntry.update_vectors
    b = BlogEntry.new
    b.title = "qqq"
    b.description = "xxxyyy"
    b.save
    id = b.id
    b = BlogEntry.find_by_tsearch("qqq")[0]
    assert id == b.id
    b = BlogEntry.find_by_tsearch("xxxyyy")[0]
    assert id == b.id
  end

  def test_add_row_and_search_flag_off
    BlogEntry.acts_as_tsearch :vectors => {
      :auto_update_index => false,
      :fields => [:title, :description]
    }
    BlogEntry.update_vectors
    b = BlogEntry.new
    b.title = "uuii"
    b.description = "ppkkjj"
    b.save
    id = b.id
    assert BlogEntry.find_by_tsearch("uuii").size == 0
    assert BlogEntry.find_by_tsearch("ppkkjj").size == 0

    #update vector
    BlogEntry.update_vector(id)
    #should be able to find it now
    assert BlogEntry.find_by_tsearch("uuii")[0].id == id
    assert BlogEntry.find_by_tsearch("ppkkjj")[0].id == id
    
  end
    
  # Test for error message if user typos field names
  def test_failure_for_bad_fields
    assert_raise ArgumentError do
      BlogEntry.acts_as_tsearch :fields => "ztitle"
    end

    assert_raise ArgumentError do
      BlogEntry.acts_as_tsearch :fields => [:ztitle, :zdescription]
    end
    
    assert_raise ArgumentError do
      BlogEntry.acts_as_tsearch :vectors => {
        :auto_update_index => false,
        :fields => {          
          "a" => {:columns => [:title]},
          "b" => {:columns => [:zdescription]}
          }
        }
    end
    
  end
  
  
end
