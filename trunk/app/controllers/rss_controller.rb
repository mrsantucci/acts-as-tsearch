class RssController < ApplicationController
  
  #sudo gem install feed_tools
  require 'feed_tools'
  
  def index
    RssEntry.reload_rss if RssEntry.find(:first).nil?
  end

  def search
    if !params[:search].blank?
      @search = params[:search] 
      if @search.size > 2
        @results = RssEntry.find_by_tsearch(@search)
      end
    end
    render :partial => "results"
  end
  
  def all
    @results = RssEntry.find(:all)
  end

  def reload
    RssEntry.reload_rss
  end
  
end
