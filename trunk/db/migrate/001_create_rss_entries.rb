class CreateRssEntries < ActiveRecord::Migration
  def self.up
    create_table :rss_entries do |t|
      t.column "title",       :string
      t.column "summary",     :text
      t.column "link",        :string
      t.column "vectors",     :tsvector      
    end
  end

  def self.down
    drop_table :rss_entries
  end
end
