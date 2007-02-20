ActiveRecord::Schema.define(:version => 1) do
  
  # Create tables for testing your plugin

   begin
     drop_table :blog_entries
   rescue
   end
   
   create_table :blog_entries do |t|
     t.column :title,   :string
     t.column :description, :text
   end
    
end
