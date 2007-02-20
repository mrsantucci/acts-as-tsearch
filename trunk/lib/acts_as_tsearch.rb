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
        def tsearch_config
          @tsearch_config
        end

        def acts_as_tsearch(options = {})
          default_config = {:locale => "default", :auto_update_index => true}
          @tsearch_config = {}
          if !options.is_a?(Hash)
            raise "Missing required fields for acts_as_tsearch.  At a bare minimum you need :fields => 'SomeFileName'.  Please see
            documentation on http://acts-as-tsearch.rubyforge.org"
          else
            fields = []
            #they passed in :fields => "somefield" or :fields => [:one, :two, :three]
            #:fields => "somefield"
            if options[:fields].is_a?(String)
              @tsearch_config = {:vectors => default_config}
              @tsearch_config[:vectors][:fields] = 
                {"a" => {:columns => [options[:fields]], :weight => 1.0}}
              fields << options[:fields]
            #:fields => [:one, :two]
            elsif options[:fields].is_a?(Array)
              @tsearch_config = {:vectors => default_config}
              @tsearch_config[:vectors][:fields] = 
                {"a" => {:columns => options[:fields], :weight => 1.0}}
              fields = options[:fields]
            # :fields => {"a" => {:columns => [:one, :two], :weight => 1},
            #              "b" => {:colums => [:three, :four], :weight => 0.5}
            #              }
            elsif options[:fields].is_a?(Hash)
              @tsearch_config = {:vectors => default_config}
              @tsearch_config[:vectors][:fields] = options[:fields]
              options[:fields].keys.each do |k|
                options[:fields][:k][:columns].each do |f|
                  fields << f
                end
              end
            else
              # :vectors => {
              #   :auto_update_index => false,
              #   :fields => [:title, :description]
              # }
              options.keys.each do |k|
                @tsearch_config[k] = default_config
                @tsearch_config[k].update(options[k])
                options[k][:fields].keys.each do |kk|
                  options[k][:fields][kk][:columns].each do |f|
                    fields << f
                  end
                end
                #TODO: add error checking here for complex fields - right know - assume it's correct
              end
            end
            
            fields.uniq!
            #check to make sure all fields exist
            missing_fields = []
            fields.each do |f|
              missing_fields << f.to_s unless column_names().include?(f.to_s)
            end
            raise ArgumentError, "Missing fields: #{missing_fields.sort.join(",")} in acts_as_tsearch definition for table #{table_name}" if missing_fields.size > 0
          end
          
          class_eval do
            after_save :update_vector_row
          
            extend TsearchMixin::Acts::Tsearch::SingletonMethods
          end
          include TsearchMixin::Acts::Tsearch::InstanceMethods
        end
      end

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
        #   locals:  TODO:  Document this... see
        #                  http://www.sai.msu.su/~megera/postgres/gist/tsearch/V2/docs/tsearch-V2-intro.html for details
        #
        #TODO:  Not sure how to handle order... current we add to it if it exists but this might not
        #be the right thing to do
        def find_by_tsearch(search_string, options = {}, tsearch_options = {})
          tsearch_options[:vector] = "vectors" unless tsearch_options[:vector]
          tsearch_options[:fix_query] = true unless tsearch_options[:fix_query]
          locale = @tsearch_config[tsearch_options[:vector].intern][:locale]
          check_for_vector_column(tsearch_options[:vector])
          
          search_string = fix_tsearch_query(search_string) if tsearch_options[:fix_query] == true
          
          #add tsearch_rank to fields returned
          select_part = "rank_cd(#{table_name}.vectors,tsearch_query) as tsearch_rank"
          if options[:select]
            options[:select] << ", #{select_part}"
          else
            options[:select] = "#{table_name}.*, #{select_part}"
          end
          
          #add headlines
          if tsearch_options[:headlines]
            tsearch_options[:headlines].each do |h|
              options[:select] << ", headline('#{locale}',#{table_name}.#{h},tsearch_query) as #{h}_headline"
            end
          end
          
          #add tsearch_query to from
          from_part = "to_tsquery('#{locale}','#{search_string}') as tsearch_query"
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
          
          order_part = "tsearch_rank desc"
          if !options[:order]
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
        def check_for_vector_column(vector_name = "vectors")
          #check for the basics
          if !column_names().include?(vector_name)
            puts "Creating vector column"
            create_vector(vector_name)
            puts "Update vector index"
            update_vector(nil,vector_name)
            # raise "Table is missing column [vectors].  Run method create_vector and then 
            # update_vector to create this column and populate it."
          end
        end

        #current just falls through if it fails... this needs work
        def create_vector(vector_name = "vectors")
          sql = []
          if column_names().include?(vector_name)
            sql << "alter table #{table_name} drop column #{vector_name}"
          end
          sql << "alter table #{table_name} add column #{vector_name} tsvector"
          sql << "CREATE INDEX #{table_name}_fts_#{vector_name}_index ON #{table_name} USING gist(#{vector_name})"
          sql.each do |s|
            begin
              connection.execute(s)
              puts s
              reset_column_information
            rescue StandardError => bang
              puts "Error in create_vector executing #{s} " + bang.to_yaml
              puts ""
            end
          end
        end
        
        def update_vectors(row_id = nil)
          @tsearch_config.keys.each do |k|
            update_vector(row_id, k.to_s)
          end
        end
        
        #This will update the vector colum for all rows (unless a row_id is passed).  If you think your indexes are screwed
        #up try running this.  This get's called by the callback after_update when you change your model.
        def update_vector(row_id = nil, vector_name = "vectors")
          if !column_names().include?(vector_name)
            create_vector(vector_name)
          end
          if !@tsearch_config[vector_name.intern]
            raise "Missing vector #{vector_name} in hash #{@tsearch_config.to_yaml}"
          else
            locale = @tsearch_config[vector_name.intern][:locale]
            fields = @tsearch_config[vector_name.intern][:fields]
            if fields.is_a?(Array)
              sql = "update #{table_name} set #{vector_name} = to_tsvector('#{locale}',#{coalesce_array(fields)})"
            elsif fields.is_a?(String)
              sql = "update #{table_name} set #{vector_name} = to_tsvector('#{locale}',
                     #{fields})"
            elsif fields.is_a?(Hash)
              if fields.size > 4
                raise "acts_as_tsearch currently only supports up to 4 weighted sets."
              else
                setweights = []
                ["a","b","c","d"].each do |f|
                  if fields[f]
                    setweights << "setweight( to_tsvector('#{locale}', 
                                    #{coalesce_array(fields[f][:columns])}),'#{f.upcase}')
                                    "
                  end
                end
                sql = "update #{table_name} set #{vector_name} = #{setweights.join(" || ")}"
              end
            else
              raise ":fields was not an Array, Hash or a String."
            end
            if !row_id.nil?
              sql << " where id = #{row_id}"
            end
            connection.execute(sql)
            puts sql
          end #tsearch config test
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
          self.class.tsearch_config.keys.each do |k|
            if self.class.tsearch_config[k][:auto_update_index] == true
              self.class.update_vector(self.id,k.to_s)
            end
          end
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