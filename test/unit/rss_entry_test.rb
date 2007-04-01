#This is just an example and a test that testing works when using acts_as_tsearch since there are custom rake jobs, etc.  The tests for tsearch are in the plugin itself and can be run via a "rake test:plugins"

require File.dirname(__FILE__) + '/../test_helper'

class RssEntryTest < Test::Unit::TestCase
  fixtures :rss_entries

  # Replace this with your real tests.
  
  #BUG
  #This currently fails because dropping the schema in rake:test also drops the functions - which requires you to run ./dbsetup.sh again
  #Needs to be fixed.
  def test_simple_find
    RssEntry.create_vector
    RssEntry.update_vector
    r = RssEntry.find_by_tsearch("title1")
    assert r.id == 1
  end
  
  # def test_fail
  #    assert false
  #  end
  
  def test_truth
    assert true, "true wasn't true ???? "
  end
end
