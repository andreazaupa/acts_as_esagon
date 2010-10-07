class <%= migration_name %> < ActiveRecord::Migration
  
<% list_of_models.each do |model| -%>
  class <%= model.camelize %> < ActiveRecord::Base
  end
<% end -%>

  def self.up
<% list_of_models.each do |model| -%>
<% klass = model.camelize.constantize -%>
    say_with_time 'Adding Esagon fields to <%= klass %>...' do
      change_table(:<%= klass.table_name %>) do |t|
         t.datetime :<%= klass.esagon_binding_properties[:name] %>_LM
         t.string :<%= klass.esagon_binding_properties[:name] %>_OW
         t.string :<%= klass.esagon_binding_properties[:name] %>_OL, :default => 'true'
      end
    end
<% end -%>
  end
  
  def self.down
<% list_of_models.each do |model| -%>
<% klass = model.camelize.constantize -%>
    say_with_time 'Removing Esagon fields from <%= model.camelize %>...' do
<% ['LM', 'OW', 'OL'].each do |e| -%>
      remove_column :<%= klass.table_name %>, :<%= "#{klass.esagon_binding_properties[:name]}_#{e}" %>
<% end -%>
    end
<% end -%>
  end
end
