require 'active_record'

module TsearchMixin
  module Acts #:nodoc:
    module Tsearch #:nodoc:

      def self.included(mod)
        mod.extend(ClassMethods)
      end

      # declare the class level helper methods which
      # will load the relevant instance methods
      # defined below when invoked
      module ClassMethods
        def acts_as_tsearch(options = {})
          @tsearch_config = {:tsearch_locale => "default"}
          @tsearch_config.update(options) if options.is_a?(Hash)
          
          class_eval do
            after_save :update_vector_row

            extend TsearchMixin::Acts::Tsearch::SingletonMethods
          end
          include TsearchMixin::Acts::Tsearch::InstanceMethods

        end
      end

      # Adds a catch_chickens class method which finds
      # all records which have a 'chickens' field set
      # to true.
      module SingletonMethods

        #Finds a tsearch2 formated query in the tables vector column and adds
        #tsearch_rank to the results
        #
        #Inputs:
        #   search_string:  just about anything.  If you want to run a tsearch styled query 
        #                   (see http://mira.sai.msu.su/~megera/pgsql/ftsdoc/fts-query.html for 
        #                   details on this) just set fix_query = false.  
        #
        #   options: standard ActiveRecord find options - see http://api.rubyonrails.com/classes/ActiveRecord/Base.html#M000989
        #
        #   headlines:  TSearch2 can generate snippets of text with words found highlighted.  Put in the column names 
        #               of any of the columns in your vector and they'll come back as "{column_name}_headline"
        #               These are pretty expensive to generate - so only use them if you need them.
        #               example:  pass this [%w{title description}]
        #                         get back this result.title_headline, result.description_headline
        #
        #   fix_query:  the default will automatically try to fix your query with the fix_tsearch_query function
        #
        #   tsearch_locale:  TODO:  Document this... see
        #                  http://www.sai.msu.su/~megera/postgres/gist/tsearch/V2/docs/tsearch-V2-intro.html for details
        #
        #TODO:  Not sure how to handle order... current we add to it if it exists but this might not
        #be the right thing to do
        def find_by_tsearch(
            search_string, 
            options = {}, 
            headlines = [], 
            tsearch_locale = @tsearch_config[:tsearch_locale], 
            fix_query = true)
          
          check_for_vector_column
          
          search_string = fix_tsearch_query(search_string) if fix_query
          
          #add tsearch_rank to fields returned
          select_part = "rank_cd(#{table_name}.vectors,tsearch_query) as tsearch_rank"
          if options[:select]
            options[:select] << ", #{select_part}"
          else
            options[:select] = "#{table_name}.*, #{select_part}"
          end
          
          #add headlines
          headlines.each do |h|
            options[:select] << ", headline('#{tsearch_locale}',#{table_name}.#{h},tsearch_query) as #{h}_headline"
          end
          
          #add tsearch_query to from
          from_part = "to_tsquery('default','#{search_string}') as tsearch_query"
          if options[:from]
            options[:from] << ", #{from_part}"
          else
            options[:from] = "#{table_name}, #{from_part}"
          end

          #add vector condition
          where_part = "#{table_name}.vectors @@ tsearch_query"
          if options[:conditions]
            options[:conditions] << " and #{where_part}"
          else
            options[:conditions] = where_part
          end

          #add order by rank (not sure if we should add to order if it exists)
          order_part = "rank_cd(#{table_name}.vectors, tsearch_query)"
          if options[:order]
            options[:order] << ", #{order_part}"
          else
            options[:order] = order_part
          end
          
          #add a limit if missing
          options[:limit] = 100 if !options[:limit]

          #finally - return results
          find(:all, options)
          # find(:all,
          #   :select => "#{table_name}.*, rank_cd(blogger_groups.vectors, query) as rank",
          #   :from => "#{table_name}, to_tsquery('default','#{search_string}') as query",
          #   :conditions => "#{table_name}.vectors @@ query",
          #   :order => "rank_cd(#{table_name}.vectors, query)",
          #   :limit => 100)
        end
        
        #Very crude attempt at creating a tsearch query compliant search phrase from a "google" type search string
        def fix_tsearch_query(search_string)
          q = search_string

          #strip ( ) if they don't match and/or aren't nested properly
          ["()"].each do |s|
            p = 0
            0.upto(q.size-1) do |i|
              p += 1 if q[i] == s[0]
              p -= 1 if q[i] == s[1]
              break if p < 0
            end
            if p != 0
              q = q.strip.gsub(s[0]," ").gsub(s[1]," ")
            end
          end

          #strip operator characters, replace human boolean words with operators, support google's convention of "-" == "not"
          q = q.strip.gsub("&"," ").gsub("|"," ").gsub("!"," ").gsub(","," ").gsub("'","''").gsub(" -"," !").gsub(" and ", "&").gsub(" or ","|")

          #join everything back up and "and" them together
          q.split(" ").join(" & ")
        end
        
        #checks to see if vector column exists.  if it doesn't exist, create it and update isn't index.
        def check_for_vector_column
          #check for the basics
          if !column_names().include?("vectors")
            puts "Creating vector column"
            create_vector
            puts "Update vector index"
            update_vector
            # raise "Table is missing column [vectors].  Run method create_vector and then 
            # update_vector to create this column and populate it."
          end
        end

        #current just falls through if it fails... this needs work
        def create_vector
          if !column_names().include?("vectors")
            begin
              sql = "alter table #{table_name} add column vectors tsvector"
              connection.execute(sql)
              reset_column_information
            rescue
              puts "Error adding vectors column"
            end

            sql = []
            sql << "drop index #{table_name}_fts_index"
            sql << "CREATE INDEX #{table_name}_fts_index 
               ON #{table_name}
               USING gist(vectors)"
            sql.each do |s|
              begin
                connetion.execute(s)
              rescue 
                puts "Error executing #{s}"
              end
            end

          end
        end
        
        #This will update the vector colum for all rows (unless a row_id is passed).  If you think your indexes are screwed
        #up try running this.  This get's called by the callback after_update when you change your model.
        def update_vector(row_id = nil)
          check_for_vector_column
          
          if !@tsearch_config[:fields]
            errmsg = "Missing required fields key from acts_as_tsearch ... try something like this: 
                    acts_as_tsearch :fields => 'title'
                    
                    or
                    
                    acts_as_tsearch :fields => [:title, :description] 
                    
                    or something more complex examples like: 
                    
                    acts_as_tsearch  :fields => {
                             :a_fields => {:columns => [:title], :weight => 1.0},
                             :b_fields => {:columns => [:description], :weight => 0.4},
                             :c_fields => {:columns => [:name], :weight => 0.2}
                            }
                            "
            raise errmsg
          else
            fields = @tsearch_config[:fields]
            if fields.is_a?(Array)
              sql = "update #{table_name} set vectors = to_tsvector('#{@tsearch_config[:tsearch_locale]}',#{coalesce_array(fields)})"
            elsif fields.is_a?(String)
              sql = "update #{table_name} set vectors = to_tsvector('#{@tsearch_config[:tsearch_locale]}',
                     #{fields})"
            elsif fields.is_a?(Hash)
              if fields.size > 4
                raise "acts_as_tsearch currently only supports up to 4 weighted sets."
              else
                setweights = []
                ["a","b","c","d"].each do |f|
                  if fields[f]
                    setweights << "setweight( to_tsvector('#{@tsearch_config[:tsearch_locale]}', 
                                    #{coalesce_array(fields[f][:columns])}),'#{f.upcase}')
                                    "
                  end
                end
                sql = "update #{table_name} set vectors = #{setweights.join(" || ")}"
              end
            else
              raise ":fields was not an Array, Hash or a String."
            end
            if !row_id.nil?
              sql << " where id = #{row_id}"
            end
            connection.execute(sql)
            puts sql
          end
        end

        def coalesce_array(arr)
          res = []
          arr.each do |f|
            res << "coalesce(#{f},'')"
          end
          return res.join(" || ' ' || ")        
        end

      end
      
      # Adds instance methods.
      module InstanceMethods
        def update_vector_row
          self.class.update_vector(self.id)
        end
      end

    end
  end
end

# reopen ActiveRecord and include all the above to make
# them available to all our models if they want it

ActiveRecord::Base.class_eval do
  include TsearchMixin::Acts::Tsearch
end