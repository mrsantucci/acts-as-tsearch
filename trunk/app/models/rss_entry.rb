class RssEntry < ActiveRecord::Base
  
  acts_as_tsearch :fields => ["title","summary"]
  
  def self.reload_rss
    RssEntry.delete_all
    feed = FeedTools::Feed.open("http://feeds.feedburner.com/RidingRails")
    feed.items.each do |f|
      RssEntry.new(:title => f.title, :summary => f.summary, :link => f.link).save
    end
  end
  
end
